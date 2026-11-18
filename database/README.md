# Tag database

The published layer of the design (`docs/design.md`): what every source item is, and what
each classification decided about it, as plain tables. No source text. Built by
`make database` (`database/build.R`) from the committed corpus tables and classification
outputs.

| File | One row per | Columns |
|---|---|---|
| `items.csv.gz` | corpus item | `source`, `item_id`, `year`, `url`, `coverage`, `hash` |
| `tags.csv.gz` | item, classification and label | `classification` (name and version), `label`, `value`, `method` (`rule`, `ai`, `adjudication`, `human`, `record`), `reader`, `prompt_hash`, `date` |
| `item_links.csv` | pair of items in different sources that are the same work | `kind`, `found_by`, `certainty` |
| `classifications.csv` | classification | question, values, reader, check reader, number of rules, prompt hash, card, blind-check agreement and kappa |
| `release.txt` | | package version, commit of the inputs, corpus build dates |

The FDA decision record enters as the classification `fda_record` (per drug and estimation
tool: `applicant`, `indirect`, `reviewer` or `both`), since it stays the decision of record;
the classification `fda_use` is an independent check of it and gives no tags. The first
links are the PubMed and Europe PMC records of the same paper, exact on the PMID.

The sources are never pooled: their units and denominators differ (an FDA drug, a paper, an
abstract). A tag joins its item on `source` and `item_id`; its reasons, rubric and prompt
are in the classification's folder under `classifications/`.
