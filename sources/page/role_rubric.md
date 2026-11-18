# Reading rubric: tool role and analysis type in PAGE abstracts

Each abstract (title and body, without authors, affiliations and references)
names one or more estimation tools, listed under TOOLS NAMED. For each, and
for the abstract as a whole, record what the authors did.

## Tool role

For every tool listed, one of:

| role | when |
|---|---|
| `used` | The authors used the tool for their own analysis: fitting, estimation, simulation with their model, or the tool is the platform their new method runs in. |
| `comparator` | The tool is a benchmark or reference the authors' own method or tool is compared with ("compared with SCM in Monolix", "results agreed with NONMEM"). |
| `mentioned` | Named only in passing: background, a list of software, an example of what others use, future work. |

If the abstract is about a tool itself (a new feature, package or interface
for that tool), the tool is `used`. A tool marked "(from poster: used)" was
already checked in the poster PDF; keep it `used`.

## Analysis type

The types of the authors' own analysis, on the agreed scale; several can
apply, give all of them as numbers separated by ";":

1. PK only
2. Continuous PK/PD, exposure-response, disease progression
3. Non-continuous endpoints, time-to-event (categorical, count, TTE)
4. Joint models (a longitudinal response and an event linked, for example
   tumour size with survival, PK/PD with informative dropout)
5. Full Bayesian hierarchical models (MCMC, Stan, BUGS; not MAP Bayesian
   forecasting)
6. Machine learning, AI, neural ODEs
7. QSP, PBPK

Clarifications added after the blind check (2026-09-29):

- `4` needs a longitudinal response and an event process estimated
  simultaneously: one joint likelihood, for example shared random effects or
  the predicted response driving the hazard within the same fit (Niclas,
  2026-09-29). A sequential or two-stage analysis, where a metric from a
  fitted longitudinal model enters a separately fitted survival or dropout
  model, is `2` and `3`, not `4`. Several continuous biomarkers modelled
  together, or two event processes linked to each other, are not `4`.
- `7` is a model the authors describe as QSP, systems pharmacology or
  systems biology, or a physiologically based (PBPK) model with organ
  volumes and blood flows. Mechanistic viral dynamics, tumour growth,
  tumour-immune, cell kinetic, bacterial or turnover models are `2`, not
  `7`, unless the authors call them QSP. An empirical organ compartment
  model is not PBPK, and neither is a PBPK model used only to simulate the
  data for another analysis (the type is that of the analysis).
- Exposure-response studied with plain statistics (correlation,
  regression) counts by its endpoint: continuous `2`, binary or event `3`.

Give `1` only when nothing higher applies. Judge the authors' own work, not
background, literature or future work. Methodology work counts by what it is
applied to (a covariate-selection method tested on PK models: 1; a neural-ODE
method: 6). Write `none` when the abstract has no analysis of its own (a
review, a software description without an application).

## Output

One row per abstract: `id,roles,types,note`, where `roles` is
`Tool=role` pairs separated by ";" (for example `Monolix=comparator;NONMEM=used`),
`types` the numbers separated by ";" or `none`, and `note` one short line in
your own words, never quoting more than a few words.
