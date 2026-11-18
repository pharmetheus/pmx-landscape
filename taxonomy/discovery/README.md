# Software discovery

A reproducible way to generate the list of tools the sources are searched
for. It finds software names in the text the sources have already cached, by
the words around a name rather than by known names, so tools nobody expected
are found too. It proposes; the taxonomy decides: a family enters the search
only when its row and pattern are added to `../software.csv` and
`../patterns.json`. No source script reads anything here, so the searches can
be refined and rerun without running discovery.

## Procedure (`discover.R`, run from this folder; `make discover`)

1. **Corpora** (cached text only, no downloads): every PAGE abstract 1992 to
   2026 (title and body, without authors, affiliations and references; poster
   PDFs are not read), the PubMed base set (title and abstract), the Europe PMC
   base set's full texts (the methods section where one is marked, otherwise
   the body; never the back matter) and the FDA review text. Each item read is
   listed in `results/scanned.csv` with the round in which it was first read.
2. **Cues** (`cues.csv`, stop names in `stopnames.txt`): a name followed by a
   version or a dotted number, a name followed by a word for software, an R
   or Python package, a trade mark sign, a maker and place in brackets, a name
   after a verb of analysis, a SAS procedure, a function written as code, and
   documentation or code links. Each cue is a regular expression whose capture
   group is the name; the note says why it has its present form. The dotted
   number cue is not applied to the FDA reviews, where it caught numbered
   headings and tables. Names of people that a cue catches (reviewers in
   FDA signature blocks) are left out of every output; `people.txt` lists
   them only as SHA-256 hashes of their key, so no name is stored.
3. **Candidates** (`results/candidates.csv`): one row per name (versions, trade
   marks and case folded together; an all-lower-case name that also occurs in
   capitals is kept apart, so the R package nlme is not the acronym NLME), with
   items per source and the first year, and the family when an existing
   pattern already covers it.
4. **Registries** (`registries.R`; `registries/`): dated lists of names from
   lists others keep: PAGE's parameter estimation software page, PAGE's
   support tools, and the CRAN Task View Pharmacokinetics. Names only; every
   listed name is read.
5. **Reading** (`rubric.md`; `tool_decisions.csv`): every name no pattern
   covers that occurs in at least 3 items of the corpora, or is on a
   registry, is decided once: estimation, auxiliary, PBPK or NCA software,
   general-purpose software, a method, not software, or unclear, with its
   family and a note. A later round reads only new names.
6. **Inclusion rule** (`toolInclusion()`, decided 2026-10-18): a family is in
   scope when it is decided as a tool and occurs in at least 3 items of one
   source, or is on a registry and occurs in at least 1 item. `results/inclusion.csv` gives each tool family's counts;
   `results/proposed.csv` the families to add to the taxonomy and the
   taxonomy families below the rule, which need a reason in `keep.csv` to
   stay (`taxonomyCheck()`).
7. **Recall** (`results/recall.csv`): of the items read as having no tool (the
   Europe PMC base papers with a model fit of their own naming no tool, and
   the PAGE abstracts using no tool), how many name a tool the taxonomy lacks.

## First round (2026-10-17)

- 15,057 items read: PAGE 6,900 (1992 to 2026), PubMed 5,156 and Europe PMC
  2,763 (2021 to 2026), FDA 238 (2021 to 2025).
- The cues were checked on this corpus before adoption: the share of software
  among each cue's 50 most frequent names was read. The package and product
  cues were mostly software; the trade mark, verb and maker cues about half;
  the version cue was swamped by FDA headings, so its dotted-number branch was
  split off and is not used for the FDA reviews, and the maker cue now needs a
  company suffix, or a city with a country or US state. Three cues (SAS
  procedures, functions, links) were added because the cues recovered neither
  MATLAB NLME nor most NLMIXED mentions; with them, every taxonomy family that
  occurs in at least 3 items is recovered.
- 1,019 names read by Claude Sonnet 5.5 readers in ten batches (each output row carries
  its name, so drift from the rows shows); a blind Claude Opus 5.5 reading of a random
  153 agreed on 144 decisions and on tool against not a tool for 149; the 9
  disagreements and 12 family names (Stan interfaces, ADAPT, MATLAB, the OSP
  Suite, the acronym NLME) were decided by Claude.
