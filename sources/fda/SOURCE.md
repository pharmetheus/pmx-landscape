# Source card: FDA review documents

| | |
|---|---|
| **Measures** | The popPK software named in FDA's published reviews of CDER novel drug approvals: the sponsor's (Applicant's) software, kept apart from software the FDA reviewer used |
| **Unit** | The drug. A tool family counts once per drug |
| **Denominator** | All CDER novel approvals of the year (238 for 2021 to 2025); tool shares use the drugs with an identifiable sponsor tool (148 from the reviews, 164 with the other documents) |
| **Snapshot and lag** | Approval year in the decision record. The bars of the reports are twelve-month periods of approval (`fdaPeriods()`, decided 2026-10-20): the latest ends on the most recent 30 June or 31 December at least three months before the count, so that its reviews are posted, which makes the periods July to June for half the year and calendar years for the other half. The analyses were typically done 1 to 3 years before approval |
| **Coverage** | 2021 to 2025, all reviews posted. For the development run (2026-10-20), also July to December 2020 (28 drugs, 27 with reviews; `extract.R 2020 2020-07-01`, the rest of 2020 waits for the production run) and 2026 (the approvals up to 2026-10-09, with the reviews posted so far, 40 of 46 drugs). For these years the FDA applicant use reading (`classifications/fda_use`) is the record, and the population PK reading (`classifications/fda_poppk`) splits the drugs whose review names no tool into software not stated and no popPK analysis. The periods table (`window.R`, `results/fda_periods.csv`): on 2026-10-20, 2020/21 to 2025/26, 288 drugs |
| **Retrieval** | FDA "Novel Drug Approvals" pages, openFDA and Drugs@FDA; Integrated, Multi-Discipline and Clinical Pharmacology reviews (Python steps 1 to 4 for 2021 to 2025; R since October 2026, `retrieve.R` and `extract.R`, which find the same drugs and documents and keep the PDFs, 2016 to 2025); regex search of the text layer and OCR of image-only pages; every mention read and attributed (`docs/METHODS.md`). For drugs whose review names no tool, also the submission's other review documents and the EMA assessment report (`other_reviews/`, R) |
| **Terms** | FDA review text is a US government work in the public domain; the extracted text is in this repository |
| **Local copies** | The review PDFs are kept in a local, git-ignored cache (`sources/fda/cache/`), used only for this project. The local copies of a source are deleted when the source is dropped from the project, and all local copies when the project ends |

## What the numbers mean

Each drug has one sponsor category: tool stated; tool stated (indirect); popPK
present, software not stated; no popPK analysis in review. Indirect evidence
counts towards the shares but stays flagged, and 9 drugs rest only on an FDA
template phrase ("The final NONMEM data file..."), which is unreliable; the
README table shows shares with and without them. When the FDA reviewer ran
the applicant's model or dataset in a tool and the review names no other tool
for the applicant, that tool is indirect evidence of the applicant's use
(Niclas, 2026-10-19). The drugs this moved (four template-only, three not
stated) are listed in `results/record_revisions.csv`, applied on top of the
record by `fdaApplyRevisions()`.

## Known biases and limits

- For late 2020 and 2026 the drugs whose review names no tool were not searched in the
  submission's other documents or the EMA reports, as the 2021 to 2025 drugs were, so their
  "software not stated" share is not lowered by that evidence.

- "Software not stated" is not "not NONMEM". In the reviews it is 60 drugs
  (63 as first read, 3 since moved by the reviewer-run rule), most of them in
  2021, when the review template had no software row. The submission's other
  documents name the tool for 16 of them (9 stated, 7 indirect;
  [other documents](other_reviews/README.md)), which leaves 44. These are applied on top of the review record
  (`fdaApplyOtherEvidence()`), which stays as read from the reviews. For some
  of the rest the sponsor's own papers point to a likely tool; see the
  [cross-check](crosscheck/README.md). That is a separate evidence tier and
  does not change the record.
- Three review types are searched for every drug, and the other documents
  only for the drugs whose review names no tool.
- Regulatory submissions come from companies large enough to take a drug to
  approval, and describe analyses done years earlier.
- OCR errors could hide a name on an image-only page.

## Files

- Corpus: `corpus/fda/`, one item per drug and one section per review page
  (`make corpus`; see `corpus/README.md`).
- `results/fda_2021_2025_popPK_software.csv`: the decision record, one row
  per drug, with review URLs and PDF page numbers for every piece of evidence.
- `results/record_revisions.csv`: decisions taken since on the same review
  text, each written against the record's strength (`from`), with pages.
- `config/`: search patterns and the only hand-made inputs, each with a reason.
- `data/<year>/`: frame, document list, extracted text and OCR text.
- `docs/METHODS.md`: the full method, borderline decisions and limitations.

Re-derive the results: `make fda-verify` from the repository root (see
`docs/fda.md`).
