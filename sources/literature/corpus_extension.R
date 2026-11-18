# Literature corpus: the extension set (docs/design.md, "The literature base set")
#
# Run from sources/literature/ after the base set of both periods is in place
# (results/ids.csv.gz and results/ids_2016_2020.csv.gz, with corpus_fetch.R run for each):
#   Rscript corpus_extension.R
#
# The extension terms decided on 2026-10-19 (the population PK short forms, population
# pharmacodynamic and NLME; refinement/terms.csv for the query strings) are searched in the
# base set's own fields for 2016 to 2026: PubMed [tiab], Europe PMC title, abstract and
# keywords with the base set's full-text filter. A paper of the base set (either period) is
# not part of the extension, also when Europe PMC lists it under another ID today; a PubMed paper matching two years is kept in the earliest.
# Records and texts are fetched as for the base set; nothing of the base set is overwritten.
#
# Writes:
#   results/extension_queries.csv          term, source, year, query, count, increment, run_date
#   results/extension_ids.csv.gz           source, year, id, admitted_by (extension terms, "; ")
#   results/extension_epmc_records.csv     id, pmid, pmcid, doi, open_access, in_epmc
#   results/extension_fulltext_status.csv  id, pmcid, open_access, status, checked
#   cache/pubmed_ext_*.xml, cache/epmc_records/ext_*.json, cache/fulltext/ (not committed)

library(rentrez)
library(europepmc)

run_date <- format(Sys.Date())
years <- 2016:2026 # 2026 is partial
ua <- "PMx Landscape literature survey (contact: niclas.jonsson@pharmetheus.com)"
terms <- read.csv("refinement/terms.csv", colClasses = "character")
terms <- terms[terms$term %in% c("population PK", "population pharmacodynamic", "NLME"), ]
stopifnot(nrow(terms) == 3)

base <- do.call(rbind, lapply(c("results/ids.csv.gz", "results/ids_2016_2020.csv.gz"), function(f) {
  x <- read.csv(gzfile(f), colClasses = "character")
  x[x$software == "All (base set)", c("source", "id")]
}))
base$source <- ifelse(grepl("^PubMed", base$source), "PubMed", "Europe PMC")

with_retry <- function(f, tries = 10) {
  for (k in seq_len(tries)) {
    r <- tryCatch(f(), error = function(e) e)
    if (!inherits(r, "error")) {
      return(r)
    }
    if (k == tries || !grepl("503|502|500|429|Timeout|timed out", conditionMessage(r))) stop(r)
    message("service error (", conditionMessage(r), "); retrying in ", 15 * k, " s")
    Sys.sleep(15 * k)
  }
}
pm_search <- function(q) {
  Sys.sleep(0.4)
  r <- with_retry(function() entrez_search(db = "pubmed", term = q, retmax = 9999))
  if (as.numeric(r$count) > 9999) stop("more than 9,999 records for ", q)
  list(count = as.numeric(r$count), ids = r$ids)
}
ep_search <- function(q) {
  Sys.sleep(0.2)
  n <- as.numeric(with_retry(function() epmc_hits(q)))
  if (n == 0) {
    return(list(count = 0, ids = character(0)))
  }
  r <- with_retry(function() epmc_search(q, output = "id_list", limit = n + 100, synonym = FALSE, verbose = FALSE))
  list(count = n, ids = unique(paste0(r$source, ":", r$id)))
}
query_dir <- file.path("cache", "queries", paste0("extension_", run_date))
dir.create(query_dir, recursive = TRUE, showWarnings = FALSE)
cached_query <- function(q, f) {
  file <- file.path(query_dir, paste0(digest::digest(q), ".rds"))
  if (file.exists(file)) {
    return(readRDS(file))
  }
  r <- f(q)
  saveRDS(r, file)
  r
}
ep_term <- function(alts) {
  a <- strsplit(alts, "|", fixed = TRUE)[[1]]
  paste0("(", paste(outer(c("TITLE", "ABSTRACT", "KW"), a, paste, sep = ":"), collapse = " OR "), ")")
}

