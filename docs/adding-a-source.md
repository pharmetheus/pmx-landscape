# Adding a source

A new source, such as ACoP abstracts or another regulator, gets its own folder
`sources/<name>/` and changes nothing in the existing ones. Propose its source
card first, in an issue on the repository, and collect nothing before it is
agreed.

## Checklist

1. **Source card** `sources/<name>/SOURCE.md`, in the shape of the existing
   ones: what is measured, the unit, the denominator, the time the snapshot
   represents and its lag, known biases, the retrieval method, the terms of
   use or copyright status of the texts, and how long the local copies are kept
   (until the source is dropped or the project ends).
2. **Terms first.** Check robots.txt and any terms of use. Where the texts are
   not free to publish (literature, conference abstracts), commit only IDs,
   URLs, classifications and counts. Consider asking the organisers for the
   data before scraping.
3. **Retrieval code** that records every query or download with its run date,
   caches what it fetches outside git, and fails loudly (a non-zero exit)
   rather than silently skipping.
4. **Shared taxonomy.** Search with `taxonomy/patterns.json` through
   `pmxlandscape` (`findSoftware()`, `findMatches()`), and classify
   affiliations with `classifyAffiliation()`, so families and classes match the
   other sources.
5. **A results table** in `sources/<name>/results/`, one row per unit.
6. **Validation**: a way to re-derive the published numbers from stored inputs,
   and a pilot whose output was read before the full run.
7. **README**: a chart and a sentence, presented next to the other sources,
   never pooled with them.

The ACoP check of September 2026 found abstracts for 2014 to 2018 only as
paywalled journal supplements, and the conference site blocking scripted
access; asking ISoP for the data is the likely route.
