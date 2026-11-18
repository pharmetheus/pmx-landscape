# FDA retrieval, ported from sources/fda/scripts/01_frame.py to 04_ocr.py. The parsers are
# pure functions (tested on invented pages); the network and file steps are in
# sources/fda/retrieve.R. Text and OCR call the same programs as the Python pipeline
# (pdftotext; pdftoppm and tesseract), not pdftools, so the text is made the same way.

fdaDocTypes <- c(clinPharmR = "ClinPharmR", integratedR = "IntegratedR", multidisciplineR = "MultidisciplineR")

# Text of a node as BeautifulSoup's get_text(" ", strip = TRUE) gives it: each text piece
# stripped, empty pieces dropped, the rest joined by single spaces.
soupText <- function(node) {
  t <- stringi::stri_trim_both(xml2::xml_text(xml2::xml_find_all(node, ".//text()")))
  paste(t[nzchar(t)], collapse = " ")
}

#' Parse FDA's novel drug approvals page into the frame
#'
#' Reads the first table of `novel-drug-approvals-<year>`, as `01_frame.py`
#' does. The application number comes from the label link
#' (`/label/<yyyy>/<appl>`), else from an `ApplNo=` link in the same row, else
#' from `overrides`; rows still without one keep `NA`.
#'
#' @param html The page.
#' @param overrides Named list (by drug name) of lists with `appl` and
#'   `source`, as one year of `config/frame_overrides.json`.
#'
#' @return A data frame with `no`, `name`, `ingr`, `date`, `label` (the link
#'   or source the number came from) and `appl`, ordered by `no`.
#' @export
fdaParseApprovals <- function(html, overrides = list()) {
  doc <- if (inherits(html, "xml_document")) html else xml2::read_html(html)
  rows <- xml2::xml_find_all(xml2::xml_find_first(doc, "//table"), ".//tr")[-1]
  out <- lapply(rows, function(tr) {
    cells <- vapply(xml2::xml_find_all(tr, ".//td"), soupText, character(1))
    if (length(cells) < 4) {
      return(NULL)
    }
    hrefs <- xml2::xml_attr(xml2::xml_find_all(tr, ".//a"), "href")
    hrefs[is.na(hrefs)] <- ""
    appl <- NA_character_
    src <- NA_character_
    lab <- stringi::stri_match_first_regex(hrefs, "/label/\\d{4}/(\\d{6})")[, 2]
    if (any(!is.na(lab))) {
      i <- which(!is.na(lab))[1]
      appl <- lab[i]
      src <- hrefs[i]
    } else {
      no <- stringi::stri_match_first_regex(hrefs, "(?i)ApplNo=(\\d{6})")[, 2]
      if (any(!is.na(no))) {
        appl <- no[!is.na(no)][1]
        src <- "Drugs@FDA link"
      } else if (cells[2] %in% names(overrides)) {
        appl <- overrides[[cells[2]]]$appl
        src <- overrides[[cells[2]]]$source
      }
    }
    num <- gsub("\\D", "", cells[1])
    data.frame(
      no = if (nzchar(num)) as.integer(num) else 0L, name = cells[2], ingr = cells[3], date = cells[4], label = src,
      appl = appl, stringsAsFactors = FALSE
    )
  })
  f <- do.call(rbind, out)
  f <- f[order(f$no), ]
  rownames(f) <- NULL
  f
}

