The question is about the Applicant (the sponsor) only. The FDA reviewer's own use of a tool is not a value of its own: it is `none`, unless it shows what the Applicant used (below).

The text is a set of windows around each place a candidate tool is named, each labelled with the review document and PDF page it comes from and, where the review has them, the numbered section headings it sits under and the last label line after them ("Applicant's Position", "FDA's Assessment", "Reviewer's Comment"). Decide by what the text says; headings and labels are hints only, since FDA reviews often reproduce the Applicant's text under FDA headings or in appendices. The reviewer's own work is described as such ("the reviewer conducted", "FDA's independent analysis", "Reviewer's Independent Analysis", "reviewer's files", "Source: Reviewer's analysis").

`stated`: the review says the Applicant's analysis used the tool, in words or in a software list or table describing the Applicant's analysis (for example a "Software" row of a table assessing the Applicant's popPK analysis). "Nonlinear mixed effects modeling" followed by a NONMEM version number (such as 7.5.0) where the software name belongs is a garbled "NONMEM" and counts as the name.

`indirect`: the tool is tied to the Applicant's model, files or outputs, without the review saying in words that the Applicant used it: "NONMEM outputs of the Applicant's model", a NONMEM control stream among the submitted files, the covariance step in an Applicant table, a dataset name or figure axis specific to the tool, an abbreviation list. It is also `indirect` when the FDA reviewer ran the Applicant's model or dataset in the tool (re-ran, revised, adopted it, or simulated from it) and the review names no other tool for the Applicant. A "final model" in the review is the Applicant's unless the review says the reviewer built a model of their own.

`template`: the sentence "The final NONMEM data file for analysis contained ..." is FDA review template text. When it is the only link between the tool and the Applicant, the value is `template`. When the review states another tool for the Applicant's analysis, the template sentence is `none`.

`none`: a tool named only in a reference list or a citation, for a nonclinical (animal) model, for another drug, among software in general, or for a model the FDA reviewer built themselves (not from the Applicant's model).

When several windows give different strengths, give the strongest: `stated`, then `indirect`, then `template`, then `none`.
