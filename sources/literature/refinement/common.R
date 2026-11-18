# Shared parts of the refinement scripts: the frozen base set, the retrieval helpers and the
# query cache. The helpers are those of ../publication_trends.R (same PubMed month split, same
# Europe PMC retry and `synonym = FALSE`), so a query here returns what it would return there.
#
# Run the scripts from sources/literature/refinement/.

library(rentrez)
library(europepmc)

years <- 2021:2025 # complete years only; 2026 is left out of the measurement
run_date <- format(Sys.Date())
dir.create("results", showWarnings = FALSE)

# The frozen base set (publication_trends.R, run 2026-09-28): every base ID of each source,
# whatever its year, so a paper of the base set never counts as missed or as an increment
baseIds <- local({
  ids <- read.csv(gzfile("../results/ids.csv.gz"), colClasses = "character")
  ids <- ids[ids$software == "All (base set)", ]
  list(PubMed = unique(ids$id[ids$source == "PubMed (title/abstract)"]),
    `Europe PMC` = unique(ids$id[ids$source == "Europe PMC (full text)"]))
})

# The base terms, as in publication_trends.R
pmBase <- paste0(
  '("population pharmacokinetic*"[tiab] OR pharmacometric*[tiab] OR ',
  '"nonlinear mixed effects"[tiab] OR "non-linear mixed effects"[tiab])'
)
epFilter <- "AND HAS_FT:Y AND NOT SRC:PPR"

# Unambiguous estimation tool names (Pumas, Stan, Torsten and ADAPT left out: they are also
# ordinary words or names), for the tool-anchored reference set and the tool-naming rate
pmTools <- paste0(
  '("NONMEM"[tiab] OR "NON-MEM"[tiab] OR NONMEN[tiab] OR NONMEMS[tiab] OR NONMENE[tiab] OR ',
  'Monolix*[tiab] OR "Phoenix NLME"[tiab:~5] OR nlmixr*[tiab] OR "saemix"[tiab] OR ',
  'Pmetrics[tiab] OR NLMIXED[tiab] OR "S-ADAPT"[tiab])'
)
epToolTerms <- paste0(
  '("NONMEM" OR "NON-MEM" OR NONMEN OR NONMEMS OR NONMENE OR Monolix* OR "Phoenix NLME"~5 OR ',
  'nlmixr OR nlmixr2 OR "saemix" OR Pmetrics OR NLMIXED OR "S-ADAPT")'
)

pmIds <- function(q, year) {
  Sys.sleep(0.4) # PubMed allows 3 requests a second without an API key
  n <- as.numeric(entrez_search(db = "pubmed", term = q, retmax = 0)$count)
  if (n == 0) {
    return(list(count = 0, ids = character(0)))
  }
  if (n <= 9999) {
    Sys.sleep(0.4)
    return(list(count = n, ids = entrez_search(db = "pubmed", term = q, retmax = 9999)$ids))
  }
  ids <- unlist(lapply(1:12, function(m) {
    last <- format(seq(as.Date(sprintf("%d-%02d-01", year, m)), by = "month", length.out = 2)[2] - 1, "%Y/%m/%d")
    qm <- sprintf('%s AND ("%d/%02d/01"[dp] : "%s"[dp])', sub(sprintf(" AND %d\\[dp\\]", year), "", q), year, m, last)
    Sys.sleep(0.4)
    r <- entrez_search(db = "pubmed", term = qm, retmax = 9999)
    if (as.numeric(r$count) > 9999) stop("More than 9,999 PubMed records in one month for: ", qm)
    r$ids
  }))
  list(count = n, ids = unique(ids))
}

withRetry <- function(f, tries = 10) {
  for (k in seq_len(tries)) {
    r <- tryCatch(f(), error = function(e) e)
    if (!inherits(r, "error")) {
      return(r)
    }
    if (k == tries || !grepl("503|502|500|429|Timeout|timed out", conditionMessage(r))) stop(r)
    message("Europe PMC error (", conditionMessage(r), "); retrying in ", 15 * k, " s")
    Sys.sleep(15 * k)
  }
}

epIds <- function(q, year) {
  Sys.sleep(0.2)
  n <- as.numeric(withRetry(function() epmc_hits(q)))
  if (n == 0) {
    return(list(count = 0, ids = character(0)))
  }
  r <- withRetry(function() epmc_search(q, output = "id_list", limit = n + 100, synonym = FALSE, verbose = FALSE))
  list(count = n, ids = unique(paste0(r$source, ":", r$id)))
}

# Each query's result is cached under the run date, so a run stopped by a service error resumes
# and a rerun the same day gives the same answer
cachedQuery <- function(q, year, source) {
  dir <- file.path("cache", "queries", run_date)
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  f <- file.path(dir, paste0(digest::digest(q), ".rds"))
  if (file.exists(f)) {
    return(readRDS(f))
  }
  r <- if (source == "PubMed") pmIds(q, year) else epIds(q, year)
  saveRDS(r, f)
  r
}

writeGz <- function(x, f) {
  con <- gzfile(f, "w")
  write.csv(x, con, row.names = FALSE)
  close(con)
}

ua <- "PMx Landscape literature survey (contact: niclas.jonsson@pharmetheus.com)"

# A GET cached to a file (as in ../corpus_fetch.R): a file already there is not fetched again
getCached <- function(url, file, query = NULL, delay = 0.3) {
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
