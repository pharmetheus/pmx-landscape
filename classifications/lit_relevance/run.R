# Literature relevance, version 1: the reading for the refinement study (sources/literature/refinement)
#
# Run from classifications/lit_relevance/:
#   Rscript run.R estimate       cost (free; nothing is read)
#   Rscript run.R read <cap>     reading of every sampled paper (Claude Sonnet 5.5)
#   Rscript run.R check <cap>    blind second reading of 15% (Claude Opus 5.5)
#   Rscript run.R decide         decisions, the check and its disagreements
#
# Or by Claude Code subagents instead of the API (development runs, 2026-10-19):
#   Rscript run.R batches        batch files for the reading and the check (cache/agent_*_v1)
#   Rscript run.R import         the subagents' answers (answers_*.jsonl) into the same parsed
#                                files as the API route, so `decide` works on either
#
# For the corpus (from 2026-10-19): the Europe PMC papers added to the corpus (the core of 2016 to
# 2020 and the extension) whose full text names no estimation tool are read the same way, as
# the base set's were (sources/literature/no_tool_decisions.csv):
#   Rscript run.R corpus-batches  batch files (cache/agent_corpus_*_v1); papers the refinement
#                                 reading already decided keep that decision
#   Rscript run.R corpus-import   corpus_decisions.csv, corpus_checks.csv,
#                                 corpus_check_disagreements.csv
#
# The items are the refinement corpus (sources/literature/refinement/corpus), built by
# 03_fetch.R from the samples in results/sample.csv. No rules: every paper is read (the
# module records that). Notes repeating the papers' text are withheld (withholdQuotes()), since
# literature text is not published here. Requests and raw responses stay in cache/.

pkgload::load_all("../../pmxlandscape", quiet = TRUE)

args <- commandArgs(trailingOnly = TRUE)
step <- args[1]
cap <- as.numeric(args[2])
steps <- c("estimate", "read", "check", "decide", "batches", "import", "corpus-batches", "corpus-import")
if (is.na(step) || !step %in% steps) stop("usage: Rscript run.R estimate|read <cap>|check <cap>|decide|batches|import")
if (step %in% c("read", "check") && is.na(cap)) stop("give a cost cap in US dollars")

m <- readModule(".")
# This script is the record of version 1 (the refinement study and the corpus papers naming no
# tool, 2026-10-19); version 2 (every corpus paper, from 2026-10-20) is run_v2.R
m$version <- "1"
m$rubric <- stringi::stri_trim_both(readText("rubric_v1.md"))
if (step %in% c("corpus-batches", "corpus-import")) {
  # the new Europe PMC full texts naming no estimation tool (local_search.R)
  x <- read.csv(gzfile("../../sources/literature/results/ids_local_all.csv.gz"), colClasses = "character")
  x <- x[x$source == "Europe PMC (full text)" & !(x$admitted == "core" & as.integer(x$year) >= 2021), ]
  noTool <- setdiff(x$id[x$software == "All (base set)"], x$id[x$software != "All (base set)"])
  m$scope <- m$scope["Europe PMC"]
  items <- moduleItems(m, "../../corpus")
  items <- items[items$item_id %in% noTool, ]
  old <- read.csv("decisions.csv", colClasses = "character")
  old <- old[order(old$method == "adjudication"), ]
  old <- old[!duplicated(paste(old$source, old$item_id), fromLast = TRUE) & old$source == "Europe PMC", ]
  kept <- old[old$item_id %in% items$item_id, ]
  req <- readingRequests(m, NULL, items[!items$item_id %in% kept$item_id, ])
  sample <- blindSample(req[c("source", "item_id")], m$check$fraction, seed = m$check$seed)
  checkReq <- req[paste(req$source, req$item_id) %in% paste(sample$source, sample$item_id), ]
  cat(nrow(items), "papers naming no tool;", nrow(kept), "decided in the refinement reading;", nrow(req), "to read;",
    nrow(checkReq), "in the check sample\n")
  cdir <- function(what) file.path("cache", paste0("agent_corpus_", what, "_v", m$version))
  if (step == "corpus-batches") {
    f1 <- writeAgentBatches(req, m, cdir("read"), size = 100, chars = 350000, format = "text")
    f2 <- writeAgentBatches(checkReq, m, cdir("check"), size = 100, chars = 350000, format = "text")
    cat(length(f1), "reading batches,", length(f2), "check batches\n")
  } else {
    get <- function(what, rq, model) {
      files <- list.files(cdir(what), pattern = "^answers_\\d+\\.jsonl$", full.names = TRUE)
      all <- file.path(cdir(what), "answers_all.jsonl")
      writeLines(unlist(lapply(files, readLines, encoding = "UTF-8")), all, useBytes = TRUE)
      readAgentAnswers(all, rq, m, model = model, run = paste0("agents-corpus-", what, "-v", m$version))
    }
    a <- get("read", req, "Claude Sonnet 5.5")
    b <- get("check", checkReq, "Claude Opus 5.5")
    cat("problems:", nrow(a$problems), "and", nrow(b$problems), "\n")
    d <- withholdQuotes(a$decisions, items)
    adj <- if (file.exists("corpus_adjudications.csv")) read.csv("corpus_adjudications.csv", colClasses = "character")
    write.csv(rbind(kept, d, adj[names(d)]), "corpus_decisions.csv", row.names = FALSE)
    ag <- agreement(a$decisions, b$decisions)
    write.csv(data.frame(run = unique(a$decisions$run), first_reader = unique(a$decisions$reader),
      check_run = unique(b$decisions$run), check_reader = unique(b$decisions$reader), items = nrow(checkReq),
      seed = m$check$seed, ag), "corpus_checks.csv", row.names = FALSE)
    sec <- withholdQuotes(b$decisions, items)
    both <- merge(d[c("source", "item_id", "value", "note")], sec[c("source", "item_id", "value", "note")],
      by = c("source", "item_id"), suffixes = c("_first", "_check"))
    write.csv(both[both$value_first != both$value_check, ], "corpus_check_disagreements.csv", row.names = FALSE)
    print(ag)
    print(table(d$value))
  }
  quit(save = "no")
}
items <- moduleItems(m, "../../sources/literature/refinement/corpus")
req <- readingRequests(m, NULL, items)
checker <- modifyList(m$reader, list(model = m$check$model))
sample <- blindSample(req[c("source", "item_id")], m$check$fraction, seed = m$check$seed)
checkReq <- req[paste(req$source, req$item_id) %in% paste(sample$source, sample$item_id), ]
cat(nrow(items), "papers;", nrow(checkReq), "in the check sample\n")

