# PMx Software Landscape: design

The design record. It describes how the project is organised: a data corpus, a
set of independent classifications, a public tag database built from them, and
numbered releases. It was written on 2026-10-18 as a proposal, before any of it
was built, and is kept as written; the decisions taken since are recorded,
with their dates, in the sections at the end.

## Why restructure

The first versions grew source by source. Each source has its own way of
retrieving text, finding tools and recording decisions, and the analyses that
came later (analysis types, model size, AI and machine learning, tool
discovery) each read the sources in their own way. That worked for one
question, which software is used, but it makes every new question a new
pipeline, and every new source a change in several places.

The aim is a structure in which a new source and a new classification can each
be added without touching the others, and in which every published number can
be traced to a release, a classification rule and a decision.

## Overview

Three layers, each built only from the one before it:

1. **Corpus.** The items from every source (an FDA review, a paper, a
   conference abstract), downloaded once, stored locally and described by one
   common item table.
2. **Classifications.** Independent modules, each tagging the items with one
   kind of property: software tools, estimation algorithms, analysis method,
   analysis type, analysis objective, covariate method, and others later.
3. **Tag database.** The tags of all classifications, with the item IDs and
   URLs, as a set of tables. This is what is published. The README and any
   other analysis are queries on it.

Downstream projects, public or private, build on a numbered release of the tag
database and may add tags of their own.

## Layer 1: the corpus

### What a source delivers

Every source, existing or new, delivers the same item table:

| Column | Content |
|---|---|
| `source` | FDA, PubMed, Europe PMC, PAGE, later ACoP, EMA |
| `item_id` | the source's own stable ID (application number and document, PMID, PMCID, PAGE abstract number) |
| `year` | the year the item represents, by the source's rule (approval year, earliest publication year, meeting year) |
| `url` | where anyone can read the item |
| `sections` | the text split into named parts: title, abstract, methods, body, tables; reference lists removed |
| `coverage` | what text exists for the item: title and abstract only, full text, full text with OCR |
| `retrieved` | date of download, and the query or listing it came from |
| `admitted_by` | for literature: the base query terms that admitted the item (core or extension) |
| `hash` | a checksum of the stored text |

Text is stored as the source delivers it (PDF, HTML, XML) plus the extracted
sections, so a better extraction can be run later without downloading again.
This includes the FDA review PDFs, which today are not kept (see TODO).

### What stays local and what is published

The downloaded text stays on the machine that ran the retrieval and is never
committed, except where it is in the public domain (FDA reviews). What is
published is the item table without the text: IDs, URLs, years, coverage and
hashes. Anyone can rebuild the corpus with the retrieval scripts, and the
hashes show whether a rebuilt item matches the one that was classified.

Conference abstract text (PAGE, ACoP) and literature full text are not
published; this is a condition of using them, and the reason the organisers of
a meeting can agree to the project.

### One search method

Today the literature counts are queries run on the PubMed and Europe PMC
servers, while PAGE and FDA are searched locally. In this design every
classification runs on the local corpus, so the literature base set is
downloaded and searched like the other sources. This has three effects:

- Literature numbers will change once, at the release that makes the switch,
  and the release notes say so. That release reports the old (server) and new
  (local) numbers side by side on the same base set, as a bridge.
- The Europe PMC series becomes "open-access papers of the base set" (2,763 of
  3,140 base papers had downloadable full text in September 2026), since only
  those can be read locally.
- Reference lists are removed before searching (Europe PMC's server search
  reaches them), and patterns can be case-sensitive (the R package nlme
  against the method NLME).

### The literature base set: a core and an extension

The base query decides which papers enter the corpus. The **core set** is the
current query, unchanged ("population pharmacokinetic(s)", pharmacometric* or
"(non-)linear mixed effects" in the title or abstract, or keywords in Europe
PMC), so the switch to local search changes only the method. An **extension
set** adds entry terms the core misses. Each extension term is tested on a
read sample before adoption (`sources/literature/refinement`), as
"mixed-effects model*" was (it would have added 18,705 papers, almost none
pharmacometric). Tool names are never entry terms, since papers admitted for
naming a tool would inflate that tool's share. The item table records which
term admitted each paper, so a query uses the core alone (the continuing
series) or core and extension. The extension can come in a later release than
the switch.

