# Glossary

The terms this project uses in a specific sense. Field terms such as population pharmacokinetics
or NONMEM are not repeated here. Each entry ends with the file where the term is used most.

## How the terms fit together

The project measures which software pharmacometricians use, from several sources. Each source has
a frame, which fixes its items. All items together form the corpus. Patterns find candidates in each
item's text, for example a paper paired with a tool family it names. A rule or a reading gives each
candidate a value. A blind check measures how reliable the reading was, and an adjudication settles
the disagreements it finds. The final value of each candidate is its tag, and the published series
are counted from the tags. The codebook defines how all of this is decided for one classification.

## Terms

**Adjudication.** The decision taken when two readers disagree about the same candidate. In a
development run, Claude Opus 5.5 decides, and the record names it as the reader. In a production run,
a person also reviews these decisions. Used in `classifications/tool_use/adjudications.csv`.

**Affiliation type.** The kind of organisation an author works for: academia, industry, contract
research organisation (CRO), software vendor or regulator. Rules decide it from the affiliation
text. No language model reads it. Used in `classifications/affiliation/`.

**Agreement.** How often two readers give the same value to the same candidate, as a count with
its denominator, for example 763 of 781. Two statistics correct it for agreement by chance: Cohen's
kappa and Krippendorff's alpha. Both are 1 when the readers always agree, and 0 when they agree no
more than chance would. Used in each classification's `card.md`.

**API.** The Anthropic API, the service through which a program sends text to a Claude language
model and receives its answer. Production runs are read through it. Used in
`classifications/README.md`.

**Base set.** The papers a literature share is counted against: the papers of the frame for one
source and year. From the development run of 2026-10-21 the README series use the papers of both
routes, 2021 to 2026, that were read as having a model fit of their own. Used in
`sources/literature/SOURCE.md`.

**Blind check.** A second reading of a random sample of the items in a run, by a second language
model that does not see the first reader's answers. It is made for every run, and its agreement
shows how reliable that run's reading is. A held-out test, by contrast, is made once, to measure
the codebook before it is frozen. Used in `classifications/README.md`.

**Candidate.** One item paired with one label that patterns found in its text. Each candidate
gets one value. Used in `classifications/README.md`.

**Classification.** One question asked of every item in scope, answered with a fixed set of values.
An example is "did the authors use this tool for their own analysis?". Each classification has its
own folder, for example `classifications/tool_use/`.

**Codebook.** Everything that defines a classification: its values and their definitions, the
rubric, the rules and the scope. It has a version number. It is developed on development items and
tested on held-out items. The project lead then approves it, and it is frozen. Used in
`classifications/tool_use/codebook.md`.

**Core set.** The literature papers found by the original search terms. The terms are
"population pharmacokinetic(s)", pharmacometric*, "nonlinear mixed effects" and "non-linear mixed
effects". Each paper records the terms that found it. Used in `sources/literature/SOURCE.md`.

**Corpus.** Every item of every source, described by one table of items and one table of text
sections per source. The sources share the corpus but are never counted together. The tables hold
IDs, URLs, years and fingerprints of the text (hashes), never the text itself. The exception is FDA
review text, which is in the public domain. Used in `corpus/README.md`.

**Development items.** The items whose reading led to a change in the codebook. They are listed so
that a later test can use only items outside them. Used in `classifications/tool_use/dev_items.csv`.

**Development run.** A reading of the whole corpus with a draft or newly frozen codebook, by Claude
Code subagents. These are language-model agents launched from the Claude Code tool, and the record
gives each one's model and version. Since 2026-10-19, Claude Sonnet 5.5 subagents read, Claude Opus
5.5 subagents make the blind check, and Claude Opus 5.5 decides the disagreements. The numbers of a development run may
change, and the production run replaces them. Used in `classifications/tool_use/card.md`.

**Estimation tool.** Software that fits a population model to data, such as NONMEM, Monolix or
Phoenix NLME. The taxonomy keeps estimation tools apart from three other groups:

- auxiliary tools, which support an analysis without fitting it, such as PsN, Pirana or mrgsolve;
- PBPK tools, for physiologically based pharmacokinetic models, such as Simcyp;
- NCA tools, for non-compartmental analysis.

Used in `taxonomy/software.csv`.

**Extension.** Literature papers found only by the extension terms. These terms were admitted after
a test that searched for relevant papers by other routes and measured which terms would have found
the ones the core set misses. The terms are the short forms of population PK (population PK, PopPK,
pop PK), "population pharmacodynamic" and NLME. The extension is part of the term route, and its
papers of 2021 to 2026 are in the README series from 2026-10-21. Used in
`sources/literature/refinement/README.md`.

**Frame.** The set of items a source counts from, fixed before anything is counted.

