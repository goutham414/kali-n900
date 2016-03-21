IMAGES=debtags-edit.png packagesearch.png ranganathan.png

all: paper-debtags.html
#paper-debtags.pdf

paper-debtags.html: paper-debtags.rst
	rst2html --no-doc-title --stylesheet=main.css $< > $@

paper-debtags.tex: paper-debtags.rst
	rst2latex $< | sed 's/\.png/\.eps/' > $@

paper-debtags.dvi: paper-debtags.tex $(IMAGES:.png=.eps)
	latex $<
	latex $<

paper-debtags.pdf: paper-debtags.dvi
	dvipdf $< $@

%.eps: %.png
	convert $< $@

clean:
	rm -f *.tex *.dvi *.pdf *.eps *.html
