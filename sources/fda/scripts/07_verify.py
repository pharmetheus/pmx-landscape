"""Step 7. Check the recorded results against a fresh search.

Usage: python scripts/07_verify.py
Run 05_search.py all first. For every drug, compares the software found by the patterns with what
results/fda_2021_2025_popPK_software.csv records (sponsor tool, FDA reviewer tool, auxiliary tools, PBPK/NCA).
Hits that are recorded, or listed with a reason in config/known_exceptions.json, count as explained.
Anything printed as UNEXPLAINED needs reading (06_context.py) and then either a correction of the CSV or a
new entry in known_exceptions.json. With the shipped data, the expected output is zero unexplained hits.
"""
import csv
import os
from collections import defaultdict

from common import CONFIG, RESULTS, load_json, year_dir

FAMILY = {"NONMEM (name expanded)": "NONMEM", "Stan/Torsten": "Stan", "S-ADAPT/ADAPT": "S-ADAPT",
          "WinBUGS/NONMEM-BUGS": "BUGS"}
AUXNAME = {"SimBiology/MATLAB": "MATLAB"}
PBPK = {"Simcyp", "GastroPlus", "PK-Sim"}
rows = list(csv.DictReader(open(os.path.join(RESULTS, "fda_2021_2025_popPK_software.csv"), encoding="utf-8")))
exc = {(str(e["year"]), e["application"], e["software"]) for e in load_json(os.path.join(CONFIG, "known_exceptions.json"))["exceptions"]}
n_bad = 0
for year in sorted({r["year"] for r in rows}):
    hits = load_json(os.path.join(year_dir(year), "hits.json"))
    found = defaultdict(lambda: defaultdict(set))
    for h in hits:
        if h["group"] in ("estimation", "auxiliary", "pbpk"):
            found[h["appl"]][FAMILY.get(h["sw"], AUXNAME.get(h["sw"], h["sw"]))].add(h["page"])
    for r in rows:
        if r["year"] != year:
            continue
        recorded = " ".join([r["sponsor_popPK_software"], r["sponsor_auxiliary_tools"], r["fda_reviewer_software"], r["pbpk_nca"], r["notes"]]).lower()
        for sw, pages in found.get(r["application"], {}).items():
            key = sw.split()[0].lower()
            if key in recorded or (year, r["application"], sw) in exc:
                continue
            n_bad += 1
            print(f"UNEXPLAINED {year} {r['drug']} ({r['application']}): {sw} on pages {sorted(pages)[:8]}")
print(f"{n_bad} unexplained software mentions")
