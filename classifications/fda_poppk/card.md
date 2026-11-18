# Classification card: FDA population PK presence

| | |
|---|---|
| **Question** | Does the drug's FDA review describe a population PK (or population PK/PD) analysis that the Applicant submitted for this application? |
| **Values** | `present`, `absent` (`values.csv`) |
| **Scope** | The FDA review pages of the drugs of the years without a decision record (July to December 2020, 2026) whose FDA applicant use reading (`classifications/fda_use`) names no tool for the Applicant, as windows of 400 characters around each population PK mention, at most 20, with the review's numbered headings |
| **Candidates** | The population PK marker of the shared patterns (`patterns.json`) |
| **Rules** | A review that never mentions population PK is `absent` |
| **Role** | Splits "No tool identified in review" into the record's two categories, "popPK present, software not stated" and "No popPK analysis in review" (Niclas, 2026-10-20), for the FDA periods (`sources/fda/window.R`) |

## Development run of 2026-10-20

39 drugs (19 of 2020, 20 of 2026); 15 reviews never mention population PK (`absent` by rule),
24 were read by Claude Code subagents (Claude Sonnet 5.5), and 4 of them blind by a Claude Opus 5.5 subagent: 4 of 4
the same (`checks.csv`). Validation: 20 drugs of the 2021 to 2025 record, 10 of each category
(seed 20261020), read the same way: 20 of 20 agree with the record (`validation.csv`). Result:
23 present, 16 absent (`decisions.csv`).

Not done for these drugs: the search of the submission's other documents and the EMA
assessment reports that the record used for 2021 to 2025 (`sources/fda/other_reviews`).
