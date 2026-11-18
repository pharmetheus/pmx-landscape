# FDA cross-check: the sponsor's own publications

Many FDA reviews describe a popPK analysis without naming the software (63
of 238 drugs, 2021 to 2025). This cross-check looks for the sponsor's own
popPK papers on each drug and records which estimation software they name.
Where a sponsor paper published close to the submission names one tool, that
tool is a **likely**, not a verified, indication of the software in the
submission. The results are a separate evidence tier: they never change
`../results/fda_2021_2025_popPK_software.csv`, where unverified stays "not
stated".

## Method (`crosscheck_literature.R`)

1. **Names.** For each drug: the brand name, each active ingredient without
   its biologic suffix or salt ("lecanemab-irmb" becomes "lecanemab"), and
   development codes from PubChem's synonyms ("AMG 510"); biologics mostly
   have no PubChem entry.
2. **Sponsor.** The sponsor name from openFDA, shortened for affiliation
   searches (`sponsorToken()`), with hand-made corrections and their reasons
   in `sponsor_overrides.csv`.
3. **Papers.** Europe PMC: one of the names in the title, and popPK wording
   ("population pharmacokinetic(s)", "population PK", popPK, pharmacometric*,
   "exposure-response", "model-informed", "model-based") in the title or the
   abstract.
4. **Tools per paper.** For open-access papers, the estimation tools named in
   the methods sections of the full text (JATS XML, reference list excluded),
   else in the body; for the rest, in the abstract. A paper is a **sponsor
   paper** if any author's affiliation names the sponsor.
5. **Per drug**, in order of strength:
   - *sponsor paper near submission*: the sponsor's papers published from 4
     years before to 2 years after approval name a single tool;
   - *sponsor paper, other years*: only sponsor papers outside that window
     name a tool, and a single one;
   - *sponsor papers name several tools*: no single answer;
   - *other authors only*: only papers without a sponsor author name a tool
     (not used as an indication);
   - *none*.

## Validation

The same procedure applied to the drugs whose tool the FDA review states
gives the error rate of each tier (`results/run_info.txt`). In the September
2026 run: *sponsor paper near submission* agreed with the FDA review for 47 of
48 drugs; *sponsor paper, other years* for 1 of 2. The disagreements were a
sponsor that published Monolix work two years before approving with NONMEM
(Epkinly), and an older formulation's papers (Keytruda Qlex).

## Limits

- Only open-access full text shows the methods; for other papers only the
  abstract is searched, which rarely names software.
- A sponsor paper may describe a different analysis than the one submitted
  (another indication, formulation or population).
- Sponsor matching uses the sponsor's name in affiliations; licensors,
  partners and CROs that ran the analysis are not matched.
- Development codes come only from PubChem.

## Files

- `results/crosscheck_drugs.csv`: one row per drug: names searched, sponsor,
  papers found, tools per tier, the likely tool and its evidence tier, and the
  IDs of the sponsor papers naming a tool.
- `results/crosscheck_papers.csv`: one row per paper: IDs, publication year,
  open access, sponsor author, tools and where they were found. No paper text.
- `results/run_info.txt`: run date, validation, counts.
- `sponsor_overrides.csv`: the only hand-made input.
