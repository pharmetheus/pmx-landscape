#' Read affiliation rules
#'
#' @param file Path to the rules CSV (`taxonomy/affiliation_rules.csv` in the
#'   repository), with columns `category`, `pattern` and `note`.
#'
#' @return The rules as a data frame, in file order.
#' @export
readAffiliationRules <- function(file) {
  utils::read.csv(file, colClasses = "character", na.strings = character(0), encoding = "UTF-8")
}

#' Classify affiliations
#'
#' Assigns each affiliation the category of the first rule whose pattern
#' matches it (case-insensitive), so the order of the rules decides conflicts.
#' Email addresses are removed first.
#'
#' @param x Character vector of affiliations.
#' @param rules Rules as returned by [readAffiliationRules()].
#'
#' @return The category for each affiliation (industry, academia, regulator or
#'   vendor in the shared rules), `"unclassified"` where no rule matches, and
#'   `NA` where the affiliation is missing.
#' @export
classifyAffiliation <- function(x, rules) {
  out <- rep(NA_character_, length(x))
  todo <- !is.na(x) & x != ""
  # Email addresses name people, not organisations ("taro.takeda@...")
  x <- stringi::stri_replace_all_regex(x, "\\S+@\\S+", " ")
  for (i in seq_len(nrow(rules))) {
    hit <- todo & is.na(out) & stringi::stri_detect_regex(x, rules$pattern[i], case_insensitive = TRUE) %in% TRUE
    out[hit] <- rules$category[i]
  }
  out[todo & is.na(out)] <- "unclassified"
  out
}

#' Affiliation of the first author
#'
#' Picks the affiliation of the first author from an author line and an
#' affiliation line in the numbered styles used by PAGE abstracts:
#' `"A. Author (1,2), B. Other (3)"` with `"(1) Uni X, (2) Company Y, (3) Z"`,
#' or the same with plain digits, `"A. Author1,2, B. Other3"` with
#' `"1Uni X, 2Company Y; 3Z"`.
#'
#' The first number in the author line is taken as the first author's
#' affiliation number n (a run of digits such as `(12)` that is not a marker
#' is read as its first digit), and the affiliation is the text from marker n
#' up to marker n + 1. Markers are `(k)`, `(k, m)`, `[k]`, `k)`, `k,` or a bare `k`
#' before a letter. Looking only for those two markers keeps postcodes and
#' street numbers from being read as markers. Where marker n is missing, the
#' affiliation line up to marker 2 is used, so a later author's institution
#' cannot decide the class. A number that comes after the start of the next
#' author's name (a comma followed by a capital letter) is not taken as the
#' first author's.
#'
#' @param authors,affiliations Character vectors of the same length.
#'
#' @return The first author's affiliation for each element, `NA` where either
#'   input is missing.
#' @export
mainAffiliation <- function(authors, affiliations) {
  marker <- affMarker
  one <- function(au, af) {
    if (is.na(au) || is.na(af)) {
      return(NA_character_)
    }
    digits <- stringi::stri_extract_first_regex(au, "\\d+")
    # A number after the start of the next author's name is not the first author's
    before <- stringi::stri_extract_first_regex(au, "^\\D*")
    if (!is.na(digits) && stringi::stri_detect_regex(before, ",\\s*\\p{Lu}")) digits <- NA_character_
    n <- if (is.na(digits)) 1L else as.integer(digits)
    if (!is.na(digits) && nchar(digits) > 1 && !stringi::stri_detect_regex(af, marker(n))) {
      n <- as.integer(substr(digits, 1, 1))
    }
    from <- stringi::stri_locate_first_regex(af, marker(n))
    if (is.na(from[1, "start"])) {
      second <- stringi::stri_locate_first_regex(af, marker(2L))[1, "start"]
      rest <- if (is.na(second)) af else stringi::stri_sub(af, 1L, second - 1L)
      return(stringi::stri_replace_all_regex(rest, "^[\\s,;.]+|[\\s,;]+$", ""))
    }
    rest <- stringi::stri_sub(af, from[1, "end"] + 1L)
    to <- stringi::stri_locate_first_regex(rest, marker(n + 1L))[1, "start"]
    if (!is.na(to)) rest <- stringi::stri_sub(rest, 1L, to - 1L)
    stringi::stri_replace_all_regex(rest, "^[\\s,;.]+|[\\s,;]+$", "")
  }
  unname(mapply(one, authors, affiliations, USE.NAMES = FALSE))
}

