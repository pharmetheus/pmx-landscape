"""Step 1. Build the frame: CDER novel approvals for one year and their application numbers.

Usage: python scripts/01_frame.py 2024 [--out frame_new.json]

Source: https://www.fda.gov/drugs/novel-drug-approvals-fda/novel-drug-approvals-<year>
Application number, in order of preference:
  1. the 6-digit number in the label link (.../drugsatfda_docs/label/<yyyy>/<appl>...),
  2. ApplNo=<appl> in a Drugs@FDA link on the same row,
  3. a manual entry in config/frame_overrides.json (used for 4 drugs in 2025, found by openFDA generic-name lookup).
Rows still without a number are reported so you can add them to the overrides file.
"""
import argparse
import os
import re

import requests
from bs4 import BeautifulSoup

from common import CONFIG, UA, load_json, save_json, year_dir

ap = argparse.ArgumentParser()
ap.add_argument("year", type=int)
ap.add_argument("--out", default="frame.json")
a = ap.parse_args()

url = f"https://www.fda.gov/drugs/novel-drug-approvals-fda/novel-drug-approvals-{a.year}"
html = requests.get(url, headers=UA, timeout=60).text
yd = year_dir(a.year)
with open(os.path.join(yd, "novel_approvals_page.html"), "w", encoding="utf-8") as f:
    f.write(html)

overrides = load_json(os.path.join(CONFIG, "frame_overrides.json"), {}).get(str(a.year), {})
rows = []
for tr in BeautifulSoup(html, "html.parser").find("table").find_all("tr")[1:]:
    c = [td.get_text(" ", strip=True) for td in tr.find_all("td")]
    if len(c) < 4:
        continue
    hrefs = [x.get("href") or "" for x in tr.find_all("a")]
    appl, src = None, None
    for h in hrefs:
        m = re.search(r"/label/\d{4}/(\d{6})", h)
        if m:
            appl, src = m.group(1), h
            break
    if not appl:
        for h in hrefs:
            m = re.search(r"ApplNo=(\d{6})", h, re.I)
            if m:
                appl, src = m.group(1), "Drugs@FDA link"
                break
    if not appl and c[1] in overrides:
        appl, src = overrides[c[1]]["appl"], overrides[c[1]]["source"]
    rows.append(dict(no=int(re.sub(r"\D", "", c[0]) or 0), name=c[1], ingr=c[2], date=c[3], label=src, appl=appl))

rows.sort(key=lambda d: d["no"])
save_json(rows, os.path.join(yd, a.out))
print(f"{a.year}: {len(rows)} drugs written to data/{a.year}/{a.out}")
missing = [r["name"] for r in rows if not r["appl"]]
if missing:
    print("No application number for:", missing, "-> add them to config/frame_overrides.json")
