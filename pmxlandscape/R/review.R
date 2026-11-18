#' Every match of the patterns in texts, with snippets
#'
#' Like [findSoftware()], but one row per match with the text around it, for
#' reading. Used for PAGE poster and presentation PDFs, where each hit is read
#' and decided (see [readDecisions()]).
#'
#' @inheritParams findSoftware
#' @param width Characters of context either side of the match.
#'
#' @return A data frame with `text` (index into `texts`), `family`, `name`
#'   (pattern), `group`, `start` and `snip` (whitespace collapsed), ordered by
#'   text, pattern and position.
#' @export
findMatches <- function(texts, patterns, groups = c("estimation", "auxiliary", "pbpk", "nca"), width = 220) {
  p <- patterns[patterns$group %in% groups, , drop = FALSE]
  # stri_locate_all_regex() gives one all-NA row for an NA text, even with omit_no_match
  texts[is.na(texts)] <- ""
  found <- lapply(seq_len(nrow(p)), function(j) {
    loc <- stringi::stri_locate_all_regex(texts, p$regex[j], omit_no_match = TRUE)
    n <- vapply(loc, nrow, integer(1))
    if (sum(n) == 0) {
      return(NULL)
    }
    m <- do.call(rbind, loc)
    data.frame(text = rep(seq_along(texts), n), pattern = j, start = m[, "start"], end = m[, "end"])
  })
  found <- do.call(rbind, found)
  if (is.null(found)) {
    return(data.frame(
      text = integer(0), family = character(0), name = character(0), group = character(0),
      start = integer(0), snip = character(0), stringsAsFactors = FALSE
    ))
  }
  found <- found[order(found$text, found$pattern, found$start), ]
  txt <- texts[found$text]
  from <- pmax(1L, found$start - as.integer(width))
  to <- pmin(stringi::stri_length(txt), found$end + as.integer(width))
  out <- data.frame(
    text = found$text, family = p$family[found$pattern], name = p$name[found$pattern],
    group = p$group[found$pattern], start = found$start,
    snip = stringi::stri_trim_both(collapseSpace(stringi::stri_sub(txt, from, to))), stringsAsFactors = FALSE
  )
  rownames(out) <- NULL
  out
}

#' Does a snippet look like a reference list entry?
#'
#' A reading aid, not a decision: flags text with "et al", a user's guide, a
#' DOI, a "year;volume" or "volume:pages" citation, or a numbered reference
#' such as `[3] Beal SL`.
#'
#' @param x Character vector of snippets.
#'
#' @return Logical vector; `NA` counts as `FALSE`.
#' @export
looksLikeCitation <- function(x) {
  cues <- paste(
    "\\bet al\\b", "users?'?\\s*guides?", "\\bdoi\\b|10\\.\\d{4,}/", "\\b(?:19|20)\\d{2}\\s*;\\s*\\d+",
    "\\d+\\s*(?:\\(\\d+\\))?\\s*:\\s*\\d+\\s*[-\\u2013]\\s*\\d+", "\\[\\d+\\]\\s*\\p{Lu}\\p{Ll}+,?\\s+\\p{Lu}{1,3}\\b",
    sep = "|"
  )
  stringi::stri_detect_regex(x, cues, case_insensitive = TRUE) %in% TRUE
}

#' Read the decisions on PDF hits
#'
#' Reads the hand-made decision file for PAGE poster and presentation PDFs:
#' one row per abstract and software family, with a `decision` of `used`
#' (the work used the software), `cited` (the software is only cited or
#' mentioned) or `other` (not the software: a name, OCR noise, an unrelated
#' word), and a `reason` in the reader's own words.
#'
#' @param file Path to the CSV with columns `abstract_no`, `family`,
#'   `decision` and `reason`.
#'
#' @return The decisions as a data frame, `abstract_no` as integer. Stops on an
#'   unknown decision, a missing reason or two decisions for the same hit.
#' @export
readDecisions <- function(file) {
  d <- utils::read.csv(file, colClasses = "character", na.strings = character(0), encoding = "UTF-8")
  allowed <- c("used", "cited", "other")
  bad <- setdiff(d$decision, allowed)
  if (length(bad) > 0) {
    stop(
      "Unknown decision(s) in ", file, ": ", paste(bad, collapse = ", "),
      " (allowed: ", paste(allowed, collapse = ", "), ")"
    )
  }
  if (any(trimws(d$reason) == "")) stop("Every decision in ", file, " needs a reason")
  key <- paste(d$abstract_no, d$family)
  if (anyDuplicated(key)) stop("more than one decision for ", paste(unique(key[duplicated(key)]), collapse = "; "))
  d$abstract_no <- as.integer(d$abstract_no)
  d
}

#' Look up the decision for each hit
#'
#' @param hits Data frame with `abstract_no` and `family`.
#' @param decisions Decisions as returned by [readDecisions()].
#'
#' @return The decision for each row of `hits`, `"pending"` where none is recorded.
#' @export
applyDecisions <- function(hits, decisions) {
  d <- decisions$decision[match(paste(hits$abstract_no, hits$family), paste(decisions$abstract_no, decisions$family))]
  ifelse(is.na(d), "pending", d)
}
