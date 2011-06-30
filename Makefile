bindir=../bin-$(shell uname -s)

$(bindir)/autoqiime: autoqiime.vala realpath.vapi
	valac -X -lmagic --pkg libmagic --pkg=gee-1.0 --pkg=libxml-2.0 -o $@ $^

$(bindir)/joinn: joinn.vala
	valac -o $@ $^

$(bindir)/qualhisto: qualhisto.c parser.c
	gcc -lz -lbz2 -o $@ $^

$(bindir)/%: %.c
	gcc -lz -lbz2 -o $@ $<