**The frame and the term rule (decided 2026-10-19).** The literature frame is
the papers that describe themselves with the field's own names for the method
in their title, abstract or keywords, as the FDA frame is CDER's novel
approvals. An extension term is a name of the method itself: the short forms
of population PK (PopPK, pop PK, pop-PK), population pharmacodynamic(s) and
NLME. Terms that name a context or a framework rather than the method (PBPK,
QSP, exposure-response, PK/PD model, mixed-effects model, MIDD and
model-informed drug development) were tested and left out: few of the papers
they add are population model fits (at most 8% for the broad terms, 22 to 36%
for PK/PD model and model-informed drug development). The base query finds
about two thirds of the relevant papers of reference sets found without its
terms; most of the rest use none of the field's words where the search looks,
so no term list recovers them, and the tool shares in the papers it misses are
similar to those it finds. The evidence is in the refinement card. PBPK and QSP
become frames of their own (see Decisions, 2026-10-19), with their own entry
terms, denominators and relevance definitions.

### Adding a source

A new source adds a folder under `sources/` with a source card (what is
measured, the unit, the denominator, the time it represents, biases, terms of
use) and a retrieval script that writes the item table. No classification
changes. Candidates: ACoP abstracts (access requested), EMA documents
(assessment reports already piloted; clinical study reports published under
EMA's clinical data publication are worth checking), other regulators, other
meetings.

## Layer 2: classifications

### What a classification is

Each classification is a module under `classifications/<name>/` with the same
parts:

| Part | Content |
|---|---|
| Vocabulary | the labels and their definitions (for tools: `software.csv`) |
| Level | the item, always; where the question is about tools, also a link from each tag to the tool it belongs to |
| Detection | patterns where a name is enough; a reading rubric and the reading prompts where judgement is needed |
| Decision log | one row per decision, with who or what decided and when |
| Validation | a blind second reading of a sample, a recall test set where one exists |
| Discovery (optional) | a procedure that proposes new labels from the corpus, as the tool discovery does |
| Dependencies | the classifications whose tags it needs |
| Card | a short description, like a source card |

A classification reads the corpus and the tags of the classifications it
depends on, and writes only its own tags. It can be changed and rerun without
touching the others; those that depend on it are rerun after it.

### One protocol for every classification

Decided 2026-10-18: every classification follows the same five steps, with
the same files and the same decision record, so the method is described once
(`classifications/README.md`) and each classification's card says only what
differs. Steps 1 to 3 are rules and exactly reproducible; reading comes only
after them, for what they leave open. Before them, step 0 (added 2026-10-19)
develops and freezes the codebook the steps apply.

0. Codebook: drafted, tried on development items, revised, tested on
   held-out items, approved and frozen.
1. Scope: the sources and sections it reads.
2. Candidates: patterns find candidate labels, or the item is the candidate.
3. Rule decisions: what a rule settles is decided by the rule.
4. Reading: the rest, with one prompt skeleton and one output schema for
   every classification, filled with its question, values and rubric.
5. Check: a blind second reading of a share by another model, disagreements
   decided, Niclas's decisions last.

The reader of record is the Anthropic Message Batches API, with the exact
prompt, a pinned model ID and the raw responses kept; Claude Code subagents
read the same requests in development, recorded as such (readers by phase:
Decisions, 2026-10-19). Every live API run needs Niclas's go-ahead and has a
cost estimate and a cap.

### The first set

| | Classification | Labels, for example | Detection | Exists today as |
|---|---|---|---|---|
| a | Software tools | NONMEM, Monolix, PsN, Simcyp; used or mentioned | patterns, then reading of use | taxonomy, patterns, discovery, the PAGE role reading, the FDA attribution |
| b | Estimation algorithms | FOCE, Laplace, SAEM, importance sampling, NPAG, MCMC | patterns, then reading | the estimation method in the model-size reading; 93 method names from the first discovery round |
| c | Analysis method | popPK, PK/PD, PBPK, QSP, machine learning, MBMA | reading | part of the analysis-type scale; the AI and machine learning analysis |
| d | Analysis type | application, methodology | reading (FDA is application by definition) | the PAGE role reading (software as the subject), the Europe PMC no-tool reading (own fit or not) |
| e | Applied analysis objective | PK only, PK/PD, disease progression, time-to-event, joint models | reading | levels 1 to 4 of the analysis-type scale |
| f | Covariate model method | SCM, FREM, COSSAC, full model, LASSO | patterns, then reading | nothing yet |
| g | Affiliation | first author academia, industry, CRO, vendor, regulator; any industry or CRO author; organisation names | rules (`taxonomy/affiliation_rules.csv`) | first-author types for PubMed and PAGE |

The current analysis-type scale (1 PK only to 7 QSP and PBPK) mixes the method
(c) and the objective (e); in this design they are two classifications.

### Rules that apply to every classification

- **Absent is not "no".** An item without a tag means the label was not found,
  not that it does not apply. A classification that answers a question for
  every item has an explicit "not stated" label, as the FDA series has today.
- **Each classification reads what it needs.** Its scope names the sections
  it reads, and its card says which and why. The reference list is never
  read, since it is not the item's own text. Questions about what the
  authors did (tools, estimation algorithm, covariate method) read the title,
  abstract and methods, with the whole body for papers whose methods section
  cannot be found; questions that need results or tables (model size) read
  more. Measured on the Europe PMC full texts (October 2026): the methods
  sections are 21% of the body text, 90% of the papers have one, and 97% of
  the tools the model-size reading found used are named in it.
- **Item level, and tool links where they matter.** Every classification tags
  the item. A classification whose question is about tools (estimation
  algorithm, covariate method, and analysis method and objective when asked
  per tool) also links each tag to a tool: made automatically, and flagged as
  inferred, when the item uses one tool; decided by a reader, with "not
  stated" allowed, when it uses several. At PAGE 90 of 3,221 abstracts using
  an estimation tool used more than one, so the reading this adds is small.
- **Prompts are part of the method.** Each classification carries its prompt
  templates, versioned with it, and every reading decision records the model
  (with its version) and the prompt version. The batches and raw reader
  outputs stay local, since they contain source text. The blind-check
  agreement is published with each classification.
- **Coverage is recorded.** A tag says which section it was read from, so a
  query can tell an abstract that does not name the algorithm from a full text
  that does not.
- **Reading is shared, decisions are not.** Reading is the expensive step.
  One reading pass over an item may fill several classifications, but each
  writes its own decision log, so each can be revised alone.
- **Evidence without text.** The published evidence of a tag is its location
  (item, section, character position), not a quotation, except for public
  domain sources.

### Reproducibility levels

1. **Numbers from tags.** Every table and figure is recomputed from the
   published tag database. Anyone can check this.
2. **Tags from decisions.** The decision logs, rubrics and patterns are
   published, so it can be seen why each tag was given.
3. **Decisions from the corpus.** Pattern tags can be recomputed exactly from
   a rebuilt corpus. Reading tags are recorded judgements, made with
   published rubrics and prompts; a rerun with a later model may differ, and
   the blind checks show by how much. Decisions made before the restructure
   record the rubric only, since their prompts were not kept.

## Layer 3: the tag database

### Tables

| Table | One row per | Main columns |
|---|---|---|
| `items` | item | source, item_id, year, url, coverage, hash |
| `tags` | item, classification and label | classification, label, level (for example used or mentioned), section, decided_by |
| `tag_links` | pair of tags in the same item that belong together | for example a tool and the analysis method it was used for |
| `item_links` | pair of items in different sources that are the same work or report on each other | kind of link, how it was found, confidence |
| `classifications` | classification and version | vocabulary, rules, rubric, date, dependencies |
| `release` | release | version, date, corpus snapshot dates per source |

The `tag_links` table answers questions such as "which tool for which
method", which an item-level tag cannot (an abstract with a QSP model in one
tool and a popPK model in another).

