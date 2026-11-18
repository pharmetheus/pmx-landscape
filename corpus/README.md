# Corpus

The first layer of the design (`docs/design.md`): every item of every source, described by
one item table and one section table per source. Classifications read the text through
these tables and nothing else. Built by `make corpus` (`corpus/build.R`) from what the
sources have cached; it downloads nothing.

## Files

| Path | Committed | Content |
|---|---|---|
| `<source>/items.csv` | yes | one row per item |
| `<source>/sections.csv.gz` | yes | one row per piece of an item's text, without the text |
| `<source>/run_info.txt` | yes | counts, what was skipped, the extraction tools |
| `cache/<source>.rds` | no | the text |

Sources: `page` (PAGE abstracts), `pubmed`, `epmc` (Europe PMC), `fda` (FDA reviews).

The local text in `cache/` is used only for this project. Affiliation texts are stored without
e-mail addresses (`stripEmails()`), and `make corpus` first removes them from the downloaded
files as well (`strip_emails.R`). The cache of a source is deleted when the source is dropped
from the project, and the whole cache when the project ends.

## Item table

| Column | Content |
|---|---|
| `source` | PAGE, PubMed, Europe PMC, FDA |
| `item_id` | PAGE abstract number; PMID; Europe PMC `MED:<pmid>` or `PMC:<pmcid>`; FDA application number |
| `year` | the year the item represents, by the source's rule (meeting year; earliest publication year in PubMed; Europe PMC publication year; approval year) |
| `url` | where anyone can read the item |
| `coverage` | what text exists for the item, for example `abstract page and poster`, `title only`, `full text`, `title and abstract (record)`, `review text and OCR` |
| `retrieved` | the date of the cached file the text was read from; FDA: not recorded by the original run |
| `admitted_by` | literature: `core: <terms>`, the core base terms that return the item (queried term by term on 2026-10-18, for 2016 to 2020 on 2026-10-19; a paper of the frozen set that no term returns any more is marked `core (frozen set)`), `extension: <terms>`, the extension terms that admitted it, or `tool: <tools>`, the tools that admitted a paper of the tool route only |
| `tool_route` | literature: the tools the tool route found the item by (`; `), also for papers of the term route; empty if none |
| `hash` | SHA-256 over the item's section names, parts and section hashes, in order |

Further columns per source: PAGE `session`, `software_demo`, `has_poster` (the page links a poster or slides; the link is not stored, since its file name often carries an author's name); FDA `drug`,
`documents` (the review PDF URLs).

## Section table

| Column | Content |
|---|---|
| `source`, `item_id` | the item |
| `seq` | position within the item |
| `section` | PAGE `title`, `authors`, `affiliations`, `body`, `poster`; PubMed `title`, `abstract`, `keywords`, `authors`, `affiliations`, `author_affiliations` (one per author, parts `a001`, ...); Europe PMC `title`, `abstract`, `keywords`, `body`, `methods` (a part of the body), `floats`, `appendix`, `back`, `authors` and `author_affiliations` (from the record); FDA `review` |
| `part` | PAGE posters and FDA reviews: the document and page (`p0003`, `219209_integratedR_2025_0 p0003`) |
| `src` | `html`, `xml`, `json` (Europe PMC record), `text` or `ocr` (FDA), `pdf text` or `pdf ocr` (PAGE posters) |
| `nchar`, `hash` | size and SHA-256 of the text |

Reference lists are not in the corpus where the source marks them: PAGE cuts them
(`pageParseAbstract()`), Europe PMC keeps them in `<ref-list>`, which is left out, and
PubMed abstracts have none. FDA reviews keep theirs: the review text is the page text,
and a reference list on a page is part of it (a known gap; cutting it would change the
FDA hits, so it belongs to the tools classification).

## What is published, and the check

The tables carry IDs, URLs, sizes and hashes, never text, except FDA review text, which is
in the public domain and committed under `sources/fda/data/`. Anyone can rebuild the
corpus with the sources' retrieval scripts and compare the hashes: an item whose hash
differs was not the text that was classified. `corpusRead()` refuses local text that does
not match the committed tables, and rebuilding from unchanged caches gives byte-identical
tables (tested).

## Per source

- **PAGE:** the cached abstract pages 1992 to 2026 (`sources/page/page_cache/`), with the
  URL from the sitemaps of 2026-09-26. Poster PDFs are cached only for abstracts whose page
  named no estimation tool (the PAGE run fetched them to look for one), so `poster`
  coverage is not a random sample. Poster text by pdftools, with OCR of image-only pages
  (`pdfPages()`).
- **PubMed:** the core, 2016 to 2026: the base set frozen by the counts run of 2026-09-28
  (`sources/literature/results/ids.csv.gz`, 2021 to 2026) and the same query for 2016 to
  2020, run 2026-10-19 (`ids_2016_2020.csv.gz`; papers already in the frozen set stay
  there); and the extension (`extension_ids.csv.gz`, `corpus_extension.R`: the population
  PK short forms, population pharmacodynamic and NLME, 2016 to 2026, run 2026-10-19). From
  the cached efetch XML. The tool route (`tool_ids.csv.gz`, `corpus_toolroute.R`, run
  2026-10-20): papers naming NONMEM, Monolix, Phoenix NLME, nlmixr, Pumas, Pmetrics, saemix
  or S-ADAPT in the title or abstract, 2016 to 2026. Snapshot of 2026-10-20: 9,321 items,
  8,045 core (5,156 of them 2021 to 2026), 769 extension and 507 tool route only.
- **Europe PMC:** the same core and extension. Full text where Europe PMC serves it (open
  access); title, abstract and keywords from the Europe PMC record otherwise
  (`sources/literature/corpus_fetch.R`, `corpus_extension.R`; per-paper status in
  `sources/literature/results/*fulltext_status*.csv`). An extension paper that Europe PMC
  now lists under another ID than a base paper (a `PMC:` record now `MED:`) is left out.
  The tool route: the same tools in the methods section of open-access full text, 2016 to
  2026; a paper of the tool route only stays in the corpus only with a downloaded full
  text (4 of 2,038 were not served), and one that the term route holds under another ID
  is recorded under the term route's ID. Snapshot of 2026-10-20: 7,150 items, 4,639 core
  (3,140 of them 2021 to 2026), 477 extension and 2,034 tool route only; 6,119 with full
  text.
- The published literature series still read the core of 2021 to 2026 only
  (`sources/literature/local_search.R` writes `ids_local.csv.gz` for them and
  `ids_local_all.csv.gz` for every item); the earlier years, the extension and the tool route
  wait for Niclas's decision.
- **FDA:** one item per drug of the decision record (2021 to 2025), one section per review
  page, OCR where the page is image-only, exactly the text the published FDA results were
  read from. The R retrieval (`sources/fda/retrieve.R`) also keeps the PDFs, for 2016 to
  2025; `sources/fda/check_text.R` compares a new extraction with the committed text.
