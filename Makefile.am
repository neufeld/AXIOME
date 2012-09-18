NULL=
ACLOCAL_AMFLAGS = -I m4
bin_SCRIPTS = \
	aq-base \
	aq-biplot \
	aq-bubbleplot \
	aq-cmplibs \
	aq-duleg \
	aq-fasta-length \
	aq-inst-cran \
	aq-libcontrib \
	aq-mothur-base \
	aq-mothur-alpha \
	aq-mrpp \
	aq-mrpp-unifrac \
	aq-nmf \
	aq-nmf-concordance \
	aq-oldillumina2fastq \
	aq-orderotu \
	aq-otu2lnotu \
	aq-otu2pcord \
	aq-otubinner \
	aq-otuhistogram \
	aq-otunolineage \
	aq-otuplothistogram \
	aq-otusum \
	aq-otutop \
	aq-pca \
	aq-pcoa \
	aq-pretendsummarize \
	aq-qiime-base \
	aq-qualityanal \
	aq-rareotuwithlineage \
	aq-sort-fasta \
	aqxs \
	$(NULL)

bin_PROGRAMS= \
	axiome \
	aq-count-n \
	aq-demux-illumina \
	aq-estimateq \
	aq-fastq2oldillumina \
	aq-filter-fastq-known \
	aq-joinn \
	aq-marry-illumina-index \
	aq-marry-otu-names \
	aq-mkrepset \
	aq-otuwithseqs \
	aq-otudulegmerge \
	aq-qualhisto \
	aq-syntheticfastq \
	$(NULL)

dist_include_HEADERS = axiome.h

vapidir = $(datadir)/vala/vapi
dist_vapi_DATA = axiome.vapi axiome.deps

man1_MANS = \
	axiome.1 \
	aq-base.1 \
	aq-biplot.1 \
	aq-bubbleplot.1 \
	aq-cmplibs.1 \
	aq-count-n.1 \
	aq-demux-illumina.1 \
	aq-duleg.1 \
	aq-estimateq.1 \
	aq-fasta-length.1 \
	aq-fastq2oldillumina.1 \
	aq-filter-fastq-known.1 \
	aq-inst-cran.1 \
	aq-joinn.1 \
	aq-libcontrib.1 \
	aq-marry-illumina-index.1 \
	aq-marry-otu-names.1 \
	aq-mkrepset.1 \
	aq-mothur-alpha.1 \
	aq-mrpp.1 \
	aq-mrpp-unifrac.1 \
	aq-nmf-concordance.1 \
	aq-nmf.1 \
	aq-oldillumina2fastq.1 \
	aq-orderotu.1 \
	aq-otu2lnotu.1 \
	aq-otu2pcord.1 \
	aq-otubinner.1 \
	aq-otuhistogram.1 \
	aq-otunolineage.1 \
	aq-otuplothistogram.1 \
	aq-otusum.1 \
	aq-otutop.1 \
	aq-otuwithseqs.1 \
	aq-otudulegmerge.1 \
	aq-pca.1 \
	aq-pcoa.1 \
	aq-pretendsummarize.1 \
	aq-qualhisto.1 \
	aq-qualityanal.1 \
	aq-rareotuwithlineage.1 \
	aq-sort-fasta.1 \
	aq-syntheticfastq.1 \
	aqxs.1 \
	autoqiime.1 \
	$(NULL)

docdir = $(datadir)/doc/@PACKAGE@
dist_pkgdata_DATA = \
	nmf.R \
	biom.R \
	primers.lst \
	aq-module.vala \
	plugins/sample.vala \
	$(NULL)

doc_DATA = \
	sample.ax \
	$(NULL)