### Links between sources

The same work often appears in more than one source, and the database links
the items where it can, so a PubMed paper finds its Europe PMC record and the
PAGE abstract that preceded it, and an FDA drug finds the sponsor's papers on
it. Each link records how it was found, since the kinds differ in certainty:

| Link | How it is found | Certainty |
|---|---|---|
| PubMed paper and Europe PMC record | the shared PMID | exact |
| FDA drug and the sponsor's papers | brand name, ingredient or development code, and sponsor affiliation, near the approval (as the FDA cross-check does today) | a judgement, checked by reading |
| PAGE (or ACoP) abstract and a later paper | shared authors and similar title and content, within a few years | a judgement, checked by reading |
| FDA drug and its EMA documents | the active substance | exact for the substance, a judgement for the analysis |

Links are a classification of their own (the same parts: rules, decision log,
validation), with pairs of items rather than items as the unit. They make new
questions possible: how long a tool takes from a PAGE abstract to a paper,
whether what is presented as methodology at PAGE is later published as an
application, and whether the tool named in a sponsor's paper is the one in
the FDA review. Linked items are never merged: each keeps its own source,
year and tags, and the sources are still not pooled.

### Format and access

The tables are CSV files in the repository (readable, diffable, citable), and
each release also builds a single database file (DuckDB or SQLite) for
queries. The `pmxlandscape` package gets query functions for the common
questions, with the sources kept apart by default, since their units and
denominators differ and are never pooled.