- Rerunning on unchanged caches gives identical results.

## Second round (2026-10-19, development)

- On the closed corpus: 4,978 items new to discovery (the literature of 2016 to
  2020 and the extension terms), 20,035 in all.
- 196 names queued (new, or now in at least 3 items), read by Claude Code
  subagents (Claude Sonnet 5.5, two batches), blind Claude Opus 5.5 subagent reading of a random 29:
  29 agree. Decided: 140 not software, 24 general, 14 methods, 8 auxiliary, 5
  estimation, 3 PBPK, 1 NCA, 1 unclear. Of the 5 estimation names, 4 belong
  to families already in the taxonomy (two spelled-out forms of the NONMEM
  name, its PREDPP library, a versioned MonolixSuite); JMbayes (Bayesian joint models in R) is
  new but below the item rule.
- Proposed (`results/proposed.csv`): 7 auxiliary or NCA families (MwPharm,
  fit4NM, BE, DAISY, openNCA, VCM-TDM, caffsim), none for estimation, so the
  tool counts are not affected.
- Decided 2026-10-20: six of the seven were added to the taxonomy, with
  patterns tested on the corpus (MwPharm 46 items, DAISY 9, fit4NM 6, caffsim,
  openNCA and VCM-TDM 2 each, in the tool use scope). BE was not added: its
  three items are the Stata/BE edition of Stata and a paper on bioequivalence,
  so no item names the R package and it fails the registry rule's one item.
- The same day, the patterns of seven estimation families were widened to the
  forms the tool use readers listed as unlisted tools (SADAPT, ADAPT alone,
  BUGS alone, nlmixed in lower case, NLME as the S-PLUS or R function, STAN,
  SAEMIX, and Phoenix in a sentence with another estimation tool), each
  checked on its new hits in the corpus (`taxonomy/software.csv`).
- Recall (`results/recall.csv`): of the 203 Europe PMC base papers with a fit
  of their own and no tool, 1 names an estimation tool the taxonomy lacks; of
  the 2,684 PAGE abstracts using no tool, 1.

## Third round (2026-10-21, development)

- On the corpus with the tool route: 2,608 items new to discovery, 22,643 in all.
- 480 names queued (new, or now in at least 3 items), read by Claude Code
  subagents (Claude Sonnet 5.5, four batches, each checked to have read its whole file),
  blind Claude Opus 5.5 subagent reading of a random 72: 70 agree; the two differences
  are between kinds of non-tool (NGS, SHAP), and the first reading was kept.
  Decided: 328 not software, 120 general, 19 methods, 8 auxiliary, 3
  estimation, 1 PBPK, 1 NCA.
- The 3 estimation names are forms the existing patterns miss, of families
  already in the taxonomy: Monolix written with its release joined
  (MonolixR2019b) or with the trademark sign split off (MonolixTM), and the
  nlmixr2 estimation package (nlmixr2est). Proposed for Niclas: widen the
  Monolix and nlmixr patterns. Not done: discovery only proposes.
- Proposed families (`results/proposed.csv`), none for estimation, so the tool
  counts are not affected: FME, MicLab, ubiquity (auxiliary), PKSolver (NCA);
  Simulx, which is already in the MonolixSuite tools family (a family name to
  merge, not a new family); and BE again, now in 7 Europe PMC items, which
  Niclas left out on 2026-10-20 because its items did not name the R package.
- Decided 2026-10-21 (Niclas, review): all proposals accepted. The Monolix and
  nlmixr patterns were widened, and FME, MicLab, ubiquity and PKSolver added,
  each with a test and checked on its hits in the corpus (FME and ubiquity
  only with the R package's context, since FME also abbreviates "full model
  estimation" and ubiquity is an English word). RsSimulx is now in the
  MonolixSuite tools pattern. BE stays out: its 7 items are the Stata/BE
  edition of Stata (6) and virtual bioequivalence (1), so its name is decided
  as general software (Stata) in `tool_decisions.csv`.

## Limits

- Cues find names written in the usual ways; a tool named only in passing
  ("we used X") without a version, maker or software word is missed unless a
  verb cue catches it.
- Poster and slide PDFs, and literature before 2021, are not read yet.
- The reading is a recorded judgement, not re-derivable exactly; the blind
  check gives its reliability.
