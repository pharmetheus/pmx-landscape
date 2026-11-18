# Literature corpus refinement: recall of the base query and yield of extra terms

| | |
|---|---|
| **Question** | Does the literature base query miss relevant papers, and would extra search terms add them? PubMed and Europe PMC only (discussion topic 3, Niclas, 2026-10-19) |
| **Relevant** | `own_fit`: the authors fit a population (mixed-effects) model of their own to data, in pharmacology (the no-tool rubric, `classifications/lit_relevance`) |
| **Years** | 2021 to 2025 (complete years) |
| **Base set** | The frozen base set of `../publication_trends.R` (run 2026-09-28), compared by ID, so live index drift does not count as a miss |
| **Status** | Development run, 2026-10-19: queries, samples, texts and the relevance reading done. Nothing here changes the published series: adopting a term is a separate step, and Niclas's decision |

## Method

**Part 1, recall.** Two reference sets found without the base terms (`01_reference.R`):

- R1, core journals: every paper of J Pharmacokinet Pharmacodyn and CPT Pharmacometrics Syst
  Pharmacol, without errata, editorials, comments and retractions (PubMed `[ta]` and `[pt]`;
  Europe PMC `ISSN:` and `PUB_TYPE:`, open-access full text as in the base set).
- R2, tool-anchored: papers naming an unambiguous estimation tool (NONMEM and its misprints,
  Monolix, Phoenix NLME, nlmixr, saemix, Pmetrics, NLMIXED, S-ADAPT; not Pumas, Stan, Torsten
  or ADAPT, which are also ordinary words or names): Europe PMC in the methods section
  (`METHODS:`), PubMed in the title or abstract.

Each set splits into papers in the base set and papers outside it; a sample of each stratum
(60 in, 100 out) is read for relevance, and the recall among relevant papers is
`stratifiedRecall()` (each stratum's relevant share weighted by its size, Jeffreys interval
by simulation). A sample of the base set itself (R0, 60 per source) gives its relevant share,
for a capture-recapture estimate (`chapman()`) of keyword search against tool-anchored search;
the two searches are not independent, so it is a rough estimate.

**Part 2, yield.** For each candidate term (`terms.csv`, in the base set's own fields:
PubMed `[tiab]`, Europe PMC title, abstract and keywords with the full-text filter), per year:
the papers it finds, the increment outside the base set, and the increment naming an
unambiguous tool (`02_terms.R`; queries only). A sample of 40 increment papers per term and
source is read for relevance (`03_fetch.R`, `classifications/lit_relevance`). Proposed for
the extension: at least 20 relevant papers a year and at least half of the sample relevant
(`04_measure.R`); the decision is Niclas's.

**Syntax checks (2026-10-19).** Europe PMC's field list (REST `/fields`) has `METHODS`, `REF`,
`JOURNAL` and `ISSN`. Test counts for 2023: `"NONMEM"` in full text 375, in `METHODS:` 332, in
`REF:` 172; `JOURNAL:"CPT Pharmacometrics Syst Pharmacol"` and `ISSN:"2163-8306"` both 178;
`NOT (...)` works in both services; PubMed `[ta]` and the `[pt]` exclusions as expected (J
Pharmacokinet Pharmacodyn 2023: 61 records, 58 without notes).

## First results (queries only, 2026-10-19)

Reference sets, papers in the base set (before the relevance reading, so not a recall yet):

| Set | Source | Papers | In the base set |
|---|---|---|---|
| R1 core journals | PubMed | 1,259 | 450 (36%) |
| R1 core journals | Europe PMC | 935 | 334 (36%) |
| R2 tool-anchored | PubMed | 1,104 | 885 (80%) |
| R2 tool-anchored | Europe PMC | 3,455 | 1,810 (52%) |

Candidate terms, 2021 to 2025: the increment outside the base set and its share naming an
unambiguous tool (Europe PMC in the full text, PubMed in the title or abstract):

