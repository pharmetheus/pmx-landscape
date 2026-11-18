#' Read a pattern file
#'
#' Reads the regular expressions used to find software mentions, in the format
#' of `config/patterns.json`: one entry per pattern with a `group` (estimation,
#' auxiliary, pbpk, nca, other or marker), a `regex` and optionally the tool
#' `family` from `taxonomy/software.csv` that the pattern counts towards.
#'
#' @param file Path to the JSON pattern file.
#'
#' @return A data frame with columns `name`, `group`, `regex` and `family`, in
#'   file order. `family` is the pattern name where the file gives none.
#' @export
readPatterns <- function(file) {
  cfg <- jsonlite::read_json(file)$patterns
  field <- function(f) unname(vapply(cfg, function(p) if (is.null(p[[f]])) NA_character_ else p[[f]], character(1)))
  p <- data.frame(name = names(cfg), group = field("group"), regex = field("regex"), stringsAsFactors = FALSE)
  p$family <- ifelse(is.na(field("family")), p$name, field("family"))
  p
}

#' Years available in an FDA source folder
#'
#' @param fdaDir Path to the FDA source folder (`sources/fda` in the repository).
#'
#' @return The years that have a folder under `data/`, sorted.
#' @export
fdaYears <- function(fdaDir) {
  d <- list.files(file.path(fdaDir, "data"))
  sort(as.integer(d[grepl("^[0-9]+$", d)]))
}

#' Years of the FDA decision record
#'
#' The years the original survey searched and decided (those with a
#' `hits.json`), 2021 to 2025. Later years (2026 on) have text but no record:
#' they are read by the FDA applicant use classification instead.
#'
#' @param fdaDir The FDA source folder.
#'
#' @return The years, sorted.
#' @export
fdaSurveyedYears <- function(fdaDir) {
  y <- fdaYears(fdaDir)
  y[file.exists(file.path(fdaDir, "data", y, "hits.json"))]
}

#' Pages of one FDA review document
#'
#' Splits the text layer of a document at form feeds and replaces each page
#' that has an OCR file (`data/<year>/ocr/<document>_p<nnnn>.txt`) with the
#' OCR text. The text after the last form feed counts as a page, as in the
#' Python pipeline.
#'
#' @inheritParams fdaYears
#' @param year The year folder.
#' @param textFile The document's `text_file` from `docs.json`, relative to the
#'   year folder.
#'
#' @return A data frame with columns `page` (PDF page index, 1-based), `text`
#'   and `src` (`"text"` or `"ocr"`).
#' @export
fdaReadPages <- function(fdaDir, year, textFile) {
  yd <- file.path(fdaDir, "data", year)
  stem <- stringi::stri_sub(basename(textFile), 1, -5)
  pages <- stringi::stri_split_fixed(readText(file.path(yd, textFile)), "\f")[[1]]
  n <- seq_along(pages)
  ocr <- file.path(yd, "ocr", sprintf("%s_p%04d.txt", stem, n))
  hasOcr <- file.exists(ocr)
  pages[hasOcr] <- vapply(ocr[hasOcr], readText, character(1), USE.NAMES = FALSE)
  data.frame(page = n, text = pages, src = ifelse(hasOcr, "ocr", "text"), stringsAsFactors = FALSE)
}

emptyHits <- function() {
  data.frame(
    year = integer(0), appl = character(0), doc = character(0), page = integer(0), src = character(0),
    sw = character(0), group = character(0), snip = character(0), stringsAsFactors = FALSE
  )
}

# All matches of all patterns in one document, ordered as the Python search
# finds them: by page, then pattern, then position.
searchPages <- function(pages, patterns, appl, doc) {
  found <- lapply(seq_len(nrow(patterns)), function(i) {
    loc <- stringi::stri_locate_all_regex(pages$text, patterns$regex[i], omit_no_match = TRUE)
    nMatch <- vapply(loc, nrow, integer(1))
    if (sum(nMatch) == 0) {
      return(NULL)
    }
    m <- do.call(rbind, loc)
    data.frame(row = rep(seq_along(loc), nMatch), pattern = i, start = m[, "start"], end = m[, "end"])
  })
  found <- do.call(rbind, found)
  if (is.null(found)) {
    return(emptyHits()[, -1])
  }
  found <- found[order(found$row, found$pattern, found$start), ]
  txt <- pages$text[found$row]
  from <- pmax(1L, found$start - 220L)
  to <- pmin(stringi::stri_length(txt), found$end + 220L)
  data.frame(
    appl = appl, doc = doc, page = pages$page[found$row], src = pages$src[found$row],
    sw = patterns$name[found$pattern], group = patterns$group[found$pattern],
    snip = collapseSpace(stringi::stri_sub(txt, from, to)), stringsAsFactors = FALSE
  )
}

#' Search FDA review text for software mentions
#'
#' The R version of `05_search.py`. Applies every pattern to every page of
#' every review document listed in `data/<year>/docs.json` and returns one row
#' per match with a snippet of 220 characters either side, whitespace
#' collapsed. It only finds mentions: whether a mention is use by the
#' Applicant, use by the FDA reviewer, a citation or OCR noise is decided by
#' reading the snippet.
#'
#' @inheritParams fdaYears
#' @param years Years to search.
#' @param patterns Patterns as returned by [readPatterns()].
#'
#' @return A data frame with columns `year`, `appl`, `doc`, `page`, `src`,
#'   `sw`, `group` and `snip`, in the order of the Python `hits.json` files.
#' @export
fdaSearch <- function(fdaDir, years = fdaSurveyedYears(fdaDir),
                      patterns = readPatterns(file.path(fdaDir, "config", "patterns.json"))) {
  perYear <- lapply(years, function(y) {
    docs <- jsonlite::read_json(file.path(fdaDir, "data", y, "docs.json"))
    perDoc <- list()
    for (appl in names(docs)) {
      for (r in docs[[appl]]) {
        doc <- stringi::stri_sub(basename(r$text_file), 1, -5)
        perDoc[[length(perDoc) + 1]] <- searchPages(fdaReadPages(fdaDir, y, r$text_file), patterns, appl, doc)
      }
    }
    h <- do.call(rbind, perDoc)
    cbind(year = rep(as.integer(y), nrow(h)), h)
  })
  hits <- do.call(rbind, c(list(emptyHits()), perYear))
  rownames(hits) <- NULL
  hits
}

#' Read stored search hits
#'
#' Reads the `data/<year>/hits.json` files written by `05_search.py`.
#'
#' @inheritParams fdaSearch
#'
#' @return A data frame in the format returned by [fdaSearch()].
#' @export
fdaReadHits <- function(fdaDir, years = fdaSurveyedYears(fdaDir)) {
  perYear <- lapply(years, function(y) {
    h <- jsonlite::fromJSON(file.path(fdaDir, "data", y, "hits.json"))
    if (length(h) == 0) {
      return(NULL)
    }
    data.frame(
      year = rep(as.integer(y), nrow(h)), appl = h$appl, doc = h$doc, page = as.integer(h$page), src = h$src,
      sw = h$sw, group = h$group, snip = h$snip, stringsAsFactors = FALSE
    )
  })
  hits <- do.call(rbind, c(list(emptyHits()), perYear))
  rownames(hits) <- NULL
  hits
}
