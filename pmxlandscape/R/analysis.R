#' Read the analysis types
#'
#' @param file Path to the rules (`taxonomy/analysis_types.csv`), with columns
#'   `level`, `type`, `pattern`, `exclude`, `keep` and `note`.
#'
#' @return The rules as a data frame, `level` as integer.
#' @export
readAnalysisTypes <- function(file) {
  t <- utils::read.csv(file, colClasses = "character", na.strings = character(0), encoding = "UTF-8")
  t$level <- as.integer(t$level)
  t
}

#' Classify texts by analysis type
#'
#' Each text gets every type of level 2 and above whose pattern it matches
#' (case-insensitive) and whose `exclude` pattern it does not match, unless its
#' `keep` pattern rescues it; and "PK only" (level 1) when it gets none of them
#' but matches the PK pattern. The level is the highest level matched.
#' Sentences about background, the literature or future work are removed
#' first, unless they also speak of the work itself ("we", "our", "this study").
#' Tool names are never part of a pattern, since the types are compared across
#' tools.
#'
#' @param texts Character vector, for example title and abstract.
#' @param types Rules as returned by [readAnalysisTypes()].
#' @param background,own Regular expressions for background sentences and for
#'   sentences about the work itself.
#' @param definitions Regular expression for abbreviation-list entries that
#'   define a type term ("MCMC, Markov chain Monte Carlo"); they are removed.
#'
#' @return A data frame with `level` (`NA` when no type matches) and a list
#'   column `types`.
#' @export
classifyAnalysis <- function(texts, types,
                             background = paste0(
                               "\\b(?:future|further (?:studies|work|research)|warranted|",
                               "previous(?:ly)? (?:studies|reported|published|developed)|(?:the )?literature|",
                               "ha(?:s|ve) been (?:shown|used|reported|proposed)|",
                               "could be (?:combined|extended|used|applied)|may be (?:combined|extended))\\b"
                             ),
                             own = "\\b(?:we|our|this (?:study|work|analysis)|the present (?:study|work)|here)\\b",
                             definitions = paste0(
                               "\\b(?:MCMC|PBPK|QSP|TTE|E-?R|PK/?PD|ML|AI|HMC|NUTS)[,:;]?\\s+",
                               "(?:markov chain monte carlo|physiologically[- ]based[a-z -]*|",
                               "quantitative systems[a-z ]*|time[- ]to[- ]event|",
                               "exposure[- ]response|pharmacokinetic[a-z /-]*|",
                               "machine learning|artificial intelligence|",
                               "hamiltonian monte carlo|no-u-turn sampler)"
                             )) {
  texts <- stringi::stri_replace_all_regex(texts, definitions, " ", case_insensitive = TRUE)
  sentences <- stringi::stri_split_regex(texts, "(?<=[.!?])\\s+")
  texts <- vapply(sentences, function(s) {
    if (length(s) == 1 && is.na(s)) {
      return(NA_character_)
    }
    drop <- stringi::stri_detect_regex(s, background, case_insensitive = TRUE) &
      !stringi::stri_detect_regex(s, own, case_insensitive = TRUE)
    paste(s[!drop], collapse = " ")
  }, character(1))
  detect <- function(p) {
    if (is.na(p) || p == "") {
      return(rep(FALSE, length(texts)))
    }
    stringi::stri_detect_regex(texts, p, case_insensitive = TRUE) %in% TRUE
  }
  higher <- types[types$level > 1, , drop = FALSE]
  pk <- types[types$level == 1, , drop = FALSE]
  hit <- vapply(seq_len(nrow(higher)), function(j) {
    detect(higher$pattern[j]) & (!detect(higher$exclude[j]) | detect(higher$keep[j]))
  }, logical(length(texts)))
  hit <- matrix(hit, nrow = length(texts))
  pkHit <- stringi::stri_detect_regex(texts, pk$pattern[1], case_insensitive = TRUE) %in% TRUE
  out <- data.frame(level = rep(NA_integer_, length(texts)))
  out$types <- lapply(seq_along(texts), function(i) {
    if (any(hit[i, ])) higher$type[hit[i, ]] else if (pkHit[i]) pk$type[1] else character(0)
  })
  out$level <- vapply(seq_along(texts), function(i) {
    if (any(hit[i, ])) max(higher$level[hit[i, ]]) else if (pkHit[i]) 1L else NA_integer_
  }, integer(1))
  out
}

#' Analysis types per tool
#'
#' @param items Data frame with `tools` (families separated by "; ") and a list
#'   column `types`, one row per paper or abstract.
#'
#' @return One row per tool (and "All") and type with `n` (items naming the
#'   tool with that type), `n_tool` (items naming the tool) and `share`.
#' @export
typeByTool <- function(items) {
  tools <- strsplit(items$tools, "; ", fixed = TRUE)
  allTypes <- unique(unlist(items$types))
  toolNames <- c("All", sort(unique(unlist(tools))))
  out <- do.call(rbind, lapply(toolNames, function(t) {
    has <- if (t == "All") rep(TRUE, nrow(items)) else vapply(tools, function(x) t %in% x, logical(1))
    data.frame(
      tool = t, type = allTypes,
      n = vapply(allTypes, function(ty) sum(has & vapply(items$types, function(x) ty %in% x, logical(1))), integer(1)),
      n_tool = sum(has), stringsAsFactors = FALSE, row.names = NULL
    )
  }))
  out$share <- out$n / out$n_tool
  out
}

