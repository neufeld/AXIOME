/* Stick indicies on CASAVA 1.8 runs */
#include<bzlib.h>
#include<ctype.h>
#include<errno.h>
#if !defined(__APPLE__)
#include<error.h>
#endif
#include<fcntl.h>
#include<math.h>
#include<stdio.h>
#include<stdlib.h>
#include<sys/stat.h>
#include<time.h>
#include<unistd.h>
#include<zlib.h>
#include "kseq.h"

/* Function pointers for file I/O such that we can deal with compressed files. */
void *(*fileopen) (char *, char *) = (void *(*)(char *, char *))gzopen;
int (*fileread) (void *, void *, int) = (int (*)(void *, void *, int))gzread;
int (*fileclose) (void *) = (int (*)(void *))gzclose;

/* Compatibility function to make BZ2_bzRead look like gzread. */
int bzread(BZFILE * file, void *buf, int len)
{
	int bzerror = BZ_OK;
	int retval = BZ2_bzRead(&bzerror, file, buf, len);
	if (bzerror == BZ_OK || bzerror == BZ_STREAM_END) {
		return retval;
	} else {
		fprintf(stderr, "bzip error %d\n", bzerror);
		return -1;
	}
}

KSEQ_INIT(void *, fileread)

int main(int argc, char **argv)
{
	int c;
	int bzip = 0;
	char *indexfilename = NULL;
	char *filename = NULL;
	void *indexfile;
	void *file;
	kseq_t *seq;
	kseq_t *indexseq;
	int len;

	/* Process command line arguments. */
	while ((c = getopt(argc, argv, "ji:f:")) != -1) {
		switch (c) {
		case 'j':
			fileopen = (void *(*)(char *, char *))BZ2_bzopen;
			fileread = (int (*)(void *, void *, int))bzread;
			fileclose = (int (*)(void *))BZ2_bzclose;
			bzip = 1;
			break;
		case 'f':
			filename = optarg;
			break;
		case 'i':
			indexfilename = optarg;
			break;
		case '?':
			if (optopt == (int)'i' || optopt == (int)'f') {
				fprintf(stderr,
					"Option -%c requires an argument.\n",
					optopt);
			} else if (isprint(optopt)) {
				fprintf(stderr,
					"Unknown option `-%c'.\n", optopt);
			} else {
				fprintf(stderr,
					"Unknown option character `\\x%x'.\n",
					(unsigned int)optopt);
			}
			return 1;
		default:
			abort();
		}
	}

	if (filename == NULL || indexfilename == NULL) {
		fprintf(stderr,
			"Usage: %s [-j] -i indices.fastq -f read.fastq\n\t-j\tInput files are bzipped.\n",
			argv[0]);
		return 1;
	}

	/* Open files and initialise FASTQ reader. */
	file = fileopen(filename, "r");
	if (file == NULL) {
		perror(filename);
		return 1;
	}
	indexfile = fileopen(indexfilename, "r");
	if (indexfile == NULL) {
		perror(indexfilename);
		return 1;
	}
	seq = kseq_init(file);
	indexseq = kseq_init(indexfile);
	while ((len = kseq_read(seq)) >= 0 && (len = kseq_read(indexseq)) >= 0) {
		printf("@%s%s\n%s\n+\n%s\n", seq->name.s, indexseq->seq.s, seq->seq.s, seq->qual.s);
	}
	kseq_destroy(seq);
	kseq_destroy(indexseq);
	if (fileclose(file) != Z_OK && bzip == 0) {
		perror(filename);
	}
	if (fileclose(indexfile) != Z_OK && bzip == 0) {
		perror(indexfilename);
	}
	return 0;
}
