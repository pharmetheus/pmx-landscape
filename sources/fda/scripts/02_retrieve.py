"""Step 2. Find and download the review PDFs for every drug in the frame.

Usage: python scripts/02_retrieve.py 2024        (resumable; re-run until every drug is done)

For each application:
  1. openFDA drugsfda (api.fda.gov/drug/drugsfda.json): collect the Drugs@FDA table-of-contents (TOC)
     URLs from submissions.application_docs where type == "Review", for all ORIG submissions.
  2. Fetch each TOC page and read `var pdfBaseName = "..."` from its source (the page builds its links in
     JavaScript, so plain link scraping finds nothing). The flags in `var pdfFiles` are also stored.
  3. Probe (HTTP HEAD) <base>ClinPharmR.pdf, <base>IntegratedR.pdf and <base>MultidisciplineR.pdf in the folders
     drugsatfda_docs/nda/<year>/ for: the approval year, the following year, and the TOC's own folder year.
  4. Download every PDF found to data/<year>/pdf/ and record it in data/<year>/docs.json.
Manual additions from config/doc_overrides.json are applied last (e.g. Zurzuvae, approved under Orig2;
Aduhelm, which has none of the three review types).

Requests are throttled (about 1 per second). Faster bursts made accessdata.fda.gov fail silently.
"""
import argparse
import os
import re
import time

import requests

from common import CONFIG, DOC_TYPES, UA, get, load_json, save_json, year_dir

ap = argparse.ArgumentParser()
ap.add_argument("year", type=int)
a = ap.parse_args()
Y = a.year
yd = year_dir(Y)
os.makedirs(os.path.join(yd, "pdf"), exist_ok=True)
os.makedirs(os.path.join(yd, "toc"), exist_ok=True)
S = requests.Session()
S.headers.update(UA)

frame = load_json(os.path.join(yd, "frame.json"))
docs = load_json(os.path.join(yd, "docs.json"), {})
log = load_json(os.path.join(yd, "retrieval_log.json"), {})
overrides = load_json(os.path.join(CONFIG, "doc_overrides.json"), {}).get(str(Y), {})


def download(appl, dtype, folder_year, url, idx):
    stem = f"{appl}_{dtype}_{folder_year}_{idx}"
    path = os.path.join(yd, "pdf", stem + ".pdf")
    r = get(S, url)
    if r is not None and r.status_code == 200 and r.content[:4] == b"%PDF":
        with open(path, "wb") as f:
            f.write(r.content)
        return dict(type=dtype, folder_year=str(folder_year), url=url.replace(" ", "%20"), text_file=f"txt/{stem}.txt")
    return None


for d in frame:
    appl = d["appl"]
    if appl in log:
        continue
    entry = dict(toc=[], bases=[], flags={}, notes=[])
    prefix = "BLA" if appl.startswith(("761", "125")) else "NDA"
    j = get(S, f'https://api.fda.gov/drug/drugsfda.json?search=application_number:"{prefix}{appl}"&limit=5').json()
    tocs = set()
    for res in j.get("results", []):
        for s in res.get("submissions", []):
            if s.get("submission_type") != "ORIG":
                continue
            for ad in s.get("application_docs") or []:
                if ad.get("type") == "Review" and "TOC" in ad.get("url", ""):
                    tocs.add(ad["url"])
    entry["toc"] = sorted(tocs)
    if not tocs:
        entry["notes"].append("no TOC in openFDA")
    for u in entry["toc"]:
        t = get(S, u).text
        with open(os.path.join(yd, "toc", f"{appl}.html"), "a", encoding="utf-8") as f:
            f.write(t)
        m = re.search(r'var pdfBaseName = "([^"]+)"', t)
        if m:
            entry["bases"].append(m.group(1))
        else:
            mb = re.search(r"/(\d{6}[^/]*?)TOC\.", u)
            if mb:
                entry["bases"].append(mb.group(1))
            entry["notes"].append("TOC without pdfBaseName; base taken from TOC URL")
        i = t.find("var pdfFiles")
        if i >= 0:
            entry["flags"] = {k: v for k, v in re.findall(r"(\w+):\s*([01])", t[i:t.find("END EDIT", i)]) if v == "1"}
        time.sleep(0.5)
    if not entry["bases"]:
        entry["bases"] = [f"{appl}Orig1s000"]
    years = sorted({Y, Y + 1} | {int(x) for u in entry["toc"] for x in re.findall(r"/nda/(\d{4})/", u)})
    found = []
    for base in entry["bases"]:
        for yr in years:
            for dtype, suffix in DOC_TYPES.items():
                u = f"https://www.accessdata.fda.gov/drugsatfda_docs/nda/{yr}/{base}{suffix}.pdf"
                r = get(S, u, head=True)
                if r is not None and r.status_code == 200 and "pdf" in r.headers.get("Content-Type", "").lower():
                    found.append((dtype, yr, u))
                time.sleep(0.6)
    wanted = {k for k in DOC_TYPES if entry["flags"].get(k) == "1"}
    got = {x[0] for x in found}
    if wanted - got:
        entry["notes"].append(f"TOC lists {sorted(wanted - got)} but the file was not found (broken link)")
    docs[appl] = []
    for dtype, yr, u in found:
        rec = download(appl, dtype, yr, u, len(docs[appl]))
        if rec:
            docs[appl].append(rec)
        time.sleep(1)
    for ov in overrides.get(appl, []):
        if any(x["url"] == ov["url"].replace(" ", "%20") for x in docs[appl]):
            continue
        rec = download(appl, ov["type"], ov["folder_year"], ov["url"], len(docs[appl]))
        if rec:
            docs[appl].append(rec)
            entry["notes"].append("manual override: " + ov["reason"])
    log[appl] = entry
    save_json(docs, os.path.join(yd, "docs.json"))
    save_json(log, os.path.join(yd, "retrieval_log.json"))
    print(d["no"], d["name"], appl, [(x["type"], x["folder_year"]) for x in docs[appl]], entry["notes"], flush=True)

print("Drugs without any review document:", [d["name"] for d in frame if not docs.get(d["appl"])])
