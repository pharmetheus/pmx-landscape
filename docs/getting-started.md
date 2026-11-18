# Getting started

## R and packages

The code is R, tested with R 4.2.3 on Ubuntu, with packages from the Posit
snapshot of 2023-04-15 (`https://packagemanager.posit.co/cran/2023-04-15`).
The package `pmxlandscape` is used from its folder, not installed:

```r
pkgload::load_all("pmxlandscape")
```

Packages used: jsonlite, stringi, rvest, xml2, ggplot2, ggrepel (package);
testthat, withr, pdftools, png (tests); httr, rentrez, europepmc, knitr
(scripts and README).

Two exceptions to the snapshot on a system with libxml2 2.15: `xml2` and
`XML` (needed by rentrez) must come from live CRAN, because the snapshot
versions do not compile against it.

## System libraries

- `libpoppler-cpp-dev` for pdftools (PAGE poster PDFs);
- `poppler-utils` and `tesseract-ocr` for text extraction and OCR (PAGE PDFs
  and FDA steps 3 and 4).

```
sudo apt install libpoppler-cpp-dev poppler-utils tesseract-ocr
```

The FDA retrieval steps 1 to 4 are still Python (3.10 or later, with
`requests` and `beautifulsoup4`); see [FDA reviews](fda.md).

## Checks

```
make test     # all tests, including the reproduction of the FDA results
make lint     # lintr 3.0.2, as in CI
make format   # styler 1.8.0, as in CI
make check    # R CMD check from a clean build
```

The FDA reproduction tests need `sources/fda/`, so they skip under
`R CMD check` and run under `make test`.
