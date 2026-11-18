# Attribution labels that 06_context.py reports before a hit.
contextLabels <- paste0(
  "(?:Applicant[\\u2019']?s?|Reviewer[\\u2019']?s?|FDA[\\u2019']?s?|Sponsor[\\u2019']?s?|",
  "[Oo]ur analysis|review team|Source:)[^.]{0,70}"
)

#' Show the text around a hit
#'
#' The R version of `06_context.py`, a reading aid for deciding who used the
#' software. For each review document of the application, prints the text
#' before and after the first match of `term` on the page, and the last five
#' attribution labels ("Applicant's ...", "FDA's ...", "Source: ...") found in
#' the two previous pages and this page up to the hit. The labels are hints
#' only: FDA appendices often reproduce Applicant text under FDA headings, so
#' always read the text.
#'
#' @inheritParams fdaReadPages
#' @param appl Application number, as a string.
#' @param page PDF page index (1-based).
#' @param term Regular expression to look for on the page.
#' @param before Number of characters to show before the match.
#'
#' @return The printed lines, invisibly.
#' @export
fdaContext <- function(fdaDir, year, appl, page, term, before = 900) {
  docs <- jsonlite::read_json(file.path(fdaDir, "data", year, "docs.json"))
  if (!appl %in% names(docs)) stop("Application ", appl, " is not in docs.json for ", year)
  printed <- character(0)
  for (r in docs[[appl]]) {
    pages <- fdaReadPages(fdaDir, year, r$text_file)
    if (page > nrow(pages)) next
    pageText <- function(n) if (n > 0 && n <= nrow(pages)) collapseSpace(pages$text[n]) else ""
    cur <- pageText(page)
    i <- stringi::stri_locate_first_regex(cur, term)[1, "start"] - 1L
    if (is.na(i)) next
    labels <- stringi::stri_extract_all_regex(
      paste(pageText(page - 2), pageText(page - 1), stringi::stri_sub(cur, 1, i)), contextLabels,
      omit_no_match = TRUE
    )[[1]]
    lines <- c(
      sprintf("== %s p%d (%s)", r$text_file, as.integer(page), pages$src[page]),
      stringi::stri_sub(cur, max(0L, i - before) + 1L, i + 300L),
      paste("-- labels before hit:", paste(stringi::stri_sub(utils::tail(labels, 5), 1, 90), collapse = " | "))
    )
    cat(lines, sep = "\n")
    printed <- c(printed, lines)
  }
  invisible(printed)
}
