# Reading rubric: AI and machine learning terms

Each row of the review file is one item (a PAGE abstract, a PubMed paper, a
Europe PMC paper or an FDA review) and one term found in it, with up to three
snippets around the matches and the item's title. Decide what the term means
**in this item**, from the snippets and the title. Open the item at its URL
only when the snippets do not decide it.

## Decisions

- **used**: the authors apply, develop, train, evaluate or compare the method
  in the work the item reports. A neural network fitted to the data, a random
  forest used for covariate selection, an LLM used to write model code, an
  "AI-based" tool the authors built or ran. A comparison counts as used when
  the method is one of the arms the authors ran.
- **mentioned**: the method is named but not applied in the reported work:
  background ("machine learning is increasingly used"), a citation of others'
  work, a proposal or future work, a review or tutorial that describes the
  method without results of its own, a session or meeting title.
- **not**: the words do not mean the method. Examples: "AI" for aromatase
  inhibitor, adequate intake, accumulation index, apnoea index, artificial
  insemination, an author's initials or a gene name; a biological neural
  network or neural circuit; "expert system" meaning a panel of human experts;
  "GPT" in a lab panel; "kNN" or "nearest neighbour" used for a non-learning
  imputation step only when the text makes clear it is not a learning method
  (when in doubt, decide used or mentioned).

A statement about the writing of the item itself ("no generative AI was used in
preparing this manuscript", "ChatGPT was used for language editing") is
**not**: it is not part of the reported work.

The AI label counts as **used** only when the authors call their own method or
tool AI ("an AI-based dosing tool we developed"). Naming AI as the field their
machine learning belongs to ("ML is a subfield of artificial intelligence"), as
background or as a motivation, is **mentioned**, even when the paper uses ML.

A term that occurs only in a reference list entry, a journal or book title, a
funding body's or programme's name, or an affiliation is **not**.

A review article counts as **mentioned**, even when it discusses the method at
length, unless it reports an analysis of its own with the method.

An FDA review is **used** only when the sponsor's or the FDA's analysis in the
submission applied the method; say which in the note.

## Note

One line in your own words (no quotation from the item): what the method is
and what it was for, or why it is not the method. For example: "neural network
predicting tacrolimus trough concentrations, compared with a popPK model" or
"AI is aromatase inhibitor".

## Output

One line per row: `source,id,term,decision,note`, in the row order given.
