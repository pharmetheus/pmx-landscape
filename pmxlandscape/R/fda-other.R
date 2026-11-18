#' Add evidence from outside the FDA review for drugs whose review names no tool
#'
#' For the drugs recorded as "popPK present, software not stated", other
#' documents of the same submission (the other FDA review documents, or
#' another regulator's assessment report) can name the sponsor's software.
#' The decisions (`sources/fda/other_reviews/decisions.csv`) are applied on
#' top of the FDA review record, which itself is never changed, so the
#' reproduction from the cached review text still holds.
#'
#' @param results The FDA results table, as from [fdaReadResults()].
#' @param decisions Data frame with `application`, `family`,
#'   `evidence_strength` (`stated` or `indirect`), `source`, `document`,
#'   `page` and `reason`, one row per drug.
#'
#' @return `results` with the decided drugs moved to "Tool stated" or "Tool
#'   stated (indirect)", their tool and evidence pages filled in, and a new
#'   column `evidence_source` ("FDA review" for every other drug).
#' @export
fdaApplyOtherEvidence <- function(results, decisions) {
  if (anyDuplicated(decisions$application)) stop("each drug may have only one decision; decide it once")
  bad <- setdiff(decisions$evidence_strength, c("stated", "indirect"))
  if (length(bad)) stop("unknown evidence_strength: ", paste(bad, collapse = ", "))
  i <- match(decisions$application, results$application)
  if (anyNA(i)) stop("applications not in the FDA results: ", paste(decisions$application[is.na(i)], collapse = ", "))
  notStated <- results$category[i] == "popPK present, software not stated"
  if (!all(notStated)) {
    stop(
      "only drugs whose review names no tool can take outside evidence; ",
      "not stated in the FDA results is required for: ", paste(results$drug[i[!notStated]], collapse = ", ")
    )
  }
  results$evidence_source <- "FDA review"
  results$sponsor_tool_family[i] <- decisions$family
  results$sponsor_popPK_software[i] <- decisions$family
  results$evidence_strength[i] <- decisions$evidence_strength
  results$category[i] <- ifelse(decisions$evidence_strength == "stated", "Tool stated", "Tool stated (indirect)")
  results$sponsor_evidence_pages[i] <- paste0(decisions$source, " ", decisions$document, " p", decisions$page)
  results$evidence_source[i] <- decisions$source
  results
}

#' Revise the evidence strength of drugs in the FDA review record
#'
#' Decisions taken after the record was made, on the same review text, are
#' kept in `sources/fda/results/record_revisions.csv` and applied on top of
#' the record, which itself is never changed (so the reproduction from the
#' cached review text still holds). A revision can raise a drug from "not
#' stated" or "template phrase only" to indirect or stated, or add evidence
#' pages without changing the strength. Each row names the strength it was
#' written against (`from`), and a revision whose `from` no longer matches
#' the record is refused.
#'
#' @param results The FDA results table, as from [fdaReadResults()].
#' @param revisions Data frame with `application`, `family`, `from` (the
#'   record's evidence strength, `""` for a drug without a named tool), `to`
#'   (`stated` or `indirect`), `pages` (the evidence, added to the record's)
#'   and `reason`, one row per drug.
#'
#' @return `results` with the revised drugs' tool, strength, category and
#'   evidence pages updated, and a new column `revision` holding the reason
#'   (`""` for every other drug).
#' @export
fdaApplyRevisions <- function(results, revisions) {
  if (anyDuplicated(revisions$application)) stop("each drug may have only one revision; decide it once")
  bad <- setdiff(revisions$to, c("stated", "indirect"))
  if (length(bad)) stop("unknown evidence strength: ", paste(bad, collapse = ", "))
  i <- match(revisions$application, results$application)
  if (anyNA(i)) stop("applications not in the FDA results: ", paste(revisions$application[is.na(i)], collapse = ", "))
  current <- results$evidence_strength[i]
  drift <- current != revisions$from
  if (any(drift)) {
    stop("revision written against another state of the record: ", paste0(
      results$drug[i[drift]], " (revision from '", revisions$from[drift], "', the record has '", current[drift], "')",
      collapse = "; "
    ))
  }
  tool <- results$sponsor_tool_family[i]
  clash <- nzchar(tool) & tool != revisions$family
  if (any(clash)) stop("the record names another tool for: ", paste(results$drug[i[clash]], collapse = ", "))
  results$revision <- ""
  results$sponsor_tool_family[i] <- revisions$family
  software <- results$sponsor_popPK_software[i]
  results$sponsor_popPK_software[i] <- ifelse(nzchar(software), software, revisions$family)
  results$evidence_strength[i] <- revisions$to
  results$category[i] <- ifelse(revisions$to == "stated", "Tool stated", "Tool stated (indirect)")
  old <- results$sponsor_evidence_pages[i]
  results$sponsor_evidence_pages[i] <- ifelse(nzchar(old), paste(old, revisions$pages, sep = "; "), revisions$pages)
  results$revision[i] <- revisions$reason
  results
}