# Marker k in an affiliation line: "(k)", "(k, m)", "[k]", "k)", "k," or a bare k before a letter.
affMarker <- function(k) {
  sprintf(
    paste0(
      "\\(\\s*%1$d\\s*(?:,[^)]*)?\\)|\\[\\s*%1$d\\s*(?:,[^\\]]*)?\\]|",
      "(?:^|(?<=[\\s,;.]))%1$d(?:\\)|[,.])?(?=\\s*\\p{L})"
    ),
    k
  )
}

# The first author's affiliation numbers ("(1,2)", "1,2", "[2,3]"); empty if the first author has none.
firstAuthorNumbers <- function(au) {
  if (is.na(au)) {
    return(integer(0))
  }
  before <- stringi::stri_extract_first_regex(au, "^\\D*")
  if (stringi::stri_detect_regex(before, ",\\s*\\p{Lu}")) {
    return(integer(0))
  }
  group <- stringi::stri_extract_first_regex(au, "\\d+(?:\\s*,\\s*\\d+)*")
  if (is.na(group)) integer(0) else as.integer(strsplit(gsub("\\s", "", group), ",")[[1]])
}

# The text of affiliation k, or NA if the line has no marker k.
affiliationPiece <- function(af, k) {
  from <- stringi::stri_locate_first_regex(af, affMarker(k))
  if (is.na(from[1, "start"])) {
    return(NA_character_)
  }
  rest <- stringi::stri_sub(af, from[1, "end"] + 1L)
  to <- stringi::stri_locate_first_regex(rest, affMarker(k + 1L))[1, "start"]
  if (!is.na(to)) rest <- stringi::stri_sub(rest, 1L, to - 1L)
  stringi::stri_replace_all_regex(rest, "^[\\s,;.:]+|[\\s,;:]+$", "")
}

#' Every institution in a PAGE affiliation line
#'
#' Splits the affiliation line of a PAGE abstract into its institutions: by
#' the numbered markers ("(1)", "[1]", "1)") where the line has them, else at
#' semicolons. Which author holds which affiliation is not kept.
#'
#' @param affiliations The affiliation line (one string).
#'
#' @return A character vector of institutions, empty for a missing line.
#' @export
pageAffiliations <- function(affiliations) {
  if (length(affiliations) != 1) stop("pageAffiliations() takes one affiliation line")
  if (is.na(affiliations) || !nzchar(stringi::stri_trim_both(affiliations))) {
    return(character(0))
  }
  pieces <- character(0)
  k <- 1L
  while (!is.na(p <- affiliationPiece(affiliations, k))) {
    pieces <- c(pieces, p)
    k <- k + 1L
  }
  if (!length(pieces)) pieces <- stringi::stri_trim_both(strsplit(affiliations, ";", fixed = TRUE)[[1]])
  unique(pieces[pieces != ""])
}

#' Classify the first author's affiliation, with fallbacks
#'
#' Classifies the piece [mainAffiliation()] picks. Where that piece does not
#' decide the class (it is unclassified), the next steps are tried in order:
#' the first author's other numbered affiliations; the piece joined with any
#' text before the first marker (a shared prefix such as "Company X: (1) City
#' A; (2) City B", or the institution in "Company X, Dept A (1), Dept B (2)");
#' and, last, the whole affiliation line (an institution named after the last
#' numbered department). Only the last step can pick up a co-author's
#' institution, so the step is returned for counting.
#'
#' @inheritParams mainAffiliation
#' @param rules Rules as returned by [readAffiliationRules()].
#'
#' @return A data frame with `affiliation` (the text classified),
#'   `affiliation_type` and `step` (`"first affiliation"`, `"other
#'   affiliation"`, `"shared prefix"`, `"whole line"`, or `NA` where the
#'   affiliation is missing or no step decides).
#' @export
classifyFirstAuthor <- function(authors, affiliations, rules) {
  decided <- function(x) {
    type <- classifyAffiliation(x, rules)
    if (!is.na(type) && type != "unclassified") type else NA_character_
  }
  one <- function(au, af) {
    piece <- mainAffiliation(au, af)
    if (is.na(piece)) {
      return(c(NA_character_, NA_character_, NA_character_))
    }
    type <- decided(piece)
    if (!is.na(type)) {
      return(c(piece, type, "first affiliation"))
    }
    for (k in utils::tail(firstAuthorNumbers(au), -1)) {
      other <- affiliationPiece(af, k)
      if (!is.na(other) && !is.na(type <- decided(other))) {
        return(c(other, type, "other affiliation"))
      }
    }
    first <- stringi::stri_locate_first_regex(af, "\\(\\s*\\d+\\s*\\)|\\[\\s*\\d+\\s*\\]")[1, "start"]
    if (!is.na(first) && first > 1) {
      joined <- paste(stringi::stri_sub(af, 1L, first - 1L), piece)
      if (!is.na(type <- decided(joined))) {
        return(c(joined, type, "shared prefix"))
      }
    }
    if (!is.na(type <- decided(af))) {
      return(c(af, type, "whole line"))
    }
    c(piece, classifyAffiliation(piece, rules), NA_character_)
  }
  out <- mapply(one, authors, affiliations, USE.NAMES = FALSE)
  data.frame(affiliation = out[1, ], affiliation_type = out[2, ], step = out[3, ], stringsAsFactors = FALSE)
}

