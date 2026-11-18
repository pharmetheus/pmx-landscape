"""Step 6 (manual review aid). Show the text around a hit and the nearest attribution labels before it.

Usage: python scripts/06_context.py 2024 216158 265 NONMEM [--before 900]
Prints the text preceding and following the first match of TERM on that page, and the last labels found in
the two previous pages plus this page up to the hit (Applicant's ..., Reviewer's ..., FDA's ..., Source: ...).
Use it to decide who ran the software. The automatic labels are hints only: FDA review appendices often
reproduce Applicant text under FDA headings, so always read the snippet.
"""
import argparse
import os
import re

from common import load_json, text_pages, year_dir

ap = argparse.ArgumentParser()
ap.add_argument("year", type=int)
ap.add_argument("appl")
ap.add_argument("page", type=int)
ap.add_argument("term")
ap.add_argument("--before", type=int, default=900)
a = ap.parse_args()
recs = load_json(os.path.join(year_dir(a.year), "docs.json"))[a.appl]
LAB = re.compile(r"(?:Applicant[’']?s?|Reviewer[’']?s?|FDA[’']?s?|Sponsor[’']?s?|[Oo]ur analysis|review team|Source:)[^.]{0,70}")
for r in recs:
    pages = text_pages(a.year, r["text_file"])
    if a.page > len(pages):
        continue
    t = lambda n: re.sub(r"\s+", " ", pages[n - 1][1]) if 0 < n <= len(pages) else ""
    cur = t(a.page)
    m = re.search(a.term, cur)
    if not m:
        continue
    i = m.start()
    print(f"== {r['text_file']} p{a.page} ({pages[a.page - 1][2]})")
    print(cur[max(0, i - a.before):i + 300])
    prior = " ".join([t(a.page - 2), t(a.page - 1), cur[:i]])
    print("-- labels before hit:", " | ".join(x[:90] for x in LAB.findall(prior)[-5:]))
