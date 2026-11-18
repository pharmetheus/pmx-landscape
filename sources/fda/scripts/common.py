"""Shared helpers. All paths are relative to the package root (the folder that contains scripts/)."""
import json
import os
import re
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")
CONFIG = os.path.join(ROOT, "config")
RESULTS = os.path.join(ROOT, "results")

UA = {"User-Agent": "Mozilla/5.0 (research script; FDA review software survey)"}
DOC_TYPES = {"clinPharmR": "ClinPharmR", "integratedR": "IntegratedR", "multidisciplineR": "MultidisciplineR"}
EMPTY_PAGE_CHARS = 50  # a page whose stripped text is shorter than this is treated as image-only


def year_dir(year):
    d = os.path.join(DATA, str(year))
    os.makedirs(d, exist_ok=True)
    return d


def load_json(path, default=None):
    if not os.path.exists(path):
        return default
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def save_json(obj, path):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f, indent=1, ensure_ascii=False)


def load_patterns():
    cfg = load_json(os.path.join(CONFIG, "patterns.json"))
    return {k: (v["group"], re.compile(v["regex"])) for k, v in cfg["patterns"].items()}


def text_pages(year, text_file):
    """Return the pages of one document, with OCR text substituted where an OCR file exists.

    text_file is relative to data/<year>/, e.g. 'txt/217424_multidisciplineR_2024.txt'.
    OCR output for page n (1-based) lives in data/<year>/ocr/<stem>_p<nnnn>.txt.
    Returns a list of (page_number, text, source) tuples with source 'text' or 'ocr'.
    """
    yd = year_dir(year)
    stem = os.path.basename(text_file)[:-4]
    with open(os.path.join(yd, text_file), encoding="utf-8", errors="ignore") as f:
        pages = f.read().split("\f")
    out = []
    for i, p in enumerate(pages):
        n = i + 1
        ocr = os.path.join(yd, "ocr", f"{stem}_p{n:04d}.txt")
        if os.path.exists(ocr):
            with open(ocr, encoding="utf-8", errors="ignore") as g:
                out.append((n, g.read(), "ocr"))
        else:
            out.append((n, p, "text"))
    return out


def image_only_pages(year, text_file):
    """Pages (1-based) whose text layer is empty or nearly empty. The trailing form feed page is ignored."""
    yd = year_dir(year)
    with open(os.path.join(yd, text_file), encoding="utf-8", errors="ignore") as f:
        pages = f.read().split("\f")
    return [i + 1 for i, p in enumerate(pages[:-1]) if len(p.strip()) < EMPTY_PAGE_CHARS]


def get(session, url, head=False, tries=5, timeout=180):
    """GET or HEAD with retries. accessdata.fda.gov throttles bursts, so callers should also sleep between calls."""
    r = None
    for i in range(tries):
        try:
            fn = session.head if head else session.get
            r = fn(url.replace(" ", "%20"), timeout=timeout, allow_redirects=True)
            if r.status_code in (200, 404):
                return r
        except Exception:
            pass
        time.sleep(3 * (i + 1))
    return r


def years_arg(arg):
    if arg == "all":
        return sorted(int(d) for d in os.listdir(DATA) if d.isdigit())
    return [int(arg)]