# ---- 1. The increments ---------------------------------------------------------------------

grid <- expand.grid(term = terms$term, source = c("PubMed", "Europe PMC"), year = years, stringsAsFactors = FALSE)
got <- lapply(seq_len(nrow(grid)), function(i) {
  g <- grid[i, ]
  t <- terms[terms$term == g$term, ]
  if (g$source == "PubMed") {
    q <- paste0(t$pubmed, " AND ", g$year, "[dp]")
    r <- cached_query(q, pm_search)
  } else {
    q <- paste0(ep_term(t$epmc), " AND PUB_YEAR:", g$year, " AND HAS_FT:Y AND NOT SRC:PPR")
    r <- cached_query(q, ep_search)
  }
  inc <- setdiff(r$ids, base$id[base$source == g$source])
  list(
    row = data.frame(g, query = q, count = r$count, increment = length(inc), run_date = run_date),
    ids = if (length(inc)) data.frame(g, id = inc)
  )
})
queries <- do.call(rbind, lapply(got, `[[`, "row"))
hits <- do.call(rbind, lapply(got, `[[`, "ids"))
# PubMed: each PMID in the earliest year it matches
first <- tapply(hits$year, paste(hits$source, hits$id), min)
hits <- hits[hits$year == first[paste(hits$source, hits$id)], ]
ext <- aggregate(term ~ source + year + id, hits, function(x) paste(sort(unique(x)), collapse = "; "))
names(ext)[names(ext) == "term"] <- "admitted_by"
ext <- ext[order(ext$source, ext$year, ext$id), ]
write.csv(queries, "results/extension_queries.csv", row.names = FALSE)
gz <- gzfile("results/extension_ids.csv.gz", "w")
write.csv(ext, gz, row.names = FALSE)
close(gz)

# ---- 2. PubMed records ---------------------------------------------------------------------

pm <- sort(unique(ext$id[ext$source == "PubMed"]))
for (b in split(pm, ceiling(seq_along(pm) / 200))) {
  f <- file.path("cache", sprintf("pubmed_ext_%s-%s_n%d.xml", b[1], b[length(b)], length(b)))
  if (!file.exists(f)) {
    Sys.sleep(0.4)
    xml <- with_retry(function() entrez_fetch(db = "pubmed", id = b, rettype = "xml", parsed = FALSE))
    writeLines(xml, f, useBytes = TRUE)
  }
  got_ids <- xml2::xml_text(xml2::xml_find_all(xml2::read_xml(f), "//PubmedArticle/MedlineCitation/PMID | //PubmedBookArticle/BookDocument/PMID"))
  if (length(setdiff(b, got_ids))) stop("PubMed returned no record for ", paste(setdiff(b, got_ids), collapse = ", "))
}

# ---- 3. Europe PMC records and full texts (as corpus_fetch.R) ------------------------------

