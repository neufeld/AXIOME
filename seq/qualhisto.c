/* Produce a sumary of quality information per site in an Illumina FASTQ read */
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
#define MAXNT 512
int n[MAXNT];
double mean[MAXNT];
double m2[MAXNT];

int main(int argc, char **argv)
{
	int c;
	int bzip = 0;
	char *filename = NULL;
	void *file;
	kseq_t *seq;
	int len;
	int i;

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

	/* Open files and initialise FASTQ reader. */
	file = fileopen(filename, "r");
	if (file == NULL) {
		perror(filename);
		return 1;
	}
	seq = kseq_init(file);

	for (i = 0; i < MAXNT; i++) {
		n[i] = 0;
		mean[i] = 0;
		m2[i] = 0;
	}

	while ((len = kseq_read(seq)) >= 0) {
		for (i = 0; i < seq->qual.l && i < MAXNT; i++) {
			double delta;
			n[i]++;
			delta = seq->qual.s[i] - '@' - mean[i];
			mean[i] += delta / n[i];
			m2[i] += delta * (seq->qual.s[i] - '@' - mean[i]);
		}
	}
	kseq_destroy(seq);

	for (i = 0; i < MAXNT && n[i] > 0; i++) {
		double variance_n = m2[i] / n[i];
		printf("%d	%f	%f\n", i, mean[i], m2[i] / (n[i] - 1));
	}
	if (fileclose(file) != Z_OK && bzip == 0) {
		perror(filename);
	}
	return 0;
}
