NULL=
ACLOCAL_AMFLAGS = -I m4
bin_SCRIPTS = \
	aq-base \
	aq-biplot \
	aq-bubbleplot \
	aq-cmplibs \
	aq-fasta-length \
	aq-libcontrib \
	aq-oldillumina2fastq \
	aq-otu2lnotu \
	aq-otu2pcord \
	aq-otubinner \
	aq-otuhistogram \
	aq-otunolineage \
	aq-otuplothistogram \
	aq-otusum \
	aq-otutop \
	aq-otuwithseqs \
	aq-pca \
	aq-pretendsummarize \
	aq-qualityanal \
	aq-rareotuwithlineage \
	aq-sort-fasta \
	$(NULL)

bin_PROGRAMS= \
	autoqiime \
	aq-count-n \
	aq-demux-illumina \
	aq-estimateq \
	aq-fastq2oldillumina \
	aq-filter-fastq-known \
	aq-joinn \
	aq-marry-illumina-index \
	aq-mkrepset \
	aq-qualhisto \
	aq-syntheticfastq \
	$(NULL)

docdir = $(datadir)/doc/@PACKAGE@
dist_pkgdata_DATA = primers.lst
doc_DATA = \
	sample.aq \
	$(NULL)

aq_count_n_CFLAGS = 
aq_count_n_SOURCES = count-n.c
aq_demux_illumina_CFLAGS = $(GLIB_CFLAGS) $(GEE_CFLAGS)
aq_demux_illumina_LDADD = $(GLIB_LIBS) $(GEE_LIBS)
aq_demux_illumina_SOURCES = demux-illumina.c
aq_estimateq_CFLAGS = 
aq_estimateq_SOURCES = estimateq.c
aq_fastq2oldillumina_CFLAGS = 
aq_fastq2oldillumina_SOURCES = fastq2oldillumina.c
aq_filter_fastq_known_CFLAGS = 
aq_filter_fastq_known_SOURCES = filter-fastq-known.c
aq_marry_illumina_index_CFLAGS = 
aq_marry_illumina_index_SOURCES = marry-illumina-index.c
aq_qualhisto_CFLAGS = 
aq_qualhisto_SOURCES = qualhisto.c parser.c
aq_syntheticfastq_CFLAGS = 
aq_syntheticfastq_SOURCES = syntheticfastq.c

aq_joinn_CFLAGS = $(GLIB_CFLAGS)
aq_joinn_VALASOURCES = joinn.vala
aq_joinn_LDADD = $(GLIB_LIBS)
aq_joinn_SOURCES = joinn.vala.stamp $(aq_joinn_VALASOURCES:.vala=.c)
aq_mkrepset_CFLAGS = $(GLIB_CFLAGS) $(GEE_CFLAGS)
aq_mkrepset_LDADD = $(GLIB_LIBS) $(GEE_LIBS)
aq_mkrepset_VALASOURCES = mkrepset.vala
aq_mkrepset_SOURCES = mkrepset.vala.stamp $(aq_mkrepset_VALASOURCES:.vala=.c)
autoqiime_CFLAGS = -DBINDIR=\"$(bindir)\" -DDATADIR=\"$(pkgdatadir)\" $(GLIB_CFLAGS) $(GEE_CFLAGS) $(LIBXML_CFLAGS)
autoqiime_LDADD = $(GLIB_LIBS) $(GEE_LIBS) $(LIBXML_LIBS)
autoqiime_VALASOURCES = autoqiime.vala
autoqiime_SOURCES = autoqiime.vala.stamp $(autoqiime_VALASOURCES:.vala=.c)

autoqiime.vala.stamp $(autoqiime_VALASOURCES:.vala=.c): $(autoqiime_VALASOURCES)
	$(VALAC) $(VALAFLAGS) -g -C --vapidir=. --pkg=libmagic --pkg=gee-1.0 --pkg=libxml-2.0 $(autoqiime_VALASOURCES)

joinn.vala.stamp $(aq_joinn_VALASOURCES:.vala=.c): $(aq_joinn_VALASOURCES)
	$(VALAC) $(VALAFLAGS) -g -C  $(aq_joinn_VALASOURCES)

mkrepset.vala.stamp $(aq_mkrepset_VALASOURCES:.vala=.c): $(aq_mkrepset_VALASOURCES)
	$(VALAC) $(VALAFLAGS) -g -C --pkg=gee-1.0 --pkg=posix $(aq_mkrepset_VALASOURCES)

