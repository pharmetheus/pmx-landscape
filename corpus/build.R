# The corpus layer: item and section tables for every source, built from the sources' caches
#
# Run from the repository root: make corpus (or Rscript corpus/build.R [page pubmed epmc fda])
#
# Downloads nothing. Reads what the sources have cached and writes, per source:
#   corpus/<source>/items.csv        one row per item: ID, year, URL, coverage, retrieval, hash
#   corpus/<source>/sections.csv.gz one row per piece of text: section, part, size, hash (no text)
#   corpus/<source>/run_info.txt     counts, skipped files and the extraction tools used
#   corpus/cache/<source>.rds        the text itself (not committed, except that FDA text is
#                                    committed under sources/fda/data)
# Rebuilding from unchanged caches gives byte-identical tables. Classifications read the text
# with corpusRead(), which refuses local text that does not match the committed hashes.

pkgload::load_all("pmxlandscape", quiet = TRUE)

steps <- commandArgs(trailingOnly = TRUE)
if (length(steps) == 0) steps <- c("page", "pubmed", "epmc", "fda")
root <- "corpus"

info <- function(name, lines) {
  writeLines(c(paste("built:", format(Sys.Date())), lines), file.path(root, name, "run_info.txt"))
  cat(name, ":", lines, sep = "\n  ")
}
counts <- function(x) {
  c(
    sprintf("items: %d (%d to %d)", nrow(x$items), min(x$items$year), max(x$items$year)),
    paste0("coverage: ", paste(names(table(x$items$coverage)), table(x$items$coverage), sep = " ", collapse = "; ")),
    sprintf("sections: %d, %.1f million characters", nrow(x$sections), sum(x$sections$nchar) / 1e6)
  )
}

# The literature items: the term route, that is the core (the base set of 2021 to 2026, run of
# 2026-09-28, and of 2016 to 2020, added in October 2026) and the extension (corpus_extension.R),
# and the tool route (corpus_toolroute.R, decided 2026-10-20); admitted_by says which route and
# terms found a paper first (core, extension, then tool), tool_route the tools the tool route found
# it by (empty when it did not)
lit <- "sources/literature/results"
readBase <- function(f) {
  x <- read.csv(gzfile(f), colClasses = "character")
  x <- x[x$software == "All (base set)", c("source", "year", "id")]
  x$source <- ifelse(grepl("^PubMed", x$source), "PubMed", "Europe PMC")
  x
}
optional <- function(f, read) if (file.exists(f)) read(f)
base <- rbind(readBase(file.path(lit, "ids.csv.gz")), optional(file.path(lit, "ids_2016_2020.csv.gz"), readBase))
base$admitted_by <- NA_character_
admitted <- rbind(
  read.csv(file.path(lit, "admitted_by.csv"), colClasses = "character"),
  optional(file.path(lit, "admitted_by_2016_2020.csv"), function(f) read.csv(f, colClasses = "character"))
)
core <- paste("core:", admitted$admitted_by[match(paste(base$source, base$id), paste(admitted$source, admitted$id))])
base$admitted_by <- ifelse(grepl("^core: no core term", core), sub("^core: ", "core (frozen set): ", core), core)
ext <- optional(file.path(lit, "extension_ids.csv.gz"), function(f) read.csv(gzfile(f), colClasses = "character"))
if (!is.null(ext)) {
  if (any(paste(ext$source, ext$id) %in% paste(base$source, base$id))) stop("an extension paper is in the base set")
  base <- rbind(base, data.frame(source = ext$source, year = ext$year, id = ext$id,
    admitted_by = paste("extension:", ext$admitted_by)))
}
tool <- optional(file.path(lit, "tool_ids.csv.gz"), function(f) read.csv(gzfile(f), colClasses = "character"))
if (!is.null(tool)) {
  only <- tool[tool$term_route == "FALSE", ]
  if (any(paste(only$source, only$id) %in% paste(base$source, base$id))) stop("a tool-route-only paper is in the term route")
  base <- rbind(base, data.frame(source = only$source, year = only$year, id = only$id,
    admitted_by = paste("tool:", only$tools)))
}
admit <- function(x, src) {
  b <- base[base$source == src, ]
  x$items$admitted_by <- b$admitted_by[match(x$items$item_id, b$id)]
  if (!is.null(tool)) {
    t <- tool[tool$source == src, ]
    x$items$tool_route <- ifelse(x$items$item_id %in% t$id, t$tools[match(x$items$item_id, t$id)], "")
  }
  x
}
litInfo <- c(
  "core: sources/literature/results/ids.csv.gz (run of 2026-09-28) and ids_2016_2020.csv.gz",
  "extension: sources/literature/results/extension_ids.csv.gz (corpus_extension.R)",
  "tool route: sources/literature/results/tool_ids.csv.gz (corpus_toolroute.R)"
)
admittedCounts <- function(x) {
  a <- table(sub(":.*", "", x$items$admitted_by), x$items$year)
  paste0("admitted by ", rownames(a), ": ", apply(a, 1, function(r) paste(colnames(a), r, sep = " ", collapse = "; ")))
}

