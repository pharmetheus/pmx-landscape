# How well do the tool use rules decide, measured against earlier readings?
#
# Run from classifications/tool_use/: Rscript rules_check.R   (no API calls)
#
# The rules (rules.csv) only ever give `used`. Their precision is the share of the candidates
# they decide that an earlier reading also read as used:
#   PAGE        the role reading (sources/page/role_decisions.csv; Claude Sonnet 5, checked by Claude Fable 5.1):
#               the set the rules were developed on, so this is in-sample
#   Europe PMC  the model-size reading (analysis/model_size/extractions.csv), papers with a fit of
#               their own and a recorded tool: not used to develop the rules (out of sample).
#               That reading records no tool for simulation-only papers, so those are left out.
# Writes rules_check.csv (counts per source and rule) and rules_disagreements.csv (IDs, labels and
# the earlier value; no source text).

pkgload::load_all("../../pmxlandscape", quiet = TRUE)
m <- readModule(".")
items <- moduleItems(m, "../../corpus")
cand <- moduleCandidates(m, items)
r <- ruleDecide(m, cand, items)
d <- r$decided

old <- read.csv("../../sources/page/role_decisions.csv", colClasses = "character")
page <- do.call(rbind, lapply(seq_len(nrow(old)), function(i) {
  x <- trimws(strsplit(old$roles[i], ";", fixed = TRUE)[[1]])
  data.frame(source = "PAGE", item_id = old$abstract_no[i], label = sub("\\s*=.*$", "", x), earlier = sub("^.*=\\s*", "", x))
}))
ex <- read.csv("../../analysis/model_size/extractions.csv", colClasses = "character")
ex <- ex[ex$own_fit %in% "yes" & !is.na(ex$tool) & !grepl("several", ex$tool), ]
named <- cand[cand$source == "Europe PMC" & cand$item_id %in% ex$id, c("source", "item_id", "label")]
named$earlier <- ifelse(mapply(function(id, lab) lab %in% trimws(strsplit(ex$tool[ex$id == id][1], ";")[[1]]), named$item_id, named$label),
  "used", "not used")
ref <- rbind(page, named)

key <- function(x) paste(x$source, x$item_id, x$label)
both <- merge(d, ref, by = c("source", "item_id", "label"))
inRef <- key(cand) %in% key(ref)
out <- do.call(rbind, lapply(c("PAGE", "Europe PMC"), function(src) {
  do.call(rbind, lapply(c("all", unique(d$reader)), function(rule) {
    b <- both[both$source == src & (rule == "all" | both$reader == rule), ]
    data.frame(
      source = src, rule = rule, reference_candidates = sum(inRef & cand$source == src),
      decided = nrow(b), share_decided = round(nrow(b) / sum(inRef & cand$source == src), 3),
      agree = sum(b$earlier == "used"), precision = round(mean(b$earlier == "used"), 4)
    )
  }))
}))
write.csv(out, "rules_check.csv", row.names = FALSE)
write.csv(both[both$earlier != "used", c("source", "item_id", "label", "reader", "earlier")], "rules_disagreements.csv", row.names = FALSE)
print(out)
cat("\nall candidates:", nrow(cand), "; decided by a rule:", nrow(d), sprintf("(%.0f%%)", 100 * nrow(d) / nrow(cand)), "\n")
print(table(cand$source, key(cand) %in% key(d)))
