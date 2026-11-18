# Model and data size by tool

Whether the tool, and the estimation algorithm behind it, goes with the size of
the models people report: the hypothesis is that SAEM (the Monolix default),
being more permissive than NONMEM's gradient-based methods, leads to larger
models. Also the size of the data the models are fitted to, per tool.

## Method

- **Papers:** every Europe PMC base-set paper (base terms in the title,
  abstract or keywords, 2021 to 2026) that names an estimation tool: 2,379
  papers. `prepare.R` fetches each paper's open-access full text (cached in
  `sources/literature/cache/`, not committed) and writes the text to read to
  `review/` (not committed): abstract, methods, the start of the results, the
  tables that look like parameter tables, and the sentences that give numbers
  of subjects or observations.
- **Extraction:** Claude Sonnet 5 readers, in 60 batches, following `rubric.md`: whether
  the authors fitted a population model of their own, with which tool and
  estimation method, the analysis type, and from the final parameter table the
  number of structural fixed effects, covariate effects, IIV, IOV and
  covariance terms and residual error parameters, the number of subjects and
  of observations. Unstated means `NA`, never a guess. The results, IDs and
  numbers only, are in `extractions.csv`.
- **Check:** a blind Claude Opus 5.5 re-extraction of a random 15% sample, stratified by
  the tools named (`results/checks.csv`). Where the two readers differ in the
  sample, the Claude Opus 5.5 value is used (`decided_by`).
- **Rules applied when merging:** counts taken from a table the reader noted as
  cut off are set to `NA` (the rule was added to the rubric after the first
  batches); Phoenix's FOCE-ELS, recorded as `other`, counts as FOCE.
- **Measures:** fixed effects = structural + covariate effects (residual error
  not counted); random effects = IIV terms. The main comparison uses papers
  with a single final model, since several models summed would read as one
  large model.
- **Comparison** (`modelSizeRatio()`): a quasi-Poisson regression of the count
  on the tool (Monolix against NONMEM) or the algorithm (SAEM against FOCE),
  crude and adjusted for analysis type, log number of subjects and publication
  year.

## Limits

- Only open-access papers with the parameters in the article text; papers that
  put the final estimates in a supplement have no counts.
- A tool named in a paper is not necessarily the one that fitted the final
  model; the readers recorded the fitting tool, and papers where it could not
  be told are left out of the tool comparison.
- The estimation method is not stated in most NONMEM papers, so the algorithm
  comparison rests on the papers that state it.
- Model size also reflects the data, the drug and the purpose of the analysis;
  the adjusted comparison removes only what analysis type, data size and year
  explain.
