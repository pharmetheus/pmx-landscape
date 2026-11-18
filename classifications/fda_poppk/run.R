# FDA population PK presence: does the review describe the Applicant's population PK analysis?
#
# For the years without a hand-built decision record (late 2020 and 2026 on), the FDA applicant
# use reading (classifications/fda_use) only sees named tools, so a drug whose review names none
# is "no tool identified". This classification splits those drugs as the record does: "popPK
# present, software not stated" or "No popPK analysis in review" (Niclas, 2026-10-20).
#
# Run from classifications/fda_poppk/:
#   Rscript run.R batches    batch files for Claude Code subagents: the drugs to decide, a blind
#                            check of 15% of them, and a validation set of 20 record drugs
#   Rscript run.R import     their answers, decisions.csv, checks.csv and validation.csv
#
# Drugs: those of the reading years whose fda_use decisions name no tool for the Applicant
# (stated, indirect or template). A drug whose review never mentions population PK (the marker
# pattern finds nothing) is `absent` by rule. Validation: 10 drugs of each category drawn from
# the 2021 to 2025 record (with its revisions), read the same way and compared with the record.

pkgload::load_all("../../pmxlandscape", quiet = TRUE)

step <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(step) || !step %in% c("batches", "import")) stop("usage: Rscript run.R batches|import")

m <- readModule(".")
items <- moduleItems(m, "../../corpus")
use <- read.csv("../fda_use/decisions.csv", colClasses = "character")
withTool <- unique(use$item_id[use$value %in% c("stated", "indirect", "template")])
recordYears <- fdaSurveyedYears("../../sources/fda")
toDecide <- items[!items$year %in% recordYears & !items$item_id %in% withTool, ]
rec <- fdaApplyRevisions(
  read.csv("../../sources/fda/results/fda_2021_2025_popPK_software.csv", colClasses = "character"),
  read.csv("../../sources/fda/results/record_revisions.csv", colClasses = "character")
)
cats <- c(present = "popPK present, software not stated", absent = "No popPK analysis in review")
set.seed(20261020)
validation <- do.call(rbind, lapply(names(cats), function(v) {
  ids <- rec$application[rec$category == cats[[v]] & rec$application %in% items$item_id]
  data.frame(item_id = sample(ids, 10), record = v)
}))
chosen <- items[items$item_id %in% c(toDecide$item_id, validation$item_id), ]
cand <- moduleCandidates(m, chosen)
req <- readingRequests(m, cand, chosen)
noMarker <- setdiff(chosen$item_id, cand$item_id)
decideReq <- req[req$item_id %in% toDecide$item_id, ]
sample <- blindSample(decideReq[c("source", "item_id")], m$check$fraction, seed = m$check$seed)
checkReq <- decideReq[decideReq$item_id %in% sample$item_id, ]
cat(
  nrow(toDecide), "drugs to decide;", length(intersect(noMarker, toDecide$item_id)), "without a population PK mention;",
  nrow(decideReq), "to read;", nrow(checkReq), "in the check;", nrow(validation), "validation drugs\n"
)

dirs <- c(read = "cache/agent_read_v1", check = "cache/agent_check_v1")
if (step == "batches") {
  writeAgentBatches(req, m, dirs[["read"]], size = 20, chars = 300000, format = "text")
  writeAgentBatches(checkReq, m, dirs[["check"]], size = 20, chars = 300000, format = "text")
}
if (step == "import") {
  parse <- function(what, r, model) {
    files <- list.files(dirs[[what]], pattern = "^answers_\\d+\\.jsonl$", full.names = TRUE)
    all <- file.path(dirs[[what]], "answers_all.jsonl")
    writeLines(unlist(lapply(files, readLines, encoding = "UTF-8")), all, useBytes = TRUE)
    readAgentAnswers(all, r, m, model = model, run = paste0("agents-", what, "-v", m$version))
  }
  first <- parse("read", req, "Claude Sonnet 5.5")
  second <- parse("check", checkReq, "Claude Opus 5.5")
  cat(
    "read:", nrow(first$decisions), "decisions,", nrow(first$problems), "problems; check:",
    nrow(second$decisions), "decisions,", nrow(second$problems), "problems\n"
  )
  rule <- data.frame(
    source = "FDA", item_id = intersect(noMarker, chosen$item_id), label = "popPK", value = "absent",
    note = "the review never mentions population PK", method = "rule"
  )
  d <- first$decisions
  d$method <- "reading"
  d <- rbind(d[names(rule)], rule)
  write.csv(d[d$item_id %in% toDecide$item_id, ], "decisions.csv", row.names = FALSE)
  v <- merge(validation, d, by = "item_id")
  v$drug <- rec$drug[match(v$item_id, rec$application)]
  write.csv(v[c("item_id", "drug", "record", "value", "method", "note")], "validation.csv", row.names = FALSE)
  cat("validation against the record:", sum(v$record == v$value), "of", nrow(v), "\n")
  a <- agreement(first$decisions, second$decisions)
  write.csv(a, "checks.csv", row.names = FALSE)
  cat("blind check:", a$agree, "of", a$compared, "\n")
  print(table(d$value[d$item_id %in% toDecide$item_id]))
}
