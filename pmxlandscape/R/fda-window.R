#' Record rows from FDA applicant-use readings
#'
#' For years without a hand-built decision record (2026 on), the readings of
#' the FDA applicant use classification (`classifications/fda_use`) are the
#' record. One row per drug of the frame: the strongest evidence among its
#' tools (`stated`, then `indirect`, then `template`), in the record's columns.
#' A reading only sees tools the review names, so a drug without one is "No
#' tool identified in review"; whether it had a population PK analysis is not
#' decided.
#'
#' @param decisions Readings with `item_id`, `label` and `value`.
#' @param frame The year's frame, with `appl`, `name` and `date` (`M/D/YYYY`).
#' @param year The approval year.
#'
#' @return A data frame with `drug`, `year`, `application`, `approval_date`,
#'   `sponsor_tool_family`, `evidence_strength` and `category`.
#' @export
fdaReadingRecord <- function(decisions, frame, year) {
  rank <- c(stated = 1, indirect = 2, template = 3)
  strength <- c(stated = "stated", indirect = "indirect", template = "indirect, template phrase only")
  rows <- lapply(seq_len(nrow(frame)), function(i) {
    d <- decisions[decisions$item_id == frame$appl[i] & decisions$value %in% names(rank), ]
    d <- d[order(rank[d$value]), ]
    tool <- if (nrow(d)) d$label[1] else NA_character_
    ev <- if (nrow(d)) unname(strength[d$value[1]]) else NA_character_
    data.frame(
      drug = frame$name[i], year = as.character(year), application = frame$appl[i],
      approval_date = as.Date(frame$date[i], "%m/%d/%Y"), sponsor_tool_family = tool, evidence_strength = ev,
      category = if (is.na(ev)) {
        "No tool identified in review"
      } else if (ev == "stated") {
        "Tool stated"
      } else {
        "Tool stated (indirect)"
      },
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

#' FDA reporting periods: twelve-month periods that follow the date
#'
#' The FDA bars are twelve-month periods (decided 2026-10-20). The latest
#' period ends on the most recent 30 June or 31 December that is at least
#' `lag` full months past `date`, so that the reviews of its approvals are
#' posted; the earlier periods step back a year at a time. The periods
#' therefore run July to June (labelled "2025/26") for half of the year and
#' January to December (labelled "2026") for the other half: on 2026-10-20 the
#' latest is 2025/26, from 2027-04-01 it is 2026, and from 2027-10-01 it is
#' 2026/27.
#'
#' @param date The date the periods are counted on.
#' @param first The earliest start date; periods starting before it are left
#'   out.
#' @param lag Full months between the end of the latest period and `date`.
#'
#' @return A data frame with `label`, `start` and `end`, oldest first.
#' @export
fdaPeriods <- function(date = Sys.Date(), first = as.Date("2016-01-01"), lag = 3) {
  # the first day of the month `lag` months back: the latest end must be before it
  limit <- seq(as.Date(format(date, "%Y-%m-01")), by = paste0("-", lag, " months"), length.out = 2)[2]
  y <- as.integer(format(limit, "%Y"))
  ends <- as.Date(c(sprintf("%d-12-31", y - 1), sprintf("%d-06-30", y), sprintf("%d-12-31", y)))
  end <- max(ends[ends < limit])
  latest <- seq(end + 1, by = "-1 year", length.out = 2)[2]
  starts <- rev(seq(latest, by = "-1 year", length.out = 60))
  starts <- starts[starts >= first]
  nextStart <- vapply(starts, function(s) as.numeric(seq(s, by = "1 year", length.out = 2)[2]), 0)
  ends <- as.Date(nextStart - 1, origin = "1970-01-01")
  sy <- as.integer(format(starts, "%Y"))
  label <- ifelse(format(starts, "%m") == "01", as.character(sy), sprintf("%d/%02d", sy, (sy + 1) %% 100))
  data.frame(label = label, start = starts, end = ends, stringsAsFactors = FALSE)
}

#' The FDA period of each date
#'
#' @param dates Approval dates.
#' @param periods Periods, as from [fdaPeriods()].
#'
#' @return The period label of each date, `NA` for dates outside every period.
#' @export
fdaPeriodOf <- function(dates, periods) {
  i <- findInterval(as.numeric(dates), as.numeric(periods$start))
  out <- periods$label[pmax(i, 1)]
  out[i == 0 | dates > periods$end[pmax(i, 1)]] <- NA
  out
}