#' Over- and under-representation of analysis types per tool
#'
#' For each tool and type, the share of the tool's items with the type against
#' the share among items that do not name the tool, as a ratio with a 95%
#' interval on the log scale (Katz). A ratio above 1 means the type is more
#' common in the tool's items.
#'
#' @inheritParams typeByTool
#' @param level Confidence level.
#'
#' @return One row per tool and type with `n`, `n_tool`, `share_tool`,
#'   `n_rest`, `share_rest`, `ratio`, `lower` and `upper` (`NA` when either
#'   count is 0).
#' @export
typeLift <- function(items, level = 0.95) {
  tools <- strsplit(items$tools, "; ", fixed = TRUE)
  allTypes <- unique(unlist(items$types))
  z <- stats::qnorm(1 - (1 - level) / 2)
  do.call(rbind, lapply(sort(unique(unlist(tools))), function(t) {
    has <- vapply(tools, function(x) t %in% x, logical(1))
    do.call(rbind, lapply(allTypes, function(ty) {
      k <- vapply(items$types, function(x) ty %in% x, logical(1))
      a <- sum(has & k)
      n1 <- sum(has)
      c <- sum(!has & k)
      n2 <- sum(!has)
      ratio <- if (a > 0 && c > 0) (a / n1) / (c / n2) else NA_real_
      se <- if (is.na(ratio)) NA_real_ else sqrt(1 / a - 1 / n1 + 1 / c - 1 / n2)
      data.frame(
        tool = t, type = ty, n = a, n_tool = n1, share_tool = a / n1, n_rest = c, share_rest = c / n2,
        ratio = ratio, lower = ratio * exp(-z * se), upper = ratio * exp(z * se), stringsAsFactors = FALSE
      )
    }))
  }))
}

#' Methodology sessions at PAGE
#'
#' PAGE labels methodology sessions with a "Methodology" prefix from 2014 and
#' by topic alone before (2011 to 2013: "New Modelling Approaches", "Study
#' Design", "Model evaluation", "Estimation methods", "Covariate/Variability
#' Model Building"). This recognises both. PBPK sessions count as applied work
#' throughout, since PAGE moved them from methodology to drug and disease
#' modelling in 2014.
#'
#' @param session Session labels.
#'
#' @return `TRUE` for methodology sessions.
#' @export
pageMethodology <- function(session) {
  topics <- paste0(
    "methodolog|new modell?ing approach|study design|model evaluation|estimation method|covariate|",
    "variability model|algorithm|new tools|machine learning|AI/ML"
  )
  isMethod <- stringi::stri_detect_regex(session, topics, case_insensitive = TRUE) %in% TRUE
  isPbpk <- stringi::stri_detect_regex(session, "PBPK|physiolog", case_insensitive = TRUE) %in% TRUE
  isMethod & !isPbpk
}

#' Methodology and applied items per group and year
#'
#' @param items Data frame with `year`, `tools` ("; "-separated), a logical
#'   `methodology` and optionally a list column `types`.
#' @param groups Tool families, or analysis types when `by = "type"`.
#' @param by `"tool"` or `"type"`.
#'
#' @return One row per group and year with `methods` and `applied` counts.
#' @export
methodsApplied <- function(items, groups, by = c("tool", "type")) {
  by <- match.arg(by)
  member <- if (by == "tool") strsplit(items$tools, "; ", fixed = TRUE) else items$types
  years <- sort(unique(items$year))
  do.call(rbind, lapply(groups, function(g) {
    has <- vapply(member, function(x) g %in% x, logical(1))
    data.frame(
      group = g, year = years,
      methods = vapply(years, function(y) sum(has & items$methodology & items$year == y), integer(1)),
      applied = vapply(years, function(y) sum(has & !items$methodology & items$year == y), integer(1)),
      stringsAsFactors = FALSE
    )
  }))
}

# The lumped categories, in level order, as agreed with the project owner (2026-09-27)
lumpedTypes <- c(
  "PK only", "PK/PD, exposure-response, disease progression", "Non-continuous endpoints, time-to-event, joint models",
  "Full Bayesian hierarchical models", "Machine learning, AI, neural ODEs", "QSP, PBPK"
)

#' Lump analysis types for presentation
#'
#' `"detailed"` merges joint models into non-continuous endpoints and
#' time-to-event (joint models are too rare to stand alone); `"simple"` keeps
#' only "PK only" against "Any type other than PK only", for sources with few complex
#' analyses (PubMed abstracts, FDA reviews).
#'
#' @param types List of character vectors, one per item.
#' @param mode `"detailed"` or `"simple"`.
#'
#' @return The lumped types, same shape.
#' @export
lumpTypes <- function(types, mode = c("detailed", "simple")) {
  mode <- match.arg(mode)
  lapply(types, function(x) {
    if (length(x) == 0) {
      return(character(0))
    }
    if (mode == "simple") {
      return(if (all(x == "PK only")) "PK only" else "Any type other than PK only")
    }
    x[x %in% c("Joint models", "Non-continuous endpoints, time-to-event")] <- lumpedTypes[3]
    unique(x)
  })
}
