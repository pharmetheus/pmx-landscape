# Classification card: tool use

| | |
|---|---|
| **Question** | For each estimation tool an item names, did the authors use it for their own analysis, use it only as a comparator, or only mention it? |
| **Values** | `used`, `comparator`, `mentioned` (`values.csv`) |
| **Scope** | Version 2: PAGE title and body; PubMed title and abstract; Europe PMC title, abstract and methods (the whole body for papers without a methods section of at least 200 characters). Version 1 (the pilot): PAGE only |
| **Candidates** | The estimation families of the shared taxonomy (`taxonomy/patterns.json`) |
| **Rules** | Three rules give `used` (`rules.csv`): the tool named with its version, the analysis said to be done in or with it, or the tool said to be used; only in a sentence that compares nothing, in an item naming no other estimation tool and comparing no tools or methods |
| **Reader** | `module.json` |
| **Status** | Version 5 (codebook approved and frozen 2026-10-20, `codebook.md`), development run on the closed corpus on 2026-10-19 and 20 by Claude Code subagents (`runs.csv`); version 4 (2026-10-18, Message Batches API) is what the published README numbers were built from |

The values and rubric carry over the tool-role part of the PAGE role rubric; its analysis
types belong to other classifications.

## Pilot, 2026-10-18

A random 100 of the PAGE abstracts the role reading decided (outside the Software
Demonstration session, tools found in the abstract itself), 106 tools, read through the
Message Batches API with module version 1 (`pilot.R`; results in `pilot/`):

| Reader | Same value as the old reading | Kappa | Problems | Cost |
|---|---|---|---|---|
| `claude-haiku-5-5` | 104 of 106 | 0.83 | 0 | $0.009 |
| `claude-sonnet-5-5` | 105 of 106 | 0.91 | 0 | $0.18 |

The two models agree with each other on 105 of 106. In the one tool where both differ from
the old reading (abstract 9771, Pumas: old `mentioned`, both now `used`), the new readings
follow the rubric's rule that the platform a new tool runs in is `used`. Claude Haiku 5.5's other
difference (2907, NONMEM as `comparator` where NONMEM ran the reference methods) is a
borderline case. Most tools are `used` (99 of 106), so the kappa says more than the share.
The system prompt was cached: of 219,000 input tokens, 88,000 were cache reads, and the
cost was about half the estimate.

## Rules, 2026-10-18

Developed on the PAGE role reading and tested, unchanged, on the Europe PMC model-size
reading (papers with a fit of their own and a recorded tool), which played no part in
developing them (`rules_check.R`, `rules_check.csv`):

| Source | Candidates in the reference | Decided by a rule | Same as the earlier reading |
|---|---|---|---|
| PAGE (in-sample) | 3,365 | 1,470 (44%) | 1,469 (99.93%) |
| Europe PMC (out of sample) | 1,784 | 924 (52%) | 919 (99.46%) |

All five Europe PMC differences are errors of the earlier reading, which recorded the tool
as "not stated" where the methods say it was used (checked by reading the sentences). The
one PAGE difference (abstract 1661) is a rule error: a methodology abstract whose
comparison with NONMEM is stated in another sentence. Over all candidates of the three
sources the rules decide 3,072 of 7,205 (43%), which are not read. The rules were made
stricter where the development data showed errors: no decision where the item names a
second estimation tool, where the sentence compares, lists or calls the tool an
implementation of an algorithm, or where the item compares tools or methods anywhere; a
digit inside a name (nlmixr2) is not a version.

## Full runs, 2026-10-18

Over the three sources, 15,196 items in scope, 7,205 candidates (an item and an estimation
family it names); the rules decide 3,072, Sonnet 5.5 reads the other 4,133 in 3,631 requests,
and Opus 5.5 reads a blind 15% of them (545 items, seed 20261018). Every run is in
`runs.csv`.

