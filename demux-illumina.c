/* Separate Illumina FASTQ reads by index tag and discard any degenerate sequences */
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
#include<glib.h>
#include<glib-object.h>
#include<gee.h>
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

static unsigned long sdbm(str)
unsigned char *str;
{
	unsigned long hash = 0;
	int c;

	while (c = *str++)
		hash = c + (hash << 6) + (hash << 16) - hash;

	return hash;
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
	int n = 0;
	GeeHashMap* files;
	g_type_init();
	files = gee_hash_map_new(G_TYPE_STRING, (GBoxedCopyFunc) g_strdup, g_free, G_TYPE_POINTER, NULL, (GDestroyNotify) fclose, NULL, NULL, NULL);

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
			"Usage: %s [-j] -f file.fastq tag1 tag2 ...\n\t-j\tInput files are bzipped.\n",
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
				gee_abstract_map_set((GeeAbstractMap*) files, argv[c], f);
				fprintf(stderr, "FOPN %s\n", buffer);
	}
	while ((len = kseq_read(seq)) >= 0) {
		unsigned long hash;
		int index;
		int ncount = 0;
		FILE *f;
		char *indextag;

		n++;
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

		for (index = 0; index < seq->name.l; index++) {
			if (seq->name.s[index] == '#') {
				break;
			}
		}
		indextag = seq->name.s + index + 1;
		if (index + 7 >= seq->name.l) {
			continue;
		}
		indextag[6] = '\0';
		f = gee_abstract_map_get ((GeeAbstractMap*) files, indextag);
		if (f == NULL) {
			fprintf(stderr, "EBADF %s\n", indextag);
		} else {
			fprintf(f, ">%s_%d\n%s\n", indextag, n,
					seq->seq.s);
		}
	}
	kseq_destroy(seq);
	g_object_unref(files);
	if (fileclose(file) != Z_OK && bzip == 0) {
		perror(filename);
	}
	return 0;
}
