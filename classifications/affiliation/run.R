# Affiliation: the first author's affiliation type, whether any author is from industry or a CRO,
# and the organisations a naming rule found, by rules only (docs/design.md, Decisions
# 2026-10-19; affiliationTags())
#
# Run from classifications/affiliation/ after make corpus:
#   Rscript run.R tags        tags.csv, coverage.csv and the comparison with the earlier types
#   Rscript run.R sample      a development check: 30 first-author affiliations per source and
#                             type, as batch files for subagents (cache/check_v1, not committed)
#   Rscript run.R precision   the subagents' answers (cache/check_v1/answers_*.jsonl) into
#                             precision.csv
#
# Author names are never written: organisations that could name a person are withheld
# (affiliationTags()), and the affiliation text read in the check stays in cache/.

pkgload::load_all("../../pmxlandscape", quiet = TRUE)

step <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(step) || !step %in% c("tags", "sample", "precision")) stop("usage: Rscript run.R tags|sample|precision")
m <- jsonlite::read_json("module.json")
rules <- readAffiliationRules("../../taxonomy/affiliation_rules.csv")
sources <- list(
  list(name = "page", label = "PAGE", sections = c("authors", "affiliations")),
  list(name = "pubmed", label = "PubMed", sections = c("authors", "author_affiliations")),
  list(name = "epmc", label = "Europe PMC", sections = c("authors", "author_affiliations"))
)
tagsOf <- function(text = FALSE) {
  do.call(rbind, lapply(sources, function(s) {
    x <- corpusRead("../../corpus", s$name, sections = s$sections)
    t <- affiliationTags(x$sections, rules, s$label, text = text)
    # items without any of the sections (no record) have no affiliation either
    miss <- setdiff(x$items$item_id, t$item_id)
    if (length(miss)) {
      add <- data.frame(
        source = s$label, item_id = miss, first_author_type = "no affiliation", first_author_organisation = NA,
        first_author_named = NA,
        any_industry = FALSE, any_cro = FALSE, organisations = NA, named_organisations = NA, withheld = 0L
      )
      if (text) add$first_author_affiliation <- NA
      t <- rbind(t, add)
    }
    t$year <- x$items$year[match(t$item_id, x$items$item_id)]
    t$admitted <- sub(" .*", "", sub(":.*", "", x$items$admitted_by[match(t$item_id, x$items$item_id)]))
    t[order(match(t$item_id, x$items$item_id)), ]
  }))
}

if (step == "tags") {
  t <- tagsOf()
  # Only names a naming rule found are published (Niclas, 2026-10-20); every other organisation
  # name stays in the local cache
  dir.create("cache", showWarnings = FALSE)
  write.csv(t, file.path("cache", "organisations_local.csv"), row.names = FALSE, na = "")
  t$first_author_organisation <- t$first_author_named
  t$first_author_named <- NULL
  t$organisations <- NULL
  t$method <- "rule"
  t$reader <- paste0("taxonomy/affiliation_rules.csv (module version ", m$version, ")")
  write.csv(t, "tags.csv", row.names = FALSE, na = "")
  cov <- do.call(rbind, lapply(split(t, t$source), function(d) {
    tab <- table(factor(d$first_author_type, levels = c(unique(rules$category), "unclassified", "no affiliation")))
    data.frame(
      source = d$source[1], first_author_type = names(tab), items = as.integer(tab),
      share = as.numeric(tab) / nrow(d), any_industry = sum(d$any_industry), any_cro = sum(d$any_cro),
      withheld_items = sum(d$withheld > 0), items_total = nrow(d)
    )
  }))
  write.csv(cov, "coverage.csv", row.names = FALSE)
  print(cov[cov$items > 0, ], row.names = FALSE, digits = 2)
  # The earlier first-author types: PubMed (sources/literature/affiliations.R) and PAGE
  old <- rbind(
    do.call(rbind, lapply(c("pubmed_affiliations.csv", "pubmed_affiliations_2016_2020.csv"), function(f) {
      f <- file.path("../../sources/literature/results", f)
      if (file.exists(f)) data.frame(source = "PubMed", read.csv(f, colClasses = "character")[c("pmid", "affiliation_type")])
    })) |> setNames(c("source", "item_id", "old")),
    with(
      read.csv("../../sources/page/results/page_abstracts.csv", colClasses = "character"),
      data.frame(source = "PAGE", item_id = abstract_no, old = ifelse(is.na(affiliation_type) | affiliation_type == "",
        "no affiliation", affiliation_type
      ))
    )
  )
  cmp <- merge(old, t[c("source", "item_id", "first_author_type")], by = c("source", "item_id"))
  agree <- aggregate(same ~ source, transform(cmp, same = old == first_author_type), function(x) c(sum(x), length(x)))
  agree <- data.frame(source = agree$source, same = agree$same[, 1], compared = agree$same[, 2])
  write.csv(agree, "earlier_agreement.csv", row.names = FALSE)
  print(agree, row.names = FALSE)
  print(table(cmp$old[cmp$old != cmp$first_author_type], cmp$first_author_type[cmp$old != cmp$first_author_type]))
}

