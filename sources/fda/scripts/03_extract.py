"""Step 3. Extract the text layer of every downloaded PDF, page by page (pages separated by form feeds).

Usage: python scripts/03_extract.py 2024
Requires poppler's pdftotext (used: 24.02.0).
"""
import os
import subprocess
import sys

from common import load_json, year_dir

Y = int(sys.argv[1])
yd = year_dir(Y)
os.makedirs(os.path.join(yd, "txt"), exist_ok=True)
for appl, recs in load_json(os.path.join(yd, "docs.json")).items():
    for r in recs:
        stem = os.path.basename(r["text_file"])[:-4]
        pdf = os.path.join(yd, "pdf", stem + ".pdf")
        out = os.path.join(yd, r["text_file"])
        if not os.path.exists(out):
            subprocess.run(["pdftotext", "-q", pdf, out], check=False)
print("done")
