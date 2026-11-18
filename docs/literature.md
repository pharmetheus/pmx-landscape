# Literature

```
make literature
```

runs `sources/literature/publication_trends.R` and then `affiliations.R`
(network access; a few minutes).

1. **Counts and IDs.** For each publication year and source, the base set and
   one query per software family. Every query's IDs are stored in
   `results/ids.csv.gz` with the count the service reported, the query string
   and the run date. The script stops unless every query retrieved as many IDs
   as the service reports and every tool ID lies in the base set of its source
   and year (`results/run_info.txt`). A PubMed paper matching two publication
   years is kept only in the earliest.
2. **Affiliations.** The PubMed records of the base-set PMIDs are fetched in
   batches of 200 (cached in `cache/`, not committed), the first author's
   first affiliation is classified, and shares by affiliation type are written.
   A sample of 30 per class goes to `review/affiliation_sample.csv` (not
   committed) for reading.

After a run, the Europe PMC papers that name no estimation tool are read:

```
cd sources/literature && Rscript no_tool_review.R
```

fetches their records and full text (cached in `cache/`, not committed) and
writes the text to read to `review/no_tool_review.csv` (not committed). Each
paper gets one decision in `no_tool_decisions.csv`, following
`no_tool_rubric.md`: `own_fit`, `not_own_fit`, `outside_field` or `unclear`.
The script reports how many papers are still undecided; the README leaves
`not_own_fit` and `outside_field` out of the Europe PMC base set
(`literatureShares(exclude = )`).

Europe PMC answers bursts with HTTP 503 now and then. The script retries with
a growing wait, and caches each query's result under `cache/queries/<run
date>/`, so a run stopped by the service resumes where it stopped.

PubMed and Europe PMC keep indexing, so a re-run differs from the stored run.
Compare with the previous `results/` before committing, and say in the commit
what moved.

To change a query, edit `pm_tools`/`ep_tools` in `publication_trends.R`. Tool
names must be families in `taxonomy/software.csv`. Europe PMC is queried
with `synonym = FALSE`, because `epmc_search()` otherwise expands the query and
returns more records than `epmc_hits()` counts.
