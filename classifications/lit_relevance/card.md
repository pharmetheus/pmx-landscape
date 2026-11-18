# Classification card: literature relevance

| | |
|---|---|
| **Question** | Did the authors of this paper fit a population model of their own to data, in pharmacology? |
| **Values** | `own_fit`, `not_own_fit`, `outside_field`, `unclear` (`values.csv`) |
| **Scope** | PubMed title and abstract; Europe PMC title, abstract and methods (the body when the methods section is missing or under 200 characters) |
| **Items** | Version 2: every literature paper of the corpus, whichever route found it. Version 1: the papers of the literature refinement study and the corpus papers naming no tool |
| **Reader** | `module.json` |
| **Status** | Version 2 (codebook frozen 2026-10-20 after its held-out test, `codebook.md`), development run on 2026-10-20 and 21 by Claude Code subagents; version 1 (`run.R`, pinned) is the record of the earlier readings |

The shares of the literature results count only papers read as `own_fit`
(`sources/literature/routes.R`). Version 2 merges the refinement rubric (version 1,
`rubric_v1.md`) and the rubric for the frame papers naming no tool
(`sources/literature/no_tool_rubric.md`).

## Held-out test, 2026-10-20

208 papers decided earlier, stratified by source and earlier value (seed 20261020,
`heldout_items.csv`), read by Claude Sonnet 5.5 subagents with version 2: 195 agree (93.8%, kappa 0.90;
`heldout.csv`, `heldout_disagreements.csv`), above the pass rule of 90% and 0.8. The 13
disagreements and the four hard cases they gave are in `codebook.md`. The first readers of the
test read only parts of their batch files; every batch was read again in full before the test was
scored, and since then each reader's transcript is checked to cover every line of its batch with
the Read tool.

## Development run, version 2 (2026-10-20 and 21)

| | PubMed | Europe PMC |
|---|---|---|
| Papers read | 9,319 | 7,150 |
| `own_fit` | 6,134 | 4,807 |
| `not_own_fit` | 2,399 | 1,726 |
| `outside_field` | 547 | 548 |
| `unclear` | 239 | 69 |

- **Readers.** Sonnet 5.5 subagents, 362 batches (`run_v2.R batches`); a blind 15% (2,470
  papers, seed 20261019) by Opus 5.5 subagents in 53 batches. Each answer carries the start of its
  paper's title, checked on import (`readAgentAnswers()`).
- **Check.** 2,362 of 2,470 agree (95.6%, kappa 0.91; `checks_v2.csv`). The 108 disagreements
  (`check_disagreements_v2.csv`) were settled by Opus 5.5 subagents given the text and both
  readings without saying which reader gave which (`adjudications_v2.csv`): 29 `own_fit`, 19
  `not_own_fit`, 22 `outside_field`, 38 `unclear`. Most `unclear` settlements are PubMed abstracts
  that name a population PK model without saying whether the authors fitted it.
- **Alignment.** Six answers were refused because their title start differed from the title only
  in typography (a Greek letter spelled out, a ligature, a hyphen, a diaeresis, a split word);
  each was checked by hand and kept (`adjudications_v2.csv`).
- **Rule change during the run.** The no-drug hard case was first written as `own_fit`; after the
  first 20 batches it was changed to `outside_field` (`codebook.md`). Those batches were read
  under the first wording, and the 38 papers in them whose note could rest on it were read again
  (`cache/agent_all_reread_v2`): 10 moved to `outside_field`, 1 to `unclear`. The decisions record
  the prompt as frozen; batches 1 to 20 had the first wording of that one rule.
- **Reading rules for the readers.** Some first readers skimmed their batches or wrote one note
  per value; their batches were read again. From then on every batch was accepted only when its
  transcript showed every line read with the Read tool and at least 80% of its notes were
  distinct.
- **Long items.** Two Europe PMC items are whole books of conference abstracts (480,000 and
  1.1 million characters), read in full each by a reader of its own; both contain abstracts with
  population model fits of their own, so both are `own_fit`. Batches of text are wrapped at 300
  characters; lines over 50,000 characters are first cut at a space, since `stri_wrap()` crashes
  on lines of a few hundred thousand.
- **Against the earlier readings.** 1,697 of the 1,808 corpus papers read before agree
  (`comparison_v2.csv`): 1,038 of 1,076 decided with version 1, 659 of 732 decided with the no-tool
  rubric. Most differences are earlier `own_fit` decisions that version 2 makes `not_own_fit` or
  `outside_field` under its hard cases (published models used for forecasting, machine learning
  without random effects, models with no drug).
- **Cost.** No API spend. Subagent tokens were not counted; at about 150,000 to 200,000 tokens
  per batch, the reading and check took roughly 65 to 75 million.

## API pilot (2026-10-21, production reader)

100 randomly drawn papers through the Message Batches API with the frozen codebook (amended with
the collections case) and `claude-sonnet-5-5` (`run_v2.R pilot 1`, `pilot.csv`,
`pilot_disagreements.csv`; Niclas approved about $1). The API reading gives the same value as the
development decisions for 97 of 99 papers (kappa 0.95), above the 90% the plan set. Both
differences are PubMed abstracts where the API reader counted a regression or exposure-response
model on the authors' own data as `own_fit`. One answer stopped at the 512-token output limit and
was refused; the production run needs a higher limit. Cost $0.33 of the $0.47 estimate, under the
$1 cap. Per paper: about 2,500 input tokens, 1,900 of them read from the prompt cache, and 110
output tokens; at that rate one reading of all 16,469 papers costs about $55, before the check.

## Not yet done

- Production run through the API (needs Niclas's go-ahead with its cost).
