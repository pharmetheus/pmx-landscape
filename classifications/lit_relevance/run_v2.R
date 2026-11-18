# Literature relevance, version 2: every literature paper of the corpus (from 2026-10-20)
#
# Every paper found by the term route or the tool route (corpus/pubmed, corpus/epmc) is read for
# whether its authors fitted a population model of their own (codebook.md), so that every paper
# is treated the same way (Niclas, 2026-10-20). Version 1 (run.R) is the record of the earlier
# readings.
#
# Run from classifications/lit_relevance/:
#   Rscript run_v2.R heldout-batches  the held-out test: 200 papers decided earlier (version 1
#                                     and the no-tool reading), stratified by source and earlier
#                                     value, read by Claude Code subagents with version 2
#   Rscript run_v2.R heldout-result   heldout.csv and heldout_disagreements.csv; the test passes
#                                     at 90% agreement and a kappa of at least 0.8
#   Rscript run_v2.R batches          batch files for every corpus paper, and a blind check of
#                                     15% (cache/agent_all_*_v2)
#   Rscript run_v2.R pilot-estimate   the cost of the API pilot (free)
#   Rscript run_v2.R pilot <cap>      the API pilot at the freeze (classifications/README.md,
#                                     Readers): 100 random papers through the Message Batches API,
#                                     compared with the development decisions (pilot.csv,
#                                     pilot_disagreements.csv); <cap> is the cost cap in US dollars
#   Rscript run_v2.R import           decisions_v2.csv (with re-reads from cache/agent_all_reread_v2
#                                     and adjudications_v2.csv applied),
#                                     checks_v2.csv, check_disagreements_v2.csv
#
# Notes repeating the papers' text are withheld (withholdQuotes()), since literature text is not
# published here. Requests and raw responses stay in cache/.

pkgload::load_all("../../pmxlandscape", quiet = TRUE)

step <- commandArgs(trailingOnly = TRUE)[1]
steps <- c("heldout-batches", "heldout-result", "batches", "import", "pilot-estimate", "pilot")
if (is.na(step) || !step %in% steps) stop("usage: Rscript run_v2.R ", paste(steps, collapse = "|"))
cap <- as.numeric(commandArgs(trailingOnly = TRUE)[2])
if (step == "pilot" && is.na(cap)) stop("give a cost cap in US dollars")

m <- readModule(".")
stopifnot(m$version == "2")
items <- moduleItems(m, "../../corpus")
cat(nrow(items), "papers in the corpus:", paste(names(table(items$source)), table(items$source), collapse = ", "), "\n")

# The earlier decisions: version 1 (the refinement study and the corpus papers naming no tool)
# and the no-tool reading of the base set (September 2026), the latest per paper
earlier <- function() {
  v1 <- rbind(
    read.csv("decisions.csv", colClasses = "character"),
    read.csv("corpus_decisions.csv", colClasses = "character")
  )
  v1 <- v1[order(v1$method == "adjudication"), ]
  v1 <- v1[!duplicated(paste(v1$source, v1$item_id), fromLast = TRUE), c("source", "item_id", "value")]
  nt <- read.csv("../../sources/literature/no_tool_decisions.csv", colClasses = "character")
  nt <- data.frame(source = "Europe PMC", item_id = nt$id, value = nt$decision)
  e <- rbind(v1, nt[!paste(nt$source, nt$item_id) %in% paste(v1$source, v1$item_id), ])
  e[paste(e$source, e$item_id) %in% paste(items$source, items$item_id), ]
}

hdir <- "cache/agent_heldout_read_v2"
if (step == "heldout-batches") {
  e <- earlier()
  set.seed(20261020)
  strata <- split(seq_len(nrow(e)), paste(e$source, e$value))
  # 200 papers, proportional to the strata, with at least 5 from each (or all, when fewer)
  n <- pmax(pmin(lengths(strata), 5), round(200 * lengths(strata) / nrow(e)))
  pick <- unlist(mapply(function(i, k) i[sample.int(length(i), min(k, length(i)))], strata, n))
  held <- e[sort(pick), ]
  write.csv(held, "heldout_items.csv", row.names = FALSE)
  print(table(held$source, held$value))
  req <- readingRequests(m, NULL, items[paste(items$source, items$item_id) %in% paste(held$source, held$item_id), ])
  f <- writeAgentBatches(req, m, hdir, size = 100, chars = 350000, format = "text")
  cat(length(f), "held-out batches\n")
}
if (step == "heldout-result") {
  held <- read.csv("heldout_items.csv", colClasses = "character")
  req <- readingRequests(m, NULL, items[paste(items$source, items$item_id) %in% paste(held$source, held$item_id), ])
  files <- list.files(hdir, pattern = "^answers_\\d+\\.jsonl$", full.names = TRUE)
  all <- file.path(hdir, "answers_all.jsonl")
  writeLines(unlist(lapply(files, readLines, encoding = "UTF-8")), all, useBytes = TRUE)
  r <- readAgentAnswers(all, req, m, model = "Claude Sonnet 5.5", run = "agents-heldout-v2")
  cat("problems:", nrow(r$problems), "\n")
  d <- withholdQuotes(r$decisions, items)
  both <- merge(held, d[c("source", "item_id", "value", "note")], by = c("source", "item_id"), suffixes = c("_earlier", "_v2"))
  write.csv(both, "heldout.csv", row.names = FALSE)
  write.csv(both[both$value_earlier != both$value_v2, ], "heldout_disagreements.csv", row.names = FALSE)
  a <- agreement(transform(both, value = value_earlier, label = ""), transform(both, value = value_v2, label = ""))
  print(a)
  print(table(earlier = both$value_earlier, v2 = both$value_v2))
  cat(if (a$share >= 0.9 && a$kappa >= 0.8) "PASS" else "FAIL", "\n")
}

