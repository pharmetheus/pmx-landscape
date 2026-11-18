# Source card: published literature

| | |
|---|---|
| **Measures** | How often published pop-PK and pharmacometric papers name each estimation tool, and how often they used it (two series, from October 2026) |
| **Unit** | The paper. A paper can count for several tools |
| **Denominator** | The frame is the papers that describe themselves with the field's own names for the method (decided 2026-10-19, `docs/design.md`). A base set per publication year: papers with "population pharmacokinetic(s)", pharmacometric*, "nonlinear mixed effects" or "non-linear mixed effects" in the title or abstract (PubMed) or in the title, abstract or keywords (Europe PMC, from September 2026; before, anywhere in the full text). Europe PMC papers that name no estimation tool are read (`no_tool_review.R`, decisions in `no_tool_decisions.csv`), and those without a model fit of their own or outside pharmacology are left out of the base set |
| **Snapshot and lag** | Publication year; the work was done earlier. 2026 is partial |
| **Coverage** | 2021 to 2026 in the published series; the corpus also holds 2016 to 2020, the extension terms and the tool route (`corpus/README.md`), not yet published. The tool route (decided 2026-10-20, `corpus_toolroute.R`) adds the papers that name an estimation tool made for pharmacometric work (NONMEM, Monolix, Phoenix NLME, nlmixr, Pumas, Pmetrics, saemix, S-ADAPT) without using the field's names: PubMed in the title and abstract, Europe PMC in the methods of open-access full text. Papers without open access are missed by the Europe PMC tool route. Run of 2026-10-20: 2,034 Europe PMC papers and 507 PubMed papers outside the term route (`results/tool_queries.csv`, `tool_ids.csv.gz`); the local search finds a route tool in 1,894 and 337 of them, most of the rest found by the plain word Pumas. From version 2 of the relevance codebook every paper of either route is read for a model fit of its own (`classifications/lit_relevance`); the development run (2026-10-21) read all 16,469 corpus papers, and `routes.R` gives the shares among papers with a fit of their own for the term route, the tool route and both (`results/route_shares.csv`, development results). PBPK tools are recorded by name only (`results/pbpk_local.csv.gz`) |
| **Retrieval** | The base set: `publication_trends.R` (run of 2026-09-28, frozen since). The tools, from October 2026: `local_search.R` finds them with the taxonomy patterns in the downloaded text (the corpus): PubMed title, abstract and keywords; Europe PMC open-access full text without the back matter and the reference list, so the Europe PMC series covers the 2,776 open-access papers of the 3,140; papers using a tool come from `classifications/tool_use`. Until then, from the servers' search: `publication_trends.R`: PubMed (`rentrez`, title and abstract, `[tiab]`) and Europe PMC (`europepmc`, full text of articles with full text, `HAS_FT:Y`, preprints excluded with `NOT SRC:PPR`, no synonym expansion). Every query's matching IDs are stored with its count, the query string and the run date. `affiliations.R` classifies the first author's affiliation of the PubMed base set |
| **Terms** | Counts, query strings and IDs (PMIDs, PMCIDs) are published. Paper text and affiliation text are not stored in the repository |
| **Local copies** | The downloaded records and full texts are kept in local, git-ignored caches (`sources/literature/cache/`, `corpus/cache/`), used only for this project. E-mail addresses are removed from the affiliation texts (`stripEmails()`). The local copies of a source are deleted when the source is dropped from the project, and all local copies when the project ends |

## What the numbers mean

Naming: a share is "papers naming X among base-set papers" for that source and
year. It counts mentions, not use: a tool development paper, a comparison or a
citation counts the same as an analysis. Using: only the tools the authors used
for their own analysis, by the tool use classification. Shares do not sum to
100%. The comparison of the local search with the servers' counts is in
`results/local_vs_server.csv`: PubMed agrees almost exactly (NONMEM 637 against
636); in Europe PMC almost all the difference is the papers without an
open-access full text.

- **PubMed (title/abstract)** is consistent over time but underestimates use,
  since software is usually named only in the Methods.
- **Europe PMC (full text)** searches the article text but not its reference
  list. Checked in September 2026: of the 419 open-access papers that cite the
  PsN paper, whose title is "Perl-speaks-NONMEM", only 256 match that phrase.
  A tool named anywhere in the text still counts, including the introduction
  or discussion.

## Known biases and limits

- PubMed's publication date `[dp]` matches both the electronic and the print
  date, so a paper can match two years. Each PMID is kept only in the earliest
  year it matches (its first publication); 667 base-set papers matched two
  years in the September 2026 run. Papers first published in 2020 and printed
  in 2021 stay in 2021, since 2020 is not queried.
- The frame reaches about two thirds of the papers that fit a population model of their
  own (development estimate, `refinement/README.md`): 62 to 64% of the relevant papers of
  the core journals and of papers naming a tool in their Europe PMC methods, 84% of those
  naming a tool in their PubMed title or abstract. Most missed papers use none of the
  field's words in their title, abstract or keywords, so further terms add little. The
  tool shares in missed papers are similar (NONMEM 86% in and outside the base set in the
  core journals), but in Europe PMC overall NONMEM is named in 78% of missed papers
  against 87% of found ones, and the tool-anchored reference set did not anchor on Pumas,
  Stan or Torsten; the samples are too small to call this a difference.
- Live indexes drift: a re-run gives different numbers. The stored IDs (in
  `results/ids.csv.gz`) are the record of this run.
- Patterns: "Torsten" (the Stan marker) is also a first name; "Pumas" can be
  the animal; the bare acronym "SAAM" may have other meanings.
- Affiliation types (PubMed only) rest on ordered keyword rules
  (`taxonomy/affiliation_rules.csv`) and the first author's first listed
  affiliation; a sample of each class was read to check them.

## Files

- Corpus: `corpus/pubmed/` and `corpus/epmc/`, one item per base-set paper,
  with the core base terms that admitted it (`admitted_by`) and the text's
  sections (`make corpus`; see `corpus/README.md`).
- `results/counts.csv`: every query, its reported count and the IDs stored.
- `results/shares.csv`: shares per source, tool and year.
- `results/ids.csv.gz`: the IDs behind every count.
- `results/pubmed_affiliations.csv`, `results/shares_by_affiliation.csv`:
  first-author affiliation type per PubMed paper, and shares by type.
- `results/run_info.txt`: run date and checks.
