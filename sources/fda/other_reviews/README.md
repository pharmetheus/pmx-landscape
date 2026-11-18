# FDA drugs without a named tool: the submission's other documents

For the 63 drugs whose FDA review has a population PK analysis but names no
software (2021 to 2025), two further kinds of document were searched. A tool
named there for the applicant's own population PK counts for the drug, on top
of the review record (`fdaApplyOtherEvidence()`, decisions in
`decisions.csv`).

## Method

1. **Other FDA review documents** (`discover.R`, `fetch.R`). The Drugs@FDA
   table of contents of each drug lists its documents. Besides the three
   review types always read (Integrated, Multi-Discipline, Clinical
   Pharmacology), the Other, Summary, Medical and Statistical reviews were
   downloaded (78 documents, 6,787 pages) and image-only pages OCRed.
   Nonclinical, chemistry, name, risk, correspondence, letters and labels
   were not searched.
2. **EMA assessment reports** (`ema_fetch.R`). EMA's medicines table was
   matched on the active substance: 48 of the 63 drugs have an EMA product.
   The public (or withdrawal or refusal) assessment report of each matched
   product was downloaded: 47 reports. EMA answers faster requests with HTTP
   429, so the script waits 4 s between requests.
3. **Search and reading** (`search.R`). The estimation-tool patterns of
   `taxonomy/patterns.json`, PsN (which runs only NONMEM) and NONMEM
   control-stream syntax were searched, and every hit was read.
4. **Decisions** (`decisions.csv`), agreed with Niclas:
   - *stated*: the applicant's population PK names the tool, in a document of
     the same submission or an EU procedure close in time to the FDA's (within
     about a year);
   - *indirect*: the tool is named in an earlier or later submission of the
     same drug (updated analysis, another product or indication), or only for
     a related analysis (PK/PD, concentration-QTc), or in wording that reads
     like an acronym for nonlinear mixed-effects modelling.

## Results

The other FDA documents added no stated tool: the only real hit is a
concentration-QTc model in NONMEM (Exkivity, indirect); the other hits were
"Stan-dard" split across lines. EMA reports named NONMEM for 15 drugs, no
other tool. In all: 9 stated, 7 indirect, all NONMEM; 47 drugs stay not
stated.

## Pilot: EMA reports as a source of their own

The EMA reports of 20 random drugs whose FDA review states the tool (19
NONMEM, 1 Monolix; 18 have a report) name it in 5, and in one more only in an
abbreviation list; all 6 agree with the FDA review. With about a third of the
drugs named in both groups, EMA reports are useful as added evidence but not
as a separate series.

## Terms and files

EMA and FDA documents are not committed; the PDFs and text are in the
git-ignored `cache/`. Committed: `results/toc_documents.csv` (documents listed
per drug), `results/other_documents.csv` and `results/ema_documents.csv` (IDs,
URLs, page counts), `results/hits_*.csv` (drug, document, page, family; no
text), `results/ema_pilot_documents.csv`, and `decisions.csv`.
