# Tool use: the full run of the protocol
#
# Run from classifications/tool_use/:
#   Rscript run.R estimate       cost of the reading and of the check (free; nothing is read)
#   Rscript run.R read <cap>     reading of every candidate the rules leave open (Claude Sonnet 5.5)
#   Rscript run.R check <cap>    blind second reading of 15% of the read items (Claude Opus 5.5)
#   Rscript run.R tags           decisions, checks and tags from what has been read
#
# Or by Claude Code subagents instead of the API (development runs, from version 5):
#   Rscript run.R batches        batch files for the reading and the check (cache/agent_*_v<N>)
#   Rscript run.R import         the subagents' answers (answers_*.jsonl) into the parsed files
#                                the API route writes, so `tags` works on either
#   Rscript run.R heldout        step 0: batch files for the held-out test (cache/heldout_v<N>),
#                                items outside dev_items.csv
#   Rscript run.R heldout-result the held-out test's agreement (heldout.csv)
#   Rscript run.R increment      after a taxonomy change: batch files for the candidates the
#                                version's reading has no answer for (new or widened families,
#                                and candidates the rules no longer settle), with a blind check
#   Rscript run.R increment-import  their answers, added to the version's parsed reading and check
#                                (both take an optional tag for a later increment: increment <tag>)
#   Rscript run.R pilot-estimate the cost of the API pilot (free)
#   Rscript run.R pilot <cap>    the API pilot at the freeze (classifications/README.md, Readers):
#                                100 read items through the Message Batches API, compared with
#                                the development tags; pilot.csv
#
# From version 4 on, a request identical to one the previous version sent keeps its answer
# (reusableRequests()); only changed requests are read again.
#
# Writes decisions.csv (rules, readings, adjudications), problems.csv, checks.csv,
# check_disagreements.csv and tags.csv. Requests and raw responses stay in cache/ (not
# committed). Adjudications of check disagreements are kept in adjudications.csv (written by
# hand after reading the disagreements) and are never overwritten here.

pkgload::load_all("../../pmxlandscape", quiet = TRUE)

args <- commandArgs(trailingOnly = TRUE)
step <- args[1]
cap <- as.numeric(args[2])
steps <- c(
  "estimate", "read", "check", "tags", "batches", "import", "heldout", "heldout-result", "increment", "increment-import",
  "pilot-estimate", "pilot"
)
if (is.na(step) || !step %in% steps) stop("usage: Rscript run.R ", paste(steps, collapse = "|"))
if (step %in% c("read", "check", "pilot") && is.na(cap)) stop("give a cost cap in US dollars")

m <- readModule(".")
items <- moduleItems(m, "../../corpus")
cand <- moduleCandidates(m, items)
rules <- ruleDecide(m, cand, items)
req <- readingRequests(m, rules$queue, items)
checker <- modifyList(m$reader, list(model = m$check$model))
sample <- blindSample(req[c("source", "item_id")], m$check$fraction, seed = m$check$seed)
checkReq <- req[paste(req$source, req$item_id) %in% paste(sample$source, sample$item_id), ]
cat(
  nrow(items), "items in scope;", nrow(cand), "candidates;", nrow(rules$decided), "decided by rules;",
  nrow(rules$queue), "left in", nrow(req), "items to read;", nrow(checkReq), "items in the check sample\n"
)

