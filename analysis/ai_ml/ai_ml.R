# AI and machine learning in pharmacometrics: when the terms first appear, and how often since
#
# Run from analysis/ai_ml/:
#   Rscript ai_ml.R                    # all steps (network for PAGE, PubMed and Europe PMC)
#   AIML_STEPS=page,pubmed Rscript ai_ml.R   # some steps only; the others are read from cache/
#
# Terms: taxonomy/ai_ml_terms.csv, two groups. ML is the named learning methods (machine
# learning, neural networks, deep learning, random forests, ...); AI is the label and its newer
# forms (artificial intelligence, AI, expert systems, large language models, ChatGPT, ...).
#
# Sources, each with its own base set (the denominator):
#   PAGE        every abstract of the meetings 1992 to 2026 (no meeting in 2020), title and body
#               (authors, affiliations and references left out by pageParseAbstract()); poster
#               and slide PDFs are not searched. The abstracts before 2006 are fetched into
#               sources/page/page_cache/ by this script, from the sitemaps cached there on
#               2026-09-26, with the same polite client as the PAGE run. They are used here only:
#               sources/page/results/ stays 2006 to 2026.
#   PubMed      the literature base set (title/abstract, as in sources/literature), every year
#               from 1965; each PMID in the earliest year it matches. Title and abstract
#               searched.
#   Europe PMC  the literature base set (base terms in title, abstract or keywords; open-access
#               full text; no preprints), every year from 1980. Title, abstract, keywords and
#               body text searched; not the back matter (reference list, declarations), which
#               Europe PMC's own search does reach. Bare "AI" is not searched.
#   FDA         the cached review text and OCR of the 238 CDER novel approvals 2021 to 2025.
#
# Every item and term found is read (rubric.md) and decided in decisions.csv: used, mentioned
# or not (the words do not mean the method). Nothing is counted while a hit is undecided.
#
# Writes (no source text):
#   results/items.csv           one row per source, item and term found, with the decision
#   results/base.csv            items in each source's base set per year
#   results/shares.csv          per source, year and group: items mentioning and using
#   results/first_by_group.csv  first year mentioned and used per source and group
#   results/first_by_term.csv   the same per term
#   results/run_info.txt        run date, queries, counts dropped at each step
# and, not committed, cache/review/review.csv: the snippets to read. results/checks.csv and
# check_decisions.csv record the blind second reading of a sample (see README.md); they are not
# written by this script.

pkgload::load_all("../../pmxlandscape", quiet = TRUE)
library(httr)

steps <- strsplit(Sys.getenv("AIML_STEPS", "page,pubmed,epmc,fda,results"), ",")[[1]]
run_date <- format(Sys.Date())
terms <- readAiMlTerms("../../taxonomy/ai_ml_terms.csv")
for (d in c("cache/pubmed", "cache/epmc_records", "cache/fulltext", "cache/queries", "cache/review", "results")) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}
ua <- user_agent("PMx Landscape survey (contact: niclas.jonsson@pharmetheus.com)")
info <- character(0)
note <- function(...) {
  line <- paste0(...)
  cat(line, "\n")
  info <<- c(info, line)
}

cached_get <- function(url, file, query = NULL, delay = 0.3, soft = FALSE) {
  failed <- paste0(file, ".failed") # a soft failure is remembered, so a rerun does not retry it
  if (soft && file.exists(failed)) {
    return(NA_character_)
  }
  if (!file.exists(file)) {
    for (attempt in 1:6) {
      Sys.sleep(delay * 2^(attempt - 1))
      r <- tryCatch(GET(url, ua, query = query, timeout(120)), error = function(e) NULL)
      if (!is.null(r) && !status_code(r) %in% c(429, 500, 502, 503)) break
    }
    if (is.null(r) || status_code(r) != 200) {
      what <- if (is.null(r)) "no response" else paste("HTTP", status_code(r))
      if (soft) {
        message(what, " for ", url)
        writeLines(c(run_date, what), failed)
        return(NA_character_)
      }
      stop(what, " for ", url)
    }
    writeBin(content(r, as = "raw"), file)
  }
  file
}

