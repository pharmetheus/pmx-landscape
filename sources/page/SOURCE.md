# Source card: PAGE meeting abstracts

| | |
|---|---|
| **Measures** | The estimation software the authors used, as read from abstracts of the PAGE meeting (Population Approach Group Europe), a snapshot of current practice at the time of each meeting |
| **Unit** | The abstract. An abstract can count for several tools |
| **Denominator** | The meeting's abstracts, without the Software Demonstration session; tool shares, and the comparison with the FDA, use the abstracts that used any estimation tool |
| **Snapshot and lag** | Meeting year; abstracts describe current or recent work |
| **Coverage** | Meetings 2006 to 2026 (no meeting in 2020): 2016 to 2026 in the charts, to match the other sources, and all years in the lag analysis against the FDA series. The AI and machine learning analysis (`analysis/ai_ml/`) also reads the 764 abstracts of 1992 to 2005, which it fetches itself; they are not in `results/` |
| **Retrieval** | `page_software_trends.R`: abstract pages from the site's sitemaps, one request every 1.5 s with a contact address, cached locally. The abstract body is searched without authors, affiliations and reference list; a poster or presentation PDF is searched only when the abstract names no estimation tool, and every tool found only in a PDF is read and decided by hand (`pdf_decisions.csv`). Every abstract naming a tool is then read for each tool's role (used, comparator, mentioned) and the analysis types (`role_review.R`, `role_rubric.md`, `role_decisions.csv`) |
| **Terms** | PAGE's About page states that the abstracts are the copyright of their authors or institutions, that they may be viewed and downloaded for private research or study, and that reuse needs the permission of the submitting author (checked 2026-11-06; the same statement is in the Internet Archive copy of 2026-06-13). robots.txt allows the abstract pages, and the site gives no machine-readable reservation (no `tdmrep.json`, no robots meta tag or header against it). Abstract text, PDFs and snippets are not committed; only abstract IDs, URLs, classifications and flags are. The organisers have not yet been contacted |
| **Local copies** | The abstract pages and posters are kept in local, git-ignored caches (`sources/page/page_cache/`, `corpus/cache/`), used only for this project. E-mail addresses are removed from the affiliation texts (`stripEmails()`). The local copies of a source are deleted when the source is dropped from the project, and all local copies when the project ends |

## What the numbers mean

- **Share of abstracts**: abstracts that used the tool among all abstracts of
  the group and year.
- **Share of abstracts using a tool**: the same among abstracts that used any
  estimation tool. This is the measure compared with the FDA's share of drugs
  with an identifiable tool.
- **Used** means the authors used the tool for their own analysis, or it is
  the platform their method runs in; a tool named as a comparator or in
  passing does not count (`pageUsedTools()`).
- **Affiliation type** is that of the first author: their first affiliation,
  or where that does not decide, their other affiliations, a shared prefix, and
  last the whole affiliation line (`classifyFirstAuthor()`; the step is in the
  results). Classes: industry, CRO, academia, regulator or vendor
  (`taxonomy/affiliation_rules.csv`). "Industry and CRO" is the sponsor side
  used for the FDA comparison.

## Known biases and limits

- A European, academic-heavy meeting; the affiliation split in the README
  shows how heavy.
- Use is read from the abstract, which is short: a tool the authors used but
  did not name is missed. Abstracts about developing or testing a tool count
  as use of it. Software Demonstration abstracts are left out.
- The role and type reading was done by a language model (Claude Sonnet 5) following
  `role_rubric.md`. A blind second reading by another model (Claude Fable 5.1) of a
  random 15% (498 abstracts) agreed on the tools used for 493 and on the set
  of analysis types for 448; the 54 disagreements were decided by a third
  reader (`results/role_check.csv`). The check showed that the first reader
  gave QSP or PBPK to mechanistic models the authors do not call QSP, so
  every such call outside the sample was read again (26 of 139 dropped).
  Joint models count only when the longitudinal and event parts are fitted
  simultaneously, so every joint-model call was read again for that (57 of
  123 kept; 46 were sequential and 20 did not say, and keep only their other
  types). No other type was re-read in full.
- The sitemaps list abstracts in abstract-number order but carry no year. The
  run selects by the year in each abstract's citation line after checking a
  sample of earlier pages (`results/run_info.txt`).
- PDF text from multi-column posters interleaves columns, which is why PDF
  hits are read rather than filtered automatically. PDFs that cannot be read
  leave their abstract out of the shares.
- Affiliation classes were checked on a sample of 30 per class (163
  abstracts); about 98% of classified ones agreed with a reader. The
  whole-line step, which can pick up a co-author's institution, decided 1.6%
  of abstracts.
- Early abstract numbers are not in year order: some pages after the start
  of the run are from the 1990s (dropped by year). One 2013 page has its
  citation outside the usual place and gets no year.

## Files

- Corpus: `corpus/page/`, one item per abstract 1992 to 2026, with the poster
  text where the PDF is cached (`make corpus`; see `corpus/README.md`).
- `results/page_abstracts.csv`: one row per abstract: ID, year, URL, session,
  Software Demonstration flag, affiliation type, tools found and where.
- `results/run_info.txt`: run date, selection, order check, counts.
- `pdf_decisions.csv`: the decision and reason for every PDF-only hit.
- `role_decisions.csv`: for every abstract naming a tool, the role of each
  tool, the analysis types, a short note in the reader's words and who
  decided it.
- `results/role_check.csv`: agreement of the blind second reading.
