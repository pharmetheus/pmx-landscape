# Software discovery: candidate tool names in every cached corpus
#
# Run from taxonomy/discovery/: Rscript discover.R
#
# Optional and separate from the searches: no source script reads what this writes. It
# proposes names for the taxonomy; a family enters the search only when its row and pattern
# are added to taxonomy/software.csv and patterns.json. See README.md.
#
# Reads the corpus (make corpus; no downloads):
#   PAGE        every abstract (title and body, without authors, affiliations and reference
#               list); poster PDFs are not read
#   PubMed      the literature base set (title, abstract)
#   Europe PMC  the base set's full texts (the methods section where one is marked, otherwise
#               the body; never the back matter)
#   FDA         the review text and OCR
# Finds names by the words around them (cues.csv; stop names in stopnames.txt), not by known
# names, and marks the names an existing pattern already covers.
#
# Writes:
#   results/candidates.csv  one row per name found in at least 2 items (all names in cache/)
#   results/cue_yield.csv   per cue: matches, items and distinct names
#   results/scanned.csv     every item read, with the round in which it was first read
#   results/run_info.txt
#   cache/                  every match and the reading queue (not committed: source text)

pkgload::load_all("../../pmxlandscape", quiet = TRUE)

round <- format(Sys.Date())
dir.create("cache", showWarnings = FALSE)
dir.create("results", showWarnings = FALSE)
cues <- readCues("cues.csv")
stop_names <- readLines("stopnames.txt")
patterns <- readPatterns("../patterns.json")
info <- c(paste("round:", round))

# ---- The corpus (corpus/, built by make corpus) -----------------------------------------
# PAGE: title and body (without authors, affiliations and reference list); posters are not
# read. PubMed: title and abstract. Europe PMC: papers with a full text, the methods section
# where one is marked, otherwise the body (never the back matter). FDA: every review page.
read_source <- function(name, label) {
  x <- corpusRead("../../corpus", name)
  list(items = x$items, sections = x$sections, label = label)
}
as_corpus <- function(x, text) {
  data.frame(source = x$label, id = text$item_id, year = x$items$year[match(text$item_id, x$items$item_id)], text = text$text)
}
p <- read_source("page", "PAGE")
page <- as_corpus(p, corpusText(p$sections, c("title", "body")))
pm <- read_source("pubmed", "PubMed")
pubmed <- as_corpus(pm, corpusText(pm$sections, c("title", "abstract"), sep = " "))
ep <- read_source("epmc", "Europe PMC")
ep$sections <- ep$sections[ep$sections$item_id %in% ep$items$item_id[ep$items$coverage == "full text"], ]
methods <- corpusText(ep$sections, "methods")
methods <- methods[nzchar(methods$text), ]
body <- corpusText(ep$sections, "body")
epmc <- as_corpus(ep, rbind(methods, body[!body$item_id %in% methods$item_id, ]))
fd <- read_source("fda", "FDA")
fda <- as_corpus(fd, corpusText(fd$sections, "review"))
rm(p, pm, ep, fd, methods, body)

corpus <- rbind(page, pubmed, epmc, fda)
for (s in unique(corpus$source)) {
  d <- corpus[corpus$source == s, ]
  info <- c(info, sprintf("%s: %d items, %d to %d", s, nrow(d), min(d$year), max(d$year)))
}

# ---- Candidates ---------------------------------------------------------------------
mentions <- do.call(rbind, lapply(split(corpus, corpus$source), function(d) {
  use <- cues[!vapply(strsplit(cues$skip_sources, ";\\s*"), function(s) d$source[1] %in% s, logical(1)), ]
  m <- softwareCandidates(d$text, d$id, use, stop = stop_names)
  if (nrow(m) == 0) NULL else cbind(source = d$source[1], m)
}))
saveRDS(mentions, "cache/mentions.rds")
meta <- corpus[c("source", "id", "year")]
# Registry names: each registry's latest snapshot. Keys are computed over corpus and registry
# names together (candidateKeys() depends on which names occur), so a listed name joins its mentions.
reg_files <- list.files("registries", pattern = "\\.csv$", full.names = TRUE)
reg <- do.call(rbind, lapply(reg_files, read.csv, colClasses = "character"))
reg <- reg[reg$fetched == ave(reg$fetched, reg$registry, FUN = max), ]
all_keys <- candidateKeys(normaliseCandidate(c(mentions$raw, reg$name)))
mentions$key <- all_keys[seq_len(nrow(mentions))]
reg$key <- all_keys[nrow(mentions) + seq_len(nrow(reg))]
tab <- candidateTable(mentions, meta, patterns)
# Names of people (reviewers in FDA signature blocks) are not stored: they are listed only as
# SHA-256 hashes of their key (people.txt) and left out here
people <- if (file.exists("people.txt")) readLines("people.txt") else character(0)
tab <- tab[!vapply(tab$key, digest::digest, "", algo = "sha256", serialize = FALSE) %in% people, ]

