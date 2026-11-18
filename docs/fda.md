# FDA reviews

The FDA source is complete for 2021 to 2025. Its results file,
`sources/fda/results/fda_2021_2025_popPK_software.csv`, is the decision
record: one row per drug, with the review URLs and PDF pages behind every
finding. See the [source card](../sources/fda/SOURCE.md) and
`sources/fda/docs/METHODS.md`.

## Check the results against the cached text

```
make fda-verify
```

This runs the search in R (`fdaSearch()`) over every page of the 241 cached
review documents and compares it with the results file (`fdaVerify()`). It
must report 0 unexplained software mentions. `make test` goes further: the R
search must reproduce the stored `hits.json` files exactly, and the summary
must equal `results/summary_sponsor_by_year.csv` byte for byte.

## Change or add a search pattern

1. Edit `sources/fda/config/patterns.json` (for the FDA record) or
   `taxonomy/patterns.json` (shared by all sources; see [Taxonomy](taxonomy.md)).
2. Run `make fda-verify`. Every UNEXPLAINED line is a mention the record does
   not account for.
3. Read each one in context:

   ```r
   pkgload::load_all("pmxlandscape")
   fdaContext("sources/fda", 2024, "216158", 265, "NONMEM")
   ```

   It prints the text around the match and the attribution labels before it.
   Labels are hints only: FDA appendices often reproduce Applicant text under
   FDA headings.
4. Correct the drug's row in the results file, or add the match to
   `sources/fda/config/known_exceptions.json` with a reason.
5. Repeat until `make fda-verify` reports 0.

Note that the ported check accepts a tool if its name appears anywhere in the
row, including the notes (see `TODO.md`); tighten it before adding years.

## Cross-check with the sponsor's papers

```
make fda-crosscheck
```

runs `sources/fda/crosscheck/crosscheck_literature.R` (network access; a few
minutes, cached). It looks for the sponsor's own popPK papers on each drug
and the software their methods name, and validates the rule on the drugs whose
review states the tool (`results/run_info.txt`). Correct a sponsor's search
name in `sponsor_overrides.csv`, with a reason. See the
[cross-check card](../sources/fda/crosscheck/README.md).

## Add a year

Retrieval is in R (`sources/fda/`; the Python scripts in `scripts/` stay as the record of
how 2021 to 2025 were made):

```
Rscript retrieve.R 2026   # frame, review documents and PDFs (resumable)
Rscript extract.R 2026    # data/2026/: frame, documents, text layer and OCR
```

`retrieve.R` reads FDA's novel approvals page for the year (CDER's NME and new biologic
compilation for years whose page FDA no longer serves, before 2021), finds the review
documents through openFDA and the Drugs@FDA tables of contents, and keeps the PDFs in the
git-ignored `cache/<year>/pdf/`. Its record of what it found and downloaded, with
checksums, is in `retrieval/<year>/`. `extract.R` makes the text with the same programs as
the Python pipeline (pdftotext; pdftoppm and tesseract for image-only pages). Then search
and read as above, add the year's rows to the results file, and run `make fda-verify` and
`make test`. Throttle accessdata.fda.gov to about one request per second; faster bursts
fail silently. The README of `sources/fda/` lists the older-year pitfalls.

The PDFs for 2016 to 2025 are downloaded (October 2026). For the surveyed years,
`retrieve.R` checks that it finds the same drugs and documents as the record
(`retrieval/<year>/compare.txt`), and `check_text.R` that a new extraction finds the same
software mentions as the committed text (`retrieval/text_check.txt`).
