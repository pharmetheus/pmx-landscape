# Analysis types by tool

Which kinds of analysis each estimation tool is named in, to see whether some
tools fill scientific or technical gaps that others leave. Covers the sources
whose text is cheap to read: PAGE abstracts, and PubMed and Europe PMC papers.
FDA reviews are covered separately, by reading (see below).

## Method (`analysis_types.R`)

- **Items:** every PAGE abstract (2006 to 2026, without Software Demonstration
  abstracts) that used an estimation tool, every Europe PMC paper (2021 to
  2026) whose authors fitted their own model with one (the fitting tool, as
  read for `analysis/model_size/`), and every PubMed paper (2021 to 2026) that
  names one. Literature reviews are left out (publication type), since they
  describe other people's work.
- **PAGE by reading:** the PAGE abstracts were read for tool roles and types
  together (`sources/page/role_decisions.csv`, rubric
  `sources/page/role_rubric.md`); the tools are those used and the types are
  the ones read, not the keyword rules. See the PAGE source card for the
  checks. Before the reading, the keyword rules gave PK only to 35% of the
  PAGE abstracts since 2016 that named a tool; the reading gives 45% of those
  that used one.
- **Text** for the keyword rules: title and abstract.
- **Types** (`taxonomy/analysis_types.csv`), agreed complexity scale: 1 PK
  only; 2 continuous PK/PD, exposure-response, disease progression; 3
  non-continuous endpoints, time-to-event; 4 joint models; 5 full Bayesian
  hierarchical models; 6 machine learning, AI, neural ODEs; 7 QSP, PBPK. An
  item can have several types; "PK only" is given only when nothing higher
  applies. Sentences about background, the literature or future work are
  dropped first. Tool names are never evidence of a type, since types are
  compared across tools.
- **Presentation** (`lumpTypes()`): results files keep all seven types. The
  README merges joint models into time-to-event (too rare to stand alone), and
  shows PubMed and the FDA reviews only as PK only against any other type,
  since they have few complex analyses.
- **Checks** (`results/checks.csv`): the reading checks behind the accuracy
  figures quoted in the README.
- **Comparison** (`typeLift()`): for each tool and type, the share among the
  tool's items against the share among the other items, as a ratio with a 95%
  interval.

## Checks

For the keyword rules (now used for the literature only): two reading checks
by a Claude Sonnet 5 reader against the category definitions, on samples of up to 12
items per type and source. The first (268 items) found
40% disagreement and led to the current rules, each correction with a test;
the second, on a fresh sample (231 items), agreed with 215 (93%), disagreed
with 11 and was unsure of 5. Remaining errors: PAGE abstracts that are
themselves reviews get every type they mention; "AI" as motivation; rare
missed continuous responses; a Bayesian analysis shown only by its tool name.

## FDA reviews (`fda_analysis_types.R`)

For each of the 148 drugs whose review names the sponsor's estimation tool,
the review text within 800 characters of each mention of the tool (OCR pages
included) is the evidence. The keyword rules did not work on it: two reading
checks agreed with 13 of 33 and 15 of 34 drugs, because FDA reviews mix
several analyses, tools and template sections on every page, and
exposure-response analyses are often done in R next to a NONMEM popPK model.
The types are therefore decided by reading, as the FDA record itself was:
Claude Sonnet 5 readers with a written rubric decided each drug from its windows, and
Claude checked a random 15% (22 drugs, 21 agreed; the one miss was
corrected). `fda_decisions.csv` holds the decisions with reasons; the keyword
result stays in `results/fda_items.csv` as `keyword_types` for comparison.
Two drugs have no windows (their tool appears in a dataset name or in a form
the pattern does not match) and no type.

## Files

- `fda_decisions.csv`: one reading decision per FDA drug: types, level,
  reason, who decided.
- `results/fda_items.csv`, `results/fda_type_by_tool.csv`: FDA types per drug
  and per tool.

- `results/items.csv`: one row per item: source, ID, year, tools, types,
  highest level. No text.
- `results/type_by_tool.csv`: counts and shares per source, tool and type.
- `results/type_lift.csv`: the ratios and intervals.
- `results/page_methods_applied.csv`: PAGE abstracts per year in methodology
  and in applied sessions, per tool and per analysis type (level 4 and up).
  Methodology sessions are recognised by topic (`pageMethodology()`), since
  PAGE labelled them without a "Methodology" prefix in 2011 to 2013; PBPK
  sessions count as applied work throughout.
- `results/run_info.txt`: counts, reviews left out.
