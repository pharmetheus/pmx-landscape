"""Step 8. Count tables from the results CSV.

Usage: python scripts/08_summarize.py
Writes results/summary_sponsor_by_year.csv and prints the sponsor table plus FDA reviewer counts.
"""
import csv
import os
from collections import Counter, defaultdict

from common import RESULTS

rows = list(csv.DictReader(open(os.path.join(RESULTS, "fda_2021_2025_popPK_software.csv"), encoding="utf-8")))
years = sorted({r["year"] for r in rows})


def label(r):
    if r["category"].startswith("Tool stated"):
        return f'{r["sponsor_tool_family"]}, {r["evidence_strength"]}'
    return r["category"]


tab = defaultdict(Counter)
for r in rows:
    tab[r["year"]][label(r)] += 1
    tab["All"][label(r)] += 1
cols = years + ["All"]
keys = sorted({k for t in tab.values() for k in t})
with open(os.path.join(RESULTS, "summary_sponsor_by_year.csv"), "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["sponsor_category"] + cols + ["share_all"])
    for k in keys:
        w.writerow([k] + [tab[c][k] for c in cols] + [f'{100 * tab["All"][k] / len(rows):.1f}%'])
    w.writerow(["Total"] + [sum(tab[c].values()) for c in cols] + ["100%"])
print(open(os.path.join(RESULTS, "summary_sponsor_by_year.csv"), encoding="utf-8").read())
tool = [r for r in rows if r["category"].startswith("Tool stated")]
fam = Counter(r["sponsor_tool_family"] for r in tool)
print("Drugs with an identifiable sponsor tool:", len(tool), {k: f"{v} ({100 * v / len(tool):.0f}%)" for k, v in fam.items()})
print("FDA reviewer software (drugs):", dict(Counter(r["fda_tool_family"] for r in rows if r["fda_tool_family"])))
