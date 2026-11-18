# Classification card: affiliation

| | |
|---|---|
| **Question** | Which kinds of organisation are the authors from? Per item: the first author's affiliation type, whether any author is from industry or a CRO, and the companies, CROs, vendors and regulators that a naming rule found (`values.csv`) |
| **Why** | A stratification variable for every other classification (Niclas, 2026-10-19), for every source except FDA (whose applicant is the sponsor by definition) |
| **Scope** | PAGE authors and affiliation line; PubMed and Europe PMC author list and each author's affiliations (`author_affiliations` in the corpus, from PubMed XML and Europe PMC records) |
| **Method** | Rules only: `taxonomy/affiliation_rules.csv`, first matching rule wins (`affiliationTags()`); no reading. Version 1, 2026-10-19 (development); version 2, 2026-10-20: the same rules, but only named organisations are published |
| **Personal data** | Author names are never stored. An organisation is withheld when the consultancy rule decides it (often named after a person) or when it contains a word of the item's own author list |
| **Published names** | Only the names that a rule marked `named` in `taxonomy/affiliation_rules.csv` matched: regulators, the larger CROs, software vendors and drug companies (decided 2026-10-20). All other organisation names, academic ones included, stay in the git-ignored `cache/organisations_local.csv` |

## Coverage (`coverage.csv`)

First author's type, share of items:

| Type | PAGE | PubMed | Europe PMC |
|---|---|---|---|
| academia | 59.5% | 76.7% | 74.7% |
| industry | 26.2% | 17.1% | 18.7% |
| CRO | 10.3% | 2.5% | 2.9% |
| vendor | 1.6% | 0.2% | 0.3% |
| regulator | 0.3% | 0.6% | 0.4% |
| unclassified | 2.0% | 1.5% | 1.6% |
| no affiliation | 0.0% | 1.4% | 1.5% |

Any author from industry: PAGE 43%, PubMed 30%, Europe PMC 33%; any author from a CRO: 17%,
11% and 13%. Organisations withheld: 127 (PAGE), 286 (PubMed), 113 (Europe PMC).

## Agreement with the earlier first-author types (`earlier_agreement.csv`)

The same rules gave the earlier types (`sources/page/results/page_abstracts.csv`,
`sources/literature/results/pubmed_affiliations*.csv`): PAGE 6,136 of 6,136 the same,
PubMed 8,044 of 8,045. The one difference is a paper whose first listed author is a group
without an affiliation: the earlier rule skipped group authors, this one reads the first
author by position, since names are not kept.

## Development check (`precision.csv`, `precision_errors.csv`)

Claude Sonnet 5.5 subagents read 30 first-author affiliations per source and type (fewer where a type has
fewer; 499 in all; seed 20261020), and judged whether the type was right, whether the stored
organisation names the organisation, and whether it names a person. A check by agents, not by
a person. It was made on version 1, which stored every organisation name; the organisation
columns below refer to those names, most of which version 2 no longer publishes.

| Type | Read | Type right | Type wrong | Organisation right |
|---|---|---|---|---|
| academia | 90 | 87 | 1 | 79 |
| industry | 90 | 86 | 2 | 85 |
| CRO | 90 | 89 | 0 | 89 |
| vendor | 65 | 62 | 3 | 65 |
| regulator | 74 | 70 | 1 | 45 |
| unclassified | 90 | (62 show a type) | | 62 |

- No stored organisation names a person (0 of 499).
- The rules' types are right for 394 of 409 classified affiliations; 7 are wrong and 8 do not
  show their type. The three vendor "errors" are the engineering firm that develops PhysPK,
  which the rules count as a vendor by design and the check's definition did not; two PAGE
  regulator rows came from the whole-line fallback picking a co-author's agency (a known
  limit, below).
- Two thirds of the unclassified affiliations do show a type (25 academia, 22 industry, 14 CRO),
  so the 1.5 to 2% unclassified share can be lowered with more rules.
- Organisation: the regulator rows store the FDA centre (CDER) rather than the agency, and some
  academic rows store an institute, college or laboratory rather than the university. A
  company's name followed by its legal form in a segment of its own stored only the legal form;
  fixed after the check (`BeiGene, Inc`), two such cases remain where the legal form is the
  first segment.

## Known limits

From TODO.md ("Affiliation classes: remaining weak spots"), still open: small modelling firms
whose type the text does not show, "presently at" footnotes, and the PAGE whole-line fallback,
which can pick up a co-author's institution. Academic organisation names are not normalised
(one university can appear under several spellings).

## Standard tables (`report_methods.csv`, `report_values.csv`)

Made by `classifications/standard_tables.R affiliation`. Every tag comes from a rule, so all are
exactly reproducible from the corpus and `taxonomy/affiliation_rules.csv`. The values table gives
the first author's types by source.
