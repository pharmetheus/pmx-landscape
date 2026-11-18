# PMx Landscape: backlog

Items parked for later. Move an item to a GitHub issue when it becomes active work.

## `fdaVerify()` accepts a tool if its name appears anywhere in the row

Ported unchanged from `07_verify.py`: a hit is explained if the first word of
the tool family occurs as a substring of the sponsor, auxiliary, FDA reviewer
or PBPK/NCA columns *or the free-text notes*. So "stan" is explained by
"standard" in a note, and a note such as "no Monolix use" explains a Monolix
hit. The test fixture contains the first case on purpose, to keep parity with
the Python script.

Measured on 2021 to 2025 (September 2026): of 274 drug/tool pairs with a hit,
271 are explained by a whole-word match in the software columns and 3 by
`known_exceptions.json`; none depends on the notes or on a substring match.
Tightening the check to whole words in the software columns would therefore
change nothing today, and would stop new years or sources from being waved
through. Do it before extending FDA to other years.

## DeepNLME

Held back from the taxonomy: the PAGE pilot abstract describes it as a
modelling approach ("a deep nonlinear mixed effects model"), not a program,
so a family would count a method as software. Waiting for Niclas.

## Affiliation classes: remaining weak spots

Checked on samples of 30 per class (PubMed: two samples, 344 papers; PAGE:
163 abstracts); among classified rows about 97 to 98% agreed with a reader,
and the rules were then corrected on those rows. Remaining: unclassified
PubMed 1.4% (71 of 5,151) and PAGE 1.3% (77 of 6,014, 2006 to 2026); small modelling firms whose type the text
does not show; "presently at" footnotes; the whole-line fallback (1.6% of
PAGE abstracts) can pick up a co-author's institution. Europe PMC
affiliations are not classified yet.

## When the ACoP abstracts arrive: one search method for every source

FDA reviews and PAGE abstracts are fetched first and searched locally with the
taxonomy's patterns. The PubMed and Europe PMC tool counts are the services'
own matches: the tool terms are sent as query strings and only the returned
IDs are stored, so what counts as a match depends on each service's indexing.
Europe PMC's full-text search reaches reference lists and declarations at
least some of the time (October 2026: of 58 records it returned for the AI and
machine learning terms that name no term in title, abstract, keywords or body,
40 had it only in the back matter), which the literature card says it does
not.

Reconsider once (if) the ACoP data come in, since ACoP will be searched
locally like PAGE: fetch the literature base set's text (PubMed abstracts,
about 5,200 for 2021 to 2026; Europe PMC full texts, about 2,600, mostly
cached from the model-size reading) and apply the same patterns, keeping the
service counts as a check. The cost: the Europe PMC numbers would no longer be
reproducible as a query on the Europe PMC site.

## Signal detection: a yearly screen for emerging tools and methods

Distinguish weak signals from noise, as pharmacovigilance does (the Uppsala
Monitoring Centre's Information Component, FDA's empirical Bayes screening):
each year, flag terms whose count is higher than the earlier years predict,
after allowing for growth in the corpus (observed against expected with
shrinkage, or burst detection), and pairs that occur together more than
expected (tool by analysis type, by affiliation, by method). A flag is a
hypothesis to read, not a finding. Needs the open candidate list from the tool
discovery procedure, so that unknown names are screened too.

Acceptance test before adopting it: a backtest on PAGE 1992 to 2026, run as
if in each past year with only the data up to it. Would it have flagged
Monolix (about 2006 to 2009), nlmixr (from 2017), Pumas (2021), machine
learning (about 2019) and large language models (2023), how early, and with
how many false alarms a year? Only if that is convincing: a yearly run and a
short README section on new signals.

## Extend the landscape from tools to methods

Measure methods as well as software: estimation algorithms (FOCE, SAEM,
importance sampling, NPAG, MCMC), model types and approaches (FREM, SCM and
other covariate methods, model averaging, MBMA, joint models, neural ODEs),
diagnostics (VPC, pcVPC, rVPC, NPDE) and so on. The analysis types and the
model-size reading already record some of this (analysis type, estimation
method). The first tool discovery round (October 2026) already decided 92
candidate names as methods (`taxonomy/discovery/tool_decisions.csv`), a
starting list. Needs its own taxonomy, a discovery step like the tools', and a
decision on which sources and which unit (mention or use) apply.

## FDA 2016 to 2020: review documents for 14 drugs not found

The review PDFs for 2016 to 2025 are downloaded and kept (October 2026,
`sources/fda/retrieve.R`, git-ignored `sources/fda/cache/`, 5.4 GB; record in
`sources/fda/retrieval/`). For 2021 to 2025 the R retrieval finds exactly the
record's drugs and documents. For 2016 to 2020 (frame from CDER's NME and new
biologic compilation, since FDA no longer serves those years' approvals
pages) it finds documents for 214 of 228 drugs: the older tables of contents
have no `pdfBaseName`, so the base name comes from the TOC URL, and some list
documents that are not at the probed addresses ("TOC lists ... but the file was
not found" in `retrieval/<year>/log.csv`). Before the FDA series is extended to
those years, read the links of the older TOC pages directly and check the
missing drugs by hand.

Then extend the FDA series to 2016 to 2020 (Niclas, 2026-10-19), to match the
literature period: the 14 missing drugs checked by hand, then the applicant
reading (`classifications/fda_use`) of the 228 drugs. For those years there is
no hand-built decision record, so the reading, checked, becomes the record;
the card says so.

## Other regulatory agencies as sources

From Niclas, 2026-10-19: evaluate which agencies could give a series like the
FDA one. EMA beyond the EPAR pilot (EPARs name the tool for about a third of
drugs), including the clinical data published under its Policy 0070, which
may hold the modelling reports themselves; PMDA, Health Canada, MHRA,
Swissmedic, TGA and others. For each: what is published, whether it names the
software, the terms of use, and whether machine reading is allowed or could
be asked for.
