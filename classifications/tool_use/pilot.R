# Pilot of the API reader on the tool use classification
#
# Run from classifications/tool_use/:
#   Rscript pilot.R estimate   token counts and cost, nothing read (free)
#   Rscript pilot.R run        reads the sample with each pilot model (costs money; cap per model)
#
# A random 100 of the PAGE abstracts the role reading decided (sources/page/role_decisions.csv),
# outside the Software Demonstration session and with the tools found in the abstract itself
# (not only in the poster), are read with the tool_use module by Haiku 5.5 and Sonnet 5.5.
# Each new reading is compared with the old decisions, tool by tool. The point is to measure
# real token counts and costs, and whether the cheaper model reads as well, before any full run.
#
# Writes pilot/decisions_<model>.csv, pilot/problems_<model>.csv and pilot/agreement.csv
# (IDs, values and the readers' short notes; no PAGE text). Requests and raw responses stay in
# cache/ (not committed).

pkgload::load_all("../../pmxlandscape", quiet = TRUE)

step <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(step) || !step %in% c("estimate", "run")) stop("usage: Rscript pilot.R estimate|run")
models <- c("claude-haiku-5-5", "claude-sonnet-5-5")
cap <- 2 # US dollars per model

m <- readModule(".")
corpus <- corpusRead("../../corpus", "page")$items
page <- read.csv("../../sources/page/results/page_abstracts.csv", colClasses = "character")
old <- read.csv("../../sources/page/role_decisions.csv", colClasses = "character")
pairs <- do.call(rbind, lapply(seq_len(nrow(old)), function(i) {
  p <- trimws(strsplit(old$roles[i], ";", fixed = TRUE)[[1]])
  data.frame(source = "PAGE", item_id = old$abstract_no[i], label = sub("\\s*=.*$", "", p), value = sub("^.*=\\s*", "", p))
}))
eligible <- old$abstract_no[old$abstract_no %in% page$abstract_no[page$estimation_source == "abstract"] &
  old$abstract_no %in% corpus$item_id[corpus$software_demo %in% c("FALSE", FALSE)]]
pick <- blindSample(data.frame(source = "PAGE", item_id = eligible), 100 / length(eligible), seed = 20261018)

items <- moduleItems(m, "../../corpus")
items <- items[items$item_id %in% pick$item_id, ]
cand <- moduleCandidates(m, items)
same <- merge(aggregate(label ~ item_id, cand, function(x) paste(sort(x), collapse = "; ")),
  aggregate(label ~ item_id, pairs[pairs$item_id %in% pick$item_id, ], function(x) paste(sort(x), collapse = "; ")),
  by = "item_id", suffixes = c("_now", "_old")
)
cat(nrow(items), "abstracts,", nrow(cand), "candidates;", sum(same$label_now == same$label_old),
  "abstracts with the same tools as the old reading\n")
req <- readingRequests(m, cand, items)

if (step == "estimate") {
  for (mod in models) apiEstimate(req, m, reader = modifyList(m$reader, list(model = mod)))
  quit(save = "no")
}

dir.create("pilot", showWarnings = FALSE)
agree <- list()
for (mod in models) {
  r <- readWithApi(req, m, file.path("cache", paste0("pilot_", mod)), cap = cap, reader = modifyList(m$reader, list(model = mod)))
  r$decisions <- withholdQuotes(r$decisions, items)
  write.csv(r$decisions, file.path("pilot", paste0("decisions_", mod, ".csv")), row.names = FALSE)
  write.csv(r$problems, file.path("pilot", paste0("problems_", mod, ".csv")), row.names = FALSE)
  a <- agreement(pairs, r$decisions)
  agree[[mod]] <- cbind(reader = mod, compared_with = "role_decisions.csv (Claude Sonnet 5, checked)", a,
    problems = nrow(r$problems), cost_usd = round(r$cost, 4))
  cat(mod, ": ", a$agree, " of ", a$compared, " tools as in the old reading (kappa ", round(a$kappa, 2), "), $",
    round(r$cost, 3), "\n", sep = "")
}
write.csv(do.call(rbind, agree), "pilot/agreement.csv", row.names = FALSE)