adir <- function(what) file.path("cache", paste0("agent_all_", what, "_v2"))
if (step %in% c("batches", "import", "pilot-estimate", "pilot")) {
  req <- readingRequests(m, NULL, items)
  sample <- blindSample(req[c("source", "item_id")], m$check$fraction, seed = m$check$seed)
  checkReq <- req[paste(req$source, req$item_id) %in% paste(sample$source, sample$item_id), ]
  cat(nrow(req), "papers to read;", nrow(checkReq), "in the check sample\n")
}
if (step == "batches") {
  f1 <- writeAgentBatches(req, m, adir("read"), size = 100, chars = 350000, format = "text")
  f2 <- writeAgentBatches(checkReq, m, adir("check"), size = 100, chars = 350000, format = "text")
  cat(length(f1), "reading batches,", length(f2), "check batches\n")
}
if (step == "import") {
  get <- function(what, rq, model) {
    files <- list.files(adir(what), pattern = "^answers_\\d+\\.jsonl$", full.names = TRUE)
    all <- file.path(adir(what), "answers_all.jsonl")
    writeLines(unlist(lapply(files, readLines, encoding = "UTF-8")), all, useBytes = TRUE)
    readAgentAnswers(all, rq, m, model = model, run = paste0("agents-all-", what, "-v2"))
  }
  a <- get("read", req, "Claude Sonnet 5.5")
  # papers read again after a rule changed during the run (codebook.md, the no-drug case): the
  # new reading replaces the first
  if (dir.exists(adir("reread"))) {
    again <- unlist(lapply(list.files(adir("reread"), "^batch_\\d+\\.txt$", full.names = TRUE), function(f) {
      sub("^======== custom_id: (\\S+) ========$", "\\1", grep("^======== custom_id: ", readLines(f), value = TRUE))
    }))
    rr <- get("reread", req[req$custom_id %in% again, ], "Claude Sonnet 5.5")
    key <- function(x) paste(x$source, x$item_id)
    a$decisions <- rbind(a$decisions[!key(a$decisions) %in% key(rr$decisions), ], rr$decisions)
    a$problems <- rbind(a$problems, rr$problems)
    cat(nrow(rr$decisions), "papers read again\n")
  }
  b <- get("check", checkReq, "Claude Opus 5.5")
  cat("problems:", nrow(a$problems), "and", nrow(b$problems), "\n")
  write.csv(rbind(a$problems, b$problems), "problems_v2.csv", row.names = FALSE)
  d <- withholdQuotes(a$decisions, items)
  adj <- if (file.exists("adjudications_v2.csv")) read.csv("adjudications_v2.csv", colClasses = "character")
  if (!is.null(adj)) d <- rbind(d[!paste(d$source, d$item_id) %in% paste(adj$source, adj$item_id), ], adj[names(d)])
  write.csv(d, "decisions_v2.csv", row.names = FALSE)
  ag <- agreement(a$decisions, b$decisions)
  write.csv(data.frame(
    run = paste(unique(a$decisions$run), collapse = "; "), first_reader = paste(unique(a$decisions$reader), collapse = "; "),
    check_run = paste(unique(b$decisions$run), collapse = "; "), check_reader = paste(unique(b$decisions$reader), collapse = "; "),
    items = nrow(checkReq),
    seed = m$check$seed, ag
  ), "checks_v2.csv", row.names = FALSE)
  sec <- withholdQuotes(b$decisions, items)
  first <- withholdQuotes(a$decisions, items)
  both <- merge(first[c("source", "item_id", "value", "note")], sec[c("source", "item_id", "value", "note")],
    by = c("source", "item_id"), suffixes = c("_first", "_check")
  )
  write.csv(both[both$value_first != both$value_check, ], "check_disagreements_v2.csv", row.names = FALSE)
  print(ag)
  print(table(d$source, d$value))
}

# The API pilot at the freeze: does the production reader agree with the development reading,
# and how many tokens does a paper take
if (step %in% c("pilot-estimate", "pilot")) {
  pick <- withr::with_seed(as.integer(m$check$seed) + 3L, sort(sample.int(nrow(req), 100)))
  pilotReq <- req[pick, ]
  if (step == "pilot-estimate") {
    apiEstimate(pilotReq, m, outputPerRequest = 80)
    quit(save = "no")
  }
  r <- readWithApi(pilotReq, m, file.path("cache", "pilot_v2"), cap = cap, outputPerRequest = 80)
  saveRDS(r, file.path("cache", "pilot_v2", "parsed.rds"))
  dev <- read.csv("decisions_v2.csv", colClasses = "character")
  dev <- dev[paste(dev$source, dev$item_id) %in% paste(pilotReq$source, pilotReq$item_id), ]
  a <- agreement(dev, r$decisions)
  u <- r$usage
  out <- data.frame(
    version = m$version, run = unique(r$decisions$run)[1], reader = unique(r$decisions$reader)[1], requests = nrow(pilotReq),
    compared = a$compared, agree = a$agree, kappa = round(a$kappa, 4), alpha = round(a$alpha, 4), cost_usd = round(r$cost, 4),
    input_tokens = sum(u$input_tokens), cache_read_tokens = sum(u$cache_read_input_tokens),
    output_tokens = sum(u$output_tokens), problems = nrow(r$problems)
  )
  write.csv(out, "pilot.csv", row.names = FALSE)
  api <- withholdQuotes(r$decisions, items)
  both <- merge(dev[c("source", "item_id", "value", "method")], api[c("source", "item_id", "value", "note")],
    by = c("source", "item_id"), suffixes = c("_development", "_api")
  )
  write.csv(both[both$value_development != both$value_api, ], "pilot_disagreements.csv", row.names = FALSE)
  print(out)
}
