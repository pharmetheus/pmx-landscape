# Taxonomy

`taxonomy/` holds what all sources share, so their numbers line up:

- `software.csv`: one row per software family, with its group (estimation,
  auxiliary, pbpk, nca, other) and the names that count towards it. Only
  estimation tools count as popPK software.
- `patterns.json`: the regular expressions, each tagged with its family, used
  wherever text is searched by regex (FDA reviews, PAGE abstracts).
- `affiliation_rules.csv`: ordered rules that classify an affiliation as
  regulator, CRO, vendor, industry or academia; the first matching rule wins,
  and an affiliation no rule matches is `unclassified`.

## Add a software family

1. Add a row to `software.csv` and a pattern to `patterns.json` with the same
   family name and group.
2. Add a test in `pmxlandscape/tests/testthat/test-taxonomy.R` that the new
   names match, and run it red before the change.
3. Run `make test`. The taxonomy tests check that every family has a row and a
   pattern with the same group, and that in the FDA text the shared patterns
   find nothing the FDA record does not account for.
4. For the literature, add a query to `pm_tools` and `ep_tools` in
   `sources/literature/publication_trends.R`.
5. Read the new hits in each source before trusting them.

## Change an affiliation rule

Write the failing case first in `pmxlandscape/tests/testthat/test-page.R`
(invented names where the real ones do not matter), then edit the rules. Mind
the order: named companies come before the academic words, so "Novartis
Institutes" stays industry, and the academic words come before the generic
company words, so "Department of Pharmaceutical Sciences, University of X"
stays academia. Company names match as whole words only.