aq_count_n_CPPFLAGS = 
aq_count_n_SOURCES = count-n.c
aq_demux_illumina_CPPFLAGS = $(GLIB_CFLAGS) $(GEE_CFLAGS)
aq_demux_illumina_LDADD = $(GLIB_LIBS) $(GEE_LIBS)
aq_demux_illumina_SOURCES = fmap.c demux-illumina.c parser.c
aq_estimateq_CPPFLAGS = 
aq_estimateq_SOURCES = estimateq.c parser.c
aq_fastq2oldillumina_CPPFLAGS = 
aq_fastq2oldillumina_SOURCES = fastq2oldillumina.c
aq_filter_fastq_known_CPPFLAGS = 
aq_filter_fastq_known_SOURCES = filter-fastq-known.c
aq_marry_illumina_index_CPPFLAGS = 
aq_marry_illumina_index_SOURCES = marry-illumina-index.c
aq_qualhisto_CPPFLAGS = 
aq_qualhisto_SOURCES = qualhisto.c parser.c
aq_syntheticfastq_CPPFLAGS = 
aq_syntheticfastq_SOURCES = syntheticfastq.c

aq_joinn_CPPFLAGS = $(GLIB_CFLAGS)
aq_joinn_VALASOURCES = joinn.vala
aq_joinn_LDADD = $(GLIB_LIBS)
aq_joinn_SOURCES = $(aq_joinn_VALASOURCES:.vala=.c)
aq_marry_otu_names_CPPFLAGS = $(GLIB_CFLAGS) $(GEE_CFLAGS)
aq_marry_otu_names_VALASOURCES = marry-otu.vala
aq_marry_otu_names_LDADD = $(GLIB_LIBS) $(GEE_LIBS)
aq_marry_otu_names_SOURCES = $(aq_marry_otu_names_VALASOURCES:.vala=.c)
aq_mkrepset_CPPFLAGS = $(GLIB_CFLAGS) $(GEE_CFLAGS)
aq_mkrepset_LDADD = $(GLIB_LIBS) $(GEE_LIBS)
aq_mkrepset_VALASOURCES = mkrepset.vala
aq_mkrepset_SOURCES = $(aq_mkrepset_VALASOURCES:.vala=.c) fasta.c
aq_otuwithseqs_CPPFLAGS = $(GLIB_CFLAGS) $(GEE_CFLAGS)
aq_otuwithseqs_LDADD = $(GLIB_LIBS) $(GEE_LIBS)
aq_otuwithseqs_VALASOURCES = otuwithseqs.vala
aq_otuwithseqs_SOURCES = $(aq_otuwithseqs_VALASOURCES:.vala=.c) fasta.c
aq_otudulegmerge_CPPFLAGS = $(GLIB_CFLAGS) $(GEE_CFLAGS)
aq_otudulegmerge_LDADD = $(GLIB_LIBS) $(GEE_LIBS)
aq_otudulegmerge_VALASOURCES = otudulegmerge.vala
aq_otudulegmerge_SOURCES = $(aq_otudulegmerge_VALASOURCES:.vala=.c)
axiome_CPPFLAGS = -DBINDIR=\"$(bindir)\" -DDATADIR=\"$(pkgdatadir)\" -DMODDIR=\"$(pkglibdir)\" $(GLIB_CFLAGS) $(GEE_CFLAGS) $(LIBXML_CFLAGS) $(GMODULE_CFLAGS) $(GIO_CFLAGS)
axiome_LDADD = $(GLIB_LIBS) $(GEE_LIBS) $(LIBXML_LIBS) $(GMODULE_LIBS) $(GIO_LIBS)
axiome_VALAFLAGS = --vapidir=. --pkg=config --pkg=libmagic --pkg=gee-$(GEE_VER) --pkg=libxml-2.0 --pkg=gmodule-2.0 --pkg=gio-2.0
axiome_VALASOURCES = \
	axiome.vala \
	plugins/a-alpha.vala \
	plugins/a-beta.vala \
	plugins/a-blast.vala \
	plugins/a-blast-classifier.vala \
	plugins/a-duleg.vala \
	plugins/a-excludetaxa.vala \
	plugins/a-heatmap.vala \
	plugins/a-jackknife.vala \
	plugins/a-libcmp.vala \
	plugins/a-mrpp.vala \
	plugins/a-multicore.vala \
	plugins/a-nmf.vala \
	plugins/a-pca.vala \
	plugins/a-pcoa.vala \
	plugins/a-qualanal.vala \
	plugins/a-rankabundance.vala \
	plugins/a-rdp.vala \
	plugins/a-rtax.vala \
	plugins/a-taxaplot.vala \
	plugins/a-uchime.vala \
	plugins/a-unifrac_mrpp.vala \
	plugins/a-withseqs.vala \
	plugins/src-fasta.vala \
	plugins/src-panda.vala \
	$(NULL)
