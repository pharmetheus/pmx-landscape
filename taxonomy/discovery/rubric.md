# Reading rubric: candidate software names

Each row is one candidate name found by the discovery cues, with up to five
snippets from different items (PAGE abstracts, PubMed and Europe PMC papers,
FDA reviews) showing it in use, its item count and any registry that lists it.
Decide what the name is, from the snippets and what is generally known about
the name. Do not fetch anything.

## Decisions

- **estimation**: software that estimates the parameters of population
  (nonlinear mixed effects) or individual PK/PD models from data: NONMEM,
  Monolix, Phoenix NLME, the R packages nlme, nlmixr and saemix, WinNonMix,
  P-PHARM, NPEM, ADAPT, Pmetrics, Stan.
- **auxiliary**: software that supports a modelling workflow without being the
  estimation engine: run managers and diagnostics (PsN, Pirana, Xpose),
  simulation tools (mrgsolve, Simulx), design tools (PopED, PFIM), model
  libraries, dosing and TDM software (InsightRX, MwPharm), reporting tools for
  pharmacometrics.
- **pbpk**: PBPK and QSP platforms (Simcyp, PK-Sim, MoBi, GastroPlus).
- **nca**: non-compartmental analysis tools (Phoenix WinNonlin, PKNCA,
  PKanalix).
- **general**: general-purpose software used in the work but not specific to
  pharmacometrics: R, RStudio, SAS, SPSS, Stata, MATLAB, Python, Excel,
  GraphPad Prism, Fortran compilers, plotting and data packages (ggplot2),
  digitisers (WebPlotDigitizer), laboratory or instrument software.
- **method**: not software but a method or algorithm: estimation methods
  (FOCE, SAEM, Laplace, importance sampling, MCMC), modelling approaches
  (PBPK as a method, Monte Carlo simulation, Kaplan-Meier), diagnostics (VPC,
  NPDE as a method). Use this only when the name means the method; if the name
  is a software package of the same name (the R package npde), decide by what
  the snippets show.
- **not_software**: anything else: drugs and brand names, reagents,
  companies and organisations (Certara, Lixoft, Sigma-Aldrich), document
  headings, terminologies and criteria (MedDRA, RECIST, CTCAE), statistical
  abbreviations, places, journals, people.
- **unclear**: the snippets do not show what it is, and it is not generally
  known.

A company that sells a tool is **not_software**; the tool is its own name.

## Family

For a tool (estimation, auxiliary, pbpk, nca, general): the family name the
tool is known by, merging variants: "MonolixSuite" and "Monolix 2024R1" are
Monolix, "rxode2" is RxODE, "IBM SPSS Statistics" is SPSS, "GraphPad" is
GraphPad Prism. Leave it empty otherwise.

## Note

One short line in your own words: what the name is (no quotation from the
snippets).

## Output

One line per input row, in input order: `row,key,name,decision,family,note`,
with row, key and name copied exactly from the input.
