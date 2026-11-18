#' Text of a PDF, page by page
#'
#' Reads the text layer of each page with pdftools. Pages with fewer than
#' `minChars` non-space characters are treated as image-only and, if `ocr` is
#' `TRUE`, rendered at 300 dpi and read by OCR with the `tesseract` command,
#' as in the FDA pipeline; it stops if tesseract is missing.
#'
#' @param file Path to the PDF.
#' @param ocr Whether to OCR image-only pages.
#' @param minChars Pages with fewer non-space characters count as image-only.
#'
#' @return A data frame with columns `page`, `text` and `src` (`"text"` or
#'   `"ocr"`).
#' @export
pdfPages <- function(file, ocr = TRUE, minChars = 50) {
  if (!requireNamespace("pdftools", quietly = TRUE)) stop("pdfPages() needs the pdftools package")
  text <- pdftools::pdf_text(file)
  src <- rep("text", length(text))
  empty <- nchar(gsub("\\s", "", text)) < minChars
  if (ocr && any(empty) && !nzchar(Sys.which("tesseract"))) {
    stop(file, " has image-only pages, and OCR needs the tesseract command, which was not found")
  }
  if (ocr && any(empty)) {
    dir <- tempfile("pdfocr")
    dir.create(dir)
    on.exit(unlink(dir, recursive = TRUE), add = TRUE)
    for (i in which(empty)) {
      png <- pdftools::pdf_convert(
        file,
        pages = i, dpi = 300, filenames = file.path(dir, "p%04d.%s"), verbose = FALSE
      )
      text[i] <- paste(system2("tesseract", c(shQuote(png), "stdout"), stdout = TRUE, stderr = FALSE), collapse = "\n")
      src[i] <- "ocr"
    }
  }
  data.frame(page = seq_along(text), text = text, src = src, stringsAsFactors = FALSE)
}