The README becomes a summary built from queries on the database, as now,
with the method details in the source and classification cards.

### Downstream use

Anyone may build on a release, under the licence (CC BY 4.0 for the database
and results, decided 2026-11-09; copyright Pharmetheus AB). A downstream project records the release
it uses (tag and DOI), joins its own tags on `source` and `item_id`, and
states the release in its outputs. It does not copy its own tags back.

## Releases and versions

### Why now

Results from the repository are already in use. A number that was read
must be findable again, as it was, after the repository has moved on.

### What a release is

- A git tag `vX.Y.Z` on `main` and a GitHub release with notes; once the
  repository is public, a Zenodo DOI per release.
- The package version in `pmxlandscape/DESCRIPTION` equals the release
  version; between releases it carries `.9000`.
- `NEWS.md` lists what changed in the results, not only in the code: new
  sources, new classifications, changed rules, and which published numbers
  moved and why.
- The README, the figures and the tag database are generated at the release
  commit and committed with it, so the release shows exactly what was
  published.

### Numbering

- **Major** (1.0.0, 2.0.0): a change in what a published number means, such
  as the switch of the literature series to local search.
- **Minor** (0.3.0): a new source, a new classification, a new yearly round,
  or new tool families.
- **Patch** (0.2.1): corrections that do not change the method, such as a
  fixed decision.

A version number that has been tagged is never reused.

### Releases for the past

The material already used can be given versions after the fact, by tagging
the commits it was built from: `v0.1.0` for the state of 2026-10-12 (the
README that was reviewed and the base of the analyses done that day), and
`v0.2.0` for 2026-10-17 (the AI and machine learning section and the tool
discovery). Their package version stays 0.0.0.9000, since those commits
cannot be changed; the release notes say so.

### Every output carries its release

The README states its release and commit at the top. Reports built from the
database, here or downstream, state the release they used. A downstream
project's scripts check that the release they are run against is the one they
record, and stop if not.

## What changes, and in which order

1. **Start releases now.** Tag the past states (above) and add `NEWS.md`.
   Nothing in the results changes.
2. **Corpus layer.** Write the item table for the four sources from the
   existing caches; keep the FDA PDFs; download the literature base set texts
   for local search.
3. **Tools as the first classification module.** Move the taxonomy, patterns,
   discovery and the use readings into the module form, add the families from
   the first discovery round (decided 2026-10-18), and switch the literature
   series to local search. This is the release that changes the published
   numbers (a major version).
4. **Split the analysis-type scale** into analysis method (c) and objective
   (e).
5. **New classifications:** analysis type (d), estimation algorithms (b),
   covariate method (f), and the links between sources (PubMed and Europe PMC
   first, since that link is exact).
6. **New sources** as they become available (ACoP, EMA), each adding only a
   folder.

## Decisions, 2026-10-18

- **Prompts are published** as part of the method (see the rules for every
  classification).
- **Level:** item level for every classification, and tool links where the
  question is about tools.
- **Text:** every classification may read the whole text except the
  reference list. Changed the same day (Niclas): each classification reads
  the sections it needs, set in its scope and stated on its card (title,
  abstract and methods for questions about what the authors did, with the
  body as fallback; more where results or tables are needed).
- **Literature base query:** the current query stays as the core set; an
  extension set with tested terms and an `admitted_by` record is added,
  possibly in a later release; tool names are never entry terms.
- **Copyright holder:** Pharmetheus AB, with Niclas as author and maintainer.
- **Licences (decided 2026-11-09):** CC BY 4.0 for the database and results;
  MIT for the code.
- **Order:** the sources first (the corpus layer), then the classifications.
- **One protocol** for every classification (above), deterministic as far as
  rules go, with readings on top.
- **Readers:** the Message Batches API is the method of record, after a
  pilot; subagents allowed for pilots and checks.
- **Earlier readings** (PAGE roles, the no-tool reading, AI and machine
  learning, model size, FDA types, discovery) are read again with the new
  protocol when their classification moves into it, and the agreement with
  the old decisions is published. Niclas's own decisions carry over.
- **FDA retrieval** is ported to R, and the review PDFs for 2016 to 2025 are
  downloaded and kept.
- **Reader:** Sonnet 5.5 through the Batch API, with a 15% blind check by
  Opus 5.5 (after the tool use pilot). Phase 3 readings capped at $40 in
  total.
- **Literature numbers after the switch to local search:** the continuing
  series stays "papers naming the tool" (the taxonomy patterns on the local
  text, shown beside the old server counts at the switch); a second series,
  "papers using the tool", comes from the reading, as for PAGE.