| Term | Europe PMC increment | naming a tool | PubMed increment | naming a tool |
|---|---|---|---|---|
| mixed-effects model | 7,094 | 0.4% | 13,531 | 0.0% |
| PBPK | 1,207 | 6.9% | 2,625 | 0.2% |
| exposure-response | 1,058 | 9.4% | 2,216 | 0.5% |
| PK/PD model | 411 | 38.2% | 886 | 2.1% |
| QSP | 234 | 10.7% | 396 | 0.0% |
| population PK (short forms) | 202 | 60.9% | 387 | 10.3% |
| MIPD | 150 | 22.0% | 313 | 2.9% |
| disease progression model | 117 | 4.3% | 200 | 0.5% |
| model-informed drug development | 116 | 23.3% | 238 | 0.4% |
| MIDD | 115 | 11.3% | 227 | 0.0% |
| model-based meta-analysis | 61 | 41.0% | 145 | 2.1% |
| NLME | 20 | 35.0% | 29 | 13.8% |
| population pharmacodynamic | 14 | 92.9% | 17 | 29.4% |

## The relevance reading (development, 2026-10-19)

All 1,663 sampled papers read through `classifications/lit_relevance` by Claude Code subagents
instead of the API (`run.R batches`, `run.R import`): Claude Sonnet 5.5 subagents read 44 batches, Claude Opus 5.5
subagents read a blind 15% check (249 papers, seed 20261019) from separate files. Each answer
repeats the start of the paper's title, and `readAgentAnswers()` refuses answers that do not
match, so an answer cannot slip onto another paper; none did. The blind check agreed on 234 of
249 (kappa 0.91); of the 15 disagreements, 6 cross the relevant line. Claude settled all 15
(`adjudications.csv`, labelled development). This is a development check by models only; no
human has checked answers.

Read values: PubMed 310 own fit, 340 not own fit, 149 outside the field, 46 unclear; Europe PMC
329, 349, 130 and 10. `unclear` papers are left out of the shares below.

The standard tables of the classification, over this reading and the corpus reading of
2026-10-19 together, are `classifications/lit_relevance/report_methods.csv` and
`report_values.csv` (`classifications/standard_tables.R lit_relevance`): all tags are readings or
settled disagreements, so none is exactly reproducible by rules.

## Results (development run, 2026-10-19)

**Recall of the base query** among relevant papers of the reference sets (`results/recall.csv`;
stratified estimate, 95% interval):

| Set | Source | Papers | In base | Relevant read: in base | outside base | Estimated relevant | Recall |
|---|---|---|---|---|---|---|---|
| R1 core journals | PubMed | 1,259 | 450 | 36 of 59 | 19 of 91 | 443 | 62% (51 to 72) |
| R1 core journals | Europe PMC | 935 | 334 | 49 of 60 | 25 of 99 | 425 | 64% (56 to 72) |
| R2 tool-anchored | PubMed | 1,104 | 885 | 55 of 60 | 70 of 96 | 971 | 84% (81 to 86) |
| R2 tool-anchored | Europe PMC | 3,455 | 1,810 | 53 of 60 | 51 of 92 | 2,511 | 64% (59 to 69) |

The base set itself is not all relevant (R0, `results/base_relevance.csv`): 39 of 58 PubMed
papers (67%, 54 to 78) and 44 of 60 Europe PMC papers (73%, 61 to 83) are the authors' own
fit. Capture-recapture of keyword search against tool-anchored search
(`results/capture_recapture.csv`, rough, as the two searches are not independent) puts the
keyword search at 84% of the relevant papers in PubMed and 64% in Europe PMC.

**Yield of the candidate terms** (`results/term_yield.csv`): relevant share of the increment
sample and estimated relevant papers a year outside the base set:

| Term | Europe PMC: relevant | a year | PubMed: relevant | a year |
|---|---|---|---|---|
| population PK (short forms) | 20 of 39 (51%) | 21 | 18 of 37 (49%) | 38 |
| PK/PD model | 14 of 39 (36%) | 30 | 8 of 31 (26%) | 46 |
| model-based meta-analysis | 28 of 40 (70%) | 9 | 26 of 38 (68%) | 20 |
| model-informed drug development | 13 of 40 (33%) | 8 | 7 of 32 (22%) | 10 |
| population pharmacodynamic | 13 of 14 (93%) | 3 | 14 of 16 (88%) | 3 |
| NLME | 8 of 20 (40%) | 2 | 11 of 29 (38%) | 2 |
| disease progression model | 6 of 40 (15%) | 4 | 8 of 38 (21%) | 8 |
| MIPD | 4 of 40 (10%) | 3 | 4 of 37 (11%) | 7 |
| exposure-response | 3 of 40 (8%) | 16 | 1 of 39 (3%) | 11 |
| QSP | 3 of 39 (8%) | 4 | 0 of 39 | 0 |
| MIDD | 2 of 40 (5%) | 1 | 1 of 37 (3%) | 1 |
| PBPK | 1 of 40 (3%) | 6 | 0 of 40 | 0 |
| mixed-effects model | 0 of 40 | 0 | 1 of 40 (3%) | 68 |

