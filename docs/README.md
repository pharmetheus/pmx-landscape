# Using this repository

Guides for re-running, checking and extending the PMx Landscape. The main
results are on the [landing page](../README.md), and every table and chart is in
the [detailed results](results/estimation-software.md); what each source
measures is on its source card.

| Guide | For |
|---|---|
| [Overview](overview.md) | One page on what is measured, from which sources, and how |
| [Detailed results](results/estimation-software.md) | Every table, chart and method of the estimation software measure, built by `make readme` |
| [Glossary](glossary.md) | The terms this project uses in a specific sense |
| [Documentation style](STYLE.md) | How documents in this repository are written |
| [Getting started](getting-started.md) | Setting up R, the system libraries and the package |
| [FDA reviews](fda.md) | Re-checking the FDA results, changing patterns, adding a year |
| [Literature](literature.md) | Re-running the PubMed and Europe PMC counts and affiliations |
| [PAGE abstracts](page.md) | The pilot, the full run, and reading PDF hits |
| [Taxonomy](taxonomy.md) | Adding a software family or an affiliation rule |
| [Discovering new tools](discovery.md) | The yearly round that proposes tools for the taxonomy |
| [Adding a source](adding-a-source.md) | What a new source (for example ACoP) needs |
| [Design](design.md) | The design record: corpus, classifications, tag database and releases, with the decisions taken since |

Source cards: [FDA](../sources/fda/SOURCE.md),
[literature](../sources/literature/SOURCE.md),
[PAGE](../sources/page/SOURCE.md).

Everything runs from the repository root through `make` (`make help` lists
the targets).
