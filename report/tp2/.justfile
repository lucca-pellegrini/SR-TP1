# SPDX-License-Identifier: ISC
# SPDX-FileCopyrightText: Copyright © 2026 Lucca M. A. Pellegrini <lucca@verticordia.com>

NAME := "Banco_de_Registradores_Registrador_de_Status_Pilha_e_Contador_de_Programa_em_VHDL_-_Coelho_Pellegrini"

MAIN := "main"
VER := `git describe --long --tags --always | sed 's/^v//;s/\([^-]*-g\)/r\1/;s/-/./g'`

# O minted chama o Pygments, o que exige -shell-escape. O biblatex usa o biber
# e o latexmk o aciona sozinho, rodando o pdflatex quantas vezes forem precisas.
LATEX := "latexmk -pdf -pdflatex='pdflatex -shell-escape -interaction=nonstopmode -file-line-error %O %S'"
LATEXFLAGS := "-outdir=build"
CLEANFLAGS := "-C -outdir=build"
RELEASE := NAME + "_" + VER

# Projetos do TP2 e pasta onde ficam os SVGs do RapidRTL (<proj>_rtl.svg)
PROJECTS := "reg_bank reg_status stack prog_cnt"
PROJDIR := "../../project"

all: pdf

# LaTeX não inclui SVG. O inkscape converte cada <proj>_rtl.svg em PDF
# vetorial, e a conversão só é refeita se o SVG for mais novo.
figuras:
	@mkdir -p build/figuras
	@for p in {{PROJECTS}}; do \
		svg={{PROJDIR}}/$p/${p}_rtl.svg; pdf=build/figuras/${p}_rtl.pdf; \
		if [ ! -e $pdf ] || [ $svg -nt $pdf ]; then \
			echo "inkscape: $svg -> $pdf"; \
			inkscape $svg --export-type=pdf --export-filename=$pdf 2>/dev/null; \
		fi; \
	done

pdf: figuras
	{{LATEX}} {{LATEXFLAGS}} {{MAIN}}.tex
	cp build/{{MAIN}}.pdf {{MAIN}}.pdf

release: release-zip release-tar-gz release-tar-xz release-tar-zst

release-pdf: pdf
	gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/prepress \
		-dNOPAUSE -dQUIET -dBATCH -sOutputFile={{RELEASE}}.pdf        \
		{{MAIN}}.pdf

release-tar: release-pdf
	tar -vcf {{RELEASE}}.tar {{RELEASE}}.pdf

release-tar-gz: release-tar
	gzip -kf {{RELEASE}}.tar

release-tar-xz: release-tar
	xz -kf {{RELEASE}}.tar

release-tar-zst: release-tar
	zstd -qf {{RELEASE}}.tar

release-zip: pdf release-pdf
	zip -r {{RELEASE}}.zip {{RELEASE}}.pdf

clean:
	{{LATEX}} {{CLEANFLAGS}} {{MAIN}}.tex
	rm -rf *.pdf *.ps *.idx *.bbl *.brf *.glo *.dvi *.toc *.lof *.aux  \
		*.log *.blg *.ilg *.ind *.out *.wsp *.fls *.synctex* *.zip \
		*.tar *.tar.gz *.tar.xz *.tar.zst *.*~ .*.stamp build/

# vim: noet ts=8 sts=8 sw=8
