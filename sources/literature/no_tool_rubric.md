# Reading rubric: Europe PMC papers that name no estimation tool

Each paper matched the base terms ("population pharmacokinetic(s)",
pharmacometric*, "(non-)linear mixed effects") in its title, abstract or
keywords, but its full text names none of the estimation tools searched for.
Decide from the title, publication type, keywords, abstract, methods and the
sentences naming software:

| decision | when |
|---|---|
| `own_fit` | The authors fit a population (nonlinear mixed effects) model of their own, in pharmacology: PK, PK/PD, exposure-response, disease progression, time-to-event, QSP or PBPK with population estimation, pharmacometric methodology tested on data or by simulation-estimation. Counts even if the software is not named, or is named but is not an estimation tool (for example their own code in R, Julia or MATLAB). |
| `not_own_fit` | No model fit of their own: uses or cites a published popPK model (for example to simulate or predict), non-compartmental analysis only, simulation only with a published model, dosing software or MIPD validation, review, systematic review, meta-analysis of published parameters without fitting a population model, editorial, commentary, letter, protocol, guideline, regulatory analysis, erratum. |
| `outside_field` | Nonlinear mixed effects or pharmacometric wording used outside pharmacology: ecology, agriculture, animal growth, psychology, epidemiology or social science without drug exposure or response. |
| `unclear` | Cannot be told from the text given. |

Rules:

- `own_fit` needs the authors to estimate model parameters from data
  themselves: a population (mixed-effects) model, or an exposure-response or
  PK/PD model fitted to their own study data. Not `own_fit`: PBPK or QSP
  models built or calibrated without population estimation, individual
  (non-population) compartmental fits, simulations from published models
  (including machine learning trained on such simulations), and Bayesian
  forecasting or MIPD with published models. (Sharpened after the check of a
  15% sample, September 2026, where these cases split the two readers.)
- A planned but not performed popPK analysis is `not_own_fit`.
- A meta-analysis that fits a population model to aggregate data is `own_fit`.
- Veterinary PK with a population model fit is `own_fit` (pharmacology).
- Judge the authors' own work, not the literature they discuss.
- The reason is one short line, in your own words, with no quotation of more
  than a few words from the paper.
