# PMx Landscape: overview

The project measures how pharmacometrics is applied in practice, as seen in regulatory files,
scientific publications and conference abstracts. It starts with the estimation software used for
population (nonlinear mixed-effects) modelling. Later classifications will add other aspects, such
as the estimation algorithm, the covariate modelling method and the modelling objective.

The measurements combine two kinds of work. Deterministic parsing and fixed rules extract what the
source data state plainly. AI readers, which are language models, classify the rest.

Each source is counted in items. An item is one drug for the FDA reviews, one paper for the
literature, and one abstract for the PAGE meetings. All numbers on this page come from a
development run, so they may still change. Terms used in a specific sense are defined in the
[glossary](glossary.md).

## Sources

Each source reaches a different audience at a different time, so each source is reported as its own
series and never added to the others. The published results give, for each source and year, the
share of items that name or use each tool family. The main results are in `README.md`, and every table and chart in
`docs/results/estimation-software.md`.

| Source | Item | Frame | Items in the corpus |
|---|---|---|---|
| FDA review documents | a drug | novel drugs approved by the FDA's drug centre (CDER), July 2020 to 2026 | 305 |
| PAGE meeting abstracts | an abstract | every abstract of the Population Approach Group in Europe meetings, 1992 to 2026 | 6,900 |
| PubMed | a paper | papers that call their method by the field's own names or name a pharmacometric estimation tool, 2016 to 2026 | 9,321 |
| Europe PMC | a paper | as for PubMed, with the open-access full text | 7,150 |

The frame of a source is the set of items it counts from, and it is fixed before anything is
counted. Each source has a card that states its frame, period and known biases
(`sources/*/SOURCE.md`).

The published literature series cover 2021 to 2026 and count only the papers whose authors fitted
a population model of their own; the corpus also holds 2016 to 2020. A paper found in both PubMed
and Europe PMC is counted in each. The FDA record covers 2021 to 2025, and the approvals of July to
December 2020 and of 2026 were read in a development run. The FDA documents for 2016 to June 2020
are downloaded but not yet read.

For the literature, the frame is found by two routes. The term route takes the papers that use the
method's names, such as "population pharmacokinetic" and "nonlinear mixed effects", and their short
forms, which were admitted only after a test that measured which relevant papers the core terms
miss (`sources/literature/refinement/README.md`). The tool route takes the papers that name an
estimation tool made for pharmacometric work, such as NONMEM, Monolix or Pumas.

## What is published

The corpus holds every item of every source, as tables of IDs, URLs, years and text fingerprints
(`corpus/`). A fingerprint lets anyone check that their copy of a text is the one that was
classified, without the text being published. Abstract and paper text stays in a local cache.
FDA review text is a US government work, so it is published.

The project publishes the item IDs, the classifications, short notes written by the AI readers in
their own words, and the code that rebuilds everything from the sources. Author names are never
stored.

## How items are classified

Each classification asks one question of every item, with a fixed set of answers. Its codebook
defines the answers, the rules and the guidance for hard cases (`classifications/README.md`). The
codebook is developed on some items, tested on items it was not developed on, and then frozen.

A classification then runs in four steps:

1. Patterns find candidates: for tool use, a candidate is an item paired with a tool family it names.
2. Fixed rules decide the candidates they can, for example "analysed with NONMEM 7.5".
3. An AI reader reads the text and decides the rest, with a short note.
4. A second AI reader reads a random sample blind, and the disagreements are settled and recorded.

Every decision records its reader and a fingerprint of the text it read. A reader is whatever
gives the value: a fixed rule, an AI reader or a person. On this page, "reader" never means the
person reading the page.

In a development run, the AI readers are Claude Code subagents: language-model agents launched
from the Claude Code tool. Claude Sonnet 5.5 subagents read the text. Claude Opus 5.5 subagents make the
blind check. Claude Opus 5.5 settles the disagreements, which is called adjudication. A production
run reads through the Anthropic API with a fixed model version, adds checks by people, and belongs
to a numbered release.

Classifications in place: tool use, the authors' affiliation type, and the tool an FDA applicant
used. Planned: estimation algorithm, covariate method, analysis method and objective, and links
between items across sources (`docs/design.md`).

## Example: tool use, version 5 of the codebook

The question is whether the authors used a tool for their own analysis, used it only as a
comparison, or only mentioned it. The development run of 2026-10-19 and 20 covered the PAGE abstracts and the literature; the readings added since are in the card
(`classifications/tool_use/`). Two measures of agreement are given. The held-out test measures the
codebook once, on 260 items that played no part in developing it. The blind check measures the run
itself, on a random sample.

| Measure | Result |
|---|---|
| Candidates | 9,121, in the 20,828 PAGE and literature items |
| Decided by fixed rules | 3,969 of 9,121 (44%) |
| Read by an AI reader | 5,152, in 4,558 items |
| Held-out test: two AI readers agree | 282 of 284 decisions |
| Held-out test: the reading confirms the rules | 60 of 60 rule decisions |
| Blind check of the run: two AI readers agree | 763 of 781 decisions |
| Items naming a tool the taxonomy lacks | 165 of the 4,558 items read |

The tools the taxonomy lacks go to tool discovery, which proposes new tool families
(`taxonomy/discovery/`).

## Status

The project is in development. A production run with checks by people comes before the first public
release, which is planned to have a citable DOI.
