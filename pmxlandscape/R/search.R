#' Software families named in texts
#'
#' Applies patterns to whole texts, such as conference abstracts, and reports
#' which software families each text names. Unlike [fdaSearch()] it does not
#' return individual matches or snippets.
#'
#' @param texts Character vector; `NA` counts as naming nothing.
#' @param patterns Patterns as returned by [readPatterns()].
#' @param groups Pattern groups to use. The popPK marker is left out by default.
#'
#' @return A list with one character vector of families per text, each family
#'   once, in pattern order.
#' @export
findSoftware <- function(texts, patterns, groups = c("estimation", "auxiliary", "pbpk", "nca")) {
  p <- patterns[patterns$group %in% groups, , drop = FALSE]
  hit <- matrix(FALSE, nrow = length(texts), ncol = nrow(p))
  for (j in seq_len(nrow(p))) hit[, j] <- stringi::stri_detect_regex(texts, p$regex[j]) %in% TRUE
  lapply(seq_along(texts), function(i) unique(p$family[hit[i, ]]))
}
