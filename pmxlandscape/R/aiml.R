#' Read the AI and machine learning terms
#'
#' Reads `taxonomy/ai_ml_terms.csv`: one row per term, with its `group` (`ML`
#' for named learning methods, `AI` for the label and its newer forms), a
#' `regex` (ICU, as used by stringi) for cached text, and the `pubmed` and
#' `epmc` query strings (empty where the term is not searched in that service).
#'
#' @param file Path to the CSV file.
#'
#' @return The terms as a data frame, with `name` and `family` set to `term`, so
#'   that it can be passed as `patterns` to [findMatches()] and [fdaSearch()].
#' @export
readAiMlTerms <- function(file) {
  terms <- utils::read.csv(file, colClasses = "character", na.strings = character(0))
  bad <- setdiff(terms$group, c("ML", "AI"))
  if (length(bad) > 0) stop("unknown group in ", file, ": ", paste(bad, collapse = ", "))
  if (anyDuplicated(terms$term)) stop("duplicated term in ", file)
  compiles <- function(r) !inherits(try(stringi::stri_detect_regex("", r), silent = TRUE), "try-error")
  ok <- vapply(terms$regex, compiles, TRUE)
  if (!all(ok)) stop("regex that does not compile in ", file, ": ", paste(terms$term[!ok], collapse = ", "))
  terms$name <- terms$term
  terms$family <- terms$term
  terms
}

#' Attach the reading to AI and machine learning hits
#'
#' Each item and term found is read and decided: `used` (the authors apply or
#' develop the method), `mentioned` (discussed, cited, proposed) or `not` (the
#' words do not mean the method, for example "AI" for aromatase inhibitor).
#'
#' @param hits Data frame with one row per `source`, `id` and `term`, and the
#'   item's `year` and the term's `group`.
#' @param decisions Data frame with `source`, `id`, `term` and `decision`.
#'
#' @return `hits` with a `decision` column. Stops if a hit has no decision, so
#'   that nothing is counted before it is read.
#' @export
aiMlDecide <- function(hits, decisions) {
  bad <- setdiff(decisions$decision, c("used", "mentioned", "not"))
  if (length(bad) > 0) stop("unknown decision: ", paste(unique(bad), collapse = ", "))
  key <- function(d) paste(d$source, d$id, d$term, sep = "\r")
  if (anyDuplicated(key(decisions))) stop("more than one decision for the same source, item and term")
  m <- match(key(hits), key(decisions))
  if (anyNA(m)) {
    first <- which(is.na(m))[1]
    example <- paste(hits$source[first], hits$id[first], hits$term[first])
    stop(sum(is.na(m)), " hit(s) without a decision, e.g. ", example)
  }
  hits$decision <- decisions$decision[m]
  hits
}

# One row per source, item and group: mentioned when any term of the group is used or mentioned,
# used when any term is used
aiMlItems <- function(decided) {
  keep <- decided[decided$decision != "not", , drop = FALSE]
  if (nrow(keep) == 0) {
    return(data.frame(
      source = character(0), id = character(0), year = integer(0), group = character(0), used = logical(0)
    ))
  }
  keep$used <- keep$decision == "used"
  stats::aggregate(used ~ source + id + year + group, keep, any)
}

#' Share of items mentioning and using AI or machine learning, per year
#'
#' @param decided Hits with decisions, from [aiMlDecide()].
#' @param base Data frame with `source`, `year` and `n`, the number of items in
#'   the source's base set that year.
#'
#' @return One row per source, year of `base` and group (`ML`, `AI`), with the
#'   number of items `mentioned` (used included) and `used`, `base_n`, and the
#'   shares `share_mentioned` and `share_used`. An item counts once per group.
#' @export
aiMlShares <- function(decided, base) {
  items <- aiMlItems(decided)
  outside <- !paste(items$source, items$year) %in% paste(base$source, base$year)
  if (any(outside)) stop(sum(outside), " item(s) from a source and year missing from base")
  grid <- merge(base, data.frame(group = c("ML", "AI")))
  k <- paste(grid$source, grid$year, grid$group)
  ki <- paste(items$source, items$year, items$group)
  grid$mentioned <- vapply(k, function(x) sum(ki == x), integer(1), USE.NAMES = FALSE)
  grid$used <- vapply(k, function(x) sum(ki == x & items$used), integer(1), USE.NAMES = FALSE)
  out <- data.frame(
    source = grid$source, year = grid$year, group = grid$group, mentioned = grid$mentioned, used = grid$used,
    base_n = grid$n, share_mentioned = grid$mentioned / grid$n, share_used = grid$used / grid$n
  )
  out[order(out$source, out$group, out$year), ]
}

#' First year AI or machine learning was mentioned and used
#'
#' @param decided Hits with decisions, from [aiMlDecide()].
#' @param by `"group"` or `"term"`.
#'
#' @return One row per source and group (or term) with any item mentioning it:
#'   `first_mentioned` and `ids_mentioned` (every item of that year, "; "
#'   separated, used included), and `first_used` and `ids_used` (`NA` when no
#'   item used it).
#' @export
aiMlFirst <- function(decided, by = c("group", "term")) {
  by <- match.arg(by)
  keep <- decided[decided$decision != "not", , drop = FALSE]
  first <- function(d) {
    if (nrow(d) == 0) {
      return(list(NA_integer_, NA_character_))
    }
    y <- min(d$year)
    list(as.integer(y), paste(sort(unique(d$id[d$year == y])), collapse = "; "))
  }
  out <- do.call(rbind, lapply(split(keep, paste(keep$source, keep[[by]], sep = "\r")), function(d) {
    m <- first(d)
    u <- first(d[d$decision == "used", , drop = FALSE])
    r <- data.frame(source = d$source[1], x = d[[by]][1], first_mentioned = m[[1]], ids_mentioned = m[[2]])
    r$first_used <- u[[1]]
    r$ids_used <- u[[2]]
    names(r)[2] <- by
    r
  }))
  rownames(out) <- NULL
  out
}

#' Keep each ID in the first year it appears
#'
#' PubMed's `[dp]` matches both the electronic and the print date, so a
#' record can be returned for two years. It is counted in the earliest.
#'
#' @param ids Data frame with `id` and `year`.
#'
#' @return The rows of `ids` from each ID's earliest year, in their order.
#' @export
keepEarliestYear <- function(ids) {
  first <- tapply(ids$year, ids$id, min)
  ids[ids$year == first[as.character(ids$id)], , drop = FALSE]
}
