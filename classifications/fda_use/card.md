# Classification card: FDA tool use (independent check)

| | |
|---|---|
| **Question** | For each estimation tool named in a drug's FDA reviews, what does the review show about the Applicant's use of it for the population analyses: stated, indirect, only the FDA template sentence, or no use by the Applicant? |
| **Values** | `stated`, `indirect`, `template`, `none` (`values.csv`); the FDA reviewer's own use is `none` unless it shows what the Applicant used (the reviewer-run rule, Niclas 2026-10-19) |
| **Scope** | The FDA review pages of the 238 drugs of 2021 to 2025 (corpus `fda`), as windows of 400 characters either side of each mention, at most 20 per tool, labelled with document and page and with the review's numbered section headings above them (the nearest within 20 pages) and the last label line ("Applicant's Position", "FDA's Assessment", "Reviewer's Comment") on the same or the previous page |
| **Candidates** | The estimation patterns of the published FDA run, regexes unchanged (`patterns.json`, from `sources/fda/config/patterns.json`; the expanded NONMEM name counts as NONMEM) |
| **Rules** | None: an independent check reads every candidate |
| **Role** | Checks the FDA decision record (`sources/fda/results/fda_2021_2025_popPK_software.csv` with `record_revisions.csv`), which stays the decision of record (Niclas, 2026-10-18). Agreement is published; every disagreement is listed for Niclas |

## Run of 2026-10-19 (version 2)

155 drug and tool pairs in 151 drugs, read by Sonnet 5.5 through the Batch API ($0.24); a
blind second reading of 23 drugs by Opus 5.5 agreed on all 23 ($0.09). Against the record
with its revisions, the reading gives the same value for 145 of 155 pairs (kappa 0.82;
`record_comparison.csv`). The 10 differences (`record_disagreements.csv`):

- 4 between stated and indirect (Pluvicto, Mounjaro, Lunsumio: the record stated, the reading
  indirect; Redemplo the other way), counted the same either way;
- 3 where the record has the template sentence only and the reading indirect evidence
  (Pyrukynd, a "NONMEM dataset" in the Applicant's analysis summary; Crenessity, the template
  sentence and the abbreviation list; Palsonify, an edited template sentence naming the
  Applicant's final model), for Niclas to decide;
- Grafapex, where the review's own evidence (the reviewer's simulation from the Applicant's
  model in NONMEM 7.4) gives indirect by the reviewer-run rule; the record has it as indirect
  from the EPAR, so the result is the same;
- Dawnzera and Rhapsido, where the reading gave `template` although the review states another
  tool, against the rubric (the record is right).

## Reading of the 2026 approvals (2026-10-20, development)

For 2026 there is no hand-built record, so this reading, checked, is the record (decided
2026-10-20). The 2026 frame has 46 approvals up to 2026-10-09; FDA's page links no labels that
year, so the application numbers come from openFDA by brand name and approval date
(`fdaApplByBrand()`); one drug (Hovilpri, approved 2026-10-09) is not yet in openFDA. Review
documents are posted for 40 drugs, all approved up to June among them. 20 of the 40 reviews name
an estimation tool; their 21 drug and tool pairs were read by Claude Code subagents (Claude Sonnet 5.5), and
3 drugs blind by a Claude Opus 5.5 subagent: 3 of 3 the same. Result: NONMEM 17 stated, 2 indirect, 1
template; one Stan/Torsten hit was OCR noise (`none`). The reading subagent wrote its answers
file with a script run through Bash, against its instructions; the answers are its own and kept.
Drugs whose review names no tool are "No tool identified in review": the reading cannot tell a
population PK analysis without a named tool from no analysis.

These drugs enter the FDA periods (`sources/fda/window.R`, `results/fda_periods.csv`).

## Reading of the July to December 2020 approvals (2026-10-20, development)

Read so that the period 2020/21 is complete (Niclas, 2026-10-20). 28 approvals, 27 with reviews
(`sources/fda/extract.R 2020 2020-07-01`); 9 reviews name an estimation tool, 10 drug and tool
pairs, read by a Claude Code subagent (Claude Sonnet 5.5), and 1 drug blind by a Claude Opus 5.5 subagent: 1 of 1 the
same (agent round `2020h2`, `run.R batches 2020h2`). Result: NONMEM 3 stated and 5 indirect; two
Stan/Torsten hits were a first name and OCR noise (`none`). Both subagents wrote their answers
nested in an extra `answer` field; a script moved each answer to the top level and added the
title start from the batch, without changing any decision. Drugs whose review names no tool go to
`classifications/fda_poppk`.

## Standard tables (`report_methods.csv`, `report_values.csv`)

Made by `classifications/standard_tables.R fda_use`. All 176 tags are readings (no rules, no
adjudications), so none is exactly reproducible; the record comparison above is this
classification's check.

## Run of 2026-10-18 (version 1, superseded)

Version 1 asked who used the tool (`applicant`, `reviewer`, `both`, `indirect`, `mentioned`). Its outputs are replaced by version 2; the numbers below are kept as the record of that run.

151 drugs with an estimation tool named, 155 drug and tool pairs, read by Sonnet 5.5 through
the Batch API ($0.23); a blind second reading of 23 drugs by Opus 5.5 agreed on all 23
($0.12). Against the record, the reading gives the same value for 142 of 155 pairs (kappa
0.82; `record_comparison.csv`). None of the 13 differences changes a drug's sponsor tool
(`record_disagreements.csv`, for Niclas to decide; the record is unchanged):

- 4 where the reader saw the FDA reviewer also running NONMEM (the record: Applicant, indirect
  evidence; the reading: both), and 1 where it saw only the reviewer's run;
- 3 where the Applicant's NONMEM use is stated in the record and the reading saw it only
  indirectly: twice the expanded name "nonlinear mixed effects modeling 7.5.0", which the
  rubric does not yet say counts as NONMEM, and once a software table the reading took as a
  list;
- 2 where the reading found stated use the record has as indirect, 1 where it found the
  reviewer's use as well (Tryvio, Monolix), and 2 template-only cases where another tool is
  stated (the record: not used; the reading, by the rubric: indirect).
