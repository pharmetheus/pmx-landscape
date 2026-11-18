# Discovering new tools: the yearly round

The searches use only `taxonomy/software.csv` and `taxonomy/patterns.json`.
Discovery proposes additions to them; it is optional, and a year in which
only the patterns are refined can skip it. Method card:
[taxonomy/discovery/README.md](../taxonomy/discovery/README.md).

1. Run the sources as usual, so their caches hold the new year (PAGE abstracts,
   literature records and full texts, FDA reviews).
2. Optionally refresh the registries: `cd taxonomy/discovery && Rscript
   registries.R` (writes a new dated snapshot; the newest of each is used).
3. `make discover`. It reads everything cached (minutes), writes the
   candidates, and puts the names still to be read in
   `taxonomy/discovery/cache/review/queue.csv` (not committed).
4. Read the queue with `taxonomy/discovery/rubric.md` and add the decisions to
   `taxonomy/discovery/tool_decisions.csv` (with `decided_by` and `round`).
   Check a random sample with a second, blind reader.
5. `make discover` again: `results/proposed.csv` lists the families to add and
   the taxonomy families below the rule (give them a reason in `keep.csv`, or
   drop them).
6. Add the chosen families to `taxonomy/software.csv` and
   `taxonomy/patterns.json`, run `make test`, read the new hits as for any new
   pattern, and rerun the sources.
