"""Step 4. OCR every image-only page (stripped text layer shorter than 50 characters).

Usage: python scripts/04_ocr.py 2024      (resumable; skips pages already done)
Each page is rendered with pdftoppm at 150 dpi, grayscale, and read with tesseract (used: 5.3.4, --psm 3).
Output: data/<year>/ocr/<stem>_p<nnnn>.txt. Roughly 1 to 1.5 s per page on one CPU core.
"""
import os
import subprocess
import sys
import tempfile

from common import image_only_pages, load_json, year_dir

Y = int(sys.argv[1])
yd = year_dir(Y)
os.makedirs(os.path.join(yd, "ocr"), exist_ok=True)
jobs = []
for appl, recs in load_json(os.path.join(yd, "docs.json")).items():
    for r in recs:
        for pg in image_only_pages(Y, r["text_file"]):
            jobs.append((os.path.basename(r["text_file"])[:-4], pg))
print(len(jobs), "image-only pages", flush=True)
tmp = tempfile.mkdtemp()
env = dict(os.environ, OMP_THREAD_LIMIT="1")
for n, (stem, pg) in enumerate(jobs, 1):
    out = os.path.join(yd, "ocr", f"{stem}_p{pg:04d}.txt")
    if os.path.exists(out):
        continue
    png = os.path.join(tmp, "page")
    subprocess.run(["pdftoppm", "-r", "150", "-gray", "-f", str(pg), "-l", str(pg), "-singlefile", "-png",
                    os.path.join(yd, "pdf", stem + ".pdf"), png], capture_output=True)
    res = subprocess.run(["tesseract", png + ".png", "-", "--psm", "3"], capture_output=True, text=True, env=env)
    with open(out, "w", encoding="utf-8") as f:
        f.write(res.stdout)
    if n % 50 == 0:
        print(n, "/", len(jobs), flush=True)
print("done")