#' Affiliation tags of corpus items
#'
#' The affiliation classification (`classifications/affiliation`), by rules
#' only. For each item: the first author's affiliation type and organisation,
#' whether any author is from industry or from a CRO, and the organisations
#' of all authors. PubMed and Europe PMC items are read from their
#' `author_affiliations` sections (one per author, in order): the first
#' author's affiliation is the first listed one, up to the first semicolon,
#' and every author's affiliations are split into institutions as in
#' [pubmedAffiliations()]. PAGE items are read from their `authors` and
#' `affiliations` lines with [classifyFirstAuthor()] and [pageAffiliations()].
#'
#' An organisation is the comma-separated segment of an institution that holds
#' the match of the rule deciding its type (the whole institution where no
#' rule decides), without e-mail addresses. Author names are never stored: a
#' segment is withheld when its rule says so (`organisation` is `withheld` in
#' the rules: consultancies, often named after a person) or when it contains
#' a word of the item's author list (a capitalised word of three or more
#' letters, group words left out). For rules that name organisations
#' (`organisation` is `named`), the name the rule matched is also given.
#'
#' @param sections A corpus section table with text, for one source.
#' @param rules Rules as returned by [readAffiliationRules()], with the
#'   `organisation` column.
#' @param source `"PAGE"`, `"PubMed"` or `"Europe PMC"`.
#' @param text If `TRUE`, also return `first_author_affiliation`, the text the
#'   first author's type was decided from (for checking by reading; it may
#'   hold names and addresses, so it is never written to a committed file).
#'
#' @return A data frame with one row per item: `source`, `item_id`,
#'   `first_author_type` (a rule category, `"unclassified"` or `"no
#'   affiliation"`), `first_author_organisation`, `first_author_named` (the
#'   name a naming rule matched in it, `NA` otherwise), `any_industry`, `any_cro`,
#'   `organisations` and `named_organisations` (distinct, joined by "; ", `NA`
#'   if none) and `withheld` (organisations not stored).
#' @export
affiliationTags <- function(sections, rules, source, text = FALSE) {
  ids <- unique(sections$item_id)
  get <- function(id, section) {
    s <- sections[sections$item_id == id & sections$section == section, ]
    s$text[order(s$part, s$seq)]
  }
  rows <- lapply(ids, function(id) {
    authors <- get(id, "authors")
    if (source == "PAGE") {
      line <- get(id, "affiliations")
      line <- if (length(line)) line[1] else NA_character_
      first <- NA_character_
      if (length(authors) && !is.na(line)) first <- classifyFirstAuthor(authors[1], line, rules)$affiliation
      inst <- pageAffiliations(line)
    } else {
      aa <- get(id, "author_affiliations")
      first <- if (length(aa)) strsplit(aa[1], "\n", fixed = TRUE)[[1]][1] else NA_character_
      if (!is.na(first)) first <- stringi::stri_trim_both(sub(";.*$", "", collapseSpace(first)))
      inst <- splitInstitutions(unlist(strsplit(aa, "\n", fixed = TRUE)))
    }
    if (!is.na(first) && !nzchar(first)) first <- NA_character_
    names <- authorWords(authors)
    org <- function(x) {
      rule <- affiliationRule(x, rules)
      seg <- organisationOf(x, rule, rules)
      keep <- !is.na(seg) & nzchar(seg)
      out <- data.frame(segment = seg, rule = rule, type = classifyAffiliation(x, rules), keep = keep)
      withheld <- (!is.na(rule) & rules$organisation[pmax(rule, 1)] == "withheld") |
        vapply(seg, function(s) {
          length(names) > 0 && any(stringi::stri_detect_regex(s, paste0("\\b\\Q", names, "\\E\\b")))
        }, logical(1))
      out$keep <- keep & !withheld
      out$withheld <- keep & withheld
      out$named <- ifelse(!is.na(rule) & rules$organisation[pmax(rule, 1)] == "named",
        stringi::stri_extract_first_regex(stringi::stri_replace_all_regex(x, "\\S+@\\S+", " "),
          rules$pattern[pmax(rule, 1)],
          case_insensitive = TRUE
        ), NA_character_
      )
      out
    }
    f <- if (is.na(first)) NULL else org(first)
    a <- if (length(inst)) org(inst) else NULL
    join <- function(x) {
      x <- unique(x[!is.na(x) & nzchar(x)])
      if (length(x)) paste(x, collapse = "; ") else NA_character_
    }
    data.frame(
      source = source, item_id = id,
      first_author_type = if (is.null(f)) "no affiliation" else f$type,
      first_author_organisation = if (is.null(f) || !f$keep) NA_character_ else f$segment,
      first_author_named = if (is.null(f) || !f$keep) NA_character_ else f$named,
      any_industry = !is.null(a) && any(a$type %in% "industry"),
      any_cro = !is.null(a) && any(a$type %in% "CRO"),
      organisations = if (is.null(a)) NA_character_ else join(a$segment[a$keep]),
      named_organisations = if (is.null(a)) NA_character_ else join(a$named),
      withheld = length(unique(c(if (!is.null(a)) a$segment[a$withheld], if (!is.null(f)) f$segment[f$withheld]))),
      first_author_affiliation = first,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  if (!text) out$first_author_affiliation <- NULL
  out
}

# Index of the rule deciding each affiliation's class (as classifyAffiliation()), NA if none.
affiliationRule <- function(x, rules) {
  out <- rep(NA_integer_, length(x))
  todo <- !is.na(x) & x != ""
  x <- stringi::stri_replace_all_regex(x, "\\S+@\\S+", " ")
  for (i in seq_len(nrow(rules))) {
    hit <- todo & is.na(out) & stringi::stri_detect_regex(x, rules$pattern[i], case_insensitive = TRUE) %in% TRUE
    out[hit] <- i
  }
  out
}

# The comma-separated segment of each affiliation that holds its rule's match, or the whole
# affiliation where no rule decides; e-mail addresses and trailing punctuation removed.
organisationOf <- function(x, rule, rules) {
  vapply(seq_along(x), function(j) {
    if (is.na(x[j])) {
      return(NA_character_)
    }
    s <- stringi::stri_trim_both(collapseSpace(stringi::stri_replace_all_regex(x[j], "\\S+@\\S+", " ")))
    if (!is.na(rule[j])) {
      # the segments the rule matches; a department, faculty or school gives way to the
      # institution it belongs to when that is matched too
      seg <- stringi::stri_trim_both(strsplit(s, ",", fixed = TRUE)[[1]])
      hit <- seg[stringi::stri_detect_regex(seg, rules$pattern[rule[j]], case_insensitive = TRUE)]
      unit <- "^(?:Department|Dept|Faculty|Faculté|Facultad|Faculdade|School|Division|Unit|Laboratory|Lab|Section)\\b"
      top <- hit[!stringi::stri_detect_regex(hit, unit, case_insensitive = TRUE)]
      pick <- if (length(top)) top[1] else if (length(hit)) hit[1] else NA_character_
      if (!is.na(pick)) {
        # a legal form on its own ("Inc.") belongs to the name before it
        k <- match(pick, seg)
        suffix <- paste0(
          "^(?:Inc|Ltd|LLC|GmbH|AG|S\\.?A\\.?S?|AB|A/S|B\\.?V|N\\.?V|Corp|plc|Co|S\\.?p\\.?A|S\\.?r\\.?l|K\\.?K)",
          "\\.?$"
        )
        if (k > 1 && stringi::stri_detect_regex(pick, suffix, case_insensitive = TRUE)) {
          pick <- paste(seg[k - 1], pick, sep = ", ")
        }
        s <- pick
      } else {
        at <- stringi::stri_locate_first_regex(s, rules$pattern[rule[j]], case_insensitive = TRUE)[1, "start"]
        commas <- stringi::stri_locate_all_fixed(s, ",")[[1]][, "start"]
        commas <- commas[!is.na(commas)]
        from <- max(c(0L, commas[commas < at])) + 1L
        to <- min(c(nchar(s) + 1L, commas[commas >= at])) - 1L
        s <- stringi::stri_sub(s, from, to)
      }
    }
    stringi::stri_replace_all_regex(stringi::stri_trim_both(s), "[\\s.,;:]+$", "")
  }, character(1))
}

# Capitalised words of three or more letters in an author list, without group words: what a
# stored organisation must not contain.
authorWords <- function(authors) {
  w <- unlist(stringi::stri_extract_all_regex(authors, "\\p{Lu}\\p{Ll}[\\p{L}'-]+"))
  group <- c(
    "The", "And", "For", "Group", "Groups", "Study", "Studies", "Consortium", "Investigators", "Network", "Team",
    "Collaboration", "Collaborative", "Working", "Society", "Committee", "Trial", "Trials", "Program", "Programme"
  )
  unique(setdiff(w[!is.na(w)], group))
}
