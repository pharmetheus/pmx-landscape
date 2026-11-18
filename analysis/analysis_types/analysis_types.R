# Analysis types by tool: PAGE, PubMed and Europe PMC
#
# Run from analysis/analysis_types/: Rscript analysis_types.R
#
# Classifies every item naming an estimation tool by analysis type
# (taxonomy/analysis_types.csv; several types per item, and the highest
# level), from the title and abstract (PAGE: title and abstract body). PAGE
# abstracts come from the local page cache; PubMed abstracts from the cached
# PubMed records; Europe PMC items from PubMed records (MED) or Europe PMC's
# own records (other sources), fetched here and cached in cache/. For Europe PMC
# the tool is the one that fitted the final model (analysis/model_size). Writes IDs
# and classifications only to results/; reading samples with text go to
# review/, which is not committed.

pkgload::load_all("../../pmxlandscape", quiet = TRUE)
library(httr)

types <- readAnalysisTypes("../../taxonomy/analysis_types.csv")
software <- read.csv("../../taxonomy/software.csv", colClasses = "character")
estimation <- software$family[software$group == "estimation"]
for (d in c("cache/pubmed", "cache/epmc", "results", "review")) dir.create(d, recursive = TRUE, showWarnings = FALSE)
ua <- user_agent("PMx Landscape analysis types (contact: niclas.jonsson@pharmetheus.com)")
run_date <- format(Sys.Date())

cached_get <- function(url, file, query = NULL, delay = 0.4) {
  if (!file.exists(file)) {
    for (attempt in 1:6) {
      Sys.sleep(delay * 2^(attempt - 1))
      r <- GET(url, ua, query = query, timeout(120))
      if (!status_code(r) %in% c(429, 500, 502, 503)) break
    }
    if (status_code(r) != 200) stop("HTTP ", status_code(r), " for ", url)
    writeBin(content(r, as = "raw"), file)
  }
  file
}

# Title and abstract of every record in a PubMed XML file
pubmed_text <- function(file) {
  doc <- xml2::read_xml(file)
  recs <- xml2::xml_find_all(doc, "//PubmedArticle")
  data.frame(
    pmid = xml2::xml_text(xml2::xml_find_first(recs, "./MedlineCitation/PMID")),
    review = vapply(recs, function(r) {
      any(xml2::xml_text(xml2::xml_find_all(r, ".//PublicationTypeList/PublicationType")) %in% c("Review", "Systematic Review"))
    }, logical(1)),
    text = vapply(recs, function(r) {
      paste(
        xml2::xml_text(xml2::xml_find_first(r, ".//ArticleTitle")),
        paste(xml2::xml_text(xml2::xml_find_all(r, ".//Abstract/AbstractText")), collapse = " ")
      )
    }, character(1)),
    stringsAsFactors = FALSE
  )
}

classify <- function(items) {
  cl <- classifyAnalysis(items$text, types)
  items$level <- cl$level
  items$types <- cl$types
  items
}

# ---- PAGE ----------------------------------------------------------------------

page <- read.csv("../../sources/page/results/page_abstracts.csv", colClasses = "character")
page <- page[page$software_demo == "FALSE" & page$estimation_source %in% c("abstract", "pdf"), ]
page$tools <- ifelse(page$estimation != "", page$estimation, page$pdf_estimation)
page_file <- function(url) {
  file.path("../../sources/page/page_cache", paste0(gsub("[^A-Za-z0-9-]", "_", basename(sub("/$", "", url))), ".html"))
}
page$text <- vapply(page$url, function(u) {
  a <- pageParseAbstract(xml2::read_html(page_file(u), encoding = "UTF-8"))
  paste(a$title, a$body)
}, character(1), USE.NAMES = FALSE)
page_items <- classify(data.frame(source = "PAGE", id = page$abstract_no, year = as.integer(page$year), tools = page$tools,
  text = page$text, session = page$session, stringsAsFactors = FALSE
))
# Where the PAGE abstracts have been read (sources/page/role_decisions.csv), the tools are those
# the abstract used (a comparator or a passing mention does not count) and the types are the ones
# read; the keyword types are kept as keyword_types for comparison. Abstracts left without a used
# tool drop out.
role_file <- "../../sources/page/role_decisions.csv"
if (file.exists(role_file)) {
  dec <- read.csv(role_file, colClasses = "character")
  used <- pageUsedTools(data.frame(abstract_no = page_items$id, estimation = page_items$tools, pdf_estimation = "",
    estimation_source = "abstract", stringsAsFactors = FALSE), dec)
  page_items$keyword_types <- vapply(page_items$types, paste, "", collapse = "; ")
  m <- match(page_items$id, dec$abstract_no)
  read_types <- lapply(strsplit(gsub("\\s", "", dec$types[m]), ";", fixed = TRUE), function(x) {
    x <- x[x %in% as.character(types$level)]
    types$type[match(as.integer(x), types$level)]
  })
  page_items$tools <- ifelse(is.na(m), page_items$tools, used$estimation)
  page_items$types[!is.na(m)] <- read_types[!is.na(m)]
  page_items$level[!is.na(m)] <- vapply(read_types[!is.na(m)], function(x) if (length(x)) max(types$level[match(x, types$type)]) else NA_integer_, 1L)
  page_items <- page_items[page_items$tools != "", ]
}