if ("page" %in% steps) {
  cache <- "sources/page/page_cache"
  maps <- list.files(file.path(cache, "sitemaps", "2026-09-26"), pattern = "^abstracts_cpt-sitemap", full.names = TRUE)
  urls <- unique(unlist(lapply(maps, function(f) {
    xml2::xml_text(xml2::xml_find_all(xml2::xml_ns_strip(xml2::read_xml(f)), "//url/loc"))
  })))
  x <- pageCorpus(list.files(cache, pattern = "\\.html$", full.names = TRUE), urls, posterDir = file.path(cache, "pdf"))
  corpusWrite(x, root, "page")
  info("page", c(
    counts(x), "listing: PAGE sitemaps of 2026-09-26; retrieved = date of the cached page",
    sprintf("items without a sitemap URL: %d", sum(is.na(x$items$url))),
    paste("pages without the abstract layout, skipped:", paste(x$skipped, collapse = ", ")),
    paste("duplicate abstract numbers, later file skipped:", paste(x$duplicates, collapse = ", ")),
    "posters: the cached PDFs (fetched only for abstracts whose page names no estimation tool)",
    sprintf("poster text: pdftools %s (poppler %s), OCR of image-only pages by %s", packageVersion("pdftools"),
      pdftools::poppler_config()$version, system2("tesseract", "--version", stdout = TRUE, stderr = TRUE)[1])
  ))
}

if ("pubmed" %in% steps) {
  pm <- base[base$source == "PubMed", c("id", "year")]
  files <- list.files("sources/literature/cache", pattern = "^pubmed_.*\\.xml$", full.names = TRUE)
  x <- admit(pubmedCorpus(files, pm), "PubMed")
  corpusWrite(x, root, "pubmed")
  info("pubmed", c(counts(x), litInfo, admittedCounts(x), "retrieved = date of the cached efetch file",
    "author_affiliations: each author's affiliations by position in the author list (no names)"))
}

if ("epmc" %in% steps) {
  ep <- base[base$source == "Europe PMC", c("id", "year")]
  files <- list.files("sources/literature/cache/fulltext", pattern = "\\.xml$", full.names = TRUE)
  # Europe PMC records (title, abstract, keywords for papers without a full text, and every
  # paper's author affiliations), from corpus_fetch.R and corpus_extension.R
  recs <- unlist(lapply(list.files("sources/literature/cache/epmc_records", pattern = "^(base|ext|tool)_.*\\.json$", full.names = TRUE),
    function(f) jsonlite::read_json(f)$resultList$result
  ), recursive = FALSE)
  val <- function(r, k) if (is.null(r[[k]])) "" else r[[k]]
  records <- data.frame(
    id = vapply(recs, function(r) paste0(r$source, ":", r$id), ""),
    title = vapply(recs, val, "", "title"),
    abstract = stringi::stri_trim_both(gsub("<[^>]+>", " ", vapply(recs, val, "", "abstractText"))),
    keywords = vapply(recs, function(r) paste(unlist(r$keywordList$keyword), collapse = "; "), "")
  )
  x <- admit(epmcCorpus(files, ep, records, epmcAuthorAffiliations(recs), epmcAuthors(recs)), "Europe PMC")
  status <- do.call(rbind, lapply(file.path(lit, c("fulltext_status.csv", "fulltext_status_2016_2020.csv",
    "extension_fulltext_status.csv", "tool_fulltext_status.csv")), optional, function(f) read.csv(f, colClasses = "character")))
  corpusWrite(x, root, "epmc")
  info("epmc", c(counts(x), litInfo, admittedCounts(x),
    "retrieved = date of the cached full text; title and abstract from the Europe PMC record otherwise (HTML tags removed)",
    paste0("full text status: ", paste(names(table(status$status)), table(status$status), collapse = "; "),
      " (sources/literature/results/*fulltext_status*.csv)"),
    "author_affiliations: each author's affiliations by position, from the Europe PMC records (no names)",
    paste("unreadable files:", length(x$unreadable))))
}

if ("fda" %in% steps) {
  x <- fdaCorpus("sources/fda")
  corpusWrite(x, root, "fda")
  info("fda", c(counts(x), sprintf("documents: %d", length(unique(sub(" p[0-9]+$", "", x$sections$part)))),
    "text: pdftotext and OCR of the original Python run (sources/fda/data), committed",
    paste("applications without a row in the record, skipped:", paste(x$skipped, collapse = ", "))))
}