| Version | What changed | Check: same value | Kappa | Cost |
|---|---|---|---|---|
| 2 | all three sources, the rules | 599 of 612 | 0.90 | $13.62 |
| 3 | Niclas's two clarifications (rubric.md): a tool run only for reference results is a comparator; software built around a tool counts as used | 598 of 613 | 0.89 | $13.63 |
| 4 | each candidate shown with the names the text uses for its family (S-ADAPT named as ADAPT 5, Stan/Torsten as Stan, BUGS as WinBUGS); the 342 changed requests read again, the other 3,289 identical requests keep their version 3 answers | 602 of 613 | 0.91 | $1.71 |

The 11 disagreements of version 4 were decided after reading the text (`adjudications.csv`,
with those of version 3 that still apply): mostly reference runs (comparator), software built
around a tool (used), and a tool named only in a list (mentioned). No reading problems remain.
43 notes that repeated eight or more words of their item were withheld.

Against the earlier PAGE role reading, 3,284 of the 3,365 pairs both read have the same value
(97.6%, kappa 0.80; `old_comparison.csv`). For the published PAGE series (2016 to 2026,
outside the Software Demonstration session) the abstracts using any estimation tool go from
1,886 to 1,899; NONMEM 1,390 to 1,383, Monolix 363 to 364, and the families added from the
discovery round enter: nlme 14, IMPRES-M 7 (`page_change.csv`). PubMed reads title and
abstract only, so a paper naming its tool only among the keywords shows no use.

## Development run, version 5 (2026-10-19 and 20)

The closed corpus (literature 2016 to 2026 with the extension, `corpus/README.md`): 20,828
items in scope, 9,121 candidates; the rules decide 3,969 (43.5%), Claude Sonnet 5.5 subagents read the
other 5,152 in 4,558 items (115 batches), Claude Opus 5.5 subagents a blind 15% (684 items, 781
candidates). All answers carry the start of their item's title and were checked against it
(`readAgentAnswers()`); none was refused. The check agrees on 763 of 781 (kappa 0.91, alpha
0.91); the 18 disagreements were settled by Claude after reading the text (`adjudications.csv`,
run `adjudication-v5`), by the rubric's cases: tools a general exchange format only connects to
are `mentioned`, reference runs and published benchmark results are `comparator`, software built
around a tool is `used`. One reader copied a candidate with its display hint; the parser now
accepts that form (test in `test-classify.R`). Two readers used Bash once each to search or
count lines of their batch, against their instructions; their answers are their own and kept.
No API spend; about 24 million subagent tokens for the reading and check.

Standard tables (`report.R`):

| Source | Candidates | By rule | By reading | By adjudication | Used |
|---|---|---|---|---|---|
| PAGE | 4,004 | 1,612 (40%) | 2,368 | 24 | 3,693 |
| PubMed | 1,603 | 741 (46%) | 861 | 1 | 1,561 |
| Europe PMC | 3,514 | 1,616 (46%) | 1,889 | 9 | 3,153 |

Bounds from rules alone (`report_bounds.csv`), items using the tool: Europe PMC NONMEM 1,285 (rules,
the rest not used) to 2,414 (the rest used), with reading 2,258; PAGE NONMEM 1,393 to 2,978, with
reading 2,804; Monolix in Europe PMC 145 to 453, with reading 386. The rules alone leave the
published counts wide open; the reading decides most of them, so its reliability is what the
numbers rest on.

Against version 4 (`report_versions.csv`, the candidates both versions have): PAGE 3,939 of 4,004
the same value, PubMed 860 of 862, Europe PMC 2,326 of 2,339; tools used 3,699 to 3,693 (PAGE),
838 to 837 (PubMed), 2,075 to 2,068 (Europe PMC). The development run changes the published
using series by under 1%.

