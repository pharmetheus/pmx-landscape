# PMx Landscape: one entry point for the repository. See docs/README.md.

R := R --slave --no-save --no-restore

.PHONY: help test check lint format check-notes corpus database fda-verify fda-crosscheck literature page-pilot page ai-ml discover readme

help:
	@echo "make test        pmxlandscape tests (includes the FDA reproduction)"
	@echo "make check       R CMD check of pmxlandscape (from a clean build)"
	@echo "make lint        lintr, as pinned in CI (3.0.2)"
	@echo "make format      styler check, as pinned in CI (1.8.0)"
	@echo "make check-notes notes that repeat their item's text (needs the local corpus text; run before a release)"
	@echo "make corpus      item and section tables of every source, from the caches (see corpus/README.md)"
	@echo "make database    the tag database from the corpus and classification outputs (see database/README.md)"
	@echo "make fda-verify  FDA search in R; fails unless 0 unexplained mentions"
	@echo "make fda-crosscheck  sponsor papers for each FDA drug (network)"
	@echo "make literature  literature counts, IDs and PubMed affiliations (network)"
	@echo "make page-pilot  PAGE pilot, 25 random abstracts (network)"
	@echo "make page        PAGE full run for the configured years (network, hours)"
	@echo "make ai-ml       AI and machine learning terms in all sources (network; needs decisions.csv)"
	@echo "make discover    candidate tool names in every cached corpus (see docs/discovery.md)"
	@echo "make readme      rebuild README.md, docs/results/ and figures/ from the committed results"

test:
	$(MAKE) -C pmxlandscape test

lint:
	$(MAKE) -C pmxlandscape check-lint

format:
	$(MAKE) -C pmxlandscape check-format

check-notes:
	Rscript classifications/check_notes.R

check:
	@dir=$$(mktemp -d) && cd $$dir && R CMD build $(CURDIR)/pmxlandscape > build.log 2>&1 && \
	  R CMD check --no-manual pmxlandscape_*.tar.gz; status=$$?; rm -rf $$dir; exit $$status

corpus:
	Rscript corpus/strip_emails.R
	Rscript corpus/build.R

database:
	Rscript database/build.R

fda-verify:
	$(R) -e 'pkgload::load_all("pmxlandscape", quiet = TRUE); u <- fdaVerify("sources/fda", hits = fdaSearch("sources/fda")); cat(nrow(u), "unexplained software mentions\n"); if (nrow(u) > 0) { print(u); quit(status = 1) }'

fda-crosscheck:
	cd sources/fda/crosscheck && Rscript crosscheck_literature.R

literature:
	cd sources/literature && Rscript publication_trends.R && Rscript affiliations.R

page-pilot:
	cd sources/page && Rscript page_software_trends.R

page:
	cd sources/page && PAGE_MODE=full Rscript page_software_trends.R

ai-ml:
	cd analysis/ai_ml && Rscript ai_ml.R

discover:
	cd taxonomy/discovery && Rscript discover.R

readme:
	$(R) -e 'knitr::opts_knit$$set(root.dir = getwd(), base.url = "../../"); knitr::knit("docs/results/estimation-software.Rmd", "docs/results/estimation-software.md", quiet = TRUE)'
	$(R) -e 'knitr::knit("README.Rmd", "README.md", quiet = TRUE)'
