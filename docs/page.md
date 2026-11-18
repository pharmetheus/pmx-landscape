# PAGE abstracts

Run from the repository root:

```
make page-pilot   # 25 random abstracts, writes sources/page/pilot/
make page         # meetings in `years` (2006 to 2026), writes sources/page/results/
```

Both need network access. A full run from an empty cache takes about three
hours plus PDFs, at one request every 1.5 s, and resumes from `sources/page/page_cache/` if it is
stopped. The cache, `pilot/` and `review/` hold PAGE's text and are not
committed.

## What the run does

1. Reads the abstract URLs from the sitemaps. They have no years, but list
   abstracts in abstract-number order. The full run bisects that order for the
   first abstract two years before the first year wanted, checks 40 random
   earlier pages for any wanted year (it stops if it finds one), and keeps
   abstracts whose own citation line gives a wanted year.
2. Parses each page (`pageParseAbstract()`): year and abstract number, the body
   without authors, affiliations and references, the session, and the first
   author's affiliation, classified with `classifyFirstAuthor()`.
3. Searches the body with `taxonomy/patterns.json`. Only when the body names no
   estimation tool is the poster or presentation PDF searched.
4. Writes `results/page_abstracts.csv` and `results/run_info.txt`, and the PDF
   hits to read to `review/pdf_review.csv`.

## Reading PDF hits

Every estimation tool found only in a PDF needs a row in
`sources/page/pdf_decisions.csv`:

| column | value |
|---|---|
| `abstract_no`, `family` | the hit |
| `decision` | `used` (the work used the software), `cited` (only cited or mentioned) or `other` (a name, OCR noise, an unrelated word) |
| `reason` | in your own words; no PAGE text |
| `decided_by`, `decided_on` | who and when |

`review/pdf_review.csv` gives up to five snippets per hit and a
`all_citation_like` hint. Only `used` counts. Until every hit is decided,
`pageShares()` refuses to count, so no share can be published with pending
hits. Re-run `make page` after recording decisions: everything is cached.

## Reading tool roles and analysis types

Only the tools an abstract used count. After the run, from `sources/page/`:

```
Rscript role_review.R
```

writes `review/role_review.csv` (git-ignored: it holds PAGE text) with the
title, body and tools of every abstract that names one, and reports how many
already have a decision. Each abstract is read following `role_rubric.md`,
and the result goes to `role_decisions.csv`, one row per abstract:

| column | value |
|---|---|
| `abstract_no` | the abstract |
| `roles` | `Tool=role` pairs separated by "; ", role `used`, `comparator` or `mentioned`; tool names as in the results |
| `types` | the analysis types, numbers 1 to 7 separated by "; ", or `none` |
| `note` | one short line in your own words; no PAGE text |
| `decided_by` | who read it |

`pageUsedTools()` applies the roles; the README and
`analysis/analysis_types/analysis_types.R` both use it. A new meeting year
only needs its new abstracts read. Check a random 15% with a blind second
reader, decide the disagreements, and record the agreement in
`results/role_check.csv`.

## Checks before publishing numbers

- `run_info.txt`: pages that could not be fetched (must be 0), the order check,
  and pending PDF hits (must be 0).
- Read a sample of each affiliation class, and change a rule only with a test
  (see [Taxonomy](taxonomy.md)).