if (step == "estimate") {
  apiEstimate(req, m, outputPerRequest = 80)
  apiEstimate(checkReq, m, reader = checker, outputPerRequest = 80)
  quit(save = "no")
}
agentDir <- function(what) file.path("cache", paste0("agent_", what, "_v", m$version))
if (step == "batches") {
  # wrapped text, about 350,000 characters a batch; the check batches hold only the check sample
  f1 <- writeAgentBatches(req, m, agentDir("read"), size = 100, chars = 350000, format = "text")
  f2 <- writeAgentBatches(checkReq, m, agentDir("check"), size = 100, chars = 350000, format = "text")
  cat(length(f1), "reading batches,", length(f2), "check batches\n")
}
if (step == "import") {
  for (what in c("read", "check")) {
    files <- list.files(agentDir(what), pattern = "^answers_\\d+\\.jsonl$", full.names = TRUE)
    if (!length(files)) next
    all <- file.path(agentDir(what), "answers_all.jsonl")
    writeLines(unlist(lapply(files, readLines, encoding = "UTF-8")), all, useBytes = TRUE)
    r <- readAgentAnswers(all, if (what == "read") req else checkReq, m,
      model = if (what == "read") "Claude Sonnet 5.5" else "Claude Opus 5.5", run = paste0("agents-", what, "-v", m$version)
    )
    dir <- file.path("cache", paste0(what, "_v", m$version))
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
    saveRDS(r, file.path(dir, "parsed.rds"))
    cat(what, ":", nrow(r$decisions), "decisions,", nrow(r$problems), "problems\n")
    if (nrow(r$problems)) print(table(r$problems$problem))
  }
}
if (step %in% c("read", "check")) {
  dir <- file.path("cache", paste0(step, "_v", m$version))
  r <- readWithApi(if (step == "read") req else checkReq, m, dir, cap = cap,
    reader = if (step == "read") m$reader else checker, outputPerRequest = 80
  )
  saveRDS(r, file.path(dir, "parsed.rds"))
  cat(step, ":", nrow(r$decisions), "decisions,", nrow(r$problems), "problems, $", round(r$cost, 2), "\n")
}
if (step == "decide") {
  first <- readRDS(file.path("cache", paste0("read_v", m$version), "parsed.rds"))
  d <- withholdQuotes(first$decisions, items)
  adj <- if (file.exists("adjudications.csv")) read.csv("adjudications.csv", colClasses = "character") else NULL
  write.csv(rbind(d, adj[names(d)]), "decisions.csv", row.names = FALSE)
  write.csv(first$problems, "problems.csv", row.names = FALSE)
  print(table(d$source, d$value))
  if (file.exists(file.path("cache", paste0("check_v", m$version), "parsed.rds"))) {
    second <- readRDS(file.path("cache", paste0("check_v", m$version), "parsed.rds"))
    sec <- withholdQuotes(second$decisions, items)
    a <- agreement(first$decisions, second$decisions)
    write.csv(cbind(
      run = unique(first$decisions$run)[1], first_reader = unique(first$decisions$reader)[1],
      check_run = unique(second$decisions$run)[1],
      check_reader = unique(second$decisions$reader)[1], items = nrow(checkReq), seed = m$check$seed, a
    ), "checks.csv", row.names = FALSE)
    both <- merge(d[c("source", "item_id", "value", "note")], sec[c("source", "item_id", "value", "note")],
      by = c("source", "item_id"), suffixes = c("_first", "_check")
    )
    write.csv(both[both$value_first != both$value_check, ], "check_disagreements.csv", row.names = FALSE)
    cat("blind check:", a$agree, "of", a$compared, sprintf("(kappa %.2f)\n", a$kappa))
  }
}