- **FDA:** the decision record stays the decision of record; the new reading
  of the FDA hits is an independent check, its agreement published and every
  disagreement listed for Niclas.

## Decisions, 2026-10-19

- **FDA measure:** the applicant's use of a tool is the measure; the FDA
  reviewer's use is not part of it.
- **FDA evidence strength:** the reporting separates the template-only cases
  from stated plus indirect; the record keeps stated and indirect apart.
- **Reviewer-run rule:** when the FDA reviewer ran the applicant's model or
  dataset in a tool, and the review names no other tool for the applicant,
  that tool is indirect evidence of the applicant's use. A "final model" in
  the review is the applicant's unless the review says the reviewer built
  their own. Applied on top of the record (`sources/fda/results/record_revisions.csv`).
- **Codebook development (step 0):** every classification starts with a
  codebook (values with definitions, rubric, rules and prompt) developed on
  development items: a draft, readings of a development sample, rules from
  the agreed cases, revisions until disagreements show no new kinds of case.
  Its reliability is then measured on held-out items that played no part in
  the development (items may have been read before, but did not inform a
  change), and Niclas approves it before it is frozen.
- **Development and production phases:** development runs are checked by
  Claude or by agents and labelled as such; numbers from them may change.
  A production run locks the corpus snapshot, the codebook and taxonomy
  versions, the model IDs and the run dates, adds human answer checks (a
  sample per classification, about 30 to 40 answers, plus a review of
  Claude's settlements), and is tied to a release tag.
- **Readers by phase:** Claude Code subagents read wherever they can, through
  the development runs, recorded as such; a small API pilot (about 100
  items) when a codebook freezes, to see whether the production reader agrees
  and to measure tokens; the Message Batches API for production runs.
- **Literature frame and extension terms:** see "The literature base set"
  above. The core plus the population PK short forms, population
  pharmacodynamic(s) and NLME; MIDD and model-informed drug development stay
  out. The literature period becomes 2016 to 2026 (the core terms for 2016
  to 2020 are added; the series in the README stays 2021 onwards until
  decided).
- **PBPK and QSP:** two frames of their own, each with its own denominator,
  relevance definition and term test, and their tools (Simcyp, GastroPlus,
  PK-Sim and the OSP Suite, SimBiology/MATLAB, where MATLAB counts only
  inside these frames). Not started.
- **Affiliation:** a classification module of its own, by rules only, for
  every source except FDA, as a stratification variable for every other
  classification. Per item: the first author's affiliation type, whether
  any author is from industry or from a CRO, and organisation names (the
  first author's and all authors'; the canonical name where a rule names the
  organisation). Author names are never collected or stored.

## Decisions, 2026-10-20

- **Two routes into the literature frame.** The term route (the field's names
  for the method, the core and the extension) is joined by a tool route:
  papers that name an estimation tool made for pharmacometric work (NONMEM,
  Monolix, Phoenix NLME, nlmixr, Pumas, Pmetrics, saemix, S-ADAPT), in
  PubMed's title and abstract and in the methods of Europe PMC's open-access
  full text. Reason: the term route holds a smaller part of the papers that
  use some tools than of those that use NONMEM (Europe PMC methods, 2021 to
  2025: NONMEM 67%, Monolix 39%, Pumas 37%). General statistical tools (BUGS,
  JAGS, Stan, nlme, NLMIXED) do not open the route, since most papers naming
  them are outside pharmacology; their use still counts in every paper either
  route found. PBPK tools are recorded but do not open it; PBPK papers wait
  for their own frame. Each paper records its routes (`admitted_by`,
  `tool_route`), and results are shown for the term route, the tool route and
  both. The tool route was added after the uneven coverage was found; the
  methods say so.
- **Every paper treated the same.** Every literature paper, whichever route
  found it, is read for a model fit of its own (relevance codebook version 2,
  `classifications/lit_relevance/codebook.md`); the shares count only papers
  read as own fit. The codebook is frozen when it passes its held-out test (90%
  agreement and kappa 0.8), without a separate approval. The development run
  reads all papers.
- **FDA periods.** The FDA bars are twelve-month periods; the latest ends on
  the most recent 30 June or 31 December at least three months past
  (`fdaPeriods()`). The July to December 2020 approvals are read for the
  development run; for years without a decision record, `fda_poppk` splits the
  drugs whose review names no tool.
- **README from the development run.** The README may be rebuilt from the
  development run once Niclas approves the results, for use in the ACoP data
  request.
