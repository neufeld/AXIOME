bindir=../bin-$(shell uname -s)

all: $(addprefix $(bindir)/, $(basename $(wildcard *.vala) $(wildcard *.c)))

$(bindir)/%: %.vala %.deps
	valac --vapidir=/usr/local/share/vala/vapi --vapidir=. $$(cat $*.deps) -o $@ $<

$(bindir)/qualhisto: qualhisto.c parser.c
	gcc -lz -lbz2 -o $@ $^

$(bindir)/%: %.c
	gcc -lz -lbz2 -o $@ $<

.PHONY: all
