# FDA tool use: an independent check of the FDA decision record (the Applicant's use)
#
# Run from classifications/fda_use/:
#   Rscript run.R estimate       cost (free; nothing is read)
#   Rscript run.R read <cap>     reading of every drug and estimation tool (Claude Sonnet 5.5)
#   Rscript run.R check <cap>    blind second reading of 15% of the drugs (Claude Opus 5.5)
#   Rscript run.R compare        decisions, checks, and the comparison with the record
#   Rscript run.R batches [round]  drugs without an answer yet (years without a record, 2026 on,
#                                and July to December 2020): batch files for Claude Code
#                                subagents, reading and blind check
#   Rscript run.R import [round]   their answers (cache/agent_*_<round>_v<N>/answers_*.jsonl)
#
# Each agent round has its own folder: "new" (default) holds the 2026 reading of 2026-10-20,
# "2020h2" the July to December 2020 approvals. A round's batches leave out every drug answered in
# an earlier round.
#
# For years without a hand-built record (2026 on, decided 2026-10-20) the reading, checked, is the
# record: the agent decisions join decisions.csv, and only the drugs in the record are compared.
#
# The record (sources/fda/results/fda_2021_2025_popPK_software.csv, with the revisions in
# record_revisions.csv) stays the decision of record. Its value per drug and tool, for the
# comparison: the evidence strength (`stated`, `indirect`, `template`) where the record's sponsor
# tool is the tool, `none` otherwise. Evidence from outside the FDA review (other_reviews/) is
# not part of the comparison, since the reading sees the review only.
#
# Writes decisions.csv, problems.csv, checks.csv, record_comparison.csv (agreement by value) and
# record_disagreements.csv (every drug and tool where the reading and the record differ, for
# Niclas). Requests and raw responses stay in cache/.

pkgload::load_all("../../pmxlandscape", quiet = TRUE)

args <- commandArgs(trailingOnly = TRUE)
step <- args[1]
cap <- if (step %in% c("read", "check")) as.numeric(args[2]) else NA
steps <- c("estimate", "read", "check", "compare", "batches", "import")
if (is.na(step) || !step %in% steps) stop("usage: Rscript run.R ", paste(steps, collapse = "|"))
if (step %in% c("read", "check") && is.na(cap)) stop("give a cost cap in US dollars")

m <- readModule(".")
items <- moduleItems(m, "../../corpus")
cand <- moduleCandidates(m, items)
req <- readingRequests(m, cand, items)
checker <- modifyList(m$reader, list(model = m$check$model))
sample <- blindSample(req[c("source", "item_id")], m$check$fraction, seed = m$check$seed)
checkReq <- req[paste(req$source, req$item_id) %in% paste(sample$source, sample$item_id), ]
cat(nrow(items), "drugs;", nrow(cand), "drug and tool pairs;", nrow(checkReq), "drugs in the check sample\n")