# ---- Literature: papers naming an estimation tool ------------------------------------

ids <- read.csv(gzfile("../../sources/literature/results/ids.csv.gz"), colClasses = "character")
tool_ids <- ids[ids$software %in% estimation, ]
paper_tools <- function(src) {
  d <- tool_ids[tool_ids$source == src, ]
  agg <- aggregate(software ~ id + year, data = d, FUN = function(x) paste(intersect(estimation, x), collapse = "; "))
  names(agg)[names(agg) == "software"] <- "tools"
  agg
}

# PubMed: text from the cached base-set records
pm <- paper_tools("PubMed (title/abstract)")
pm_text <- do.call(rbind, lapply(list.files("../../sources/literature/cache", pattern = "^pubmed_.*\\.xml$", full.names = TRUE), pubmed_text))
pm$text <- pm_text$text[match(pm$id, pm_text$pmid)]
pm$review <- pm_text$review[match(pm$id, pm_text$pmid)]
if (any(is.na(pm$text))) stop(sum(is.na(pm$text)), " PubMed papers without a cached record")
n_reviews <- c(PubMed = sum(pm$review))
pm <- pm[!pm$review, ] # reviews describe other people's work
pubmed_items <- classify(data.frame(source = "PubMed", id = pm$id, year = as.integer(pm$year), tools = pm$tools,
  text = pm$text, session = NA_character_, stringsAsFactors = FALSE
))

# Europe PMC: MED records from PubMed (cached or fetched), the rest from Europe PMC
ep <- paper_tools("Europe PMC (full text)")
ep$src <- sub(":.*", "", ep$id)
ep$ext <- sub("^[^:]*:", "", ep$id)
med <- unique(ep$ext[ep$src == "MED"])
need <- setdiff(med, pm_text$pmid)
batches <- split(need, ceiling(seq_along(need) / 200))
fetched <- do.call(rbind, c(list(pm_text[0, ]), lapply(batches, function(b) {
  f <- cached_get("https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi",
    file.path("cache/pubmed", sprintf("pubmed_%s-%s_n%d.xml", b[1], b[length(b)], length(b))),
    query = list(db = "pubmed", id = paste(b, collapse = ","), rettype = "xml")
  )
  pubmed_text(f)
})))
all_pm <- rbind(pm_text, fetched)
ep$text <- ifelse(ep$src == "MED", all_pm$text[match(ep$ext, all_pm$pmid)], NA_character_)
ep$review <- ifelse(ep$src == "MED", all_pm$review[match(ep$ext, all_pm$pmid)], FALSE)
other <- ep[ep$src != "MED", c("src", "ext")]
if (nrow(other) > 0) {
  groups <- split(seq_len(nrow(other)), ceiling(seq_len(nrow(other)) / 50))
  got <- do.call(rbind, lapply(groups, function(g) {
    q <- paste0("(", paste0("(EXT_ID:", other$ext[g], " AND SRC:", other$src[g], ")", collapse = " OR "), ")")
    f <- cached_get("https://www.ebi.ac.uk/europepmc/webservices/rest/search",
      file.path("cache/epmc", sprintf("epmc_%s_%s_n%d.json", other$ext[g[1]], other$ext[g[length(g)]], length(g))),
      query = list(query = q, resultType = "core", format = "json", pageSize = 100), delay = 0.2
    )
    r <- jsonlite::fromJSON(f, simplifyVector = FALSE)$resultList$result
    do.call(rbind, lapply(r, function(p) {
      pt <- unlist(p$pubTypeList$pubType)
      data.frame(
        key = paste0(p$source, ":", p$id), text = paste(p$title, if (is.null(p$abstractText)) "" else p$abstractText),
        review = any(tolower(pt) %in% c("review", "systematic review", "review-article"))
      )
    }))
  }))
  ep$text[ep$src != "MED"] <- got$text[match(ep$id[ep$src != "MED"], got$key)]
  ep$review[ep$src != "MED"] <- got$review[match(ep$id[ep$src != "MED"], got$key)]
}
ep$review[is.na(ep$review)] <- FALSE
n_reviews <- c(n_reviews, `Europe PMC` = sum(ep$review))
ep <- ep[!ep$review, ]
# The tool is the one that fitted the final model, as read for the model-size analysis
# (analysis/model_size/extractions.csv), not every tool the paper names: a tool named only as a
# comparator or in passing does not count. Papers without an own fit by one estimation tool drop out.
fitted <- read.csv("../model_size/extractions.csv", colClasses = "character")
fitted <- fitted[fitted$own_fit %in% "yes" & fitted$tool %in% estimation, ]
n_epmc_named <- nrow(ep)
ep$tools <- fitted$tool[match(ep$id, fitted$id)]
ep <- ep[!is.na(ep$tools), ]
epmc_items <- classify(data.frame(source = "Europe PMC", id = ep$id, year = as.integer(ep$year), tools = ep$tools,
  text = ifelse(is.na(ep$text), "", ep$text), session = NA_character_, stringsAsFactors = FALSE
))