get_cached <- function(url, file, query = NULL, delay = 0.3) {
  if (file.exists(file)) {
    return(list(file = file, status = 200L))
  }
  req <- httr2::request(url) |>
    httr2::req_user_agent(ua) |>
    httr2::req_url_query(!!!query) |>
    httr2::req_timeout(120) |>
    httr2::req_retry(max_tries = 6, is_transient = function(r) httr2::resp_status(r) %in% c(429, 500, 502, 503)) |>
    httr2::req_error(is_error = function(r) FALSE)
  Sys.sleep(delay)
  r <- tryCatch(httr2::req_perform(req), error = function(e) NULL)
  if (is.null(r)) {
    return(list(file = NA_character_, status = NA_integer_))
  }
  status <- httr2::resp_status(r)
  if (status != 200) {
    return(list(file = NA_character_, status = status))
  }
  writeBin(httr2::resp_body_raw(r), file)
  list(file = file, status = status)
}
ep <- ext$id[ext$source == "Europe PMC"]
rec_dir <- file.path("cache", "epmc_records")
src <- sub(":.*", "", ep)
eid <- sub("^[^:]*:", "", ep)
records <- do.call(rbind, lapply(split(seq_along(ep), ceiling(seq_along(ep) / 50)), function(g) {
  q <- paste0("(", paste0("(EXT_ID:", eid[g], " AND SRC:", src[g], ")", collapse = " OR "), ")")
  f <- get_cached("https://www.ebi.ac.uk/europepmc/webservices/rest/search",
    file.path(rec_dir, sprintf("ext_%s_%s_n%d.json", eid[g[1]], eid[g[length(g)]], length(g))),
    query = list(query = q, resultType = "core", format = "json", pageSize = 100)
  )
  if (is.na(f$file)) stop("could not fetch Europe PMC records (HTTP ", f$status, ")")
  res <- jsonlite::read_json(f$file)$resultList$result
  val <- function(r, k) if (is.null(r[[k]])) NA_character_ else as.character(r[[k]])
  data.frame(
    id = vapply(res, function(r) paste0(r$source, ":", r$id), ""),
    pmid = vapply(res, val, "", "pmid"), pmcid = vapply(res, val, "", "pmcid"), doi = vapply(res, val, "", "doi"),
    open_access = vapply(res, val, "", "isOpenAccess"), in_epmc = vapply(res, val, "", "inEPMC")
  )
}))
records <- records[!duplicated(records$id) & records$id %in% ep, ]
# A base paper can be indexed under another ID today (a PMC: record now listed as MED:, say), so
# its PMID or PMCID is compared too, from the base records and from the base IDs themselves
baseRec <- do.call(rbind, lapply(c("results/epmc_records.csv", "results/epmc_records_2016_2020.csv"), read.csv,
  colClasses = "character"))
epBase <- base$id[base$source == "Europe PMC"]
pmcids <- c(baseRec$pmcid, sub("^PMC:", "", epBase[startsWith(epBase, "PMC:")]))
pmids <- c(baseRec$pmid, sub("^MED:", "", epBase[startsWith(epBase, "MED:")]))
again <- records$id[(!is.na(records$pmcid) & records$pmcid %in% pmcids) | (!is.na(records$pmid) & records$pmid %in% pmids)]
if (length(again)) {
  message(length(again), " extension papers are base papers under another ID, left out: ", paste(again, collapse = ", "))
  records <- records[!records$id %in% again, ]
  ep <- setdiff(ep, again)
  ext <- ext[!(ext$source == "Europe PMC" & ext$id %in% again), ]
  gz <- gzfile("results/extension_ids.csv.gz", "w")
  write.csv(ext, gz, row.names = FALSE)
  close(gz)
}
missing <- setdiff(ep, records$id)
records <- records[order(match(records$id, ep)), ]
write.csv(records, "results/extension_epmc_records.csv", row.names = FALSE)

ft_dir <- file.path("cache", "fulltext")
status <- vapply(seq_len(nrow(records)), function(i) {
  pmcid <- records$pmcid[i]
  if (is.na(pmcid)) {
    return("no PMCID")
  }
  if (file.exists(file.path(ft_dir, paste0(pmcid, ".xml")))) {
    return("cached")
  }
  if (!identical(records$open_access[i], "Y")) {
    return("not open access")
  }
  f <- get_cached(sprintf("https://www.ebi.ac.uk/europepmc/webservices/rest/%s/fullTextXML", pmcid),
    file.path(ft_dir, paste0(pmcid, ".xml")),
    delay = 0.2
  )
  if (is.na(f$file)) paste("open access, not served: HTTP", f$status) else "fetched"
}, "")
st <- data.frame(id = records$id, pmcid = records$pmcid, open_access = records$open_access, status = status, checked = run_date)
if (length(missing)) st <- rbind(st, data.frame(id = missing, pmcid = NA, open_access = NA, status = "no record", checked = run_date))
write.csv(st, "results/extension_fulltext_status.csv", row.names = FALSE)

cat("extension papers by source and term:\n")
print(table(ext$source, ext$admitted_by))
print(table(st$status))