axiome_SOURCES = $(axiome_VALASOURCES:.vala=.c) plugins/types.c

BUILT_SOURCES = \
	fmap.c fmap.h \
	$(axiome_VALASOURCES:.vala=.c) \
	$(aq_joinn_VALASOURCES:.vala=.c) \
	$(aq_mkrepset_VALASOURCES:.vala=.c) \
	$(NULL)

axiome.vapi axiome.h $(axiome_SOURCES): $(axiome_VALASOURCES)
	$(VALAC) $(VALAFLAGS) -g -C -H axiome.h --vapi axiome.vapi $(axiome_VALAFLAGS) $(axiome_VALASOURCES) && touch $(axiome_VALASOURCES:.vala=.c) axiome.vapi axiome.h
	awk '/define/ && /_get_type / { t[substr($$3, 2)] = 1 } END { print "#include<glib-object.h>"; for(x in t) { print "extern GType " x "(void);"; } print "void register_plugin_types(void) {"; for(x in t) { print "\t"x"();"; } print "}"}' $(axiome_SOURCES) > plugins/types.c

$(aq_joinn_SOURCES): $(aq_joinn_VALASOURCES)
	$(VALAC) $(VALAFLAGS) -g -C  $(aq_joinn_VALASOURCES) && touch $@

$(aq_marry_otu_names_VALASOURCES:.vala=.c): $(aq_marry_otu_names_VALASOURCES)
	$(VALAC) $(VALAFLAGS) -g -C --pkg=gee-$(GEE_VER) $(aq_marry_otu_names_VALASOURCES) && touch $@

$(aq_mkrepset_VALASOURCES:.vala=.c): $(aq_mkrepset_VALASOURCES) fasta.vapi
	$(VALAC) $(VALAFLAGS) -g -C --pkg=gee-$(GEE_VER) --pkg=posix $(aq_mkrepset_VALASOURCES) fasta.vapi && touch $@

$(aq_otudulegmerge_VALASOURCES:.vala=.c): $(aq_otudulegmerge_VALASOURCES)
	$(VALAC) $(VALAFLAGS) -g -C --pkg=gee-$(GEE_VER) $(aq_otudulegmerge_VALASOURCES) && touch $@

$(aq_otuwithseqs_VALASOURCES:.vala=.c): $(aq_otuwithseqs_VALASOURCES) fasta.vapi
	$(VALAC) $(VALAFLAGS) -g -C --pkg=gee-$(GEE_VER) --pkg=posix $(aq_otuwithseqs_VALASOURCES) fasta.vapi && touch $@

fmap.c fmap.h: fmap.vala
	$(VALAC) $(VALAFLAGS) -g -C -H fmap.h --pkg=gee-$(GEE_VER) fmap.vala && touch $@

fasta.vapi fasta.c fasta.h: fasta.vala
	$(VALAC) $(VALAFLAGS) -g -C -H fasta.h --vapi=fasta.vapi --pkg=gee-$(GEE_VER) --pkg=posix fasta.vala && touch $@

AXIOMEManual.pdf: $(man1_MANS)
	(cat cover.ps; groff -Tps -mandoc -fN $^) | ps2pdf - > $@

doc/index.htm: $(axiome_VALASOURCES)
	test ! -d doc || rm -rf doc
	valadoc -o doc --package-name=axiome --package-version=$(VERSION) $(VALAFLAGS) $(axiome_VALAFLAGS) $(axiome_VALASOURCES)

install-exec-hook:
	test ! -L $(DESTDIR)$(bindir)/autoqiime$(EXEEXT) || rm $(DESTDIR)$(bindir)/autoqiime$(EXEEXT)
	$(LN_S) axiome$(EXEEXT) $(DESTDIR)$(bindir)/autoqiime$(EXEEXT)

