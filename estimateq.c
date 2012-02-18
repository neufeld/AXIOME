/* Estimate error probability from tags an Illumina FASTQ read */
#include<bzlib.h>
#include<ctype.h>
#include<errno.h>
#if !defined(__APPLE__)
#include<error.h>
#endif
#include<fcntl.h>
#include<stdio.h>
#include<stdlib.h>
#include<sys/stat.h>
#include<time.h>
#include<unistd.h>
#include<zlib.h>
#include "kseq.h"
#include "parser.h"

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
	char *filename = NULL;
	void *file;
	kseq_t *seq;
	int len;
	int taglen;
	int i, j;
	int count = 0;
	int totalmismatches = 0;

	/* Process command line arguments. */
	while ((c = getopt(argc, argv, "jf:")) != -1) {
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
		case '?':
			if (optopt == (int)'f') {
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

	if (filename == NULL) {
		fprintf(stderr,
			"Usage: %s [-j] -f file.fastq\n\t-j\tInput files are bzipped.\n",
			argv[0]);
		return 1;
	}

	taglen = strlen(argv[optind]);
	for (i = optind + 1; i < argc; i++) {
		if (strlen(argv[i]) != taglen) {
			fprintf(stderr,
				"Primer %s is not of the same length.\n",
				argv[i]);
			return 1;
		}
	}
	printf("PRIMERS = %d\nTAGLEN = %d\n", argc - optind, taglen);

	/* Open files and initialise FASTQ reader. */
	file = fileopen(filename, "r");
	if (file == NULL) {
		perror(filename);
		return 1;
	}
	seq = kseq_init(file);

	while ((len = kseq_read(seq)) >= 0) {
		int bestmismatches = taglen;
		seqidentifier id;
		if (seqid_parse(&id, seq->name.s) == 0)
			continue;

		for (i = optind; i < argc; i++) {
			int mismatches = 0;
			int k;
			if (strlen(id.tag) != taglen) {
				printf("Tags specified are of length %d, but tag in file has length %d. Skipping.\n", taglen, (int)strlen(id.tag));
				continue;
			}
			for (k = 0; k < taglen; k++) {
				if (id.tag[k] != argv[i][k]) {
					mismatches++;
				}
			}
			if (mismatches < bestmismatches) {
				bestmismatches = mismatches;
			}
		}
		count++;
		totalmismatches += bestmismatches;
	}
	kseq_destroy(seq);
	printf("TOTAL = %d\nMISMATCHES = %d\nQ = %f\n", count * taglen,
	       totalmismatches, (1.0 * totalmismatches) / (count * taglen));
	if (fileclose(file) != Z_OK && bzip == 0) {
		perror(filename);
	}
	return 0;
}
