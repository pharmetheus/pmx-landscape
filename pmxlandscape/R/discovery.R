#' Read the cue table for software discovery
#'
#' Reads `taxonomy/discovery/cues.csv`: one row per cue, a named regular
#' expression (ICU, as used by stringi) for the words around a software name,
#' such as a version number or the maker and place in brackets. The name is the
#' first capture group that matched; a cue may have several, one per
#' alternative.
#'
#' @param file Path to the CSV file.
#'
#' @return The cues as a data frame with `cue`, `regex`, `example`, `note` and
#'   `skip_sources` (sources the cue is not applied to, "; " separated).
#' @export
readCues <- function(file) {
  cues <- utils::read.csv(file, colClasses = "character", na.strings = character(0), encoding = "UTF-8")
  if (!"skip_sources" %in% names(cues)) cues$skip_sources <- ""
  if (anyDuplicated(cues$cue)) stop("duplicated cue in ", file)
  groups <- vapply(cues$regex, function(r) {
    m <- tryCatch(stringi::stri_match_first_regex("", r), error = function(e) NULL)
    if (is.null(m)) -1L else ncol(m) - 1L
  }, integer(1))
  if (any(groups < 0)) stop("regex that does not compile in ", file, ": ", paste(cues$cue[groups < 0], collapse = ", "))
  if (any(groups == 0)) {
    stop("cue without a capture group in ", file, ": ", paste(cues$cue[groups == 0], collapse = ", "))
  }
  cues
}

