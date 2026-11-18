# PMx Landscape 0.3.0 (2026-11-17)

The first release meant for the public. PMx Landscape measures how pharmacometric modelling is
done in practice; this release holds its first measure, the estimation software used, and the
corpus every later measure will read. The literature results now come from every paper that
fits a population model of its own, however it was found, and every number can be traced to the
texts and decisions behind it. Results from a development run are labelled as such: they were
read by Claude Code subagents and may change at the production run.

## The literature counts the papers that fit a model of their own

- Papers are found by two routes:
  - **Term route:** the paper uses the field's names for the method, such as "population
    pharmacokinetic", "pharmacometric" or "population PK".
  - **Tool route:** the paper names an estimation tool made for pharmacometric work, such as
    NONMEM, Monolix, Phoenix NLME, nlmixr or Pumas.
- Every paper found was read for whether its authors fitted a population model of their own, in
  pharmacology. Only those papers count.
- The tool route changes the shares mainly in Europe PMC, where the tool is named in the methods.
  Among the papers of 2021 to 2025 that use an estimation tool, NONMEM's share falls from 74% (term
  route only) to 68% (both routes), and Monolix's rises from 14% to 19%.
- The literature series cover 2021 to 2026; 2026 is partial.

## FDA approvals by twelve-month period

- A chart gives the approvals by July-to-June period next to the yearly results of 2021 to 2025.
- It includes the approvals of July to December 2020 and of 2026, read as a development run. For
  them, a review naming no tool is split into "software not stated" and "no population PK
  analysis" by a reading of its own.

## Every number can be traced

- **Corpus:** one table of items and one of sections per source, with IDs, links, sizes and
  hashes, the fingerprints that show whether a text is the one that was read (`corpus/`). Text from the literature and from conference abstracts stays local. FDA
  review text, a US government work in the public domain, is published.
- **Classifications:** every question asked of the texts has a codebook, a record of every
  decision with its reader, prompt and input, and a blind second reading of a sample
  (`classifications/`).
- **Tag database:** the final values of the tool-use and affiliation classifications and of the
  FDA decision record, for every item, in one place (`database/`). The relevance reading of the
  literature has its decisions in `classifications/lit_relevance/`.

## Other notable additions

- Tool discovery searches the corpus for software names the project does not know yet (`make
  discover`). Its first round added 67 tool families, estimation tools such as nlme among them.
  The later rounds added auxiliary and non-compartmental analysis tools, and no estimation tool.
- Names of PBPK tools (Simcyp, PK-Sim, GastroPlus and others) are recorded for every literature
  paper. They do not yet form a series of their own.
- `CITATION.cff` gives the details for citing the project.

## Changes to existing behaviour

- PAGE: the tools an abstract used come from the tool use classification, the same as for the
  literature, rather than from an earlier separate reading.
- FDA: when an FDA reviewer ran the applicant's model or dataset in a tool, and the review names no
  other tool, that tool counts as the applicant's, as indirect evidence.
- Every reader is named with its model version (for example Claude Sonnet 5.5), in the records and
  in the documents.
- No public table holds a person's name. PAGE poster links, whose file names often carry an
  author's name, are no longer stored; the tables say only whether an abstract has a poster.

# PMx Software Landscape 0.2.0 (2026-10-18)

The first numbered release, used inside the project only.

- FDA reviews of the 238 CDER novel drug approvals of 2021 to 2025, with every software mention
  read.
- Published literature of 2021 to 2026 in PubMed (title and abstract) and Europe PMC (full text of
  open-access papers).
- PAGE abstracts of 2006 to 2026, with the tools each abstract used.
- Analyses of tools by analysis type, by model and data size, and over time, and the emergence of
  machine learning and AI in all four sources.