if (step == "sample") {
  t <- tagsOf(text = TRUE)
  t <- t[!is.na(t$first_author_affiliation), ]
  set.seed(m$check$seed)
  s <- do.call(rbind, lapply(split(t, list(t$source, t$first_author_type), drop = TRUE), function(d) {
    d[sample(nrow(d), min(m$check$per_class, nrow(d))), ]
  }))
  dir <- file.path("cache", "check_v1")
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  s$check_id <- sprintf("c%04d", seq_len(nrow(s)))
  saveRDS(s, file.path(dir, "sample.rds"))
  for (b in split(seq_len(nrow(s)), ceiling(seq_len(nrow(s)) / 120))) {
    lines <- sprintf(
      "%s\t%s\t%s\t%s", s$check_id[b], s$first_author_type[b],
      ifelse(is.na(s$first_author_organisation[b]), "(withheld or none)", s$first_author_organisation[b]),
      gsub("[\t\n]", " ", s$first_author_affiliation[b])
    )
    writeLines(
      c("check_id\tassigned_type\tstored_organisation\taffiliation", lines),
      file.path(dir, sprintf("batch_%03d.tsv", b[1] %/% 120 + 1))
    )
  }
  cat(nrow(s), "affiliations in", ceiling(nrow(s) / 120), "batches\n")
  print(table(s$source, s$first_author_type))
}

if (step == "precision") {
  dir <- file.path("cache", "check_v1")
  s <- readRDS(file.path(dir, "sample.rds"))
  a <- do.call(rbind, lapply(list.files(dir, "^answers_\\d+\\.jsonl$", full.names = TRUE), function(f) {
    do.call(rbind, lapply(readLines(f), function(l) as.data.frame(jsonlite::fromJSON(l))))
  }))
  if (any(!a$check_id %in% s$check_id) || anyDuplicated(a$check_id)) stop("answers do not match the sample")
  s <- merge(s, a, by = "check_id", all.x = TRUE)
  p <- do.call(rbind, lapply(split(s, list(s$source, s$first_author_type), drop = TRUE), function(d) {
    data.frame(
      source = d$source[1], first_author_type = d$first_author_type[1], read = sum(!is.na(d$type_ok)),
      type_correct = sum(d$type_ok %in% "yes"), type_wrong = sum(d$type_ok %in% "no"),
      organisation_correct = sum(d$organisation_ok %in% "yes"), organisation_wrong = sum(d$organisation_ok %in% "no"),
      names_a_person = sum(d$names_person %in% "yes")
    )
  }))
  p$reader <- "Claude Code subagent (Claude Sonnet 5.5), development check"
  write.csv(p, "precision.csv", row.names = FALSE)
  print(p, row.names = FALSE)
  # the wrong ones, without the affiliation text, for the card
  w <- s[
    s$type_ok %in% "no" | s$organisation_ok %in% "no" | s$names_person %in% "yes",
    c("source", "item_id", "first_author_type", "should_be", "type_ok", "organisation_ok", "names_person", "note")
  ]
  write.csv(w, "precision_errors.csv", row.names = FALSE)
}
