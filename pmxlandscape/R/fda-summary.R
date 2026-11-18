#' Count tables for the FDA results
#'
#' The R version of `08_summarize.py`. Tabulates the sponsor category of every
#' drug by year. Drugs with a stated tool are labelled by tool family and
#' evidence strength (for example "NONMEM, indirect"); the others by category.
#'
#' @inheritParams fdaVerify
#' @param file Optional path. If given, the sponsor table is written there in
#'   the format of `results/summary_sponsor_by_year.csv`.
#'
#' @return A list with `sponsorByYear` (the table, with a `Total` row and the
#'   share of all drugs) and `sponsorTools` (drugs per sponsor tool family
#'   among drugs with an identifiable tool, with `share` in percent).
#'   Invisibly if `file` is given. The FDA reviewer's tools are not tallied:
#'   they are recorded only to tell the reviewer's use from the applicant's.
#' @export
fdaSummary <- function(fdaDir, results = fdaReadResults(fdaDir), file = NULL) {
  stated <- startsWith(results$category, "Tool stated")
  label <- ifelse(stated, paste0(results$sponsor_tool_family, ", ", results$evidence_strength), results$category)
  years <- sort(unique(results$year), method = "radix")
  keys <- sort(unique(label), method = "radix")
  count <- function(x) as.integer(table(factor(x, levels = keys)))

  tab <- data.frame(sponsor_category = keys, stringsAsFactors = FALSE)
  for (y in years) tab[[y]] <- count(label[results$year == y])
  tab$All <- count(label)
  tab$share_all <- sprintf("%.1f%%", 100 * tab$All / nrow(results))
  total <- c(list(sponsor_category = "Total"), lapply(tab[c(years, "All")], sum), list(share_all = "100%"))
  tab <- rbind(tab, as.data.frame(total, check.names = FALSE, stringsAsFactors = FALSE))

  sponsorTools <- countInOrder(results$sponsor_tool_family[stated])
  sponsorTools$share <- 100 * sponsorTools$n / sum(stated)
  summary <- list(sponsorByYear = tab, sponsorTools = sponsorTools)

  if (is.null(file)) {
    return(summary)
  }
  lines <- c(csvLine(names(tab)), vapply(seq_len(nrow(tab)), function(i) csvLine(unlist(tab[i, ])), character(1)))
  writeBin(charToRaw(enc2utf8(paste0(lines, "\r\n", collapse = ""))), file)
  invisible(summary)
}