Unlisted tools (`other_tools.csv`, `report_other_tools.csv`): 165 of the 4,558 read items name
an estimation tool outside their candidates (119 distinct names). Several are forms of taxonomy
families the patterns do not catch (Phoenix alone, ADAPT alone, BUGS, NLMIXED, nlme, Stan), a
pattern gap to look at; others are tools outside the taxonomy (lme4, NIMBLE, MCSim, SPK, NPML,
IT2B, JM, ITSIM) or auxiliary TDM software (MwPharm, mapbayr, Tucuxi). Items decided by rules
alone are not read, so this is a lower bound.

## Taxonomy change and increment (2026-10-20, development)

The codebook was approved and frozen on 2026-10-20. The same day the patterns of seven estimation
families were widened (`taxonomy/software.csv`, tested on the corpus) and six auxiliary or NCA
families added. The taxonomy change gave 72 candidates without an answer, in 62 items: 68 new
candidates of the widened families, and 2 NONMEM and 2 Monolix candidates that the rules no longer
settle, because their items now name a second tool (`run.R increment`). Claude Sonnet 5.5 subagents read
them, and Claude Opus 5.5 subagents read 9 items blind; 9 of 10 decisions agree. The one disagreement (a
tool-independent exchange format, BUGS) was settled by Claude as `mentioned`. The first import
refused 27 answers whose title start had been cut in the middle of a word; the alignment check now
accepts a cut last word when the words before it agree (`titleMatches()`, test in
`test-classify.R`). Candidates now 9,196; the rules decide 3,974 (43.2%).

## API pilot (2026-10-20, production reader)

100 randomly drawn read items through the Message Batches API with the frozen codebook and
`claude-sonnet-5-5` (`run.R pilot 2`, `pilot.csv`, `pilot_disagreements.csv`). The API reading
agrees with the development tags on 111 of 112 decisions (kappa 0.96); the one difference is a
BUGS candidate the development reading had as `used` and the API as `comparator`. Four answers
added a decision with an empty label besides the valid ones, refused as problems. Cost $0.32 of
the $0.39 estimate, under the $2 cap Niclas approved. Per request: about 4,000 input tokens, 1,500 of them read from the
prompt cache, and 95 output tokens; this is the measure for costing the production run.

## Tool route increment (2026-10-21, development)

The tool route added 2,541 literature papers to the corpus (`corpus/README.md`). Their tools
were read with the frozen codebook as an increment of its own (`run.R increment toolroute`, run
`agents-read-v5-increment-toolroute`): 1,359 candidates without an answer, in 1,253 items, read by
Claude Sonnet 5.5 subagents (63 batches), and a blind 15% (188 items, 203 candidates) by Claude Opus 5.5 subagents.
Every reader was checked to have read its whole batch with the Read tool and to give a note per
candidate. The check agrees on 194 of 203. The 9 disagreements were settled by a Claude Opus 5.5 subagent
given the text and both readings: 8 Monolix candidates are `mentioned`, since the software run
was a MonolixSuite product of another family (PKanalix for non-compartmental analysis, Simulx or
mlxR for simulation), and 1 NONMEM candidate in a trial protocol is `mentioned`. One answer
refused because its title start differed from the title only in a ligature was kept after a
check by hand. All candidates now 11,463; the rules decide 4,882 (42.6%). Over every run of
version 5 the check agrees on 966 of 994 (kappa 0.89). No existing decision changed.

## Taxonomy change, round 3 (2026-10-21, development)

After the third discovery round Niclas approved wider patterns for Monolix (releases written
joined, such as MonolixR2019b, and MonolixTM) and nlmixr (the nlmixr2est package). Candidates went
from 11,463 to 11,469 and rule decisions from 4,882 to 4,887; the 4 candidates left without an
answer (3 Monolix, 1 NONMEM) were read as an increment of their own (`run.R increment patterns3`):
all `used`, and the blind check of 1 agrees. The four new families
of the round (FME, MicLab, ubiquity, PKSolver) are auxiliary or NCA tools, outside this
classification's candidates.
