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
	int maxn;

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

	printf("#x	y	n	len	qbar	qsd	bcliff\n");
	while ((len = kseq_read(seq)) >= 0) {
		int ncnt = 0;
		double seqmean = 0;
		double seqm2 = 0;
		char *x;
		char *y;
		int colons = 0;
		int bclifflen = 0;

		for (i = 0; i < seq->name.l; i++) {
			if (seq->name.s[i] == ':' || seq->name.s[i] == '#') {
				colons++;
				if (colons ==  3) {
					x = seq->name.s + i + 1;
				} else if (colons == 4) {
					y = seq->name.s + i + 1;
				}

				if (colons == 4 || colons == 5) {
					seq->name.s[i] = '\0';
				}
			}
		}

		if (colons != 5) continue;

		for (i = 0; i < seq->seq.l; i++) {
			if (seq->seq.s[i] == 'N') ncnt++;
		}

		for (i = (seq->qual.l > MAXNT ? MAXNT : seq->qual.l) - 1; i > 0 && seq->qual.s[i] == 'B'; i--) bclifflen++;
		for (; i > 0; i--) {
			double delta;
			double seqdelta;
			n[i]++;
			delta = seq->qual.s[i] - '@' - mean[i];
			seqdelta = seq->qual.s[i] - '@' - seqmean;
			mean[i] += delta / n[i];
			seqmean += seqdelta / (i + 1);
			m2[i] += delta * (seq->qual.s[i] - '@' - mean[i]);
			seqm2 += seqdelta * (seq->qual.s[i] - '@' - seqmean);
		}
		printf("%s\t%s\t%d\t%d\t%f\t%f\t%d\n", x, y, ncnt, (int)seq->seq.l, seqmean, seqm2 / (seq->seq.l - 1), bclifflen);
	}
	kseq_destroy(seq);

	for (maxn = MAXNT; maxn > 0 && n[maxn-1] == 0; maxn--);

	for (i = 0; i < maxn; i++) {
		double variance_n = m2[i] / n[i];
		fprintf(stderr, "%d	%f	%f\n", i, mean[i], m2[i] / (n[i] - 1));
	}
	if (fileclose(file) != Z_OK && bzip == 0) {
		perror(filename);
	}
	return 0;
}
