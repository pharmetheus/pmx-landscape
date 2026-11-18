# Download the other review documents (Other, Summary, Medical, Statistical) of the FDA
# "not stated" drugs, extract their text and OCR the image-only pages.
#
# Run from sources/fda/other_reviews/ after discover.R: Rscript fetch.R
# Writes cache/pdf/, cache/txt/<stem>/p<page>.txt and results/other_documents.csv.
# About 1 request per second; resumes from the cache.

`%||%` <- function(a, b) if (is.null(a)) b else a
wanted <- c(otherR = "OtherR", sumR = "SumR", medR = "MedR", statR = "StatR")
toc <- read.csv("results/toc_documents.csv", colClasses = "character")
dir.create("cache/pdf", recursive = TRUE, showWarnings = FALSE)
dir.create("cache/txt", recursive = TRUE, showWarnings = FALSE)
ua <- "pmx-software-landscape (research; niclas.jonsson@pharmetheus.com)"
req <- function(url, method = "GET") {
  Sys.sleep(1)
  httr2::request(url) |>
    httr2::req_user_agent(ua) |>
    httr2::req_method(method) |>
    httr2::req_retry(max_tries = 4) |>
    httr2::req_timeout(300) |>
    httr2::req_error(is_error = function(r) FALSE) |>
    httr2::req_perform()
}
emptyChars <- 50 # a page with less text than this is OCRed, as in the Python pipeline
out <- list()
for (i in seq_len(nrow(toc))) {
  r <- toc[i, ]
  docs <- intersect(names(wanted), strsplit(r$documents, "; ")[[1]])
  if (!length(docs) || is.na(r$base)) next
  years <- unique(c(as.integer(r$year), as.integer(r$year) + 1L, as.integer(regmatches(r$toc, regexpr("(?<=/nda/)\\d{4}", r$toc, perl = TRUE)))))
  for (dt in docs) {
    stem <- paste0(r$application, "_", dt)
    pdf <- file.path("cache/pdf", paste0(stem, ".pdf"))
    url <- NA_character_
    if (!file.exists(pdf)) {
      for (y in years) {
        u <- sprintf("https://www.accessdata.fda.gov/drugsatfda_docs/nda/%d/%s%s.pdf", y, r$base, wanted[[dt]])
        h <- req(u, "HEAD")
        if (httr2::resp_status(h) == 200 && grepl("pdf", httr2::resp_header(h, "content-type") %||% "", ignore.case = TRUE)) {
          g <- req(u)
          body <- httr2::resp_body_raw(g)
          if (httr2::resp_status(g) == 200 && identical(rawToChar(body[1:4]), "%PDF")) {
            writeBin(body, pdf)
            url <- u
            break
          }
        }
      }
    }
    if (!file.exists(pdf)) {
      out[[length(out) + 1]] <- data.frame(r[c("year", "drug", "application")], document = dt, url = "", pages = NA, ocr_pages = NA, note = "listed in the TOC but not found")
      cat(r$drug, dt, "NOT FOUND\n")
      next
    }
    tdir <- file.path("cache/txt", stem)
    dir.create(tdir, showWarnings = FALSE)
    n <- pdftools::pdf_info(pdf)$pages
    txt <- pdftools::pdf_text(pdf)
    ocr <- 0L
    for (p in seq_len(n)) {
      f <- file.path(tdir, sprintf("p%04d.txt", p))
      if (file.exists(f)) next
      t <- txt[p]
      if (nchar(gsub("\\s", "", t)) < emptyChars) {
        png <- tempfile(fileext = "")
        st <- system2("pdftoppm", c("-r", "300", "-f", p, "-l", p, "-png", "-singlefile", shQuote(pdf), shQuote(png)))
        if (st != 0) stop("pdftoppm failed on ", pdf, " page ", p)
        st <- system2("tesseract", c(shQuote(paste0(png, ".png")), shQuote(png), "--psm", "3"), stdout = FALSE, stderr = FALSE)
        if (st != 0) stop("tesseract failed on ", pdf, " page ", p)
        t <- paste(readLines(paste0(png, ".txt"), warn = FALSE), collapse = "\n")
        unlink(c(paste0(png, ".png"), paste0(png, ".txt")))
        ocr <- ocr + 1L
        t <- paste0("[OCR]\n", t)
      }
      writeLines(t, f)
    }
    out[[length(out) + 1]] <- data.frame(r[c("year", "drug", "application")], document = dt, url = url %||% "", pages = n, ocr_pages = ocr, note = "")
    cat(r$drug, dt, n, "pages,", ocr, "OCRed\n")
  }
}
d <- do.call(rbind, out)
old <- if (file.exists("results/other_documents.csv")) read.csv("results/other_documents.csv", colClasses = "character") else NULL
write.csv(d, "results/other_documents.csv", row.names = FALSE)
cat("DONE documents:", nrow(d), " not found:", sum(d$note != ""), "\n")
