/* Count Ns in an Illumina FASTQ read */
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
	char *filename = NULL;
	void *file;
	kseq_t *seq;
	int len;
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

	for (i = optind; i < argc; i++) {
		if (strlen(argv[i]) != 6) {
			fprintf(stderr,
				"Primer %s is not of the right length.\n",
				argv[i]);
			return 1;
		}
	}
	printf("PRIMERS = %d\n", argc - optind);

	/* Open files and initialise FASTQ reader. */
	file = fileopen(filename, "r");
	if (file == NULL) {
		perror(filename);
		return 1;
	}
	seq = kseq_init(file);

	while ((len = kseq_read(seq)) >= 0) {
		int bestmismatches = 6;

		for (j = 0; j < seq->name.l && seq->name.s[j] != '#'; j++) ;

		if (j + 6 >= seq->name.l)
			continue;

		for (i = optind; i < argc; i++) {
			int mismatches = 0;
			int k;
			for (k = 0; k < 6; k++) {
				if (seq->name.s[j + k + 1] != argv[i][k]) {
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
	printf("TOTAL = %d\nMISMATCHES = %d\nQ = %f\n", count * 6,
	       totalmismatches, (1.0 * totalmismatches) / (count * 6));
	if (fileclose(file) != Z_OK && bzip == 0) {
		perror(filename);
	}
	return 0;
}
