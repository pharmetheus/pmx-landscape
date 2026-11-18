# The standard tables of a run (classifications/README.md; Niclas, 2026-10-19): how much the rules
# decide, what the published numbers would be from rules alone, how each tag was decided, what
# changed against the previous version, and the tools the readers found outside the taxonomy
#
# Run from classifications/tool_use/ after run.R tags. Writes report_coverage.csv,
# report_bounds.csv, report_methods.csv, report_versions.csv and report_other_tools.csv.

tags <- read.csv("tags.csv", colClasses = "character")
tags$method[tags$method == "adjudication"] <- "adjudication"

# rule coverage by source and value: candidates, decided by a rule, and the values the rules gave
cov <- do.call(rbind, lapply(split(tags, tags$source), function(d) {
  data.frame(source = d$source[1], candidates = nrow(d), by_rule = sum(d$method == "rule"),
    share_by_rule = round(mean(d$method == "rule"), 3), by_reading = sum(d$method == "ai"),
    by_adjudication = sum(d$method == "adjudication"),
    used = sum(d$value == "used"), used_by_rule = sum(d$value == "used" & d$method == "rule"))
}))
write.csv(cov, "report_coverage.csv", row.names = FALSE)

# bounds: items using each family, from rules alone (undecided as not used, and as used) against
# rules plus reading
fam <- names(sort(table(tags$label[tags$value == "used"]), decreasing = TRUE))[1:6]
bounds <- do.call(rbind, lapply(split(tags, tags$source), function(d) {
  do.call(rbind, lapply(fam, function(f) {
    x <- d[d$label == f, ]
    data.frame(source = d$source[1], family = f, candidates = nrow(x),
      used_rules_only_low = sum(x$method == "rule" & x$value == "used"),
      used_rules_only_high = sum(x$method == "rule" & x$value == "used") + sum(x$method != "rule"),
      used = sum(x$value == "used"))
  }))
}))
write.csv(bounds, "report_bounds.csv", row.names = FALSE)

# how the tags were decided: exactly reproducible (rule), recorded reading, settled by Claude
meth <- as.data.frame.matrix(table(tags$source, tags$method))
meth <- cbind(source = rownames(meth), meth, share_reproducible = round(meth$rule / rowSums(meth), 3))
write.csv(meth, "report_methods.csv", row.names = FALSE)

# version 4 against version 5, on the candidates both have
old <- read.csv(pipe("git show 1454241:classifications/tool_use/tags.csv"), colClasses = "character")
k <- function(d) paste(d$source, d$item_id, d$label)
both <- merge(old[c("source", "item_id", "label", "value")], tags[c("source", "item_id", "label", "value")],
  by = c("source", "item_id", "label"), suffixes = c("_v4", "_v5"))
ver <- do.call(rbind, lapply(split(both, both$source), function(d) {
  data.frame(source = d$source[1], compared = nrow(d), same = sum(d$value_v4 == d$value_v5),
    used_v4 = sum(d$value_v4 == "used"), used_v5 = sum(d$value_v5 == "used"))
}))
ver$new_candidates <- as.vector(table(factor(tags$source[!k(tags) %in% k(old)], levels = ver$source)))
write.csv(ver, "report_versions.csv", row.names = FALSE)

# tools the readers named outside the taxonomy
ot <- read.csv("other_tools.csv", colClasses = "character")
ot$name <- trimws(ot$value)
items <- tapply(paste(ot$source, ot$item_id), tolower(ot$name), function(x) length(unique(x)))
otab <- data.frame(name = names(items), items = as.integer(items))
otab <- otab[order(-otab$items, otab$name), ]
write.csv(otab, "report_other_tools.csv", row.names = FALSE)
read_items <- length(unique(paste(tags$source, tags$item_id)[tags$method != "rule"]))
cat("unlisted tools:", length(unique(paste(ot$source, ot$item_id))), "of", read_items, "read items name one;",
  nrow(otab), "distinct names\n")
print(cov, row.names = FALSE)
print(bounds[bounds$family %in% fam[1:3], ], row.names = FALSE)
print(meth, row.names = FALSE)
print(ver, row.names = FALSE)
print(head(otab, 20), row.names = FALSE)
