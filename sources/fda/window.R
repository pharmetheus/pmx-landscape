# The FDA periods (decided 2026-10-20): twelve-month periods, the latest ending on the most
# recent 30 June or 31 December at least three months before the run, so that the reviews of its
# approvals are posted (fdaPeriods()). Approvals of 2021 to 2025 come from the decision record
# (with its revisions and the other documents' evidence, as in the README); the other years from
# the FDA applicant use reading (classifications/fda_use), which is their record, with the
# population PK reading (classifications/fda_poppk) splitting the drugs whose review names no tool
# into "software not stated" and "no popPK analysis". Drugs without posted reviews are "Review not
# posted".
#
# Run from sources/fda/: Rscript window.R [date]   (default today)
# Writes results/fda_periods.csv (one row per drug in a period) and prints the summary.

pkgload::load_all("../../pmxlandscape", quiet = TRUE)

on <- commandArgs(trailingOnly = TRUE)[1]
on <- if (is.na(on)) Sys.Date() else as.Date(on)
periods <- fdaPeriods(on, first = as.Date("2020-07-01"))
dates <- do.call(rbind, lapply(fdaYears("."), function(y) {
  f <- jsonlite::fromJSON(file.path("data", y, "frame.json"))
  data.frame(application = f$appl, approval_date = as.Date(f$date, "%m/%d/%Y"))
}))
rec <- fdaApplyOtherEvidence(
  fdaApplyRevisions(fdaReadResults("."), read.csv("results/record_revisions.csv", colClasses = "character")),
  read.csv("other_reviews/decisions.csv", colClasses = "character")
)
rec$approval_date <- dates$approval_date[match(rec$application, dates$application)]
rec$from <- "decision record"
cols <- c("drug", "year", "application", "approval_date", "sponsor_tool_family", "evidence_strength", "category", "from")
d <- read.csv("../../classifications/fda_use/decisions.csv", colClasses = "character")
later <- setdiff(fdaYears("."), as.integer(unique(rec$year)))
pk <- read.csv("../../classifications/fda_poppk/decisions.csv", colClasses = "character")
new <- do.call(rbind, lapply(later, function(y) {
  f <- jsonlite::fromJSON(file.path("data", y, "frame.json"))
  f <- f[!is.na(f$appl), ]
  docs <- jsonlite::read_json(file.path("data", y, "docs.json"))
  posted <- f$appl %in% names(docs)[lengths(docs) > 0]
  r <- cbind(fdaReadingRecord(d, f, y), from = "fda_use reading")
  none <- r$category == "No tool identified in review"
  v <- pk$value[match(r$application, pk$item_id)]
  r$category[none & v %in% "present"] <- "popPK present, software not stated"
  r$category[none & v %in% "absent"] <- "No popPK analysis in review"
  r$category[!posted] <- "Review not posted"
  r$from[none & !is.na(v)] <- "fda_use and fda_poppk readings"
  r
}))
all <- rbind(rec[cols], new[cols])
all$period <- fdaPeriodOf(all$approval_date, periods)
win <- all[!is.na(all$period), ]
win <- win[order(win$approval_date), ]
write.csv(win, "results/fda_periods.csv", row.names = FALSE, na = "")
cat(sprintf("periods counted on %s: %s; %d drugs\n", on, paste(periods$label, collapse = ", "), nrow(win)))
print(table(win$period, win$category))
print(table(win$period, ifelse(startsWith(win$category, "Tool stated"), win$sponsor_tool_family, "-")))
