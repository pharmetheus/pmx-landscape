# Licence for the data, results and documents

PMx Landscape uses two licences. The copyright holder of both is Pharmetheus AB.

| Content | Licence |
|---|---|
| Code: R, Python and shell scripts, Makefiles, and the R package `pmxlandscape` | [MIT](LICENSE) |
| Everything else the project made: the tables of items and their classifications, the results and charts, the tool lists and search patterns (`taxonomy/`), the codebooks and rubrics that instruct the language models, and the documents. Not the FDA review text, which is in the public domain (below) | [Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/legalcode) |

## Licence by kind of file

Inside the R package `pmxlandscape/`, every file is under MIT. Everywhere
else, the kind of file decides the licence, not the folder. A folder such as `sources/fda/` or
`classifications/tool_use/` holds files under both licences.

| Files | Licence |
|---|---|
| The R package in `pmxlandscape/`: code, help pages (`man/`), tests, configuration, and the shared prompt for the language models in `pmxlandscape/inst/prompts/` | MIT |
| Code outside the package: R (`.R`) and Python (`.py`) scripts, shell scripts, and the `Makefile` files | MIT |
| Documents, Markdown (`.md`) and R Markdown (`.Rmd`) files: `README.Rmd`, `README.md`, the files in `docs/`, the source cards, and the codebooks and rubrics that instruct the language models | CC BY 4.0 |
| Data and results: tables (`.csv`, `.csv.gz`), JSON files such as `taxonomy/patterns.json`, and `database/` | CC BY 4.0 |
| Charts: `figures/` and other image files | CC BY 4.0 |
| Text of FDA review documents in `sources/fda/data/`: extracted text (`txt/`) and text read from scanned pages (`ocr/`) | Neither: in the public domain, as described under "Content owned by others" |

The MIT licence text speaks of "associated documentation files". In this project those are the
help pages of the R package. The other documents of the project are under CC BY 4.0.

CC BY 4.0 lets anyone copy, share and adapt this content, also commercially. Whoever reuses it must
credit the source, link to the licence and say whether they changed it. A suggested credit:
"PMx Landscape, version [release], Pharmetheus AB, CC BY 4.0".

## Content owned by others

Pharmetheus AB can license only what the project made. The following content belongs to others,
and the terms of its owners apply.

- **FDA review documents.** The text in `sources/fda/data/` is the text of FDA review documents as
  FDA publishes them. They are works of the US government and in the public domain in the United
  States. They may include material from third parties, such as figures from the applicants.
- **PubMed.** The repository holds PubMed IDs and the project's own classifications, no text.
  PubMed data are courtesy of the U.S. National Library of Medicine, which does not endorse this
  project. Records may have changed since they were retrieved.
- **Europe PMC.** The repository holds identifiers and the project's own classifications, no text.
  Each article has its own licence, shown on its Europe PMC page.
- **PAGE abstracts.** The abstracts of the PAGE meeting (Population Approach Group in Europe). The
  repository holds abstract numbers, links and the project's own
  classifications, no text. The links are PAGE's own addresses, which contain the abstract titles.
  The abstracts are the copyright of their authors or institutions, as PAGE states on its website.
- **EMA documents.** Some FDA results draw on assessment reports of the European Medicines Agency
  (EMA). The repository holds their document names, page numbers and the project's own notes,
  no text. EMA documents are © European Medicines Agency.
- **Software names.** The names of software tools are trademarks of their owners. They are used only
  to identify the software, and their use implies no endorsement.

## Personal data

The tables include, for each paper and abstract, the type of organisation of the first author and
whether any author works for a drug company or a contract research organisation.
[PRIVACY.md](PRIVACY.md) describes how these data are handled and how an author can object.
Whoever reuses the data is responsible for their own compliance with data protection law. Please
do not use the data to profile individual authors.
