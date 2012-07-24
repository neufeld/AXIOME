/* Separate Illumina FASTQ reads by index tag and discard any degenerate sequences */
#include<bzlib.h>
#include<ctype.h>
#include<errno.h>
#if !defined(__APPLE__)
#include<error.h>
#endif
#include<fcntl.h>
#include<stdbool.h>
#include<stdio.h>
#include<stdlib.h>
#include<sys/stat.h>
#include<time.h>
#include<unistd.h>
#include<zlib.h>
#include<glib.h>
#include<glib-object.h>
#include "fmap.h"
#include "config.h"
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
	bool bzip = false;
	char *filename = NULL;
	void *file;
	kseq_t *seq;
	int len;
	int n = 0;
	bool no_n = false;
	seqidentifier id;
	g_type_init();
	files_init();
	/* Process command line arguments. */
	while ((c = getopt(argc, argv, "jf:n")) != -1) {
		switch (c) {
		case 'j':
			fileopen = (void *(*)(char *, char *))BZ2_bzopen;
			fileread = (int (*)(void *, void *, int))bzread;
			fileclose = (int (*)(void *))BZ2_bzclose;
			bzip = true;
			break;
		case 'f':
			filename = optarg;
			break;
		case 'n':
			no_n = true;
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
			"Usage: %s [-j] [-n] -f file.fastq tag1 tag2 ...\n\t-j\tInput files are bzipped.\n\t-n\tDiscard sequences with Ns.\n",
			argv[0]);
		return 1;
	}

	/* Open files and initialise FASTQ reader. */
	file = fileopen(filename, "r");
	if (file == NULL) {
		perror(filename);
		return 1;
	}
	seq = kseq_init(file);

	for (c = optind; c < argc; c++){
				FILE *f;
				char buffer[FILENAME_MAX];
				snprintf(buffer, FILENAME_MAX, "%s.%s",
					 filename, argv[c]);
				f = fopen(buffer, "w");
				if (f == NULL) {
					perror(buffer);
					return 1;
				}
				files_put(argv[c], f);
				fprintf(stderr, "FOPN %s\n", buffer);
	}
	while ((len = kseq_read(seq)) >= 0) {
		unsigned long hash;
		int index;
		int ncount = 0;
		FILE *f;

		n++;
		if (no_n) {
			for (index = 0; index < seq->seq.l; index++) {
				if (seq->seq.s[index] == 'N') {
					ncount++;
					break;
				}
			}
			if (ncount > 0) {
				fprintf(stderr, "SKIP %s\n", seq->name.s);
				continue;
			}
		}
		if (seqid_parse(&id, seq->name.s) == 0) {
			fprintf(stderr, "BAD HEADER %s\n", seq->name.s);
			continue;
		}
		if (!files_write(id.tag, ">%s_%d\n%s\n", id.tag, n, seq->seq.s)) {
			fprintf(stderr, "EBADF %s\n", id.tag);
		}
	}
	kseq_destroy(seq);
	files_finish();
	if (fileclose(file) != Z_OK && bzip == 0) {
		perror(filename);
	}
	return 0;
}
