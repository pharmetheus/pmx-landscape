# Literature corpus: the tool route (decided 2026-10-20, docs/design.md)
#
# Run from sources/literature/ after corpus_fetch.R and corpus_extension.R:
#   Rscript corpus_toolroute.R
#
# The term route (the base set and the extension) finds papers by the field's names for the
# method. The tool route finds papers that name a pharmacometric estimation tool, whatever they
# call their method: PubMed in the title and abstract ([tiab]), Europe PMC in the methods section
# of open-access full text (METHODS:, OPEN_ACCESS:Y), for 2016 to 2026. The tools are the
# estimation families made for pharmacometric work (`tools` below, with the name forms of
# taxonomy/software.csv); general statistical tools (BUGS, JAGS, Stan, nlme, NLMIXED) do not find
# papers. "Pumas" is searched as a plain word too, since papers write "Pumas 2.4"; papers about
# the animal are dropped by the local tool search and the relevance reading.
#
# Every ID found is kept with the tools that found it, term-route papers included, so that a
# paper found by both routes records both. Papers not in the term route are fetched as the base
# set is: PubMed records, Europe PMC records and open-access full texts. A Europe PMC paper whose
# full text cannot be downloaded leaves the tool route, since the tool is named in text that must
# be read. A paper of the term route listed under another ID today counts as a term-route paper.
#
# Writes:
#   results/tool_queries.csv           tool, source, year, query, count, outside, run_date
#   results/tool_ids.csv.gz            source, year, id, tools ("; "), term_route (TRUE/FALSE)
#   results/tool_epmc_records.csv      id, pmid, pmcid, doi, open_access, in_epmc
#   results/tool_fulltext_status.csv   id, pmcid, open_access, status, checked
#   cache/pubmed_tool_*.xml, cache/epmc_records/tool_*.json, cache/fulltext/ (not committed)

library(rentrez)
library(europepmc)

run_date <- format(Sys.Date())
years <- 2016:2026 # 2026 is partial
ua <- "PMx Landscape literature survey (contact: niclas.jonsson@pharmetheus.com)"
tools <- data.frame(
  tool = c("NONMEM", "Monolix", "Phoenix NLME", "nlmixr", "Pumas", "Pmetrics", "saemix", "S-ADAPT"),
  pubmed = c(
    '("NONMEM"[tiab] OR "NON-MEM"[tiab] OR NONMEN[tiab] OR NONMEMS[tiab] OR NONMENE[tiab])',
    "Monolix*[tiab]", '"Phoenix NLME"[tiab:~5]', "nlmixr*[tiab]", "Pumas[tiab]", "Pmetrics[tiab]",
    '"saemix"[tiab]', '"S-ADAPT"[tiab]'
  ),
  epmc = c(
    '(METHODS:"NONMEM" OR METHODS:"NON-MEM" OR METHODS:NONMEN OR METHODS:NONMEMS OR METHODS:NONMENE)',
    "METHODS:Monolix*", 'METHODS:"Phoenix NLME"~5', "(METHODS:nlmixr OR METHODS:nlmixr2)", "METHODS:Pumas",
    "METHODS:Pmetrics", 'METHODS:"saemix"', 'METHODS:"S-ADAPT"'
  ),
  stringsAsFactors = FALSE
)

readBase <- function(f) {
  x <- read.csv(gzfile(f), colClasses = "character")
  x <- x[x$software == "All (base set)", c("source", "id")]
  x$source <- ifelse(grepl("^PubMed", x$source), "PubMed", "Europe PMC")
  x
}
term <- rbind(
  readBase("results/ids.csv.gz"), readBase("results/ids_2016_2020.csv.gz"),
  read.csv(gzfile("results/extension_ids.csv.gz"), colClasses = "character")[c("source", "id")]
)

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
query_dir <- file.path("cache", "queries", paste0("toolroute_", run_date))
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

# ---- 1. The searches -----------------------------------------------------------------------

grid <- expand.grid(tool = tools$tool, source = c("PubMed", "Europe PMC"), year = years, stringsAsFactors = FALSE)
got <- lapply(seq_len(nrow(grid)), function(i) {
  g <- grid[i, ]
  t <- tools[tools$tool == g$tool, ]
  if (g$source == "PubMed") {
    q <- paste0(t$pubmed, " AND ", g$year, "[dp]")
    r <- cached_query(q, pm_search)
  } else {
    q <- paste0(t$epmc, " AND PUB_YEAR:", g$year, " AND OPEN_ACCESS:Y AND NOT SRC:PPR")
    r <- cached_query(q, ep_search)
  }
  outside <- setdiff(r$ids, term$id[term$source == g$source])
  list(
    row = data.frame(g, query = q, count = r$count, outside = length(outside), run_date = run_date),
    ids = if (length(r$ids)) data.frame(g, id = r$ids, row.names = NULL)
  )
})
queries <- do.call(rbind, lapply(got, `[[`, "row"))
hits <- do.call(rbind, lapply(got, `[[`, "ids"))
# PubMed: each PMID in the earliest year it matches
first <- tapply(hits$year, paste(hits$source, hits$id), min)
hits <- hits[hits$year == first[paste(hits$source, hits$id)], ]
found <- aggregate(tool ~ source + year + id, hits, function(x) paste(sort(unique(x)), collapse = "; "))
names(found)[names(found) == "tool"] <- "tools"
found$term_route <- paste(found$source, found$id) %in% paste(term$source, term$id)
write.csv(queries, "results/tool_queries.csv", row.names = FALSE)

