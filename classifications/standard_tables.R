# The standard tables of a classification run (classifications/README.md; decided 2026-10-19):
# how each tag was decided, and how much of each value the rules alone give. The tool use
# classification has its own, fuller report (tool_use/report.R).
#
# Run from classifications/: Rscript standard_tables.R fda_use|lit_relevance|affiliation
# Writes <module>/report_methods.csv and <module>/report_values.csv.

pkgload::load_all("../pmxlandscape", quiet = TRUE)

name <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(name) || !name %in% c("fda_use", "lit_relevance", "affiliation")) {
  stop("usage: Rscript standard_tables.R fda_use|lit_relevance|affiliation")
}
read <- function(f) {
  f <- file.path(name, f)
  if (file.exists(f)) read.csv(f, colClasses = "character") else NULL
}
if (name == "affiliation") {
  # rules only: one row per item, the first author's type as the value
  t <- read("tags.csv")
  tags <- data.frame(source = t$source, item_id = t$item_id, label = "", value = t$first_author_type, method = t$method)
} else {
  cols <- c("source", "item_id", "label", "value", "method", "date")
  d <- rbind(read("decisions.csv"), read("corpus_decisions.csv"))
  adj <- rbind(read("adjudications.csv"), read("corpus_adjudications.csv"))
  tags <- moduleTags(rbind(d[cols], if (!is.null(adj)) adj[cols]))
}

# how each tag was decided, by source: rule (exactly reproducible), reading (recorded), settled
# disagreement, person
methods <- c("rule", "ai", "adjudication", "human")
tab <- as.data.frame.matrix(table(tags$source, factor(tags$method, levels = methods)))
names(tab) <- c("rule", "reading", "adjudication", "person")
out <- data.frame(source = rownames(tab), tags = rowSums(tab), tab, share_reproducible = round(tab$rule / rowSums(tab), 3))
write.csv(out, file.path(name, "report_methods.csv"), row.names = FALSE)
print(out, row.names = FALSE)

# each value by source: how many tags have it, and how many of those a rule gave
v <- aggregate(cbind(tags = 1, by_rule = tags$method == "rule") ~ source + value, transform(tags, one = 1), sum)
v <- v[order(v$source, -v$tags), ]
write.csv(v, file.path(name, "report_values.csv"), row.names = FALSE)
print(v, row.names = FALSE)