# A listed name not found in the corpora gets a row with no items, so it is read too
missing <- setdiff(reg$key, tab$key)
if (length(missing)) {
  add <- tab[0, ][seq_along(missing), ]
  add[] <- lapply(add, function(col) if (is.numeric(col)) 0L else "")
  add$key <- missing
  add$name <- normaliseCandidate(reg$name[match(missing, reg$key)])
  add$first_year <- NA_integer_
  known <- findSoftware(add$name, patterns, groups = c("estimation", "auxiliary", "pbpk", "nca", "other"))
  add$known_family <- vapply(known, function(f) paste(f, collapse = "; "), "")
  tab <- rbind(tab, add)
}
tab$registries <- vapply(tab$key, function(k) paste(sort(unique(reg$registry[reg$key == k])), collapse = "; "), "")
saveRDS(tab, "cache/candidates_all.rds")
write.csv(tab[tab$items >= 2 | nzchar(tab$registries), ], "results/candidates.csv", row.names = FALSE)

# Reading queue: names no pattern covers, in at least 3 items or on a registry, not yet decided.
# Up to five examples per name, from different items and sources first, with the text around it.
decided <- if (file.exists("tool_decisions.csv")) read.csv("tool_decisions.csv", colClasses = "character")$key else character(0)
queue <- tab[!nzchar(tab$known_family) & (tab$items >= 3 | nzchar(tab$registries)) & !tab$key %in% decided, ]
text_of <- setNames(corpus$text, paste(corpus$source, corpus$id))
snips <- lapply(queue$key, function(k) {
  d <- mentions[mentions$key == k, ]
  d <- d[!duplicated(paste(d$source, d$id)), ]
  d <- d[order(duplicated(d$source)), ][seq_len(min(5, nrow(d))), , drop = FALSE]
  vapply(seq_len(nrow(d)), function(i) {
    t <- text_of[[paste(d$source[i], d$id[i])]]
    at <- stringi::stri_locate_first_fixed(t, d$raw[i])[1, 1]
    s <- if (is.na(at)) "" else stringi::stri_sub(t, max(1, at - 200), at + stringi::stri_length(d$raw[i]) + 200)
    paste0("[", d$source[i], " ", d$id[i], "] ", collapseSpace(s))
  }, "")
})
queue$snippets <- vapply(snips, function(x) paste(x, collapse = " || "), "")
dir.create("cache/review", showWarnings = FALSE)
write.csv(queue[c("key", "name", "items", "first_year", "registries", "cues", "snippets")], "cache/review/queue.csv", row.names = FALSE)
info <- c(info, sprintf("reading queue: %d names (no pattern covers them; in at least 3 items or on a registry; not yet decided)", nrow(queue)))

yield <- do.call(rbind, lapply(split(mentions, mentions$cue), function(d) {
  data.frame(
    cue = d$cue[1], matches = nrow(d), items = nrow(unique(d[c("source", "id")])),
    names = length(unique(d$key))
  )
}))
write.csv(yield, "results/cue_yield.csv", row.names = FALSE)