#' Application number of a drug from an openFDA brand-name search
#'
#' The fallback for approvals pages without label or Drugs@FDA links (2026):
#' among the applications openFDA returns for a brand name, the one whose
#' original submission was approved on the frame's approval date.
#'
#' @param json The answer of `api.fda.gov/drug/drugsfda.json` to a
#'   `products.brand_name` search, as a string or parsed list.
#' @param date The approval date as the approvals page writes it (`M/D/YYYY`).
#'
#' @return The six-digit application number, or `NA` if no original approval
#'   has that date.
#' @export
fdaApplByBrand <- function(json, date) {
  j <- if (is.character(json)) jsonlite::fromJSON(json, simplifyVector = FALSE) else json
  want <- format(as.Date(date, "%m/%d/%Y"), "%Y%m%d")
  for (r in j$results %||% list()) {
    ok <- vapply(r$submissions %||% list(), function(s) {
      identical(s$submission_type, "ORIG") && identical(s$submission_status, "AP") &&
        identical(s$submission_status_date, want)
    }, logical(1))
    if (any(ok)) {
      return(sub("^\\D+", "", r$application_number))
    }
  }
  NA_character_
}

#' Review TOC links of an application in openFDA
#'
#' @param json The answer of `api.fda.gov/drug/drugsfda.json` for one
#'   application, as a string or parsed list.
#'
#' @return The URLs of the review tables of contents of the original (ORIG)
#'   submissions, sorted and unique.
#' @export
fdaReviewTocs <- function(json) {
  j <- if (is.character(json)) jsonlite::fromJSON(json, simplifyVector = FALSE) else json
  urls <- character(0)
  for (res in j$results) {
    for (s in res$submissions) {
      if (!identical(s$submission_type, "ORIG")) next
      for (ad in s$application_docs) {
        if (identical(ad$type, "Review") && grepl("TOC", ad$url %||% "", fixed = TRUE)) urls <- c(urls, ad$url)
      }
    }
  }
  sort(unique(urls))
}

`%||%` <- function(a, b) if (is.null(a)) b else a

#' Read a Drugs@FDA table of contents
#'
#' The page builds its links in JavaScript; the PDF base name is in
#' `var pdfBaseName`, and `var pdfFiles` flags the documents that exist. When
#' the page has no base name it is taken from the TOC URL, as `02_retrieve.py`
#' does.
#'
#' @param html The TOC page source.
#' @param url The TOC URL.
#'
#' @return A list with `base` (`NA` if none), `flags` (the documents flagged
#'   1) and `note` (`""` or why the base came from the URL).
#' @export
fdaParseToc <- function(html, url) {
  base <- stringi::stri_match_first_regex(html, 'var pdfBaseName = "([^"]+)"')[, 2]
  note <- ""
  if (is.na(base)) {
    base <- stringi::stri_match_first_regex(url, "/(\\d{6}[^/]*?)TOC\\.")[, 2]
    note <- "TOC without pdfBaseName; base taken from TOC URL"
  }
  flags <- character(0)
  at <- stringi::stri_locate_first_fixed(html, "var pdfFiles")[1, 1]
  if (!is.na(at)) {
    end <- stringi::stri_locate_first_fixed(stringi::stri_sub(html, at), "END EDIT")[1, 1]
    seg <- stringi::stri_sub(html, at, if (is.na(end)) -2L else at + end - 2L)
    m <- stringi::stri_match_all_regex(seg, "(\\w+):\\s*([01])")[[1]]
    flags <- m[m[, 3] == "1", 2]
  }
  list(base = base, flags = flags, note = note)
}

#' Candidate review PDF URLs
#'
#' @param bases PDF base names (for example `219999Orig1s000`).
#' @param years Folder years to try.
#'
#' @return A data frame with `type`, `folder_year` and `url`, one row per base,
#'   year and review type, in that nesting order.
#' @export
fdaReviewUrls <- function(bases, years) {
  g <- expand.grid(type = names(fdaDocTypes), folder_year = years, base = bases, stringsAsFactors = FALSE)
  g$url <- sprintf(
    "https://www.accessdata.fda.gov/drugsatfda_docs/nda/%d/%s%s.pdf", g$folder_year, g$base, fdaDocTypes[g$type]
  )
  g[c("type", "folder_year", "url")]
}

