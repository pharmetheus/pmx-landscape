# FDA text and OCR in R (the R port of scripts/03_extract.py and 04_ocr.py)
#
# Run from sources/fda/ after retrieve.R: Rscript extract.R <year> [from]   (resumable)
#
# With `from` (YYYY-MM-DD), only the approvals on or after that date are taken into data/<year>/
# (frame and documents), as for the July to December 2020 approvals read for the development run
# (Niclas, 2026-10-20); the rest of the year waits for the production run.
#
# Makes a retrieved year a surveyed one: copies retrieval/<year>/frame.json and docs.json to
# data/<year>/, extracts the text layer of each review PDF with pdftotext to
# data/<year>/txt/, and OCRs every image-only page (less than 50 characters of text) with
# pdftoppm (150 dpi, grey) and tesseract (--psm 3) to data/<year>/ocr/<document>_p<nnnn>.txt,
# as the Python pipeline did. The text is then searched and read as for the other years
# (docs/fda.md). Stops if a year already has a data folder, so the published years are never
# overwritten.

pkgload::load_all("../../pmxlandscape", quiet = TRUE)

y <- as.integer(commandArgs(trailingOnly = TRUE)[1])
if (is.na(y)) stop("usage: Rscript extract.R <year>")
out <- file.path("data", y)
if (file.exists(file.path(out, "docs.json")) && !file.exists(file.path(out, ".extracting"))) {
  stop(out, " already exists; the surveyed years are not re-extracted (see check_text.R)")
}
dir.create(file.path(out, "txt"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(out, "ocr"), showWarnings = FALSE)
file.create(file.path(out, ".extracting"))
from <- as.Date(commandArgs(trailingOnly = TRUE)[2])
if (is.na(from)) {
  file.copy(file.path("retrieval", y, c("frame.json", "docs.json")), out, overwrite = TRUE)
} else {
  frame <- jsonlite::read_json(file.path("retrieval", y, "frame.json"), simplifyVector = TRUE)
  frame <- frame[as.Date(frame$date, "%m/%d/%Y") >= from, ]
  jsonlite::write_json(frame, file.path(out, "frame.json"), pretty = TRUE, auto_unbox = TRUE)
  allDocs <- jsonlite::read_json(file.path("retrieval", y, "docs.json"))
  jsonlite::write_json(allDocs[intersect(names(allDocs), frame$appl)], file.path(out, "docs.json"), pretty = TRUE, auto_unbox = TRUE)
  writeLines(paste0("frame: approvals from ", from, " only"), file.path(out, "frame_from.txt"))
}
docs <- jsonlite::read_json(file.path(out, "docs.json"))
cores <- max(1, parallel::detectCores() - 2)
for (appl in names(docs)) {
  for (r in docs[[appl]]) {
    stem <- sub("\\.txt$", "", basename(r$text_file))
    pdf <- file.path("cache", y, "pdf", paste0(stem, ".pdf"))
    if (!file.exists(pdf)) stop("no PDF for ", stem, "; run retrieve.R ", y, " first")
    txt <- file.path(out, r$text_file)
    if (!file.exists(txt)) fdaExtractText(pdf, txt)
    pages <- fdaImageOnlyPages(txt)
    ocr <- file.path(out, "ocr", sprintf("%s_p%04d.txt", stem, pages))
    todo <- which(!file.exists(ocr))
    parallel::mclapply(todo, function(k) writeBin(charToRaw(enc2utf8(fdaOcrPage(pdf, pages[k]))), ocr[k]), mc.cores = cores)
    cat(appl, stem, length(pages), "image-only pages\n")
  }
}
file.remove(file.path(out, ".extracting"))
writeLines(c(
  paste("extracted:", format(Sys.Date())),
  paste("pdftotext:", system2("pdftotext", "-v", stdout = TRUE, stderr = TRUE)[1]),
  paste("tesseract:", system2("tesseract", "--version", stdout = TRUE, stderr = TRUE)[1])
), file.path(out, "extraction.txt"))