# Items read, with the round in which each was first read
scanned <- data.frame(meta, round = round)
if (file.exists("results/scanned.csv")) {
  old <- read.csv("results/scanned.csv", colClasses = c(id = "character", round = "character"))
  k <- paste(scanned$source, scanned$id)
  hit <- match(k, paste(old$source, old$id))
  scanned$round[!is.na(hit)] <- old$round[hit[!is.na(hit)]]
}
write.csv(scanned[order(scanned$source, scanned$year, scanned$id), ], "results/scanned.csv", row.names = FALSE)
info <- c(info,
  sprintf("new items this round: %d", sum(scanned$round == round)),
  sprintf("matches: %d; names: %d; in at least 2 items: %d; of those already covered by a pattern: %d",
    nrow(mentions), nrow(tab), sum(tab$items >= 2), sum(tab$items >= 2 & nzchar(tab$known_family)))
)
writeLines(info, "results/run_info.txt")
cat(info, sep = "\n")

# ---- Inclusion rule, taxonomy check and recall (once names are decided) ------------
if (file.exists("tool_decisions.csv")) {
  read_dec <- read.csv("tool_decisions.csv", colClasses = "character")
  # Names an existing pattern covers count for that family without being read
  software <- read.csv("../software.csv", colClasses = "character")
  group_of <- setNames(ifelse(software$group == "other", "general", software$group), software$family)
  seeded <- tab[nzchar(tab$known_family) & !tab$key %in% read_dec$key, ]
  seeded_family <- sub(";.*", "", seeded$known_family)
  decisions <- rbind(
    read_dec[c("key", "decision", "family")],
    data.frame(key = seeded$key, decision = unname(group_of[seeded_family]), family = seeded_family)
  )
  inclusion <- toolInclusion(mentions, decisions, reg[c("key", "registry")], minItems = 3)
  write.csv(inclusion, "results/inclusion.csv", row.names = FALSE)
  keep <- if (file.exists("keep.csv")) read.csv("keep.csv", colClasses = "character") else data.frame(family = character(0), reason = character(0))
  proposed <- taxonomyCheck(inclusion, software, keep)
  proposed <- merge(proposed, inclusion[setdiff(names(inclusion), "group")], by = "family", all.x = TRUE)
  write.csv(proposed[order(proposed$action, -proposed$max_items), ], "results/proposed.csv", row.names = FALSE)
  info <- c(info, sprintf(
    "inclusion: %d tool families in scope; to add: %d; kept below the rule: %d; to review: %d",
    sum(inclusion$in_scope), sum(proposed$action == "add"), sum(proposed$action == "keep"), sum(proposed$action == "review")
  ))

  # Recall: items read as fitting a model of their own, or using no tool, that name a tool family
  # the taxonomy does not have
  new_tools <- decisions$key[decisions$decision %in% c("estimation", "auxiliary", "pbpk", "nca") &
    !decisions$family %in% software$family]
  hits <- unique(mentions[mentions$key %in% new_tools, c("source", "id", "key")])
  own_fit <- read.csv("../../sources/literature/no_tool_decisions.csv", colClasses = "character")
  own_fit <- own_fit$id[own_fit$decision == "own_fit"]
  page_res <- read.csv("../../sources/page/results/page_abstracts.csv", colClasses = "character")
  page_none <- page_res$abstract_no[page_res$estimation_source == "none" & page_res$software_demo != "TRUE"]
  est_keys <- decisions$key[decisions$decision == "estimation" & !decisions$family %in% software$family]
  recall <- data.frame(
    set = c("Europe PMC base papers with a model fit of their own naming no tool", "PAGE abstracts 2006 to 2026 using no tool"),
    items = c(length(own_fit), length(page_none)),
    naming_new_estimation_tool = c(
      length(unique(hits$id[hits$source == "Europe PMC" & hits$id %in% own_fit & hits$key %in% est_keys])),
      length(unique(hits$id[hits$source == "PAGE" & hits$id %in% page_none & hits$key %in% est_keys]))
    ),
    naming_any_new_tool = c(
      length(unique(hits$id[hits$source == "Europe PMC" & hits$id %in% own_fit])),
      length(unique(hits$id[hits$source == "PAGE" & hits$id %in% page_none]))
    )
  )
  write.csv(recall, "results/recall.csv", row.names = FALSE)
  writeLines(info, "results/run_info.txt")
  cat(tail(info, 1), "\n")
  print(recall)
}
