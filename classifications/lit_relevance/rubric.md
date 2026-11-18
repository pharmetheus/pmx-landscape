The papers were found either because their title, abstract or keywords use the field's names for the method (such as "population pharmacokinetic"), or because they name a pharmacometric estimation tool (such as NONMEM, Monolix or Pumas). Judge each paper by what its authors did, not by the words or tools it names.

The text is the title and abstract (PubMed), or the title, abstract and methods section of the open-access full text (Europe PMC; the body when there is no methods section).

- `own_fit` needs the authors to estimate model parameters from data themselves: a population (mixed-effects) model, or an exposure-response or PK/PD model fitted to their own study data with a population approach. The software does not matter and need not be named.
- Not `own_fit`: PBPK or QSP models built or calibrated without population estimation, individual (non-population) compartmental fits, simulations from published models (including machine learning trained on such simulations), Bayesian forecasting or MIPD with published models, and a planned but not performed analysis. A simulation and re-estimation study of a method is `own_fit`.
- A published model used for forecasting or simulation is `own_fit` when the authors also fit a population part of their own to their data, such as a covariate or biomarker model with between-subject variability, or re-estimate the model's parameters.
- Machine learning or neural network PK models without random effects are not `own_fit`, even when compared with a population model, unless the authors fit that population model themselves.
- A drug trial whose only model is a statistical mixed model of a clinical endpoint (a linear or generalized linear mixed model, MMRM), with no drug exposure in the model, is `not_own_fit`.
- Population models of a disease course, biomarkers, growth, development or survival with no drug exposure or response in the model are `outside_field`, even when built with pharmacometric methods (for example a response to surgery).
- A collection of conference abstracts or congress proceedings is `not_own_fit`, even when some of its abstracts fit a model: it is not one paper.
- A meta-analysis that fits a population model to aggregate data (model-based meta-analysis) is `own_fit`; pooling published parameters without a model fit is `not_own_fit`.
- Veterinary and preclinical PK with a population model fit is `own_fit` (pharmacology).
- A tool named only when citing others' models, in background text or in a list of software does not make a paper `own_fit`. A paper describing a tool is `own_fit` only with an example fit to data.
- A word that only looks like a tool's name (the animal puma, "pumas"), or mixed-effects models outside pharmacology, is `outside_field`.
- Judge the authors' own work, not the literature they discuss.
- When the title and abstract alone do not show whether the authors fitted a model, and nothing else is given, the value is `unclear`. A specific statement is enough ("A population PK model was developed from the phase 1 data").
