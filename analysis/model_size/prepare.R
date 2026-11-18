# Model and data size by tool: reading set
#
# Run from analysis/model_size/: Rscript prepare.R
#
# Every Europe PMC base-set paper (sources/literature/results/ids.csv.gz) that
# names an estimation tool. Fetches each paper's record and open-access full
# text (cached in sources/literature/cache/, not committed) and writes, per
# paper, the text to read: abstract, methods, the start of the results, the
# tables that look like parameter tables, and the sentences that give numbers
# of subjects or observations. The text goes to review/ (not committed: it is
# the publishers'); the numbers read from it go to extractions.csv.

pkgload::load_all("../../pmxlandscape", quiet = TRUE)
library(httr)

ua <- user_agent("PMx Landscape literature survey (contact: niclas.jonsson@pharmetheus.com)")
lit_cache <- "../../sources/literature/cache"
for (d in c(file.path(lit_cache, c("epmc_records", "fulltext")), "review")) dir.create(d, recursive = TRUE, showWarnings = FALSE)

cached_get <- function(url, file, query = NULL, delay = 0.3, soft = FALSE) {
  if (!file.exists(file)) {
    for (attempt in 1:6) {
      Sys.sleep(delay * 2^(attempt - 1))
      r <- tryCatch(GET(url, ua, query = query, timeout(120)), error = function(e) NULL)
      if (!is.null(r) && !status_code(r) %in% c(429, 500, 502, 503)) break
    }
    if (is.null(r) || status_code(r) != 200) {
      what <- if (is.null(r)) "no response" else paste("HTTP", status_code(r))
      if (soft || (!is.null(r) && status_code(r) == 404)) {
        message(what, " for ", url, "; read from the record only")
        return(NA_character_)
      }
      stop(what, " for ", url)
    }
    writeBin(content(r, as = "raw"), file)
  }
  file
}

software <- read.csv("../../taxonomy/software.csv", colClasses = "character")
estimation <- software$family[software$group == "estimation"]
ids <- read.csv(gzfile("../../sources/literature/results/ids.csv.gz"), colClasses = "character")
ep <- ids[ids$source == "Europe PMC (full text)", ]
base <- unique(ep$id[ep$software == "All (base set)"])
named <- ep[ep$software %in% estimation & ep$id %in% base, ]
papers <- aggregate(software ~ id + year, data = named, FUN = function(x) paste(intersect(estimation, x), collapse = "; "))
names(papers)[names(papers) == "software"] <- "tools"
papers <- papers[order(papers$year, papers$id), ]
cat(nrow(papers), "papers naming an estimation tool\n")

# Records (title, abstract, publication type, PMCID), 50 per query
papers$src <- sub(":.*", "", papers$id)
papers$ext <- sub("^[^:]*:", "", papers$id)
groups <- split(seq_len(nrow(papers)), ceiling(seq_len(nrow(papers)) / 50))
rec <- do.call(rbind, lapply(groups, function(g) {
  q <- paste0("(", paste0("(EXT_ID:", papers$ext[g], " AND SRC:", papers$src[g], ")", collapse = " OR "), ")")
  f <- cached_get("https://www.ebi.ac.uk/europepmc/webservices/rest/search",
    file.path(lit_cache, "epmc_records", sprintf("ms_%s_%s_n%d.json", papers$ext[g[1]], papers$ext[g[length(g)]], length(g))),
    query = list(query = q, resultType = "core", format = "json", pageSize = 100)
  )
  r <- jsonlite::fromJSON(f, simplifyVector = FALSE)$resultList$result
  do.call(rbind, lapply(r, function(p) {
    data.frame(
      id = paste0(p$source, ":", p$id), pmcid = if (is.null(p$pmcid)) NA_character_ else p$pmcid,
      title = if (is.null(p$title)) "" else p$title,
      abstract = if (is.null(p$abstractText)) "" else gsub("<[^>]+>", " ", p$abstractText),
      pubtype = paste(unlist(p$pubTypeList$pubType), collapse = "; "), stringsAsFactors = FALSE
    )
  }))
}))
papers <- merge(papers, rec[!duplicated(rec$id), ], by = "id", all.x = TRUE)
if (any(is.na(papers$title))) stop(sum(is.na(papers$title)), " papers without a Europe PMC record")

# Text of one article: methods, results start, parameter-like tables, data-size sentences
textOf <- function(nodes) {
  if (length(nodes) == 0) {
    return("")
  }
  collapseSpace(paste(vapply(nodes, function(n) paste(xml2::xml_text(xml2::xml_find_all(n, ".//text()")), collapse = " "), ""), collapse = " "))
}
sectionText <- function(doc, rx) {
  secs <- xml2::xml_find_all(doc, "//body//sec")
  titles <- xml2::xml_text(xml2::xml_find_first(secs, "./title"))
  keep <- secs[!is.na(titles) & stringi::stri_detect_regex(titles, rx, case_insensitive = TRUE)]
  textOf(keep)
}
articleText <- function(f) {
  doc <- xml2::xml_ns_strip(xml2::read_xml(f))
  s <- jatsSections(doc)
  results <- sectionText(doc, "^\\s*(\\d+\\.?\\s*)?results")
  tabs <- xml2::xml_find_all(doc, "//table-wrap")
  tab_text <- vapply(tabs, function(t) textOf(list(t)), "")
  score <- stringi::stri_count_regex(tab_text, "(?i)parameter|estimate|RSE|shrinkage|final model|IIV|BSV|omega|theta|clearance")
  tab_text <- tab_text[order(-score)][score[order(-score)] > 0]
  body_sent <- unlist(stringi::stri_split_regex(paste(s$methods, results), "(?<=[.!?])\\s+"))
  data_rx <- "\\d[\\d,]*\\s+(?:\\w+\\s+){0,3}(?:patients|subjects|participants|individuals|volunteers|children|infants|neonates|animals|samples|concentrations|observations|measurements|data points)"
  list(
    methods = substr(if (nzchar(s$methods)) s$methods else s$body, 1, 5000),
    results = substr(results, 1, 1500),
    tables = substr(paste(tab_text, collapse = " || "), 1, 5000),
    data_sentences = substr(paste(unique(body_sent[stringi::stri_detect_regex(body_sent, data_rx, case_insensitive = TRUE)]), collapse = " | "), 1, 1500)
  )
}

for (col in c("methods", "results", "tables", "data_sentences")) papers[[col]] <- ""
papers$full_text <- FALSE
for (i in seq_len(nrow(papers))) {
  if (is.na(papers$pmcid[i])) next
  f <- cached_get(
    sprintf("https://www.ebi.ac.uk/europepmc/webservices/rest/%s/fullTextXML", papers$pmcid[i]),
    file.path(lit_cache, "fulltext", paste0(papers$pmcid[i], ".xml")),
    delay = 0.2, soft = TRUE
  )
  if (is.na(f)) next
  a <- tryCatch(articleText(f), error = function(e) NULL)
  if (is.null(a)) next
  papers$full_text[i] <- TRUE
  for (col in names(a)) papers[[col]][i] <- a[[col]]
  if (i %% 200 == 0) cat("read", i, "of", nrow(papers), "\n")
}
write.csv(papers[c("id", "year", "tools", "pmcid", "pubtype", "title", "abstract", "methods", "results", "tables", "data_sentences", "full_text")],
  "review/reading_set.csv",
  row.names = FALSE
)
cat("written review/reading_set.csv:", nrow(papers), "papers,", sum(papers$full_text), "with full text\n")