- FDA: the novel drug approvals of the FDA's drug centre (CDER).
- Literature: the papers that describe themselves with the field's own names for the method (the
  term route) or that name a pharmacometric estimation tool (the tool route, from 2026-10-20).
- PAGE: every abstract of the annual meeting of the Population Approach Group in Europe.

Used in each source card, for example `sources/literature/SOURCE.md`.

**Held-out test.** A test of a codebook on items that played no part in developing it. Two readers
read the items independently, and their agreement is the codebook's reliability. It is made once,
before the codebook is frozen. Used in `classifications/tool_use/card.md`.

**Item.** One unit of a source: a drug for FDA, a paper for the literature, an abstract for PAGE.
An item counts once for each tool family it names, however often it names it. An item that names two
families counts once for each, so the shares of the families do not add up to 100%. Used in
`corpus/README.md`.

**Label.** What a candidate is about. In the tool use classification the label is a tool family.
Used in `classifications/README.md`.

**Naming and using.** Two ways to count a tool. An item names a tool when the tool's name appears in
its text, for whatever reason. An item uses a tool when the authors used it for their own analysis,
which takes a reading to decide. Used in `README.md` and in `sources/literature/SOURCE.md`.

**Own fit.** A paper whose authors fitted a population (nonlinear mixed-effects) model of their own
to data, in pharmacology. It is the value `own_fit` of the relevance classification, and the
literature shares count only such papers. Used in `classifications/lit_relevance/codebook.md`.

**Production run.** The reading that the published series come from. The codebook is frozen, and
the reading goes through the API with a fixed model version, so the run can be repeated. A sample of
the answers is checked by people. The run belongs to a numbered release of the repository, which is
planned to get a citable DOI. Used in `classifications/README.md`.

**Published series.** The numbers the project reports in `README.md`: for each source and year, the
share of items that name or use each tool family. The tags they are counted from are published
too.

**Reader.** Whoever or whatever gives a value to a candidate: a rule, a named language model, or a
person. Every decision records its reader, and a language model is always named with its version
(Claude Sonnet 5.5, not Claude Sonnet). Used in `classifications/README.md`.

**Relevance classification.** The classification that asks of every literature paper whether its
authors fitted a population model of their own, in pharmacology. Its values are own fit, not own
fit, outside the field and unclear. Used in `classifications/lit_relevance/card.md`.

**Reading.** The step in which a language model reads an item's text and gives a value for each
candidate that no rule settled, with a short note in its own words. Used in
`classifications/README.md`.

**Rubric.** Guidance for the cases that the value definitions leave open. An example is a tool that
the authors ran only to produce reference results. Used in `classifications/tool_use/rubric.md`.

**Rule.** A fixed decision from a pattern in the text around a candidate. The same text always gives
the same decision. Used in `classifications/tool_use/rules.csv`.

**Source.** Where items come from: FDA reviews, PubMed, Europe PMC and PAGE abstracts. Each source
has its own folder in `sources/`. The sources are reported side by side and never pooled. Used in
`README.md`.

**Source card.** The `SOURCE.md` file of a source. It states what the source measures, the unit, the
denominator, the period, how items were retrieved, known biases and the terms of use. Used in
`docs/adding-a-source.md`.

**Tag.** The final value of one candidate. It is a person's decision if there is one, otherwise an
adjudication, otherwise the reading or rule. The published series are counted from the tags. Used in
`classifications/tool_use/tags.csv`.

**Taxonomy.** The list of tool families with their group and the patterns that find them in text.
Used in `taxonomy/software.csv` and `taxonomy/patterns.json`.

**Term route.** The way into the literature frame by the field's names for the method in a paper's
title, abstract or keywords, such as "population pharmacokinetic". It covers the core set and the
extension. Used in `corpus/README.md` (the `admitted_by` column).

**Tool discovery.** A procedure that looks through the corpus for names of software the taxonomy
does not list, and proposes new tool families. It only proposes. A family enters the taxonomy when
it is added by hand. Used in `taxonomy/discovery/`.

**Tool family.** A tool with all its versions and spellings counted as one. For example, the nlmixr
family covers nlmixr and nlmixr2, and the NONMEM family includes misprints such as "NONMEMS". Used
in `taxonomy/software.csv`.

**Tool route.** The way into the literature frame by the name of an estimation tool made for
pharmacometric work (NONMEM, Monolix, Phoenix NLME, nlmixr, Pumas, Pmetrics, saemix or S-ADAPT),
whatever a paper calls its method: in PubMed's title and abstract, and in the methods section of
Europe PMC's open-access full text. General statistical tools such as BUGS or Stan do not open it.
Decided on 2026-10-20. Used in `sources/literature/corpus_toolroute.R` (the `tool_route` column).

**Unlisted tool.** A tool that a reader found named in an item but that no tool family in the
taxonomy covers. Readers list them so that tool discovery can consider them. Used in
`classifications/tool_use/other_tools.csv`.
