# Codebook: literature relevance, version 2

Status: frozen on 2026-10-20. It passed the held-out test (below), which approves it without a
separate approval (Niclas, 2026-10-20). Four hard cases (a published model with a part of the
authors' own, machine learning, statistical mixed models, no drug) were written after the test,
from its disagreements. The collections case was added on 2026-10-21 by Niclas's decision, after
the development run; the two collections the run had read as `own_fit` were changed to match. Terms used in a specific sense are defined in
`docs/glossary.md`.

This page explains how the relevance classification decides. The files the code reads are
`module.json`, `values.csv` and `rubric.md`. The method shared by all classifications is in
`classifications/README.md`.

## The question

Did the authors of this paper fit a population model of their own to data, in pharmacology?

An example: a paper reports a phase 2 trial and, in its methods, says the plasma concentrations
were "analysed with a two-compartment population PK model in NONMEM 7.5". The authors estimated
the model's parameters from their own data, so the value is `own_fit`. A review that discusses
published NONMEM models has no fit of its own, so the value is `not_own_fit`.

## Why it is asked

The literature results count which tools pharmacometric papers use, as a share of the papers
counted. Only papers with a model fit of their own are counted. From 2026-10-20 every paper is
read for this, whichever route found it: the term route (the field's names for the method in the
title, abstract or keywords) or the tool route (a pharmacometric estimation tool named in the
title and abstract, or in the methods of the full text). Version 1 was the rubric of the
literature refinement study of 2026-10-19; the frame papers that named no tool were read earlier
with a rubric of their own (`sources/literature/no_tool_rubric.md`). Version 2 merges the two.

## What is decided

One value per paper. The software does not matter, and need not be named: a paper that fits a
model in its own code, or does not say with what, can be `own_fit`.

## The text that is read

- PubMed: the title and abstract.
- Europe PMC: the title, abstract and methods section of the open-access full text. When the
  methods section is missing or shorter than 200 characters, the body is read instead.

## Values

| Value | Meaning |
|---|---|
| `own_fit` | The authors fit a population (nonlinear mixed-effects) model of their own to data, in pharmacology: PK, PK/PD, exposure-response, disease progression, time-to-event, QSP or PBPK with population estimation, or pharmacometric methodology tested on data or by simulation and estimation. |
| `not_own_fit` | No population model fit of the authors' own: a published model used to simulate or predict, non-compartmental analysis only, simulation only, dosing software or MIPD validation, review, meta-analysis of published parameters without a population model, editorial, commentary, letter, protocol, guideline, erratum. |
| `outside_field` | The paper is not in pharmacology: mixed-effects models or a tool's name in ecology, agriculture, animal growth, psychology, epidemiology or social science without drug exposure or response, or a word that only looks like a tool's name (the animal puma). |
| `unclear` | The text given does not show whether the authors fitted a population model. |

## Hard cases

- **Estimation from their own data.** `own_fit` needs the authors to estimate model parameters
  from data themselves: a population model, or an exposure-response or PK/PD model fitted to
  their own study data with a population approach.
- **Not a population fit.** PBPK or QSP models built or calibrated without population estimation,
  individual (non-population) compartmental fits, and Bayesian forecasting or MIPD with published
  models are `not_own_fit`.
- **Simulation.** Simulations from published models are `not_own_fit`, including machine learning
  trained on such simulations. A simulation and re-estimation study of a method is `own_fit`.
- **A published model with a part of the authors' own.** A published model used for
  forecasting or simulation is `own_fit` when the authors also fit a population part of their
  own to their data (a covariate or biomarker model with between-subject variability), or
  re-estimate the model's parameters. Used as published, it is `not_own_fit`.
- **Machine learning.** Machine learning or neural network PK models without random effects are
  `not_own_fit`, even when compared with a population model, unless the authors fit that
  population model themselves.
- **Statistical mixed models.** A drug trial whose only model is a statistical mixed model of a
  clinical endpoint (a linear or generalized linear mixed model, MMRM), with no drug exposure in
  the model, is `not_own_fit`.
- **No drug.** Population models of a disease course, biomarkers, growth, development or
  survival with no drug exposure or response in the model are `outside_field`, even when built
  with pharmacometric methods (for example a response to surgery).
- **Collections.** A collection of conference abstracts or congress proceedings is
  `not_own_fit`, even when some of its abstracts fit a model: it is not one paper (Niclas,
  2026-10-21).
- **Plans.** A planned but not performed analysis (a protocol) is `not_own_fit`.
- **Model-based meta-analysis.** A population model fitted to aggregate data from the literature
  is `own_fit`. Pooling published parameters without a model fit is `not_own_fit`.
- **Animals.** Veterinary and preclinical PK with a population model fit is `own_fit`: it is
  pharmacology.
- **A tool named but not used.** A paper that names a tool only when citing others' models, in
  background text or in a list of software is judged by what its authors did. Naming a tool does
  not make a paper `own_fit`.
- **Software papers.** A paper describing a tool, with an example fit to data, is `own_fit`
  (methodology tested on data). Without an example fit, it is `not_own_fit`.
- **The authors' own work.** Judge the authors' own work, not the literature they discuss.
- **Not enough text.** When the title and abstract alone do not show whether the authors fitted a
  model, and nothing else is given, the value is `unclear`. A specific statement is enough ("A
  population PK model was developed from the phase 1 data").

## How the codebook is tested

The development items are the papers already read with the two earlier rubrics, in the corpus
(`decisions.csv` of the refinement, `corpus_decisions.csv`, and
`sources/literature/no_tool_decisions.csv`). A random sample of them, stratified by source and
earlier value, is held out and read with this version by Claude Code subagents. The test passes
at 90% agreement with the earlier decisions and a kappa of at least 0.8. Every disagreement is
read; a rule changes only when the disagreement shows the rule, not the earlier reader, was
unclear.

## Result of the test, 2026-10-20

- **Agreement.** 195 of 208 held-out papers (93.8%), kappa 0.90 (`heldout.csv`,
  `heldout_disagreements.csv`). The test passed. Readers: Claude Code subagents running Claude Sonnet
  5.5, each checked to have read its whole batch file.
- **The 13 disagreements, read by Claude (Opus 5.5).**
  - The earlier reading was wrong in 6: 2 papers state a population PK analysis of their own
    that the earlier reader missed, and 4 were called `unclear` although they state that a
    model was developed, which this version counts as enough.
  - This version's reader was wrong in 2: a phase 2 trial stating its population PK analysis,
    and a paper fitting its own mixed-effects biomarker model on top of a published PK model.
  - The rules did not settle 4, which gave three hard cases: machine learning without random
    effects (2 papers), a drug trial analysed with a statistical mixed model, and population
    models of a disease course after surgery. The reader's second error gave the fourth, a
    published model with a part of the authors' own.
  - The no-drug case was first written as `own_fit`. The first 20 reading batches showed it
    admitting developmental and natural-history models (one paper on hand use in cerebral
    palsy), so it was changed the same day to `outside_field`, the earlier reading's value
    and the tested version's definition of the field. Papers of batches 1 to 20 read under the
    first wording and called `own_fit` without a drug were read again.
  - 1 more was an earlier error under a rule that already existed (a minimal PBPK model fitted
    without population estimation).
- **Not tested again.** The four added hard cases were not tested on held-out papers. The
  blind check of the development run tests the version as frozen.
