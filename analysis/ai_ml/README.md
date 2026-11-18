# AI and machine learning

When machine learning and AI first appear in pharmacometrics, and how often
since, in four sources: PAGE abstracts, PubMed and Europe PMC papers, and FDA
reviews. Results are in the README section "AI and machine learning".

## Method

- **Terms** (`taxonomy/ai_ml_terms.csv`): two groups. *ML* is the named
  learning methods (machine learning, neural networks, deep learning, neural
  ODEs, random forests, gradient boosting, support vector machines,
  reinforcement learning, symbolic regression, k-nearest neighbours). *AI* is
  the label and its newer forms (artificial intelligence, AI in capitals,
  expert systems, large language models, ChatGPT and GPT-3 to GPT-5,
  generative AI, AI agents). Each term has a regular expression for cached text
  and query strings for PubMed and Europe PMC. Left out: genetic algorithms
  and decision trees (more often optimisation and decision analysis than
  learning), bare "GPT" (also glutamic pyruvic transaminase) and, in Europe
  PMC, bare "AI".
- **Sources** (`ai_ml.R`, run from this folder; caches in `cache/`, not
  committed):
  - PAGE: every abstract in the site's sitemaps of 2026-09-26, 1992 to 2026
    (6,900 abstracts). The 764 abstracts from before 2006 were fetched for
    this analysis with the same polite client as the PAGE run, into
    `sources/page/page_cache/`; the PAGE results files stay 2006 to 2026.
    Title and body are searched, without authors, affiliations and reference
    list (`pageParseAbstract()`); poster and slide PDFs are not.
  - PubMed: the literature base query (title/abstract) per year from 1965 (the
    first base paper is from 1971), and the base query with each group's terms.
    Each PMID counts in the earliest year it matches (`keepEarliestYear()`).
    Title and abstract are searched. 14 PMIDs that PubMed returned name no
    term in the title or abstract (PubMed matched "aims", "Ai" or other
    fields) and are not counted.
  - Europe PMC: the literature base query (base terms in title, abstract or
    keywords; open-access full text; no preprints) per year from 1980, and the
    base query with each group's terms. Title, abstract, keywords and body of
    the full text are searched; the back matter (reference list, declarations)
    is not. 39 papers whose full text the service did not return (HTTP 500)
    and 58 papers that name no term in the searched text are not counted. In
    40 of those 58 the term is in the back matter: Europe PMC's search reaches
    reference lists and statements on the use of generative AI.
  - FDA: the cached review text and OCR of the 238 approvals 2021 to 2025
    (`fdaSearch()` with the terms as patterns); one item per drug.
- **Reading** (`rubric.md`): each item and term found was decided *used* (the
  authors apply or develop the method), *mentioned* (background, citation,
  review, proposal) or *not* (the words do not mean the method). The AI label
  counts as used only when the authors call their own method or tool AI;
  naming AI as the field their machine learning belongs to is a mention. Terms
  only in a reference entry, a funding programme's name or a statement about
  writing the item are *not*. Claude Sonnet 5.5 readers read 2,230 item and term pairs
  (988 items) in nine batches. Two batches were read again in smaller parts
  after a check of each note against its row showed that the decisions had
  drifted from the rows; the second reading carried each row's title to prove
  the alignment. A blind Claude Opus 5.5 reading of a random 15% of the items (148 items,
  315 pairs) agreed on 299 decisions and on 309 for whether the term counts
  at all (`results/checks.csv`, `check_decisions.csv`); the 16 disagreements
  were decided by Claude. Every item that a first year rests on was read again
  in full, which corrected one FDA decision (a reference-list title).
- **Results** (`results/`): `items.csv` (every item and term with its
  decision), `base.csv` (items in each base set per year), `shares.csv`
  (`aiMlShares()`: per source, year and group, items mentioning, items using,
  and their shares), `first_by_group.csv` and `first_by_term.csv`
  (`aiMlFirst()`), `run_info.txt`. No source text is committed;
  `decisions.csv` holds one line per decision in the reader's own words.

## Limits

- Publication lags the work, and only pharmacometric publications are
  counted: the base terms leave out machine learning papers on drug
  concentrations that do not call themselves population PK or pharmacometric.
- Europe PMC's open-access full text is thin before about 2010, so its first
  years are late by construction. PAGE, with every abstract since 1992, dates
  the emergence best.
- A mention in an introduction counts as a mention; Europe PMC therefore has
  the highest mention shares.
- The AI label is counted as the authors use it: POPKAN (PAGE 1995) is a
  Bayesian program presented as an expert system, and the first PubMed use of
  "artificial intelligence" (2016) is a regression spline method the authors
  call AI.
