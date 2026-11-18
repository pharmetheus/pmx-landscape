# Codebook: tool use, version 5

Status: approved by the project lead and frozen on 2026-10-20. Drafted on 2026-10-19 and used in a
development run. Terms used in a specific sense are defined in `docs/glossary.md`.

This page explains, in one place, how the tool use classification decides. The files the code reads
are `module.json`, `values.csv`, `rubric.md` and `rules.csv`. The method shared by all
classifications is in `classifications/README.md`.

## The question

For each estimation tool that an item names, the classification asks: did the authors use the tool
for their own analysis, use it only for comparison, or only mention it?

An example: a PAGE abstract says "the model was developed in NONMEM 7.5 and compared with a Monolix
fit". It names two estimation tools, so it has two candidates. NONMEM gets the value `used`, and
Monolix gets `comparator`.

## What is decided

The classification decides one value per candidate. A candidate is an item paired with one tool
family it names. Only families of the estimation group count, such as NONMEM, Monolix or nlmixr.
Auxiliary tools such as PsN are not candidates. The families and the patterns that find them are in
`taxonomy/software.csv` and `taxonomy/patterns.json`. Each run records which version of the
taxonomy it used. When a family is added later, only that family's candidates are read.

## The text that is read

The classification reads PAGE abstracts and the literature. FDA reviews are classified separately,
by FDA applicant use (`classifications/fda_use/`). A review names the FDA reviewers' tools as well
as the applicant's, and its template text names NONMEM even when the applicant used another tool,
so it needs values of its own.

- PAGE abstracts: the title and the body.
- PubMed: the title and the abstract.
- Europe PMC: the title, the abstract and the methods section. A paper without a methods section is
  read in full instead.

Reference lists are never read, so a tool cited only in the references is not a candidate.

## Values

| Value | Meaning | Typical case |
|---|---|---|
| `used` | The authors used the tool for their own analysis: to fit or estimate, or to simulate with their model. It is also `used` when the authors' new method runs inside the tool, or their software is built around it. | "the model was developed in the tool", a version number, an estimation method of the tool |
| `comparator` | The tool is a benchmark that the authors' own method or tool is compared with. This includes a tool run only to produce the reference results. | a new method compared with the tool's estimates |
| `mentioned` | The tool is named only in passing: in the background, in a list of software, as what others use, or as future work. | an introduction listing the common tools |

## Hard cases

The value definitions leave some cases open. The rubric (`rubric.md`) settles them:

- The item is about the tool itself, for example a new feature or interface for it: `used`.
- Only the authors' own work counts, not the background, the literature or future work.
- The tool is named, but the text says nothing about what was done with it: `mentioned`.
- The tool is run only to produce reference results for a new method: `comparator` (decided
  2026-10-18).
- The authors built software around the tool, without an analysis in it: `used` (decided
  2026-10-18).

New in version 5, from the disagreements found in versions 3 and 4:

- Any member of a family counts for the family, for example nlmixr2 for nlmixr.
- A tool run through another program, such as PsN running NONMEM, is `used`.
- A second tool run only to check the main results is `comparator`.
- A tool named only as something a planned framework will support is `mentioned`.
- A tool named only as one of the programs a general platform connects to is `mentioned`.
- A tool that is both the platform and the benchmark is `used`.

## Fixed rules

Three rules give `used` without a reading:

1. the tool is named with a version number;
2. the analysis is said to be done in, with or using the tool;
3. the tool is said to have been used.

The rules apply only when the item names no other estimation tool and compares no tools or methods.
The sentence that triggers a rule must not compare or list anything. The rules were written from the
PAGE abstracts. On Europe PMC papers that played no part in writing them, the rules agreed with an
earlier reading in 99.5% of cases. In the five differences, the earlier reading was wrong.

## Tools the taxonomy lacks

New in version 5: each reading also lists any other estimation software the text names. These are
the unlisted tools (`other_tools.csv`). They go to tool discovery, which proposes new tool families
for the project lead to decide on.

The list is a lower bound. Items decided by rules alone are not read. Items that name no known tool
have no candidates, so they are not read either.

## How the codebook was developed

| Version | Items it was developed on | What changed |
|---|---|---|
| 1 | a pilot of 100 PAGE abstracts | the values and rubric of an earlier PAGE reading |
| 2 | a sample of 545 items | all three sources; the fixed rules |
| 3 | the same sample | two clarifications by the project lead |
| 4 | the same sample | each candidate shown with the names its text uses for the family |
| 5 | none (tested on new items) | the hard cases of versions 3 and 4; the unlisted tools |

The 642 items that led to a change are listed in `dev_items.csv`. For the fixed rules, all PAGE
abstracts count as development items. The agreement measured for versions 2 to 4 is optimistic,
because it was measured on the same items the changes came from.

## Held-out test of version 5

The test used 260 items that played no part in the development. They were drawn at random
(seed 20261020) in five groups:

- 50 items from each of PAGE, PubMed, Europe PMC and the literature extension, all with candidates
  the rules leave open;
- 60 literature items whose candidates the rules decide alone, to test the rules.

Claude Sonnet 5.5 subagents read the items with this codebook. Claude Opus 5.5 subagents read them again,
blind (`heldout.csv`, `heldout_rules.csv`).

| Group | Decisions compared | Same value | Cohen's kappa |
|---|---|---|---|
| PAGE | 56 | 56 | 1.00 |
| PubMed | 54 | 54 | 1.00 |
| Europe PMC | 60 | 60 | 1.00 |
| Extension | 54 | 52 | 0.86 |
| Decided by rules | 60 | 60 | |
| All | 284 | 282 | 0.96 |

Some items name more than one tool, so 260 items gave 284 decisions. The reading agreed with the
rules on all 60 rule decisions.

The two disagreements are cases the rubric already settles (`heldout_disagreements.csv`). In one, a
trial protocol names a tool for an analysis that is only planned, which is future work and so
`mentioned`. In the other, a tool is run only to simulate reference values for a new method, which
is `comparator`. No new kind of case appeared, so the rubric was not changed again.

The readers listed 15 unlisted tool names in 8 of the 260 items. Examples are R packages for mixed
models such as lme4, and a SAS procedure. One reader also listed BUGS, which is in the taxonomy but
was not found as a candidate in that item. That points to a gap in the BUGS pattern.

The test compares two language models. Their agreement is not the same as accuracy against a
person, which the production run measures with checks by people.
