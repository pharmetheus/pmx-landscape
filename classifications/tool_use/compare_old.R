# The tool use tags against the earlier PAGE role reading (sources/page/role_decisions.csv)
#
# Run from classifications/tool_use/ after run.R tags: Rscript compare_old.R
# Writes old_comparison.csv (old value by new value, PAGE) and page_change.csv (abstracts
# using each estimation family, 2016 to 2026, by the old reading and by the new tags, outside the
# Software Demonstration session).

pkgload::load_all("../../pmxlandscape", quiet = TRUE)
tags <- read.csv("tags.csv", colClasses = "character")
old <- read.csv("../../sources/page/role_decisions.csv", colClasses = "character")
pairs <- do.call(rbind, lapply(seq_len(nrow(old)), function(i) {
  x <- trimws(strsplit(old$roles[i], ";", fixed = TRUE)[[1]])
  data.frame(source = "PAGE", item_id = old$abstract_no[i], label = sub("\\s*=.*$", "", x), value = sub("^.*=\\s*", "", x))
}))
a <- agreement(pairs, tags)
both <- merge(pairs, tags[c("source", "item_id", "label", "value", "method")], by = c("source", "item_id", "label"),
  suffixes = c("_old", "_new"))
tab <- as.data.frame(table(old = both$value_old, new = both$value_new))
write.csv(tab, "old_comparison.csv", row.names = FALSE)
cat("PAGE pairs in both:", a$compared, "same value:", a$agree, sprintf("(%.1f%%, kappa %.2f)\n", 100 * a$share, a$kappa))
print(table(old = both$value_old, new = both$value_new))

page <- read.csv("../../sources/page/results/page_abstracts.csv")
recent <- function(p) p[p$year >= 2016 & !p$software_demo, ]
oldUse <- recent(pageUsedTools(page, old))
newUse <- recent(pageToolUse(page, tags))
count <- function(p) {
  tools <- ifelse(nzchar(p$estimation), p$estimation, ifelse(is.na(p$pdf_estimation), "", p$pdf_estimation))
  t <- unlist(strsplit(tools[nzchar(tools)], "; ", fixed = TRUE))
  table(t)
}
o <- count(oldUse)
n <- count(newUse)
fam <- union(names(o), names(n))
ch <- data.frame(family = fam, old = as.integer(o[fam]), new = as.integer(n[fam]))
ch[is.na(ch)] <- 0L
ch <- ch[order(-ch$new), ]
ch$change <- ch$new - ch$old
write.csv(ch, "page_change.csv", row.names = FALSE)
cat("\nabstracts using any estimation tool, 2016 to 2026: old",
  sum(nzchar(oldUse$estimation) | nzchar(ifelse(is.na(oldUse$pdf_estimation), "", oldUse$pdf_estimation))),
  "new", sum(nzchar(newUse$estimation) | nzchar(ifelse(is.na(newUse$pdf_estimation), "", newUse$pdf_estimation))), "\n")
print(ch, row.names = FALSE)