#' Image-only pages of an extracted review
#'
#' Pages whose text, stripped of white space, is shorter than `minChars`
#' characters; the text after the last form feed is not a page, as in
#' `04_ocr.py`.
#'
#' @param textFile A pdftotext output file.
#' @param minChars The threshold (50 in the Python pipeline).
#'
#' @return The page numbers (1-based).
#' @export
fdaImageOnlyPages <- function(textFile, minChars = 50) {
  pages <- stringi::stri_split_fixed(readText(textFile), "\f")[[1]]
  pages <- pages[-length(pages)]
  stripped <- stringi::stri_replace_all_regex(pages, paste0("^", pySpace, "+|", pySpace, "+$"), "")
  which(nchar(stripped) < minChars)
}

#' Extract the text layer of a PDF with pdftotext
#'
#' @param pdf The PDF.
#' @param out The text file to write (pages separated by form feeds).
#'
#' @return `out`, invisibly; stops if pdftotext is missing or wrote nothing.
#' @export
fdaExtractText <- function(pdf, out) {
  if (!nzchar(Sys.which("pdftotext"))) stop("fdaExtractText() needs poppler's pdftotext")
  system2("pdftotext", c("-q", shQuote(pdf), shQuote(out)))
  if (!file.exists(out)) stop("pdftotext wrote no text for ", pdf)
  invisible(out)
}

#' OCR one PDF page as the Python pipeline does
#'
#' Renders the page with `pdftoppm -r 150 -gray` and reads it with
#' `tesseract --psm 3`, single-threaded.
#'
#' @param pdf The PDF.
#' @param page The page (1-based).
#'
#' @return The OCR text.
#' @export
fdaOcrPage <- function(pdf, page) {
  for (tool in c("pdftoppm", "tesseract")) if (!nzchar(Sys.which(tool))) stop("fdaOcrPage() needs ", tool)
  dir <- tempfile("fdaocr")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  png <- file.path(dir, "page")
  args <- c("-r", "150", "-gray", "-f", page, "-l", page, "-singlefile", "-png", shQuote(pdf), shQuote(png))
  system2("pdftoppm", args, stdout = FALSE, stderr = FALSE)
  txt <- file.path(dir, "page.txt")
  system2("tesseract", c(shQuote(paste0(png, ".png")), "-", "--psm", "3"),
    stdout = txt, stderr = FALSE, env = "OMP_THREAD_LIMIT=1"
  )
  if (file.exists(txt) && file.size(txt) > 0) readText(txt) else ""
}

#' One year of CDER's NME and new biologic compilation as the frame
#'
#' For years whose "Novel Drug Approvals" page FDA no longer serves (2016 to
#' 2020, October 2026), the frame comes from the "Compilation of CDER New
#' Molecular Entity (NME) Drug and New Biologic Approvals" spreadsheet, the
#' same set of approvals. For 2021 to 2025 its application numbers match the
#' frames read from the pages.
#'
#' @param x The spreadsheet, as a data frame (`readxl::read_excel()`), with
#'   the columns `Proprietary  Name`, `Active Ingredient/Moiety`, `Application
#'   Number(1)`, `FDA Approval Date` and `Approval Year`.
#' @param year The year.
#'
#' @return A frame as [fdaParseApprovals()] gives it, in order of approval
#'   date, the date written as on FDA's pages (`1/19/2021`).
#' @export
fdaCompilationFrame <- function(x, year) {
  x <- x[x[["Approval Year"]] %in% year, , drop = FALSE]
  date <- as.Date(x[["FDA Approval Date"]])
  x <- x[order(date), , drop = FALSE]
  date <- sort(date)
  data.frame(
    no = seq_len(nrow(x)), name = x[["Proprietary  Name"]], ingr = x[["Active Ingredient/Moiety"]],
    date = sprintf("%d/%d/%s", as.integer(format(date, "%m")), as.integer(format(date, "%d")), format(date, "%Y")),
    label = "CDER NME and new biologic compilation", appl = sprintf("%06d", as.integer(x[["Application Number(1)"]])),
    stringsAsFactors = FALSE
  )
}
