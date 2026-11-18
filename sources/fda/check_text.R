# Does the R pipeline make the same review text as the Python one?
#
# Run from sources/fda/ after retrieve.R: Rscript check_text.R [years] (default: the surveyed years)
#
# For every document of the committed record (data/<year>/docs.json) whose PDF retrieve.R
# downloaded, extracts the text layer with pdftotext and OCRs the image-only pages with
# pdftoppm and tesseract (fdaExtractText(), fdaOcrPage()), as scripts/03_extract.py and
# 04_ocr.py did, and compares the result byte for byte with the committed text and OCR
# files. The committed text stays the corpus text; this records whether, and where, a new
# extraction would differ (other tool versions can change line breaks or OCR readings), and
# whether the difference changes any software mention found by the published patterns.
#
# Writes retrieval/text_check.csv (one row per document) and retrieval/text_check.txt; the new
# text goes to cache/<year>/txt and cache/<year>/ocr (not committed).

pkgload::load_all("../../pmxlandscape", quiet = TRUE)

years <- as.integer(commandArgs(trailingOnly = TRUE))
if (length(years) == 0) years <- fdaYears(".")
cores <- max(1, parallel::detectCores() - 2)
patterns <- readPatterns("config/patterns.json") # the published FDA run's patterns

rows <- list()
for (y in years) {
  docs <- jsonlite::read_json(file.path("data", y, "docs.json"))
  stems <- unlist(lapply(docs, function(d) vapply(d, function(r) sub("\\.txt$", "", basename(r$text_file)), "")))
  dir.create(file.path("cache", y, "txt"), showWarnings = FALSE, recursive = TRUE)
  dir.create(file.path("cache", y, "ocr"), showWarnings = FALSE, recursive = TRUE)
  for (stem in stems) {
    pdf <- file.path("cache", y, "pdf", paste0(stem, ".pdf"))
    old_txt <- file.path("data", y, "txt", paste0(stem, ".txt"))
    if (!file.exists(pdf)) {
      rows[[length(rows) + 1]] <- data.frame(year = y, document = stem, pdf = FALSE, text_identical = NA,
        pages_new = NA, pages_record = NA, ocr_pages_new = NA, ocr_pages_record = NA, ocr_same_pages = NA, ocr_identical = NA,
        mentions_record = NA, mentions_new = NA, mentions_lost = NA, mentions_gained = NA)
      next
    }
    new_txt <- file.path("cache", y, "txt", paste0(stem, ".txt"))
    if (!file.exists(new_txt)) fdaExtractText(pdf, new_txt)
    pages <- function(f) length(stringi::stri_split_fixed(readText(f), "\f")[[1]])
    img <- fdaImageOnlyPages(new_txt)
    old_ocr <- list.files(file.path("data", y, "ocr"), pattern = paste0("^", stem, "_p[0-9]{4}\\.txt$"))
    old_img <- as.integer(sub(".*_p([0-9]{4})\\.txt$", "\\1", old_ocr))
    new_ocr <- file.path("cache", y, "ocr", sprintf("%s_p%04d.txt", stem, img))
    todo <- which(!file.exists(new_ocr))
    if (length(todo)) {
      parallel::mclapply(todo, function(k) writeBin(charToRaw(enc2utf8(fdaOcrPage(pdf, img[k]))), new_ocr[k]), mc.cores = cores)
    }
    both <- intersect(img, old_img)
    same <- vapply(both, function(p) {
      identical(readText(sprintf("cache/%d/ocr/%s_p%04d.txt", y, stem, p)), readText(sprintf("data/%d/ocr/%s_p%04d.txt", y, stem, p)))
    }, logical(1))
    # The software mentions found on each page, by the published FDA patterns, in both versions
    new_pages <- stringi::stri_split_fixed(readText(new_txt), "\f")[[1]]
    new_src <- rep("text", length(new_pages))
    for (k in seq_along(img)) {
      new_pages[img[k]] <- readText(new_ocr[k])
      new_src[img[k]] <- "ocr"
    }
    new_pages <- data.frame(page = seq_along(new_pages), text = new_pages, src = new_src)
    old_pages <- fdaReadPages(".", y, file.path("txt", paste0(stem, ".txt")))
    mentions <- function(pg) unique(with(searchPages(pg, patterns, "", stem), paste(page, sw)))
    m_new <- mentions(new_pages)
    m_old <- mentions(old_pages)
    rows[[length(rows) + 1]] <- data.frame(year = y, document = stem, pdf = TRUE,
      text_identical = identical(readText(new_txt), readText(old_txt)), pages_new = pages(new_txt), pages_record = pages(old_txt),
      ocr_pages_new = length(img), ocr_pages_record = length(old_img), ocr_same_pages = length(both), ocr_identical = sum(same),
      mentions_record = length(m_old), mentions_new = length(m_new),
      mentions_lost = paste(setdiff(m_old, m_new), collapse = "; "), mentions_gained = paste(setdiff(m_new, m_old), collapse = "; "))
    cat(y, stem, "text", rows[[length(rows)]]$text_identical, "OCR", sum(same), "of", length(old_img), "\n")
  }
}
check <- do.call(rbind, rows)
write.csv(check, "retrieval/text_check.csv", row.names = FALSE)
d <- check[check$pdf, ]
lines <- c(
  paste("checked:", format(Sys.Date())),
  paste("pdftotext:", system2("pdftotext", "-v", stdout = TRUE, stderr = TRUE)[1], "(the Python run used 24.02.0)"),
  paste("tesseract:", system2("tesseract", "--version", stdout = TRUE, stderr = TRUE)[1], "(the Python run used 5.3.4)"),
  sprintf("documents: %d in the record, %d with a downloaded PDF", nrow(check), nrow(d)),
  sprintf("text layer identical: %d of %d; same page count: %d", sum(d$text_identical), nrow(d), sum(d$pages_new == d$pages_record)),
  sprintf("image-only pages: %d now, %d in the record, %d in both", sum(d$ocr_pages_new), sum(d$ocr_pages_record), sum(d$ocr_same_pages)),
  sprintf("OCR text identical: %d of %d pages in both", sum(d$ocr_identical), sum(d$ocr_same_pages)),
  sprintf("software mentions (page and pattern, published FDA patterns): %d in the record, %d now; lost %d, gained %d",
    sum(d$mentions_record), sum(d$mentions_new), sum(nzchar(unlist(strsplit(d$mentions_lost, "; ")))),
    sum(nzchar(unlist(strsplit(d$mentions_gained, "; ")))))
)
writeLines(lines, "retrieval/text_check.txt")
cat(lines, sep = "\n")