#' Software names found by the words around them
#'
#' Applies each cue to each text and returns every name it captures. The cues
#' do not know any software name, so tools nobody expected are found too, along
#' with words that are not software, which the reading removes.
#'
#' @param texts Character vector; `NA` counts as empty.
#' @param ids Item IDs, one per text.
#' @param cues Cues as returned by [readCues()].
#' @param stop Names never returned, such as "Table" or "Figure" (case-sensitive).
#'
#' @return A data frame with one row per match: `id`, `cue` and `raw` (the
#'   captured name as written).
#' @export
softwareCandidates <- function(texts, ids, cues, stop = character(0)) {
  texts[is.na(texts)] <- ""
  out <- lapply(seq_len(nrow(cues)), function(j) {
    m <- stringi::stri_match_all_regex(texts, cues$regex[j], omit_no_match = TRUE)
    n <- vapply(m, nrow, integer(1))
    if (sum(n) == 0) {
      return(NULL)
    }
    all <- do.call(rbind, m)
    groups <- all[, -1, drop = FALSE]
    raw <- apply(groups, 1, function(g) g[!is.na(g)][1])
    data.frame(id = rep(ids, n), cue = cues$cue[j], raw = stringi::stri_trim_both(raw), stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, c(list(data.frame(id = character(0), cue = character(0), raw = character(0))), out))
  out <- out[!is.na(out$raw), ]
  # a two-word name whose first word is a stop name ("The WinNonMix") keeps the second word
  first <- stringi::stri_extract_first_regex(out$raw, "^\\S+(?=\\s)")
  lead <- !is.na(first) & first %in% stop
  out$raw[lead] <- stringi::stri_trim_both(stringi::stri_sub(out$raw[lead], stringi::stri_length(first[lead]) + 1))
  out <- out[!out$raw %in% stop & !normaliseCandidate(out$raw) %in% c(stop, ""), ]
  rownames(out) <- NULL
  out
}

#' Clean a candidate software name
#'
#' Removes trade mark signs, a trailing version ("NONMEM 7.5.1", "Pumas
#' v2.4", "nlmixr2"), a Monolix-style release ("Monolix2024R1") and stray
#' punctuation, so the variants of a name group together.
#'
#' @param x Character vector of names.
#'
#' @return The cleaned names.
#' @export
normaliseCandidate <- function(x) {
  x <- stringi::stri_replace_all_regex(x, "[®™]|\\((?:R|TM)\\)", "")
  x <- stringi::stri_replace_all_regex(x, "(?<=\\p{L})\\d{4}R\\d$", "")
  version <- "(?:[\\s-]*(?:[Vv]ersion|[Vv]er\\.|[Vv]\\.?)\\s*|[\\s-]+)\\d+(?:\\.\\d+)*[a-z]?$"
  x <- stringi::stri_replace_all_regex(x, version, "")
  x <- stringi::stri_replace_all_regex(x, "(?<=\\p{Ll})\\d+$", "")
  x <- stringi::stri_replace_all_regex(x, "^[^\\p{L}\\p{N}]+|[^\\p{L}\\p{N}+#*]+$", "")
  stringi::stri_trim_both(x)
}

#' Grouping key for a candidate name
#'
#' @param x Cleaned names, as from [normaliseCandidate()].
#'
#' @return Lower-case names without spaces, dots, hyphens or underscores, so
#'   that "PK-Sim", "PKSim" and "pk sim" share a key.
#' @export
candidateKey <- function(x) tolower(stringi::stri_replace_all_regex(x, "[\\s._-]", ""))

#' Grouping keys for a set of candidate names
#'
#' Like [candidateKey()], but a key that occurs both as an all-lower-case name
#' and as an all-capitals one is split: the lower-case form gets the key with
#' "_lc" added. Package names are lower case and acronyms are capitals, so the
#' R package nlme stays apart from NLME, the acronym of nonlinear mixed effects.
#'
#' @inheritParams candidateKey
#'
#' @return One key per name.
#' @export
candidateKeys <- function(x) {
  key <- candidateKey(x)
  lower <- x == tolower(x) & stringi::stri_detect_regex(x, "\\p{Ll}")
  upper <- x == toupper(x) & stringi::stri_detect_regex(x, "\\p{Lu}")
  clash <- key %in% key[lower] & key %in% key[upper]
  key[clash & lower] <- paste0(key[clash & lower], "_lc")
  key
}

#' One row per candidate name, with its counts
#'
#' @param mentions Data frame with `source`, `id`, `cue` and `raw`, as from
#'   [softwareCandidates()] with a `source` column added, and optionally `key`
#'   (from [candidateKeys()] over a wider set of names; computed if absent).
#' @param meta Data frame with `source`, `id` and `year` for every item.
#' @param patterns Patterns as from [readPatterns()], to mark names an existing
#'   family already covers.
#'
#' @return A data frame with one row per key: `key`, `name` (the most frequent
#'   cleaned form), `items` (distinct items), `items_<source>` per source,
#'   `first_year`, `cues` (sorted, "; " separated), `examples` (up to five item
#'   IDs as "source:id") and `known_family` ("" when no existing pattern
#'   matches the name), ordered by items.
#' @export
candidateTable <- function(mentions, meta, patterns) {
  mentions$name <- normaliseCandidate(mentions$raw)
  if (is.null(mentions$key)) mentions$key <- candidateKeys(mentions$name)
  mentions$year <- meta$year[match(paste(mentions$source, mentions$id), paste(meta$source, meta$id))]
  if (anyNA(mentions$year)) stop("mentions of items missing from meta")
  sources <- sort(unique(meta$source))
  rows <- lapply(split(mentions, mentions$key), function(d) {
    items <- unique(d[c("source", "id", "year")])
    r <- data.frame(
      key = d$key[1], name = names(sort(table(d$name), decreasing = TRUE))[1], items = nrow(items),
      first_year = as.integer(min(items$year)), cues = paste(sort(unique(d$cue)), collapse = "; "),
      examples = paste(utils::head(paste(items$source, items$id, sep = ":"), 5), collapse = "; "),
      stringsAsFactors = FALSE
    )
    for (s in sources) r[[paste0("items_", s)]] <- sum(items$source == s)
    r
  })
  tab <- do.call(rbind, rows)
  known <- findSoftware(tab$name, patterns, groups = c("estimation", "auxiliary", "pbpk", "nca", "other"))
  tab$known_family <- vapply(known, function(f) paste(f, collapse = "; "), "")
  tab <- tab[order(-tab$items, tab$key), ]
  rownames(tab) <- NULL
  tab
}

toolGroups <- c("estimation", "auxiliary", "pbpk", "nca")

#' Which tool families meet the inclusion rule
#'
#' A family is in scope for the search when it is decided as a tool
#' (estimation, auxiliary, PBPK or NCA software) and it occurs in at least
#' `minItems` distinct items of one source, or it is on a registry and occurs
#' in at least `registryMinItems` items of all sources together (Niclas,
#' October 2026: a listed name is searched once it is first seen).
#' General-purpose software is not a search family.
#'
#' @param mentions Data frame with `source`, `id` and `key`.
#' @param decisions Data frame with `key`, `decision` and `family`.
#' @param registries Data frame with `key` and `registry`.
#' @param minItems Items needed in one source.
#' @param registryMinItems Items (all sources) needed by a family on a registry.
#'
#' @return One row per tool family: `family`, `group` (the decision most of
#'   its keys have), `items_<source>` (distinct items), `max_items`,
#'   `registries` and `in_scope`.
#' @export
toolInclusion <- function(mentions, decisions, registries, minItems = 3, registryMinItems = 1) {
  tools <- decisions[decisions$decision %in% toolGroups & nzchar(decisions$family), ]
  m <- mentions[mentions$key %in% tools$key, ]
  m$family <- tools$family[match(m$key, tools$key)]
  m <- unique(m[c("source", "id", "family")])
  sources <- sort(unique(mentions$source))
  fams <- sort(unique(tools$family))
  out <- data.frame(family = fams, stringsAsFactors = FALSE)
  out$group <- vapply(fams, function(f) names(sort(table(tools$decision[tools$family == f]), decreasing = TRUE))[1], "")
  for (s in sources) {
    out[[paste0("items_", s)]] <- vapply(fams, function(f) sum(m$family == f & m$source == s), integer(1))
  }
  counts <- as.matrix(out[paste0("items_", sources)])
  out$max_items <- if (length(sources)) apply(counts, 1, max) else 0L
  regKeys <- lapply(fams, function(f) tools$key[tools$family == f])
  listedIn <- function(k) paste(sort(unique(registries$registry[registries$key %in% k])), collapse = "; ")
  out$registries <- vapply(regKeys, listedIn, "")
  total <- rowSums(counts)
  out$in_scope <- out$max_items >= minItems | (nzchar(out$registries) & total >= registryMinItems)
  rownames(out) <- NULL
  out
}

#' Compare the taxonomy with the inclusion rule
#'
#' @param inclusion Output of [toolInclusion()] (`family`, `group`, `in_scope`).
#' @param software `taxonomy/software.csv` (`family`, `group`).
#' @param keep Data frame with `family` and `reason`: taxonomy families kept
#'   although the rule does not include them.
#'
#' @return One row per family needing attention or kept: `family`, `group`,
#'   `action` ("add": in scope, not in the taxonomy; "keep": in the taxonomy
#'   below the rule, with a reason; "review": in the taxonomy below the rule,
#'   no reason) and `reason`. General-purpose families ("other") are left out.
#' @export
taxonomyCheck <- function(inclusion, software, keep) {
  sw <- software[software$group %in% toolGroups, ]
  add <- inclusion[inclusion$in_scope & !inclusion$family %in% sw$family, ]
  below <- sw[!sw$family %in% inclusion$family[inclusion$in_scope], ]
  reason <- keep$reason[match(below$family, keep$family)]
  out <- rbind(
    data.frame(family = add$family, group = add$group, action = rep("add", nrow(add)), reason = rep("", nrow(add))),
    data.frame(
      family = below$family, group = below$group, action = ifelse(is.na(reason), "review", "keep"),
      reason = ifelse(is.na(reason), "", reason)
    )
  )
  rownames(out) <- NULL
  out
}
