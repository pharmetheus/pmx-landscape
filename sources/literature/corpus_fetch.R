# Literature corpus: what the corpus layer needs beyond the counts run
#
# Run from sources/literature/: Rscript corpus_fetch.R
#
# For the base set frozen by the counts run of 2026-09-28 (results/ids.csv.gz), or, with
# LIT_YEARS=2016-2020, for the earlier years' base set (results/ids_2016_2020.csv.gz), whose
# outputs get the same suffix:
# 1. admitted_by: each core base term is queried on its own, per year, so the corpus can
#    record which terms admitted each paper. The services keep indexing, so a paper of the
#    frozen set that no term returns today is recorded as such, not dropped.
# 2. Europe PMC records (title, abstract, keywords, IDs, open-access flag) for every base
#    paper, 50 per query, so papers without a downloadable full text still have their
#    title and abstract in the corpus.
# 3. Full texts: every open-access base paper without a cached full text is tried again,
#    and the outcome for every base paper is recorded.
#
# Writes:
#   results/admitted_by.csv      source, id, admitted_by (core terms, "; "), checked
#   results/epmc_records.csv     id, pmid, pmcid, doi, open_access, in_epmc
#   results/fulltext_status.csv  id, pmcid, open_access, status, checked
#   cache/                       query results, records and full texts (not committed)

library(rentrez)
library(europepmc)

run_date <- format(Sys.Date())
ua <- "PMx Landscape literature survey (contact: niclas.jonsson@pharmetheus.com)"
span <- Sys.getenv("LIT_YEARS")
suffix <- if (nzchar(span)) paste0("_", sub("-", "_", span)) else ""
outFile <- function(name) file.path("results", paste0(name, suffix, ".csv"))
ids <- read.csv(gzfile(paste0("results/ids", suffix, ".csv.gz")), colClasses = "character")
base <- ids[ids$software == "All (base set)", ]
pm_base <- unique(base$id[base$source == "PubMed (title/abstract)"])
ep_base <- unique(base$id[base$source == "Europe PMC (full text)"])
years <- sort(unique(as.integer(base$year)))

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

query_dir <- file.path("cache", "queries", paste0("terms_", run_date))
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

# ---- 1. Which core terms admitted each paper ---------------------------------------------

pm_terms <- c(
  "population pharmacokinetic*" = '"population pharmacokinetic*"[tiab]', "pharmacometric*" = "pharmacometric*[tiab]",
  "nonlinear mixed effects" = '"nonlinear mixed effects"[tiab]', "non-linear mixed effects" = '"non-linear mixed effects"[tiab]'
)
ep_terms <- c(
  "population pharmacokinetic" = '"population pharmacokinetic"', "population pharmacokinetics" = '"population pharmacokinetics"',
  "pharmacometric*" = "pharmacometric*", "nonlinear mixed effects" = '"nonlinear mixed effects"',
  "non-linear mixed effects" = '"non-linear mixed effects"'
)
pm_search <- function(q) {
  Sys.sleep(0.4)
  r <- entrez_search(db = "pubmed", term = q, retmax = 9999)
  if (as.numeric(r$count) > 9999) stop("more than 9,999 records for ", q)
  r$ids
}
ep_search <- function(q) {
  Sys.sleep(0.2)
  n <- as.numeric(with_retry(function() epmc_hits(q)))
  if (n == 0) {
    return(character(0))
  }
  r <- with_retry(function() epmc_search(q, output = "id_list", limit = n + 100, synonym = FALSE, verbose = FALSE))
  unique(paste0(r$source, ":", r$id))
}
hits <- list()
for (t in names(pm_terms)) for (y in years) {
  hits[[length(hits) + 1]] <- data.frame(source = "PubMed", term = t, id = cached_query(paste0(pm_terms[[t]], " AND ", y, "[dp]"), pm_search))
}
for (t in names(ep_terms)) for (y in years) {
  q <- sprintf("(TITLE:%s OR ABSTRACT:%s OR KW:%s) AND HAS_FT:Y AND NOT SRC:PPR AND PUB_YEAR:%d", ep_terms[[t]], ep_terms[[t]], ep_terms[[t]], y)
  hits[[length(hits) + 1]] <- data.frame(source = "Europe PMC", term = t, id = cached_query(q, ep_search))
}
hits <- do.call(rbind, hits)
admitted <- function(src, set) {
  h <- hits[hits$source == src & hits$id %in% set, ]
  by <- tapply(h$term, factor(h$id, levels = set), function(x) paste(unique(x), collapse = "; "))
  by[is.na(by)] <- paste("no core term matched on", run_date)
  data.frame(source = src, id = set, admitted_by = unname(by), checked = run_date)
}
adm <- rbind(admitted("PubMed", pm_base), admitted("Europe PMC", ep_base))
write.csv(adm, outFile("admitted_by"), row.names = FALSE)

# ---- 2. Europe PMC records for the whole base set ------------------------------------------

rec_dir <- file.path("cache", "epmc_records")
dir.create(rec_dir, showWarnings = FALSE)
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
src <- sub(":.*", "", ep_base)
ext <- sub("^[^:]*:", "", ep_base)
groups <- split(seq_along(ep_base), ceiling(seq_along(ep_base) / 50))
records <- do.call(rbind, lapply(groups, function(g) {
  q <- paste0("(", paste0("(EXT_ID:", ext[g], " AND SRC:", src[g], ")", collapse = " OR "), ")")
  f <- get_cached("https://www.ebi.ac.uk/europepmc/webservices/rest/search",
    file.path(rec_dir, sprintf("base_%s_%s_n%d.json", ext[g[1]], ext[g[length(g)]], length(g))),
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
records <- records[!duplicated(records$id) & records$id %in% ep_base, ]
missing <- setdiff(ep_base, records$id)
if (length(missing)) message(length(missing), " base papers returned no record")
records <- records[order(match(records$id, ep_base)), ]
write.csv(records, outFile("epmc_records"), row.names = FALSE)

# ---- 3. Full texts: retry and record --------------------------------------------------------

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
write.csv(st, outFile("fulltext_status"), row.names = FALSE)

cat("admitted_by:", sum(!grepl("^no core term", adm$admitted_by)), "of", nrow(adm), "matched a core term\n")
print(table(adm$source, grepl("^no core term", adm$admitted_by)))
print(table(st$status))