# Every match of the terms in texts: one row per item and term, with up to three snippets
term_hits <- function(texts, ids, years, source, use = terms) {
  m <- findMatches(texts, use, groups = c("ML", "AI"), width = 200)
  if (nrow(m) == 0) {
    return(NULL)
  }
  m$id <- ids[m$text]
  per <- split(m, paste(m$id, m$family, sep = "\r"))
  do.call(rbind, lapply(per, function(d) {
    data.frame(
      source = source, id = d$id[1], year = years[d$text[1]], group = d$group[1], term = d$family[1],
      n_matches = nrow(d), snippets = paste(utils::head(d$snip, 3), collapse = " || ")
    )
  }))
}

# ---- PAGE -------------------------------------------------------------------------

page_dir <- "../../sources/page/page_cache"
if ("page" %in% steps) {
  sitemap_dir <- file.path(page_dir, "sitemaps", "2026-09-26")
  maps <- list.files(sitemap_dir, pattern = "^abstracts_cpt-sitemap", full.names = TRUE)
  urls <- unique(unlist(lapply(maps, function(f) {
    xml2::xml_text(xml2::xml_find_all(xml2::xml_ns_strip(xml2::read_xml(f)), "//url/loc"))
  })))
  urls <- urls[!grepl("/Abstracts/?$", urls)]
  page_file <- function(url) file.path(page_dir, paste0(gsub("[^A-Za-z0-9-]", "_", basename(sub("/$", "", url))), ".html"))
  todo <- urls[!file.exists(page_file(urls))]
  note("PAGE: ", length(urls), " abstract pages in the sitemaps of 2026-09-26, ", length(todo), " not yet cached")
  for (i in seq_along(todo)) {
    if (i %% 50 == 0) cat("fetched", i, "of", length(todo), "\n")
    cached_get(todo[i], page_file(todo[i]), delay = 1.5, soft = TRUE)
  }
  files <- page_file(urls)
  ok <- file.exists(files)
  note("PAGE: ", sum(!ok), " pages could not be fetched")
  parsed <- do.call(rbind, lapply(which(ok), function(i) {
    p <- pageParseAbstract(xml2::read_html(files[i], encoding = "UTF-8"))
    cbind(url = urls[i], p[c("abstract_no", "year", "title", "body", "session", "software_demo")])
  }))
  no_year <- is.na(parsed$year)
  note("PAGE: ", sum(no_year), " pages without the abstract layout (no citation year), left out")
  parsed <- parsed[!no_year, ]
  dup <- duplicated(parsed$abstract_no)
  note("PAGE: ", sum(dup), " duplicate abstract numbers left out")
  parsed <- parsed[!dup, ]
  saveRDS(parsed, "cache/page_parsed.rds")
}
page_hits <- page_base <- NULL
if (file.exists("cache/page_parsed.rds")) {
page <- readRDS("cache/page_parsed.rds")
page$id <- as.character(page$abstract_no)
page_text <- paste(ifelse(is.na(page$title), "", page$title), ifelse(is.na(page$body), "", page$body), sep = "\n")
page_base <- as.data.frame(table(year = page$year), stringsAsFactors = FALSE)
page_base <- data.frame(source = "PAGE", year = as.integer(page_base$year), n = as.integer(page_base$Freq))
page_hits <- term_hits(page_text, page$id, page$year, "PAGE")
page_hits$url <- page$url[match(page_hits$id, page$id)]
page_hits$title <- page$title[match(page_hits$id, page$id)]
}

# ---- PubMed -----------------------------------------------------------------------

pm_base_q <- paste0(
  '("population pharmacokinetic*"[tiab] OR pharmacometric*[tiab] OR ',
  '"nonlinear mixed effects"[tiab] OR "non-linear mixed effects"[tiab])'
)
group_query <- function(col, g) paste0("(", paste(terms[[col]][terms$group == g & nzchar(terms[[col]])], collapse = " OR "), ")")
pm_years <- 1965:2026

cached_query <- function(q, f) {
  file <- file.path("cache/queries", paste0(digest::digest(q), ".rds"))
  if (file.exists(file)) {
    return(readRDS(file))
  }
  r <- f(q)
  saveRDS(r, file)
  r
}
pm_search <- function(q) {
  Sys.sleep(0.4)
  r <- rentrez::entrez_search(db = "pubmed", term = q, retmax = 9999)
  if (as.numeric(r$count) > 9999) stop("more than 9,999 PubMed records for ", q)
  list(count = as.numeric(r$count), ids = as.character(r$ids))
}