if (step == "estimate") {
  apiEstimate(req, m, outputPerRequest = 120)
  apiEstimate(checkReq, m, reader = checker, outputPerRequest = 120)
  quit(save = "no")
}
# Requests identical to ones the previous version sent (the whole body) keep their answers; only
# the others are read again.
readStep <- function(kind, requests, reader) {
  dir <- file.path("cache", paste0(kind, "_v", m$version))
  prev <- file.path("cache", paste0(kind, "_v", as.integer(m$version) - 1))
  reuse <- reusableRequests(requests, m, prev, reader = reader)
  todo <- requests[!requests$custom_id %in% reuse, ]
  cat(kind, ":", length(reuse), "requests unchanged since version", as.integer(m$version) - 1, "(answers kept);", nrow(todo), "to read\n")
  r <- if (nrow(todo)) {
    readWithApi(todo, m, dir, cap = cap, reader = reader, outputPerRequest = 120)
  } else {
    list(decisions = NULL, problems = NULL, usage = NULL, cost = 0)
  }
  if (length(reuse)) {
    old <- readRDS(file.path(prev, "parsed.rds"))
    kept <- paste(requests$source, requests$item_id)[requests$custom_id %in% reuse]
    r$decisions <- rbind(old$decisions[paste(old$decisions$source, old$decisions$item_id) %in% kept, ], r$decisions)
    r$problems <- rbind(old$problems[paste(old$problems$source, old$problems$item_id) %in% kept, ], r$problems)
  }
  r$reused <- length(reuse)
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  saveRDS(r, file.path(dir, "parsed.rds"))
  cat(kind, ":", nrow(r$decisions), "decisions,", nrow(r$problems), "problems, $", round(r$cost, 2), "\n")
}
agentDir <- function(what) file.path("cache", paste0("agent_", what, "_v", m$version))
importAgents <- function(dir, requests, model, run) {
  files <- list.files(dir, pattern = "^answers_\\d+\\.jsonl$", full.names = TRUE)
  if (!length(files)) stop("no answers in ", dir)
  all <- file.path(dir, "answers_all.jsonl")
  writeLines(unlist(lapply(files, readLines, encoding = "UTF-8")), all, useBytes = TRUE)
  r <- readAgentAnswers(all, requests, m, model = model, run = run)
  r$cost <- 0
  r$reused <- 0
  r
}
if (step == "batches") {
  f1 <- writeAgentBatches(req, m, agentDir("read"), size = 100, chars = 300000, format = "text")
  f2 <- writeAgentBatches(checkReq, m, agentDir("check"), size = 100, chars = 300000, format = "text")
  cat(length(f1), "reading batches,", length(f2), "check batches\n")
}
if (step == "import") {
  for (what in c("read", "check")) {
    if (!length(list.files(agentDir(what), pattern = "^answers_\\d+\\.jsonl$"))) next
    r <- importAgents(agentDir(what), if (what == "read") req else checkReq,
      model = if (what == "read") "Claude Sonnet 5.5" else "Claude Opus 5.5", run = paste0("agents-", what, "-v", m$version)
    )
    dir <- file.path("cache", paste0(what, "_v", m$version))
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
    saveRDS(r, file.path(dir, "parsed.rds"))
    cat(what, ":", nrow(r$decisions), "decisions,", nrow(r$problems), "problems,", nrow(r$extra), "other tools named\n")
    if (nrow(r$problems)) print(table(r$problems$problem))
  }
}
# Step 0: the held-out test, on items that informed no change of the codebook (dev_items.csv);
# about 200 items, stratified by source, a quarter of them from the extension, read by Claude Sonnet 5.5
# and blind by Claude Opus 5.5 subagents
heldDir <- function(what) file.path("cache", paste0("heldout_", what, "_v", m$version))
if (step %in% c("heldout", "heldout-result")) {
  dev <- read.csv("dev_items.csv", colClasses = "character")
  pool <- req[!paste(req$source, req$item_id) %in% paste(dev$source, dev$item_id), ]
  adm <- do.call(rbind, lapply(c("pubmed", "epmc"), function(n) {
    it <- read.csv(file.path("../../corpus", n, "items.csv"), colClasses = "character")
    it[c("source", "item_id", "admitted_by")]
  }))
  pool$stratum <- ifelse(paste(pool$source, pool$item_id) %in%
    paste(adm$source, adm$item_id)[grepl("^extension", adm$admitted_by)], "extension", pool$source)
  size <- c(PAGE = 50, PubMed = 50, "Europe PMC" = 50, extension = 50)
  held <- withr::with_seed(as.integer(m$heldout$seed), do.call(rbind, lapply(names(size), function(st) {
    d <- pool[pool$stratum == st, ]
    d[sort(sample.int(nrow(d), min(size[[st]], nrow(d)))), ]
  })))
  # rule precision: literature items whose candidates the rules all decided (the rules were
  # developed on PAGE, so PAGE is left out), read in full and compared with the rules
  key <- function(d) paste(d$source, d$item_id)
  ruleOnly <- setdiff(key(rules$decided), key(rules$queue))
  ruleOnly <- ruleOnly[!ruleOnly %in% key(dev) & !startsWith(ruleOnly, "PAGE ")]
  pick <- withr::with_seed(as.integer(m$heldout$seed) + 1L, sort(sample(ruleOnly, min(60, length(ruleOnly)))))
  ruleReq <- readingRequests(m, cand[key(cand) %in% pick, ], items)
  ruleReq$stratum <- "rule"
  # the rule items are numbered on their own, so their IDs are made distinct from the others'
  ruleReq$custom_id <- paste0(ruleReq$custom_id, "-rule")
  held <- rbind(held, ruleReq[names(held)])
}
if (step == "heldout") {
  write.csv(held[c("source", "item_id", "stratum")], "heldout_items.csv", row.names = FALSE)
  f1 <- writeAgentBatches(held, m, heldDir("read"), size = 100, chars = 300000, format = "text")
  f2 <- writeAgentBatches(held, m, heldDir("check"), size = 100, chars = 300000, format = "text")
  cat(nrow(held), "held-out items;", length(f1), "batches each for the reading and the check\n")
  print(table(held$stratum))
}
# The batches of 2026-10-19 were written before the rule items' IDs were made distinct (three
# IDs occurred twice). Each batch file names every item once, so an answer is tied to its item
# through the batch it answers, and given the item's present ID.
importHeld <- function(dir, model, run) {
  key <- paste(held$source, held$item_id)
  fixed <- unlist(lapply(list.files(dir, pattern = "^batch_\\d+\\.txt$", full.names = TRUE), function(f) {
    l <- readLines(f, encoding = "UTF-8")
    id <- sub("^======== custom_id: (.*) ========$", "\\1", l[grepl("^======== custom_id: ", l)])
    it <- sub("^Item: (.*) \\(\\d+\\)$", "\\1", l[grepl("^Item: ", l)])
    ans <- sub("\\.txt$", ".jsonl", sub("batch_", "answers_", f))
    vapply(readLines(ans, encoding = "UTF-8"), function(x) {
      a <- jsonlite::fromJSON(x, simplifyVector = FALSE)
      a$custom_id <- held$custom_id[match(it[match(a$custom_id, id)], key)]
      as.character(jsonlite::toJSON(a, auto_unbox = TRUE))
    }, "", USE.NAMES = FALSE)
  }))
  all <- file.path(dir, "answers_all.jsonl")
  writeLines(fixed, all, useBytes = TRUE)
  readAgentAnswers(all, held, m, model = model, run = run)
}
if (step == "heldout-result") {
  a <- importHeld(heldDir("read"), "Claude Sonnet 5.5", paste0("agents-heldout-read-v", m$version))
  b <- importHeld(heldDir("check"), "Claude Opus 5.5", paste0("agents-heldout-check-v", m$version))
  saveRDS(list(read = a, check = b), file.path(heldDir("read"), "parsed_both.rds"))
  st <- held$stratum[match(paste(a$decisions$source, a$decisions$item_id), paste(held$source, held$item_id))]
  res <- do.call(rbind, lapply(c("all", unique(held$stratum)), function(s) {
    keep <- if (s == "all") rep(TRUE, length(st)) else st == s
    data.frame(stratum = s, agreement(a$decisions[keep, ], b$decisions))
  }))
  res$problems_read <- nrow(a$problems)
  res$problems_check <- nrow(b$problems)
  write.csv(res, "heldout.csv", row.names = FALSE)
  print(res)
  k <- function(d) paste(d$source, d$item_id, d$label)
  both <- merge(withholdQuotes(a$decisions, items)[c("source", "item_id", "label", "value", "note")],
    withholdQuotes(b$decisions, items)[c("source", "item_id", "label", "value", "note")],
    by = c("source", "item_id", "label"), suffixes = c("_first", "_check")
  )
  write.csv(both[both$value_first != both$value_check, ], "heldout_disagreements.csv", row.names = FALSE)
  # the rules against the Claude Sonnet 5.5 reading of the same candidates
  rr <- a$decisions[paste(a$decisions$source, a$decisions$item_id) %in% key(held[held$stratum == "rule", ]), ]
  rp <- data.frame(stratum = "rule precision (rules against the reading)", agreement(rules$decided, rr))
  write.csv(rp, "heldout_rules.csv", row.names = FALSE)
  print(rp)
}
if (step == "read") readStep("read", req, m$reader)
if (step == "check") readStep("check", checkReq, checker)
# After a taxonomy change (a family added or widened, 2026-10-20): only the candidates the
# version's reading has no answer for are read, with the same check fraction. A tag (second
# argument, for example `Rscript run.R increment toolroute`) makes a later increment a run of its
# own, on top of every earlier answer (the tool route's new papers, 2026-10-21)
tag <- if (step %in% c("increment", "increment-import") && !is.na(args[2])) args[2] else ""
incDir <- function(what) {
  file.path("cache", paste0("agent_increment_", if (nzchar(tag)) paste0(tag, "_"), what, "_v", m$version))
}
if (step %in% c("increment", "increment-import")) {
  done <- readRDS(file.path("cache", paste0("read_v", m$version), "parsed.rds"))
  ckey <- function(d) paste(d$source, d$item_id, d$label)
  incRun <- paste0("agents-%s-v", m$version, "-increment", if (nzchar(tag)) paste0("-", tag))
  thisRun <- function(run) if (nzchar(tag)) run %in% sprintf(incRun, c("read", "check")) else grepl("-increment$", run)
  old <- done$decisions[!thisRun(done$decisions$run), ]
  newq <- rules$queue[!ckey(rules$queue) %in% ckey(old), ]
  incReq <- readingRequests(m, newq, items)
  incSample <- blindSample(incReq[c("source", "item_id")], m$check$fraction, seed = m$check$seed)
  incCheck <- incReq[paste(incReq$source, incReq$item_id) %in% paste(incSample$source, incSample$item_id), ]
  cat(nrow(newq), "candidates without an answer, in", nrow(incReq), "items;", nrow(incCheck), "items in the check\n")
  print(table(newq$label))
}
if (step == "increment") {
  f1 <- writeAgentBatches(incReq, m, incDir("read"), size = 100, chars = 300000, format = "text")
  f2 <- writeAgentBatches(incCheck, m, incDir("check"), size = 100, chars = 300000, format = "text")
  cat(length(f1), "reading batches,", length(f2), "check batches\n")
}
if (step == "increment-import") {
  for (what in c("read", "check")) {
    r <- importAgents(incDir(what), if (what == "read") incReq else incCheck,
      model = if (what == "read") "Claude Sonnet 5.5" else "Claude Opus 5.5", run = sprintf(incRun, what)
    )
    f <- file.path("cache", paste0(what, "_v", m$version), "parsed.rds")
    p <- readRDS(f)
    keep <- function(d) if (is.null(d) || !nrow(d)) d else d[!thisRun(d$run %||% rep("", nrow(d))), , drop = FALSE]
    p$decisions <- rbind(keep(p$decisions), r$decisions)
    p$problems <- rbind(keep(p$problems), r$problems)
    p$extra <- rbind(keep(p$extra), r$extra)
    saveRDS(p, f)
    cat(what, ":", nrow(r$decisions), "decisions added,", nrow(r$problems), "problems\n")
    if (nrow(r$problems)) print(table(r$problems$problem))
  }
}
# The API pilot at the freeze: does the production reader agree with the development reading,
# and how many tokens does a request take
if (step %in% c("pilot-estimate", "pilot")) {
  pick <- withr::with_seed(as.integer(m$check$seed) + 3L, sort(sample.int(nrow(req), min(100, nrow(req)))))
  pilotReq <- req[pick, ]
  if (step == "pilot-estimate") {
    apiEstimate(pilotReq, m, outputPerRequest = 120)
    quit(save = "no")
  }
  r <- readWithApi(pilotReq, m, file.path("cache", paste0("pilot_v", m$version)), cap = cap, outputPerRequest = 120)
  saveRDS(r, file.path("cache", paste0("pilot_v", m$version), "parsed.rds"))
  dev <- read.csv("tags.csv", colClasses = "character")
  a <- agreement(dev, r$decisions)
  u <- r$usage
  out <- data.frame(
    version = m$version, run = unique(r$decisions$run)[1], reader = unique(r$decisions$reader)[1], requests = nrow(pilotReq),
    compared = a$compared, agree = a$agree, kappa = round(a$kappa, 4), alpha = round(a$alpha, 4), cost_usd = round(r$cost, 4),
    input_tokens = sum(u$input_tokens), cache_read_tokens = sum(u$cache_read_input_tokens),
    output_tokens = sum(u$output_tokens), problems = nrow(r$problems)
  )
  write.csv(out, "pilot.csv", row.names = FALSE)
  k <- function(d) paste(d$source, d$item_id, d$label)
  both <- merge(dev[c("source", "item_id", "label", "value", "method")], r$decisions[c("source", "item_id", "label", "value", "note")],
    by = c("source", "item_id", "label"), suffixes = c("_development", "_api")
  )
  write.csv(both[both$value_development != both$value_api, ], "pilot_disagreements.csv", row.names = FALSE)
  print(out)
}
if (step == "tags") {
  first <- readRDS(file.path("cache", paste0("read_v", m$version), "parsed.rds"))
  ai <- withholdQuotes(first$decisions, items)
  adj <- if (file.exists("adjudications.csv")) read.csv("adjudications.csv", colClasses = "character") else NULL
  decisions <- rbind(rules$decided, ai, adj[names(ai)])
  write.csv(decisions, "decisions.csv", row.names = FALSE)
  write.csv(first$problems, "problems.csv", row.names = FALSE)
  if (file.exists(file.path("cache", paste0("check_v", m$version), "parsed.rds"))) {
    second <- readRDS(file.path("cache", paste0("check_v", m$version), "parsed.rds"))
    sec <- withholdQuotes(second$decisions, items)
    a <- agreement(first$decisions, second$decisions)
    checks <- data.frame(
      run = unique(first$decisions$run)[1], first_reader = unique(first$decisions$reader)[1],
      check_run = unique(second$decisions$run)[1], check_reader = unique(second$decisions$reader)[1],
      items = nrow(checkReq), seed = m$check$seed, a
    )
    write.csv(checks, "checks.csv", row.names = FALSE)
    # every run of every version, kept across versions
    hist <- if (file.exists("runs.csv")) read.csv("runs.csv", colClasses = "character") else NULL
    row <- data.frame(
      version = m$version, run = paste(unique(first$decisions$run), collapse = "; "),
      check_run = paste(unique(second$decisions$run), collapse = "; "), first_reader = unique(first$decisions$reader)[1],
      check_reader = unique(second$decisions$reader)[1], requests = nrow(req), check_items = nrow(checkReq),
      reused = first$reused %||% 0, check_reused = second$reused %||% 0, compared = a$compared,
      agree = a$agree, kappa = round(a$kappa, 4), alpha = round(a$alpha, 4),
      cost_usd = round(first$cost + second$cost, 2), prompt_hash = promptHash(m),
      taxonomy_hash = substr(corpusHash(paste(
        readText("../../taxonomy/software.csv"),
        readText("../../taxonomy/patterns.json")
      )), 1, 16)
    )
    if (!is.null(hist)) {
      hist <- hist[hist$version != m$version, , drop = FALSE]
      for (col in setdiff(names(row), names(hist))) hist[[col]] <- rep("0", nrow(hist))
    }
    hist <- rbind(hist, row[names(row)])
    write.csv(hist, "runs.csv", row.names = FALSE)
    k <- function(d) paste(d$source, d$item_id, d$label)
    both <- merge(ai[c("source", "item_id", "label", "value", "note")],
      sec[c("source", "item_id", "label", "value", "note")],
      by = c("source", "item_id", "label"), suffixes = c("_first", "_check")
    )
    write.csv(both[both$value_first != both$value_check, ], "check_disagreements.csv", row.names = FALSE)
    print(checks)
  }
  if (nrow(first$extra %||% data.frame())) {
    write.csv(first$extra[first$extra$field == "other_tools", c("source", "item_id", "value", "reader", "run", "date")],
      "other_tools.csv",
      row.names = FALSE
    )
  }
  tags <- moduleTags(decisions)
  write.csv(tags, "tags.csv", row.names = FALSE)
  print(table(tags$source, tags$value))
}