# ---- Output ----------------------------------------------------------------------------

page_items$keyword_types <- NULL
items <- rbind(page_items, pubmed_items, epmc_items)
flat <- items[c("source", "id", "year", "tools", "level")]
flat$types <- vapply(items$types, paste, character(1), collapse = "; ")
flat$has_text <- nzchar(trimws(items$text))
write.csv(flat, "results/items.csv", row.names = FALSE)

by_tool <- do.call(rbind, lapply(split(items, items$source), function(d) cbind(source = d$source[1], typeByTool(d))))
write.csv(by_tool, "results/type_by_tool.csv", row.names = FALSE)
lift <- do.call(rbind, lapply(split(items, items$source), function(d) cbind(source = d$source[1], typeLift(d))))
write.csv(lift, "results/type_lift.csv", row.names = FALSE)

# PAGE: methodology and applied abstracts per year, for tools and for the rarer analysis types
page_only <- items[items$source == "PAGE", ]
page_only$methodology <- pageMethodology(page_only$session)
ma <- rbind(
  cbind(by = "tool", methodsApplied(page_only, c("NONMEM", "Monolix", "BUGS", "nlmixr", "Pumas", "Stan/Torsten"))),
  cbind(by = "type", methodsApplied(page_only, types$type[types$level >= 4], by = "type"))
)
write.csv(ma, "results/page_methods_applied.csv", row.names = FALSE)

# Reading sample: up to 12 items per type per source, and 12 without a type (text not committed)
set.seed(9)
checked <- if (file.exists("review/checked_ids.txt")) readLines("review/checked_ids.txt") else character(0)
items_for_sample <- items[!paste(items$source, items$id) %in% checked, ]
sample_rows <- do.call(rbind, lapply(split(seq_len(nrow(items_for_sample)), items_for_sample$source), function(rows) {
  d <- items_for_sample[rows, ]
  per <- lapply(c(types$type, "none"), function(t) {
    has <- if (t == "none") lengths(d$types) == 0 else vapply(d$types, function(x) t %in% x, logical(1))
    w <- which(has)
    w[sample.int(length(w), min(12, length(w)))]
  })
  d <- d[unique(unlist(per)), ]
  data.frame(source = d$source, id = d$id, tools = d$tools, types = vapply(d$types, paste, "", collapse = "; "),
    level = d$level, text = substr(d$text, 1, 2500))
}))
write.csv(sample_rows, "review/sample.csv", row.names = FALSE)

info <- c(
  paste("run_date:", run_date),
  paste("reviews left out:", paste(names(n_reviews), n_reviews, sep = ": ", collapse = ", ")),
  paste("Europe PMC papers naming a tool (reviews left out):", n_epmc_named, "; with an own fit by one estimation tool, kept:", nrow(ep)),
  vapply(split(flat, flat$source), function(d) {
    sprintf("%s: %d items naming a tool, %d without text, %d without a type", d$source[1], nrow(d), sum(!d$has_text), sum(is.na(d$level)))
  }, character(1))
)
writeLines(info, "results/run_info.txt")
cat(info, sep = "\n")
