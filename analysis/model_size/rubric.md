# Extraction rubric: model and data size

One row per paper. Read the title, abstract, methods, the start of the
results, the tables and the data sentences. Report only what the text states;
unstated means `NA`, never a guess.

| field | what to record |
|---|---|
| `own_fit` | `yes` if the authors estimated a population (mixed-effects) model themselves; `no` for reviews, tutorials without a fit, papers that only use or cite a published model, NCA only, simulation only. If `no`, leave every other field `NA` except `note`. |
| `tool` | The estimation tool that fitted the final model, as one of the tool names given with the paper. `several` if final models were fitted with different tools; `not stated` if the paper names tools but not which one fitted the final model. |
| `method` | The estimation method of the final model as stated: `FO`, `FOCE`, `FOCE-I`, `LAPLACE`, `SAEM`, `IMP`, `BAYES` (MCMC, NUTS, HMC), `NPAG`, `other`, or `not stated`. FOCE with interaction is `FOCE-I`. NONMEM SAEM is `SAEM`; the Monolix default is SAEM only if the paper says SAEM or does not name another method (then write `SAEM (default)`). |
| `analysis` | Type of the final model(s): `pk_only` (PK, including parent and metabolite PK), `pkpd` (PK/PD or exposure-response with a continuous response), `tte` (time-to-event, count or categorical responses), `disease` (disease progression without drug PK), `other`. |
| `n_models` | How many final models the counts below add up (a PK model and a separately fitted PD model: 2; one joint PK/PD model: 1). |
| `structural` | Estimated structural fixed effects: typical values such as CL, V, Q, ka, F, lag time, Emax, EC50, baseline, rate constants. Not covariate effects, not residual error, not parameters fixed to a value. |
| `covariates` | Estimated covariate effect parameters in the final model: each coefficient counts (a covariate with three categories and two estimated effects: 2). Fixed allometric exponents do not count; estimated exponents do. |
| `iiv` | Estimated between-subject (IIV) variance or SD terms. |
| `iov` | Estimated between-occasion (IOV) terms. |
| `covariances` | Estimated off-diagonal random-effect terms (covariances or correlations). |
| `residual` | Estimated residual error parameters. |
| `params_source` | `table` or `text` where the final estimates were read; `not_reported` if they are not in the text given (then the six counts are `NA`). |
| `n_subjects` | Individuals in the dataset the final model was fitted to. |
| `n_obs` | Observations the final model was fitted to (PK concentrations for a PK model; all fitted observations for PK/PD). |
| `note` | One short line in your own words; never quote more than a few words. |

Counting rules:

- Count the parameters of the final model(s), from the final parameter table
  where there is one.
- A parameter shown as fixed (FIX, fixed, no RSE given and marked as taken from
  the literature) is not counted.
- If only a base model and a final model are given, count the final model.
- If a parameter table is cut off, write `NA` for every count it does not
  fully show; a partial count would undercount the model. (Added after the
  first batches; for those, counts in rows whose note says the table was
  truncated are treated as `NA`.)
- When a count cannot be made with confidence, write `NA` for that count and
  say why in `note`.
