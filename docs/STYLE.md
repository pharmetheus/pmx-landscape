# Documentation style

This guide applies to anyone who writes in this repository, whether a person or an AI agent.

## Audience

The audience is a pharmacometrician or R developer who knows the domain well but has never seen this
codebase. Assume expertise in the field and no knowledge of our internals.

## Which documents it covers

**User-facing documents** follow the whole guide:

- `README.md` (written in `README.Rmd`) and `NEWS.md`;
- `docs/overview.md`, `docs/glossary.md` and this style guide;
- commit messages;
- review pages, reports and decision requests written for the project's reviewers.

**Technical documents** may use internal names and may assume the audience has the repository open:

- the source cards (`sources/*/SOURCE.md`) and the classification cards (`classifications/*/`);
- `docs/design.md` and the usage guides in `docs/`;
- code comments and notes in data files.

The house rules apply to technical documents too.

## Structure

- Headers are declarative labels ("Estimating covariate effects"), never questions. Indirect
  questions count too: "What is asked", "How it is answered", "Where the answers come from".
- A header names its subject, so it means something before the section is read. In a results
  report, each header states the finding of its section: "Most methods give a conditional answer",
  not "How it is answered". A header is never a bridge from the section before ("Compared with
  the earlier runs", "Three explanations tested").
- Each section must make sense on its own. Do not refer to the header, to "this section", or to
  earlier or later sentences ("as noted above", "more on this below"). Restate what is needed instead,
  or link the term to the glossary.
- Each item in a list stands on its own, so the items could be put in any order. An item does
  not point back to another with "such", "these", "this", "the same", "also" or "too": write
  "Every one of the 211 drugs has at least one dose question with no matching method", not "Every
  one of the 211 drugs has at least one such question".
- Lead with what something does and why a user would care, then how to use it, then details.
- No label that hides a question, such as "**What it covers.**" or "**The options.**", followed by
  text that answers it. The label has no question mark, so the reader is answered before anything
  was asked. Either ask the question in full, with its question mark, or let the next sentence
  name its subject ("The licence would cover the tables that record ..."). Labels that name a fixed part
  of a section, such as "**In short.**" or "**Methods.**", are fine.
- A report leads with its conclusion, or with the question it asks.
- Source cards and classification cards keep their fixed headings.
- When several terms are defined together, use a definition list: one bullet per term, the term in
  bold with a colon, then a one-sentence definition ("**Term route:** the paper uses the field's
  names for the method."). A single term is defined in the sentence that first uses it.

## Readability

- One idea per sentence. Split a sentence that needs a bracket inside a bracket.
- Do not open a sentence with "Its" plus a noun that points back to the previous sentence ("Its
  first measure is which software is used"). Name the subject again and use a verb: "It first
  measures which software is used", or "NONMEM was used in 81% of the abstracts from 2016".
- Use a possessive form ("the applicant's", "the guidelines'", "the model's") only when no plain
  phrase will do. Write "dose questions from applicants", "methods in the guidelines" and "the
  coefficients of the model" instead. A run of possessives makes every sentence about who owns
  what.
- Use "a", not "the", for a kind of answer, effect or estimate that has not been identified: "the
  method gives a conditional answer", not "the conditional answer". "The" suggests that one fixed
  answer exists to be found.
- At most two numbers in a sentence. Round them in prose and give exact values in tables. Write
  "the two readers agree on 763 of 781 decisions", not "763/781, kappa 0.91, alpha 0.91".
- No abbreviations or version shorthand without a definition: write "version 5 of the tool
  codebook", not "v5", and "Europe PMC", not "EPMC".
- One name per concept, the one in the glossary, every time. Do not call the same reader
  "the reader", "the subagent" and "the agent" in turn.

## Language

- Describe behaviour in domain terms, not implementation terms.
- Do not use internal names (classes, helper functions, internal data structures, pipeline stage
  names) unless the audience must type them. If one is necessary, define it in one plain sentence on
  first use.
- Repository paths given as cross-references are allowed and need no definition, for example
  "the method is described in `classifications/README.md`".
- No rhetorical questions, no "Here's the thing", no "Let's dive in", no em-dashes.
- Prefer a short concrete example over an abstract description.

## Decision requests

Each decision stands on its own and has five parts:

1. the question, in one sentence;
2. what it is about, in two or three sentences;
3. the options, and what each would change;
4. the recommendation, and why;
5. what happens after the decision.

A report that asks for decisions puts them at the top.

## Commit messages

- The subject line says what changed, in plain words.
- The body says why, and what someone using the results would notice.
- Counts, file lists and agreement statistics belong in the cards, not in the message.

## House rules (all documents)

- No em-dashes.
- A fact not verified in a source is written as "not stated", never as a guess.
- Counts come with their denominator ("763 of 781").
- Dates are absolute ("2026-10-19", not "last week").
- Results of a development run are labelled as such until the production run replaces them.
- A reader, meaning whatever gives a value to a candidate, is named by what it is: a rule, a named
  language model, or a person.

## Before finishing

List every term a newcomer would not know, and either define it, link it to the glossary, or
remove it. List the user-facing documents you produced, so that they can be given to a cold reader
(a reviewer who has not seen the project).