By the proposed threshold (at least 20 relevant papers a year and at least half of the sample
relevant), only the population PK short forms pass, in Europe PMC; in PubMed they are at the
threshold (49%).

**Would the terms close the gap?** Of the relevant papers outside the base set in the
reference samples, any candidate term finds: PubMed R1 11 of 19, R2 31 of 70 (21 by the
population PK short forms); Europe PMC R1 13 of 25, R2 17 of 51 (7 by the short forms). Most
missed papers use none of the field's words in their title, abstract or keywords, so a longer
term list cannot recover them.

**Do the missed papers use other tools?** Europe PMC relevant full-text papers naming an
estimation tool (local search, `findSoftware()`): NONMEM in 110 of 127 in the base set (87%)
and 120 of 153 outside it (78%); Monolix 13% and 14%; Phoenix NLME 2% and 5%. In the core
journals and the base sample alone, NONMEM is 68 of 79 (86%) in and 19 of 22 (86%) outside.
The outside sample is mostly the tool-anchored set, which did not anchor on Pumas, Stan or
Torsten. Small samples, not a test: no large difference, a possibly lower NONMEM share outside.

**Reading of the results (for Niclas to decide).** The base query finds about two thirds of
the relevant papers in Europe PMC and the core journals, and more in PubMed title and abstract
search. Extra terms add few relevant papers, except the population PK short forms; the rest of
the gap is papers that do not describe themselves with the field's words where the search
looks. For the published shares, the gap matters only if the missed papers use other tools,
and the samples show no large difference.

## Decision (Niclas, 2026-10-19)

- The extension takes the terms that are names of the method itself: the population PK
  short forms (the only term passing the proposed threshold), population pharmacodynamic
  and NLME (both small, with most of their sample relevant). Model-informed drug development
  and MIDD stay out, with the broad context terms: they name a framework or a context, not
  the method, and add few relevant papers.
- The frame is defined as the papers that describe themselves with the field's names for
  the method (`docs/design.md`, "The literature base set"); the remaining gap is stated as
  the frame's coverage, with the tool shares in missed papers (`../SOURCE.md`).
- PBPK and QSP become frames of their own, with their own test.
- Adopting the extension in the published series is a separate decision; the corpus
  records `admitted_by` for every extension paper.

## The extension in the corpus (development, 2026-10-19)

The three terms were queried for 2016 to 2026 (`../corpus_extension.R`), together with the
core for 2016 to 2020, and are in the corpus with `admitted_by` "extension": PubMed 769 papers,
Europe PMC 477 (three more were base papers that Europe PMC now lists under another ID, and are
left out). Europe PMC papers of the new years and of the extension whose full text names no
estimation tool were read for relevance as the base set's were (330 papers; 26 already decided
in the refinement reading; Claude Sonnet 5.5 subagents, blind Claude Opus 5.5 check 45 of 46, kappa 0.95, one
disagreement settled by Claude; `classifications/lit_relevance/corpus_decisions.csv`): 85 own
fit, 218 not own fit, 20 outside the field, 7 unclear.

Effect on the tool shares (papers naming each tool among papers naming any, by source and
year, `results/extension_shares.csv`, `05_extension.R`): at most 3.7 percentage points (PubMed
NONMEM 2020, 75% to 71%), mostly under 2. NONMEM in Europe PMC 2025: 74% with and without the
extension; Monolix 20% and 21%. The extension adds papers but does not change what they show.

## Files

- `common.R`: base set, query helpers and cache (as in `../publication_trends.R`).
- `results/reference_queries.csv`, `results/reference_ids.csv.gz`: the reference sets.
- `results/term_queries.csv`, `results/term_ids.csv.gz`: the term increments.
- `results/sample.csv`: the samples (seed 20261019); `results/fulltext_status.csv`.
- `corpus/pubmed`, `corpus/epmc`: the sampled papers' item and section tables (text in
  `corpus/cache`, not committed).
- `results/recall.csv`, `base_relevance.csv`, `capture_recapture.csv`, `term_yield.csv`:
  written by `04_measure.R` from `classifications/lit_relevance/decisions.csv`.