if ("pubmed" %in% steps) {
  qs <- expand.grid(year = pm_years, set = c("base", "ML", "AI"), stringsAsFactors = FALSE)
  qs$query <- ifelse(qs$set == "base", paste0(pm_base_q, " AND ", qs$year, "[dp]"),
    paste0(pm_base_q, " AND ", qs$year, "[dp] AND ", vapply(qs$set, function(g) if (g == "base") "" else group_query("pubmed", g), ""))
  )
  got <- lapply(qs$query, cached_query, f = pm_search)
  ids <- do.call(rbind, lapply(seq_along(got), function(i) {
    if (length(got[[i]]$ids) == 0) {
      return(NULL)
    }
    data.frame(year = qs$year[i], set = qs$set[i], id = got[[i]]$ids)
  }))
  base_ids <- keepEarliestYear(ids[ids$set == "base", ])
  hit_ids <- unique(ids$id[ids$set != "base"])
  note(
    "PubMed: base set ", nrow(base_ids), " PMIDs ", min(base_ids$year), " to ", max(base_ids$year), "; ",
    length(hit_ids), " PMIDs match an ML or AI query"
  )
  # Title and abstract of the hits, 200 per request
  chunks <- split(sort(hit_ids), ceiling(seq_along(hit_ids) / 200))
  recs <- do.call(rbind, lapply(chunks, function(ch) {
    f <- file.path("cache/pubmed", sprintf("pubmed_%s-%s_n%d.xml", ch[1], ch[length(ch)], length(ch)))
    if (!file.exists(f)) {
      Sys.sleep(0.4)
      writeLines(rentrez::entrez_fetch(db = "pubmed", id = ch, rettype = "xml"), f)
    }
    doc <- xml2::read_xml(f)
    arts <- xml2::xml_find_all(doc, "//PubmedArticle")
    data.frame(
      id = xml2::xml_text(xml2::xml_find_first(arts, "./MedlineCitation/PMID")),
      title = xml2::xml_text(xml2::xml_find_first(arts, ".//ArticleTitle")),
      abstract = vapply(arts, function(a) paste(xml2::xml_text(xml2::xml_find_all(a, ".//Abstract/AbstractText")), collapse = " "), "")
    )
  }))
  recs$year <- base_ids$year[match(recs$id, base_ids$id)]
  outside <- is.na(recs$year)
  note("PubMed: ", sum(outside), " hit PMIDs not in the base set, left out")
  recs <- recs[!outside, ]
  saveRDS(list(base = base_ids, recs = recs, queries = qs), "cache/pubmed.rds")
}
pm_hits <- pm_base <- NULL
pm_no_term <- character(0)
if (file.exists("cache/pubmed.rds")) {
pm <- readRDS("cache/pubmed.rds")
pm_base <- as.data.frame(table(year = pm$base$year), stringsAsFactors = FALSE)
pm_base <- data.frame(source = "PubMed", year = as.integer(pm_base$year), n = as.integer(pm_base$Freq))
pm_hits <- term_hits(paste(pm$recs$title, pm$recs$abstract, sep = "\n"), pm$recs$id, pm$recs$year, "PubMed")
pm_hits$url <- paste0("https://pubmed.ncbi.nlm.nih.gov/", pm_hits$id, "/")
pm_hits$title <- pm$recs$title[match(pm_hits$id, pm$recs$id)]
pm_no_term <- setdiff(pm$recs$id, pm_hits$id)
}

# ---- Europe PMC -------------------------------------------------------------------

