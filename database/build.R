# The tag database: the published layer of the design (docs/design.md)
#
# Run from the repository root: Rscript database/build.R
#
# Builds, from the committed corpus tables and classification outputs (no text, no downloads):
#   database/items.csv.gz       every corpus item: source, item_id, year, url, coverage, hash
#   database/tags.csv.gz        one row per item, classification and label: value, method, reader,
#                               prompt hash, date
#   database/item_links.csv     pairs of items in different sources that are the same work
#   database/classifications.csv  each classification: version, question, values, reader, check,
#                               rules, prompt hash, agreement
#   database/release.txt        the package version, the commit and the corpus build dates
# The FDA decision record enters as the classification `fda_record` (per drug and tool:
# applicant, indirect, reviewer, both), since it stays the decision of record.

pkgload::load_all("pmxlandscape", quiet = TRUE)
out <- "database"
dir.create(out, showWarnings = FALSE)
gz <- function(x, f) {
  con <- gzfile(file.path(out, f), "w")
  utils::write.csv(x, con, row.names = FALSE)
  close(con)
}

# ---- items ----
names <- c("page", "pubmed", "epmc", "fda")
items <- do.call(rbind, lapply(names, function(n) {
  x <- read.csv(file.path("corpus", n, "items.csv"), colClasses = "character")
  x[c("source", "item_id", "year", "url", "coverage", "hash")]
}))
gz(items, "items.csv.gz")

# ---- tags ----
tagCols <- c("source", "item_id", "classification", "label", "value", "method", "reader", "prompt_hash", "date")
mods <- list.dirs("classifications", recursive = FALSE)
mods <- mods[file.exists(file.path(mods, "tags.csv"))]
tags <- do.call(rbind, lapply(mods, function(d) {
  m <- jsonlite::read_json(file.path(d, "module.json"))
  t <- read.csv(file.path(d, "tags.csv"), colClasses = "character")
  if (!"label" %in% names(t)) {
    # A module with one row per item and one column per field (affiliation): one tag per field,
    # empty fields left out
    fields <- setdiff(names(t), c("source", "item_id", "year", "admitted", "method", "reader"))
    t <- do.call(rbind, lapply(fields, function(f) {
      data.frame(source = t$source, item_id = t$item_id, label = f, value = t[[f]], method = t$method,
        reader = t$reader, prompt_hash = "", date = "")
    }))
    t <- t[!is.na(t$value) & nzchar(t$value), ]
  }
  t$classification <- paste0(m$name, " v", m$version)
  t[tagCols]
}))
rec <- read.csv("sources/fda/results/fda_2021_2025_popPK_software.csv", colClasses = "character")
rec <- fdaApplyRevisions(rec, read.csv("sources/fda/results/record_revisions.csv", colClasses = "character"))
fr <- rbind(
  data.frame(application = rec$application, label = rec$sponsor_tool_family, evidence = rec$evidence_strength, who = "applicant"),
  data.frame(application = rec$application, label = rec$fda_tool_family, evidence = "", who = "reviewer")
)
fr <- fr[nzchar(fr$label), ]
fr <- do.call(rbind, lapply(split(fr, paste(fr$application, fr$label)), function(d) {
  a <- d[d$who == "applicant", ]
  value <- if (nrow(a) && a$evidence[1] == "stated") {
    if (any(d$who == "reviewer")) "both" else "applicant"
  } else if (nrow(a)) "indirect" else "reviewer"
  data.frame(source = "FDA", item_id = d$application[1], classification = "fda_record", label = d$label[1], value = value,
    method = "record", reader = "FDA decision record (sources/fda/results)", prompt_hash = "", date = "2026-09-29")
}))
tags <- rbind(tags, fr)
gz(tags[order(tags$source, tags$item_id, tags$classification, tags$label), ], "tags.csv.gz")

# ---- links: PubMed and Europe PMC records of the same paper (exact, on the PMID) ----
rec <- read.csv("sources/literature/results/epmc_records.csv", colClasses = "character")
ep <- items[items$source == "Europe PMC", ]
pmid <- ifelse(startsWith(ep$item_id, "MED:"), sub("^MED:", "", ep$item_id), rec$pmid[match(ep$item_id, rec$id)])
pm <- items$item_id[items$source == "PubMed"]
hit <- !is.na(pmid) & pmid %in% pm
links <- data.frame(source_a = "PubMed", item_a = pmid[hit], source_b = "Europe PMC", item_b = ep$item_id[hit],
  kind = "same paper", found_by = "PMID", certainty = "exact")
write.csv(links, file.path(out, "item_links.csv"), row.names = FALSE)

# ---- classifications ----
cls <- do.call(rbind, lapply(mods, function(d) {
  raw <- jsonlite::read_json(file.path(d, "module.json"))
  if (is.null(raw$rubric)) {
    # A rules-only module (affiliation): no rubric, no language-model reader; its check is
    # described on its card
    v <- read.csv(file.path(d, raw$values %||% "values.csv"), colClasses = "character")
    return(data.frame(
      classification = paste0(raw$name, " v", raw$version), question = raw$question,
      values = paste(v[[1]], collapse = "; "), reader = as.character(raw$reader),
      check_reader = raw$check$reader %||% "", rules = nrow(read.csv(file.path(d, raw$rules))),
      prompt_hash = "", card = file.path(d, "card.md"), check_agreement = NA, check_kappa = NA
    ))
  }
  m <- readModule(d)
  ck <- if (file.exists(file.path(d, "checks.csv"))) read.csv(file.path(d, "checks.csv")) else NULL
  data.frame(
    classification = paste0(m$name, " v", m$version), question = m$question,
    values = paste(m$values$value, collapse = "; "), reader = m$reader$model, check_reader = m$check$model %||% "",
    rules = nrow(m$rules), prompt_hash = promptHash(m), card = file.path(d, "card.md"),
    check_agreement = if (is.null(ck)) NA else ck$share[1], check_kappa = if (is.null(ck)) NA else ck$kappa[1]
  )
}))
write.csv(cls, file.path(out, "classifications.csv"), row.names = FALSE)

# ---- release ----
built <- vapply(names, function(n) sub("^built: ", "", readLines(file.path("corpus", n, "run_info.txt"))[1]), "")
writeLines(c(
  paste("package version:", read.dcf("pmxlandscape/DESCRIPTION")[, "Version"]),
  paste("commit of the inputs:", system2("git", c("rev-parse", "--short", "HEAD"), stdout = TRUE)),
  paste0("corpus built: ", paste(names, built, sep = " ", collapse = "; "))
), file.path(out, "release.txt"))
cat(nrow(items), "items;", nrow(tags), "tags in", length(unique(tags$classification)), "classifications;", nrow(links), "links\n")
