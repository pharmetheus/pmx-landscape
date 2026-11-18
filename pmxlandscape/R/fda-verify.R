#' Read the FDA results table
#'
#' @inheritParams fdaYears
#'
#' @return `results/fda_2021_2025_popPK_software.csv`, one row per drug, with
#'   every column as character and empty cells as `""`.
#' @export
fdaReadResults <- function(fdaDir) {
  utils::read.csv(
    file.path(fdaDir, "results", "fda_2021_2025_popPK_software.csv"),
    colClasses = "character", na.strings = character(0), check.names = FALSE, encoding = "UTF-8"
  )
}

#' Read the known exceptions
#'
#' @inheritParams fdaYears
#'
#' @return `config/known_exceptions.json` as a data frame with columns `year`,
#'   `application`, `software` and `reason`.
#' @export
fdaReadExceptions <- function(fdaDir) {
  exc <- jsonlite::read_json(file.path(fdaDir, "config", "known_exceptions.json"))$exceptions
  field <- function(f) vapply(exc, function(e) as.character(e[[f]]), character(1))
  data.frame(
    year = field("year"), application = field("application"), software = field("software"),
    reason = field("reason"), stringsAsFactors = FALSE
  )
}

# Pattern names that verification checks under another name.
verifyFamily <- c(
  "NONMEM (name expanded)" = "NONMEM", "Stan/Torsten" = "Stan", "S-ADAPT/ADAPT" = "S-ADAPT",
  "WinBUGS/NONMEM-BUGS" = "BUGS", "SimBiology/MATLAB" = "MATLAB"
)

#' Check the recorded FDA results against a search
#'
#' The R version of `07_verify.py`. For every drug, compares the estimation,
#' auxiliary and PBPK software that the search found with what the results
#' table records. A software family counts as explained if the first word of
#' its name occurs anywhere in the drug's sponsor software, auxiliary tools,
#' FDA reviewer software, PBPK/NCA or notes columns (case-insensitive), or if
#' it is listed in the known exceptions. NCA and marker hits are not checked.
#'
#' @inheritParams fdaYears
#' @param hits Search hits, as from [fdaSearch()] or [fdaReadHits()].
#' @param results The results table, as from [fdaReadResults()].
#' @param exceptions Known exceptions, as from [fdaReadExceptions()].
#'
#' @return One row per unexplained software family and drug, with columns
#'   `year`, `drug`, `application`, `software` and `pages` (a list of the pages
#'   with a hit). Zero rows means every mention is accounted for.
#' @export
fdaVerify <- function(fdaDir, hits = fdaReadHits(fdaDir), results = fdaReadResults(fdaDir),
                      exceptions = fdaReadExceptions(fdaDir)) {
  hits <- hits[hits$group %in% c("estimation", "auxiliary", "pbpk"), , drop = FALSE]
  hits$family <- ifelse(hits$sw %in% names(verifyFamily), verifyFamily[hits$sw], hits$sw)
  exceptionKeys <- paste(exceptions$year, exceptions$application, exceptions$software, sep = "\r")
  out <- list()
  for (year in sort(unique(results$year), method = "radix")) {
    hitsYear <- hits[as.character(hits$year) == year, , drop = FALSE]
    rows <- results[results$year == year, , drop = FALSE]
    for (i in seq_len(nrow(rows))) {
      r <- rows[i, ]
      recorded <- stringi::stri_trans_tolower(paste(
        r$sponsor_popPK_software, r$sponsor_auxiliary_tools, r$fda_reviewer_software, r$pbpk_nca, r$notes
      ))
      hitsDrug <- hitsYear[hitsYear$appl == r$application, , drop = FALSE]
      for (family in unique(hitsDrug$family)) {
        key <- stringi::stri_trans_tolower(stringi::stri_extract_first_regex(family, "\\S+"))
        if (stringi::stri_detect_fixed(recorded, key) ||
          paste(year, r$application, family, sep = "\r") %in% exceptionKeys) {
          next
        }
        out[[length(out) + 1]] <- list(
          year = year, drug = r$drug, application = r$application, software = family,
          pages = sort(unique(hitsDrug$page[hitsDrug$family == family]))
        )
      }
    }
  }
  unexplained <- data.frame(
    year = vapply(out, `[[`, character(1), "year"),
    drug = vapply(out, `[[`, character(1), "drug"),
    application = vapply(out, `[[`, character(1), "application"),
    software = vapply(out, `[[`, character(1), "software"),
    stringsAsFactors = FALSE
  )
  unexplained$pages <- lapply(out, `[[`, "pages")
  unexplained
}
