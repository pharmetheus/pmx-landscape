"""Step 5. Regex search of every page (text layer, or OCR text for image-only pages).

Usage: python scripts/05_search.py 2024      or      python scripts/05_search.py all
Patterns: config/patterns.json. Output: data/<year>/hits.json, one record per match with a 440-character
snippet. The page number is the PDF page index (1-based), not the printed page number.
The script only finds mentions. Deciding who used the software (Applicant or FDA reviewer) and whether a
mention is real use, a citation or OCR noise is done by reading the snippets (see docs/METHODS.md).
"""
import os
import re
import sys
from collections import Counter

from common import load_json, load_patterns, save_json, text_pages, year_dir, years_arg

PAT = load_patterns()
for Y in years_arg(sys.argv[1]):
    yd = year_dir(Y)
    hits = []
    for appl, recs in load_json(os.path.join(yd, "docs.json")).items():
        for r in recs:
            for pg, txt, src in text_pages(Y, r["text_file"]):
                for name, (group, rx) in PAT.items():
                    for m in rx.finditer(txt):
                        s, e = max(0, m.start() - 220), min(len(txt), m.end() + 220)
                        hits.append(dict(appl=appl, doc=os.path.basename(r["text_file"])[:-4], page=pg, src=src,
                                         sw=name, group=group, snip=re.sub(r"\s+", " ", txt[s:e])))
    save_json(hits, os.path.join(yd, "hits.json"))
    c = Counter(h["sw"] for h in hits if h["group"] in ("estimation", "auxiliary", "pbpk", "nca"))
    print(Y, len(hits), "hits;", dict(c.most_common()))
