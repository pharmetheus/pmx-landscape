The papers come from the reference sets and candidate search terms of the literature refinement study (`sources/literature/refinement`): some match the survey's base search terms, some do not. Judge each paper by what its authors did, not by the words it uses.

The text is the title and abstract (PubMed), or the title, abstract and methods section of the open-access full text (Europe PMC; the body when there is no methods section).

- `own_fit` needs the authors to estimate model parameters from data themselves: a population (mixed-effects) model, or an exposure-response or PK/PD model fitted to their own study data with a population approach. The software does not matter and need not be named.
- Not `own_fit`: PBPK or QSP models built or calibrated without population estimation, individual (non-population) compartmental fits, simulations from published models (including machine learning trained on such simulations), Bayesian forecasting or MIPD with published models, and a planned but not performed analysis.
- A meta-analysis that fits a population model to aggregate data (model-based meta-analysis) is `own_fit`.
- Veterinary PK with a population model fit is `own_fit` (pharmacology).
- Judge the authors' own work, not the literature they discuss.
- When the title and abstract alone do not show whether the authors fitted a model, and nothing else is given, the value is `unclear`.
