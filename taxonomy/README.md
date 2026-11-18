# Shared software taxonomy

One list of software families and one set of search patterns, used by every
source so that results line up.

- `software.csv`: one row per family, with its group and the names that count
  towards it. Groups: `estimation` (popPK estimation tools), `auxiliary` (PsN,
  Pirana, Xpose, simulation and other helpers), `pbpk`, `nca` and `other`
  (general-purpose software such as SAS and R). Only estimation tools count as
  popPK software; the other groups are tallied separately.
- `patterns.json`: the regular expressions, each with its group and family,
  for sources searched by regex. The PAGE script and the FDA cross-check use
  it; the published FDA run keeps its own copy (below). Literature counts use
  query strings instead, which live in the literature script and follow the
  same families and variants, written in each service's query syntax.

`sources/fda/config/patterns.json` is the pattern set of the published FDA
run and is kept unchanged as that record. This shared file started from it and
adds BUGS (MultiBUGS, PKBugs), OpenPMX, and PhysPK, PoPy and SAAM II from
PAGE's parameter estimation software page, none of which occur in the FDA
reviews for 2021 to 2025. Simcyp is case-insensitive here: the FDA set missed
14 mentions spelt simcyp, SimCyp, SimCYP or SIMCYP, all in drugs that already
record Simcyp. The `pmxlandscape` tests check that those are the only FDA hits
the shared set adds, and that every family has both a row and a pattern.

- `affiliation_rules.csv`: ordered rules that classify an affiliation as
  regulator, CRO, vendor, industry or academia; the first matching rule wins, and
  an affiliation no rule matches is `unclassified`. Used for the first
  author's affiliation of conference abstracts.

To add a tool: add a row to `software.csv` and a pattern to `patterns.json`,
run the `pmxlandscape` tests, and check the new hits by reading them.

Which tools to add is proposed by the discovery procedure in
[`discovery/`](discovery/README.md): it finds software names in the cached
text of every source by the words around them, records a decision for each
name, and applies a fixed inclusion rule (October 2026). The list above grew
before it; the first round's proposals are waiting for a decision.

September 2026 additions, from a sample of the 2024 literature: MonolixSuite
and versioned Monolix names (Monolix2024R1), Phoenix followed by NLME within
six words (including "Phoenix® NLMETM", where the trade mark sign is
flattened), and a new estimation family, MATLAB NLME (nlmefit, nlmefitsa,
sbiofitmixed). Checked against the project's own inputs: in the FDA reviews
they add nothing; in the PAGE abstracts they add Monolix to 32 abstracts and
MATLAB NLME to 2.