# ---- 2. PubMed records of the papers outside the term route ---------------------------------

pm <- sort(unique(found$id[found$source == "PubMed" & !found$term_route]))
for (b in split(pm, ceiling(seq_along(pm) / 200))) {
  f <- file.path("cache", sprintf("pubmed_tool_%s-%s_n%d.xml", b[1], b[length(b)], length(b)))
  if (!file.exists(f)) {
    Sys.sleep(0.4)
    xml <- with_retry(function() entrez_fetch(db = "pubmed", id = b, rettype = "xml", parsed = FALSE))
    writeLines(xml, f, useBytes = TRUE)
  }
  got_ids <- xml2::xml_text(xml2::xml_find_all(
    xml2::read_xml(f), "//PubmedArticle/MedlineCitation/PMID | //PubmedBookArticle/BookDocument/PMID"
  ))
  if (length(setdiff(b, got_ids))) stop("PubMed returned no record for ", paste(setdiff(b, got_ids), collapse = ", "))
}

# ---- 3. Europe PMC records and full texts (as corpus_extension.R) ---------------------------

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
ep <- found$id[found$source == "Europe PMC" & !found$term_route]
rec_dir <- file.path("cache", "epmc_records")
src <- sub(":.*", "", ep)
eid <- sub("^[^:]*:", "", ep)
records <- do.call(rbind, lapply(split(seq_along(ep), ceiling(seq_along(ep) / 50)), function(g) {
  q <- paste0("(", paste0("(EXT_ID:", eid[g], " AND SRC:", src[g], ")", collapse = " OR "), ")")
  f <- get_cached("https://www.ebi.ac.uk/europepmc/webservices/rest/search",
    file.path(rec_dir, sprintf("tool_%s_%s_n%d.json", eid[g[1]], eid[g[length(g)]], length(g))),
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
# A term-route paper can be indexed under another ID today, so its PMID or PMCID is compared too
termRec <- do.call(rbind, lapply(
  c("results/epmc_records.csv", "results/epmc_records_2016_2020.csv", "results/extension_epmc_records.csv"),
  read.csv,
  colClasses = "character"
))
epTerm <- term$id[term$source == "Europe PMC"]
termKeys <- rbind(
  data.frame(key = paste0("pmcid:", termRec$pmcid), id = termRec$id),
  data.frame(key = paste0("pmid:", termRec$pmid), id = termRec$id),
  data.frame(key = paste0("pmcid:", sub("^PMC:", "", epTerm)), id = epTerm)[startsWith(epTerm, "PMC:"), ],
  data.frame(key = paste0("pmid:", sub("^MED:", "", epTerm)), id = epTerm)[startsWith(epTerm, "MED:"), ]
)
termKeys <- termKeys[termKeys$id %in% epTerm & !grepl(":(NA)?$", termKeys$key), ]
termKeys <- termKeys[!duplicated(termKeys$key), ]
byPmcid <- termKeys$id[match(paste0("pmcid:", records$pmcid), termKeys$key)]
byPmid <- termKeys$id[match(paste0("pmid:", records$pmid), termKeys$key)]
records$term_id <- ifelse(is.na(byPmcid), byPmid, byPmcid)
again <- records$id[!is.na(records$term_id)]
if (length(again)) {
  # Such a paper is recorded under its term-route ID, the one the corpus holds it by
  message(length(again), " tool-route papers are term-route papers under another ID: ", paste(again, collapse = ", "))
  i <- found$source == "Europe PMC" & found$id %in% again
  found$id[i] <- records$term_id[match(found$id[i], records$id)]
  found$term_route[i] <- TRUE
  key <- paste(found$source, found$id)
  found <- do.call(rbind, lapply(split(found, factor(key, unique(key))), function(x) {
    data.frame(
      source = x$source[1], year = min(x$year), id = x$id[1],
      tools = paste(sort(unique(unlist(strsplit(x$tools, "; ")))), collapse = "; "), term_route = any(x$term_route)
    )
  }))
  records <- records[!records$id %in% again, ]
  ep <- setdiff(ep, again)
}
records$term_id <- NULL
missing <- setdiff(ep, records$id)
records <- records[order(match(records$id, ep)), ]
write.csv(records, "results/tool_epmc_records.csv", row.names = FALSE)

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
write.csv(st, "results/tool_fulltext_status.csv", row.names = FALSE)

# Europe PMC papers outside the term route stay in the tool route only with a downloaded full text
noText <- st$id[!st$status %in% c("cached", "fetched")]
found <- found[!(found$source == "Europe PMC" & !found$term_route & found$id %in% noText), ]
found <- found[order(found$source, found$year, found$id), ]
gz <- gzfile("results/tool_ids.csv.gz", "w")
write.csv(found, gz, row.names = FALSE)
close(gz)

cat("tool route papers by source, in the term route or not:\n")
print(table(found$source, found$term_route))
print(table(st$status))