ep_terms <- c(
  '"population pharmacokinetic"', '"population pharmacokinetics"', "pharmacometric*",
  '"nonlinear mixed effects"', '"non-linear mixed effects"'
)
ep_base_q <- paste0(
  "(", paste(outer(c("TITLE", "ABSTRACT", "KW"), ep_terms, paste, sep = ":"), collapse = " OR "), ") ",
  "AND HAS_FT:Y AND NOT SRC:PPR"
)
ep_years <- 1980:2026
with_retry <- function(f, tries = 10) {
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
ep_search <- function(q, ids = TRUE) {
  Sys.sleep(0.2)
  n <- as.numeric(with_retry(function() europepmc::epmc_hits(q)))
  if (n == 0 || !ids) {
    return(list(count = n, ids = character(0)))
  }
  r <- with_retry(function() europepmc::epmc_search(q, output = "id_list", limit = n + 100, synonym = FALSE, verbose = FALSE))
  list(count = n, ids = unique(paste0(r$source, ":", r$id)))
}

if ("epmc" %in% steps) {
  qs <- expand.grid(year = ep_years, set = c("base", "ML", "AI"), stringsAsFactors = FALSE)
  qs$query <- paste0(ep_base_q, " AND PUB_YEAR:", qs$year)
  qs$query[qs$set != "base"] <- paste0(qs$query[qs$set != "base"], " AND ", vapply(qs$set[qs$set != "base"], group_query, "", col = "epmc"))
  got <- mapply(function(q, s) cached_query(q, function(q) ep_search(q, ids = s != "base")), qs$query, qs$set, SIMPLIFY = FALSE)
  qs$count <- vapply(got, `[[`, numeric(1), "count")
  hits <- unique(do.call(rbind, lapply(which(qs$set != "base"), function(i) {
    if (length(got[[i]]$ids) == 0) {
      return(NULL)
    }
    data.frame(year = qs$year[i], id = got[[i]]$ids)
  })))
  note("Europe PMC: base set ", sum(qs$count[qs$set == "base"]), " papers; ", length(unique(hits$id)), " match an ML or AI query")
  # Records for the PMCIDs, 50 per request; then the full text
  hits$src <- sub(":.*", "", hits$id)
  hits$ext <- sub("^[^:]*:", "", hits$id)
  groups <- split(seq_len(nrow(hits)), ceiling(seq_len(nrow(hits)) / 50))
  rec <- do.call(rbind, lapply(groups, function(g) {
    q <- paste0("(", paste0("(EXT_ID:", hits$ext[g], " AND SRC:", hits$src[g], ")", collapse = " OR "), ")")
    f <- cached_get("https://www.ebi.ac.uk/europepmc/webservices/rest/search",
      file.path("cache/epmc_records", sprintf("%s_%s_n%d.json", hits$ext[g[1]], hits$ext[g[length(g)]], length(g))),
      query = list(query = q, resultType = "lite", format = "json", pageSize = 100)
    )
    r <- jsonlite::fromJSON(f, simplifyVector = FALSE)$resultList$result
    do.call(rbind, lapply(r, function(p) {
      data.frame(id = paste0(p$source, ":", p$id), pmcid = if (is.null(p$pmcid)) NA_character_ else p$pmcid, title = if (is.null(p$title)) "" else p$title)
    }))
  }))
  hits <- merge(hits, unique(rec), by = "id", all.x = TRUE)
  lit_ft <- "../../sources/literature/cache/fulltext"
  hits$body <- NA_character_
  for (i in which(!is.na(hits$pmcid))) {
    own <- file.path(lit_ft, paste0(hits$pmcid[i], ".xml"))
    f <- if (file.exists(own)) {
      own
    } else {
      cached_get(sprintf("https://www.ebi.ac.uk/europepmc/webservices/rest/%s/fullTextXML", hits$pmcid[i]),
        file.path("cache/fulltext", paste0(hits$pmcid[i], ".xml")),
        delay = 0.2, soft = TRUE
      )
    }
    if (is.na(f)) next
    s <- tryCatch(jatsSections(f), error = function(e) NULL)
    if (is.null(s)) next
    front <- xml2::xml_text(xml2::xml_find_all(xml2::xml_ns_strip(xml2::read_xml(f)), "//front//abstract|//front//kwd"))
    hits$body[i] <- paste(hits$title[i], paste(front, collapse = " "), s$body, sep = "\n")
  }
  note("Europe PMC: ", sum(is.na(hits$body)), " hits without readable full text, left out")
  saveRDS(list(base = qs[qs$set == "base", c("year", "count")], hits = hits[!is.na(hits$body), ], queries = qs), "cache/epmc.rds")
}
ep_hits <- ep_base <- NULL
ep_no_term <- character(0)
if (file.exists("cache/epmc.rds")) {
ep <- readRDS("cache/epmc.rds")
ep_base <- data.frame(source = "Europe PMC", year = as.integer(ep$base$year), n = as.integer(ep$base$count))
ep_hits <- term_hits(ep$hits$body, ep$hits$id, ep$hits$year, "Europe PMC", use = terms[nzchar(terms$epmc), ]) # no bare AI
ep_hits$url <- paste0("https://europepmc.org/article/", sub(":", "/", ep_hits$id))
ep_hits$title <- ep$hits$title[match(ep_hits$id, ep$hits$id)]
ep_no_term <- setdiff(ep$hits$id, ep_hits$id)
}

# ---- FDA --------------------------------------------------------------------------

fda_dir <- "../../sources/fda"
if ("fda" %in% steps) {
  saveRDS(fdaSearch(fda_dir, patterns = terms[c("name", "group", "regex", "family")]), "cache/fda_hits.rds")
}
fda_hits <- fda_base <- NULL
if (file.exists("cache/fda_hits.rds")) {
fda_raw <- readRDS("cache/fda_hits.rds")
fda_results <- fdaReadResults(fda_dir)
fda_base <- as.data.frame(table(year = fda_results$year), stringsAsFactors = FALSE)
fda_base <- data.frame(source = "FDA", year = as.integer(fda_base$year), n = as.integer(fda_base$Freq))
fda_hits <- if (nrow(fda_raw) == 0) {
  NULL
} else {
  fda_raw$id <- fda_raw$appl
  per <- split(fda_raw, paste(fda_raw$appl, fda_raw$sw, sep = "\r"))
  do.call(rbind, lapply(per, function(d) {
    r <- fda_results[fda_results$application == d$appl[1], ][1, ]
    data.frame(
      source = "FDA", id = d$appl[1], year = as.integer(r$year), group = terms$group[terms$term == d$sw[1]], term = d$sw[1],
      n_matches = nrow(d), snippets = paste(utils::head(paste0("[", d$doc, " p", d$page, "] ", d$snip), 3), collapse = " || "),
      url = strsplit(r$review_urls, "\\s*[;|]\\s*|\\s+")[[1]][1], title = r$drug
    )
  }))
}
}

# ---- Review file and results ------------------------------------------------------

hits <- rbind(page_hits, pm_hits, ep_hits, fda_hits)
hits <- hits[order(hits$source, hits$year, hits$id, hits$term), ]
decisions <- if (file.exists("decisions.csv")) read.csv("decisions.csv", colClasses = "character") else
  data.frame(source = character(0), id = character(0), term = character(0), decision = character(0), note = character(0), decided_by = character(0))
key <- paste(hits$source, hits$id, hits$term)
hits$decided <- key %in% paste(decisions$source, decisions$id, decisions$term)
write.csv(hits, "cache/review/review.csv", row.names = FALSE)
note(
  "Hits (item and term): ", paste(names(table(hits$source)), table(hits$source), collapse = ", "),
  "; ", sum(!hits$decided), " not yet decided"
)
note("Server matches with no term found in the text: PubMed ", length(pm_no_term), ", Europe PMC ", length(ep_no_term))

complete <- !is.null(page_base) && !is.null(pm_base) && !is.null(ep_base) && !is.null(fda_base)
if ("results" %in% steps && complete && all(hits$decided)) {
  decided <- aiMlDecide(hits[c("source", "id", "year", "group", "term")], decisions)
  base <- rbind(page_base, pm_base, ep_base, fda_base)
  base <- base[base$n > 0, ]
  items <- cbind(decided, hits[c("url", "n_matches")])
  write.csv(items, "results/items.csv", row.names = FALSE)
  write.csv(base, "results/base.csv", row.names = FALSE)
  write.csv(aiMlShares(decided, base), "results/shares.csv", row.names = FALSE)
  write.csv(aiMlFirst(decided), "results/first_by_group.csv", row.names = FALSE)
  write.csv(aiMlFirst(decided, by = "term"), "results/first_by_term.csv", row.names = FALSE)
  writeLines(c(paste("run date:", run_date), info), "results/run_info.txt")
  cat("results written\n")
} else if ("results" %in% steps) {
  cat("results not written: run every source step, then read the hits in cache/review/review.csv and add them to decisions.csv\n")
}
