# Europe PMC base-set papers that name no estimation tool: reading set
#
# Run from sources/literature/ after publication_trends.R:
#   Rscript no_tool_review.R
#
# Lists the Europe PMC base-set papers (base terms in the title, abstract or
# keywords) that name no estimation tool, fetches each paper's record and, where
# Europe PMC has it, the full text (cached in cache/, not committed), and writes
# the text to read to review/no_tool_review.csv (not committed: the text is the
# publishers'). Each paper is read and decided in no_tool_decisions.csv:
#
#   own_fit        the authors fit a population (mixed effects) model of their own
#                  in pharmacology (PK, PK/PD, disease progression, ...)
#   not_own_fit    no model fit of their own: uses or cites a published model, NCA,
#                  review, editorial, commentary, protocol, simulation only
#   outside_field  nonlinear mixed effects outside pharmacology (ecology,
#                  agriculture, growth, psychology, ...)
#   unclear        cannot be told from the text
#
# not_own_fit and outside_field are removed from the base set when the shares are
# computed (literatureShares(exclude = )); own_fit and unclear stay. Papers that
# name a tool are not read, so only one side of the base set is cleaned.

pkgload::load_all("../../pmxlandscape", quiet = TRUE)
library(httr)

ua <- user_agent("PMx Landscape literature survey (contact: niclas.jonsson@pharmetheus.com)")
software <- read.csv("../../taxonomy/software.csv", colClasses = "character")
estimation <- software$family[software$group == "estimation"]
for (d in c("cache/epmc_records", "cache/fulltext", "review")) dir.create(d, recursive = TRUE, showWarnings = FALSE)

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

ids <- read.csv(gzfile("results/ids.csv.gz"), colClasses = "character")
ep <- ids[ids$source == "Europe PMC (full text)", ]
base <- unique(ep[ep$software == "All (base set)", c("id", "year")])
with_tool <- unique(ep$id[ep$software %in% estimation])
papers <- base[!base$id %in% with_tool, ]
papers <- papers[order(papers$year, papers$id), ]
cat("Europe PMC base set:", nrow(base), "papers;", nrow(papers), "name no estimation tool\n")

# Records (title, abstract, keywords, publication type, PMCID), 50 per query
papers$src <- sub(":.*", "", papers$id)
papers$ext <- sub("^[^:]*:", "", papers$id)
groups <- split(seq_len(nrow(papers)), ceiling(seq_len(nrow(papers)) / 50))
rec <- do.call(rbind, lapply(groups, function(g) {
  q <- paste0("(", paste0("(EXT_ID:", papers$ext[g], " AND SRC:", papers$src[g], ")", collapse = " OR "), ")")
  f <- cached_get("https://www.ebi.ac.uk/europepmc/webservices/rest/search",
    file.path("cache/epmc_records", sprintf("%s_%s_n%d.json", papers$ext[g[1]], papers$ext[g[length(g)]], length(g))),
    query = list(query = q, resultType = "core", format = "json", pageSize = 100)
  )
  r <- jsonlite::fromJSON(f, simplifyVector = FALSE)$resultList$result
  do.call(rbind, lapply(r, function(p) {
    data.frame(
      id = paste0(p$source, ":", p$id), pmcid = if (is.null(p$pmcid)) NA_character_ else p$pmcid,
      title = if (is.null(p$title)) "" else p$title,
      abstract = if (is.null(p$abstractText)) "" else gsub("<[^>]+>", " ", p$abstractText),
      keywords = paste(unlist(p$keywordList$keyword), collapse = "; "),
      pubtype = paste(unlist(p$pubTypeList$pubType), collapse = "; "), stringsAsFactors = FALSE
    )
  }))
}))
papers <- merge(papers, rec, by = "id", all.x = TRUE)
if (any(is.na(papers$title))) stop(sum(is.na(papers$title)), " papers without a Europe PMC record")

# Full text: the methods section (or the start of the body) and every sentence naming software
software_rx <- paste0(
  "software|package|program|\\bversion\\b|estimated (?:using|with|in)|implemented in|fitted (?:using|with|in)|",
  "\\bR\\b|\\bSAS\\b|MATLAB|Phoenix|WinNonlin|Julia|Python|Stata|SPSS|Simcyp|PK-Sim|GastroPlus"
)
papers$methods <- ""
papers$software_sentences <- ""
papers$full_text <- FALSE
for (i in seq_len(nrow(papers))) {
  if (is.na(papers$pmcid[i])) next
  f <- cached_get(
    sprintf("https://www.ebi.ac.uk/europepmc/webservices/rest/%s/fullTextXML", papers$pmcid[i]),
    file.path("cache/fulltext", paste0(papers$pmcid[i], ".xml")),
    delay = 0.2, soft = TRUE
  )
  if (is.na(f)) next
  s <- tryCatch(jatsSections(f), error = function(e) NULL)
  if (is.null(s)) next
  papers$full_text[i] <- TRUE
  text <- if (nzchar(s$methods)) s$methods else s$body
  papers$methods[i] <- substr(text, 1, 6000)
  sent <- unlist(stringi::stri_split_regex(s$body, "(?<=[.!?])\\s+"))
  papers$software_sentences[i] <- substr(paste(sent[stringi::stri_detect_regex(sent, software_rx)], collapse = " | "), 1, 3000)
}
write.csv(papers[c("id", "year", "pmcid", "pubtype", "title", "keywords", "abstract", "methods", "software_sentences", "full_text")],
  "review/no_tool_review.csv",
  row.names = FALSE
)
decided <- if (file.exists("no_tool_decisions.csv")) read.csv("no_tool_decisions.csv", colClasses = "character")$id else character(0)
cat(
  "written review/no_tool_review.csv:", nrow(papers), "papers,", sum(papers$full_text), "with full text;",
  sum(!papers$id %in% decided), "not yet decided\n"
)
