bindir=../bin-$(shell uname -s)
VALAOPTS=--vapidir=/usr/local/share/vala/vapi --vapidir=. -g 
all: $(addprefix $(bindir)/, $(basename $(wildcard *.vala) $(wildcard *.c)))

doc: $(addsuffix -doc, $(basename $(wildcard *.vala)))

%-doc: %.vala %.deps
	valadoc $(VALAOPTS) --private --internal -o $@ $< $(cat $*.deps)

$(bindir)/%: %.vala %.deps
	valac $(VALAOPTS) -X -DDATADIR=\"$$(realpath .)\" $$(cat $*.deps) -o $@ $<

$(bindir)/qualhisto: qualhisto.c parser.c
	gcc -lz -lbz2 -o $@ $^

$(bindir)/%: %.c
	gcc -lz -lbz2 -o $@ $<

.PHONY: all