if (step == "estimate") {
  apiEstimate(req, m, outputPerRequest = 150)
  apiEstimate(checkReq, m, reader = checker, outputPerRequest = 150)
  quit(save = "no")
}
if (step %in% c("read", "check")) {
  dir <- file.path("cache", paste0(step, "_v", m$version))
  r <- readWithApi(if (step == "read") req else checkReq, m, dir,
    cap = cap,
    reader = if (step == "read") m$reader else checker, outputPerRequest = 150
  )
  saveRDS(r, file.path(dir, "parsed.rds"))
  cat(step, ":", nrow(r$decisions), "decisions,", nrow(r$problems), "problems, $", round(r$cost, 2), "\n")
}
round <- if (step %in% c("batches", "import")) args[2] else NA
if (is.na(round)) round <- "new"
agentDir <- function(what, r = round) file.path("cache", paste0("agent_", what, "_", r, "_v", m$version))
agentRounds <- function() {
  d <- list.files("cache", pattern = paste0("^agent_read_.+_v", m$version, "$"))
  sub(paste0("^agent_read_(.+)_v", m$version, "$"), "\\1", d)
}
agentAnswered <- function(except = round) {
  unlist(lapply(setdiff(agentRounds(), except), function(r) {
    f <- file.path(agentDir("read", r), "parsed.rds")
    if (file.exists(f)) readRDS(f)$decisions$item_id
  }))
}
if (step %in% c("batches", "import", "compare")) {
  answered <- readRDS(file.path("cache", paste0("read_v", m$version), "parsed.rds"))$decisions$item_id
  newReq <- req[!req$item_id %in% c(answered, if (step != "compare") agentAnswered()), ]
  newSample <- blindSample(newReq[c("source", "item_id")], m$check$fraction, seed = m$check$seed)
  newCheck <- newReq[paste(newReq$source, newReq$item_id) %in% paste(newSample$source, newSample$item_id), ]
  cat(nrow(newReq), "drugs without an answer;", nrow(newCheck), "in their check sample\n")
}
if (step == "batches") {
  f1 <- writeAgentBatches(newReq, m, agentDir("read"), size = 25, chars = 300000, format = "text")
  f2 <- writeAgentBatches(newCheck, m, agentDir("check"), size = 25, chars = 300000, format = "text")
  cat(length(f1), "reading batches,", length(f2), "check batches\n")
}
if (step == "import") {
  for (what in c("read", "check")) {
    files <- list.files(agentDir(what), pattern = "^answers_\\d+\\.jsonl$", full.names = TRUE)
    if (!length(files)) next
    all <- file.path(agentDir(what), "answers_all.jsonl")
    writeLines(unlist(lapply(files, readLines, encoding = "UTF-8")), all, useBytes = TRUE)
    r <- readAgentAnswers(all, if (what == "read") newReq else newCheck, m,
      model = if (what == "read") "Claude Sonnet 5.5" else "Claude Opus 5.5", run = paste0("agents-", what, "-", round, "-v", m$version)
    )
    saveRDS(r, file.path(agentDir(what), "parsed.rds"))
    cat(what, ":", nrow(r$decisions), "decisions,", nrow(r$problems), "problems\n")
    if (nrow(r$problems)) print(table(r$problems$problem))
  }
}
if (step == "compare") {
  first <- readRDS(file.path("cache", paste0("read_v", m$version), "parsed.rds"))
  extras <- lapply(agentRounds(), function(r) {
    f <- file.path(agentDir("read", r), "parsed.rds")
    if (file.exists(f)) readRDS(f)
  })
  extra <- list(
    decisions = do.call(rbind, lapply(extras, `[[`, "decisions")),
    problems = do.call(rbind, lapply(extras, `[[`, "problems"))
  )
  # FDA review text is in the public domain; the notes need no withholding
  write.csv(rbind(first$decisions, extra$decisions), "decisions.csv", row.names = FALSE)
  write.csv(rbind(first$problems, extra$problems), "problems.csv", row.names = FALSE)
  d <- first$decisions
  rec <- fdaApplyRevisions(
    read.csv("../../sources/fda/results/fda_2021_2025_popPK_software.csv", colClasses = "character"),
    read.csv("../../sources/fda/results/record_revisions.csv", colClasses = "character")
  )
  r <- rec[match(d$item_id, rec$application), ]
  strength <- c(stated = "stated", indirect = "indirect", "indirect, template phrase only" = "template")
  d$record <- ifelse(d$label == r$sponsor_tool_family, unname(strength[r$evidence_strength]), "none")
  d$drug <- r$drug
  d$year <- r$year
  write.csv(as.data.frame(table(record = d$record, reading = d$value)), "record_comparison.csv", row.names = FALSE)
  dis <- d[d$value != d$record, c("year", "drug", "item_id", "label", "record", "value", "note")]
  names(dis)[names(dis) == "value"] <- "reading"
  write.csv(dis, "record_disagreements.csv", row.names = FALSE)
  a <- agreement(transform(d, value = record), d)
  cat("reading against the record:", a$agree, "of", a$compared, sprintf("(kappa %.2f)\n", a$kappa))
  print(table(record = d$record, reading = d$value))
  if (file.exists(file.path("cache", paste0("check_v", m$version), "parsed.rds"))) {
    second <- readRDS(file.path("cache", paste0("check_v", m$version), "parsed.rds"))
    ca <- agreement(first$decisions, second$decisions)
    write.csv(cbind(
      run = unique(first$decisions$run)[1], first_reader = m$reader$model, check_run = unique(second$decisions$run)[1],
      check_reader = m$check$model, items = nrow(checkReq), seed = m$check$seed, ca
    ), "checks.csv", row.names = FALSE)
    cat("blind check:", ca$agree, "of", ca$compared, sprintf("(kappa %.2f)\n", ca$kappa))
  }
}
