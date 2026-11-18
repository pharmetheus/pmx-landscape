# Classifications

The second layer of the design (`docs/design.md`). A classification tags corpus items
with one kind of property: the software tools an item used, its estimation algorithm,
its analysis method, and so on. Every classification follows the same protocol, with the
same steps, the same files and the same decision record, so the method is described once,
here; a classification's own card says only what differs: its question, values, rubric,
scope, patterns and rules.

## The protocol

The method is content analysis with a codebook: a codebook is developed and frozen
(step 0), then applied the same way to every item (steps 1 to 5).

0. **Codebook** (development). The codebook is the values with their definitions
   (`values.csv`), the rubric for the cases they leave open (`rubric.md`), the rules
   (`rules.csv`), the scope and candidates (`module.json`) and the prompt it fills. It is
   drafted from the question, tried on development items (a pilot, then blind double
   readings), and revised until the disagreements show no new kinds of case; rules are
   written from the cases the readers agree on. Its reliability is then measured on
   held-out items: items that played no part in the development (they may have been read
   before, but did not inform a change), listed in `dev_items.csv` for the items that did.
   Niclas approves the codebook, and it is frozen with a version number; a later change
   gives a new version and a new reading of what it changes.
1. **Scope** (rule). Which sources, and which sections of their items, the classification
   reads (`module.json`, `scope`). Each classification reads only the sections its
   question needs, and its card says which: title, abstract and methods for what the
   authors did, with the whole body where a paper has no methods section the parser
   finds; more where results or tables are needed. Reference lists are never read.
2. **Candidates** (rule). Patterns find candidate labels in the text, for example each
   tool family named. A classification asked of every item as a whole has the item as its
   candidate.
3. **Rule decisions** (rule). Where a rule settles a candidate (`rules.csv`: a label, a
   context pattern and the value it gives), it decides it. Steps 1 to 3 are exact: the
   same corpus and the same files give the same result.
4. **Reading** (AI). The candidates no rule settles are read. Every classification uses the
   same prompt skeleton (`pmxlandscape/inst/prompts/reading.md`), filled with its
   question, values and rubric, and the same output schema: one decision per candidate,
   with a label, one of the values and a short note in the reader's own words. The reader
   (model and parameters) is set in `module.json`.
5. **Check**. A blind second reading of a random share of the items by another model
   (`module.json`, `check`), disagreements decided and recorded, and Niclas's decisions
   last.

## Files of a classification

`classifications/<name>/`:

| File | Content |
|---|---|
| `module.json` | name, version, question, scope, candidates, text mode, reader, check |
| `values.csv` | the values and their definitions |
| `rubric.md` | how to decide the cases the definitions leave open |
| `rules.csv` | deterministic decisions (optional) |
| `dev_items.csv` | the items that informed the codebook's development (step 0) |
| `card.md` | what the classification measures and how well (agreement, recall) |
| `decisions.csv` | every decision, in the columns below |
| `checks.csv` | the agreement of each check |
| `tags.csv` | one decision per item and label: the published tags |

## The decision record

| Column | Content |
|---|---|
| `source`, `item_id` | the corpus item |
| `label`, `value` | the candidate and the decision |
| `method` | `rule`, `ai`, `adjudication` or `human` |
| `reader` | `rules.csv:<id>`; the model ID the API reports; `Claude Code subagent (<model>)`; or the person |
| `prompt`, `prompt_hash` | the prompt (skeleton and module version) and a hash of everything the reading depends on except the item: prompt, schema, reader settings, text mode |
| `run` | the batch ID or run name |
| `date` | when it was decided |
| `input_hash` | the corpus item hash of the text that was read |
| `note` | the reason, in the reader's own words, never a quotation; a note that repeats eight or more words of the item's text is withheld before it is written (`withholdQuotes()`) |

The tags keep, per item and label, a human decision if there is one, else an
adjudication, else the latest reading or rule (`moduleTags()`).

## Readers

The method of record is the Anthropic Message Batches API (`readWithApi()`): the exact
prompt is sent with a pinned model ID, and the raw responses are kept with the run. Before
anything is sent, the cost is estimated from token counts of a sample of requests, and the
run stops if the estimate exceeds the cap it is given; every live run needs Niclas's
go-ahead. Claude Code subagents read the same rendered requests
(`writeAgentBatches()`, `readAgentAnswers()`), recorded as such; each answer repeats the
start of its item's title, and answers that do not match their item are refused.

Readers by phase:

- **Development** (codebook development and development runs): subagents, and checks by
  Claude or by subagents, labelled as such. Numbers from a development run may change.
- **Freeze**: a small API pilot (about 100 items) with the frozen codebook, to see whether
  the production reader agrees with the development readings and to measure tokens.
- **Production**: the Message Batches API, with the corpus snapshot, the codebook and
  taxonomy versions, the model IDs and the run dates locked; human answer checks (a sample
  of about 30 to 40 answers per classification, and a review of Claude's settlements); tied
  to a release tag.

## What is reproducible

- Tags from decisions, and every number from the tags: exactly.
- Rule decisions from the corpus: exactly.
- Readings from the corpus: documented, not exact. The prompt, the model ID, the settings
  and the text read are recorded, and anyone with an API key can repeat a run; a model
  may answer differently on a rerun, and models are retired. The blind checks show how
  much readings vary between readers.

The rendered requests and raw responses contain source text and stay in the local cache
(`classifications/<name>/cache/`, not committed).
