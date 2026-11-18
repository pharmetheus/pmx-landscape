# Remove authors' e-mail addresses from the affiliation texts in the local caches
#
# Run from the repository root: Rscript corpus/strip_emails.R (make corpus runs it first)
#
# The corpus readers already drop e-mail addresses from affiliations (stripEmails()), so nothing
# published changes. This script cleans the downloaded files themselves, so that no local copy
# keeps the addresses either. In each file it touches only the affiliation parts:
#   PubMed XML        <Affiliation> elements
#   Europe PMC JSON   "affiliation" values of the core records
#   JATS full texts   <contrib>, <aff>, <corresp> and <author-notes> elements in <front> (never
#                     the title, abstract or keywords)
#   PAGE pages        addresses that appear in the affiliation paragraph
# and replaces each address with a placeholder that stripEmails() removes in the same way, so the
# corpus built from a cleaned cache is identical to the corpus built from the original download.
# Re-running it changes nothing. Files are rewritten only when an address was replaced, and keep
# their modification time, which the corpus records as the retrieval date.

pkgload::load_all("pmxlandscape", quiet = TRUE)

placeholder <- "removed@removed.invalid"
backup <- Sys.getenv("STRIP_EMAILS_BACKUP") # a folder for the original files, for checking a first run
address <- "[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\\.[A-Za-z0-9-]+)*\\.[A-Za-z]{2,}"

readText <- function(f) {
  x <- readChar(f, file.size(f), useBytes = TRUE)
  Encoding(x) <- "UTF-8"
  x
}
writeText <- function(x, f) writeBin(charToRaw(enc2utf8(x)), f)

# Replace the addresses inside every match of `region` (a perl regex), leaving the placeholder
replaceIn <- function(x, region) {
  m <- gregexpr(region, x, perl = TRUE)
  parts <- regmatches(x, m)[[1]]
  if (length(parts) == 0) {
    return(x)
  }
  clean <- gsub(address, placeholder, parts, perl = TRUE)
  regmatches(x, m) <- list(clean)
  x
}
personal <- function(x) {
  a <- regmatches(x, gregexpr(address, x, perl = TRUE))[[1]]
  setdiff(a, placeholder)
}

cleanFiles <- function(files, edit) {
  changed <- 0L
  for (f in files) {
    x <- readText(f)
    y <- edit(x)
    if (!identical(x, y)) {
      if (nzchar(backup)) file.copy(f, file.path(backup, gsub("/", "__", f)), copy.date = TRUE)
      time <- file.mtime(f)
      writeText(y, f)
      Sys.setFileTime(f, time)
      changed <- changed + 1L
    }
  }
  changed
}

pubmedEdit <- function(x) replaceIn(x, "(?s)<Affiliation>.*?</Affiliation>")
jsonEdit <- function(x) replaceIn(x, "\"affiliation\"\\s*:\\s*\"(?:[^\"\\\\]|\\\\.)*\"")
jatsEdit <- function(x) {
  front <- regexpr("(?s)<front>.*?</front>", x, perl = TRUE)
  if (front < 0) {
    return(x)
  }
  f <- regmatches(x, front)
  f <- replaceIn(f, "(?s)<(contrib|aff|corresp|author-notes)\\b[^>]*>.*?</\\1>")
  regmatches(x, front) <- f
  x
}
pageEdit <- function(x) {
  doc <- xml2::read_html(x, encoding = "UTF-8")
  box <- rvest::html_element(doc, "article div.content-cleanse")
  if (inherits(box, "xml_missing")) {
    return(x)
  }
  text <- stringi::stri_trim_both(collapseSpace(rvest::html_text2(rvest::html_children(box))))
  text <- text[text != ""]
  if (length(text) < 2) {
    return(x)
  }
  for (a in personal(text[2])) x <- gsub(a, placeholder, x, fixed = TRUE)
  x
}

files <- function(dir, pattern) {
  if (dir.exists(dir)) list.files(dir, pattern, full.names = TRUE, recursive = TRUE) else character(0)
}
pubmedXml <- c(
  files("sources/literature/cache", "^pubmed_.*\\.xml$"),
  files("sources/literature/refinement/cache", "^pubmed_.*\\.xml$"),
  files("analysis/ai_ml/cache", "^pubmed_.*\\.xml$"),
  files("analysis/analysis_types/cache/pubmed", "\\.xml$")
)
epmcJson <- c(
  files("sources/literature/cache/epmc_records", "\\.json$"),
  files("sources/literature/refinement/cache", "^rec_.*\\.json$"),
  files("analysis/ai_ml/cache", "\\.json$"),
  files("analysis/analysis_types/cache/epmc", "\\.json$"),
  files("sources/fda/crosscheck/cache/epmc", "\\.json$")
)
jats <- c(
  files("sources/literature/cache/fulltext", "^PMC.*\\.xml$"),
  files("sources/literature/refinement/cache", "^PMC.*\\.xml$"),
  files("analysis/ai_ml/cache", "^PMC.*\\.xml$"),
  files("sources/fda/crosscheck/cache/fulltext", "^PMC.*\\.xml$")
)
page <- files("sources/page/page_cache", "\\.html$")

cat("PubMed XML:", cleanFiles(pubmedXml, pubmedEdit), "of", length(pubmedXml), "files changed\n")
cat("Europe PMC records:", cleanFiles(epmcJson, jsonEdit), "of", length(epmcJson), "files changed\n")
cat("JATS full texts:", cleanFiles(jats, jatsEdit), "of", length(jats), "files changed\n")
cat("PAGE pages:", cleanFiles(page, pageEdit), "of", length(page), "files changed\n")
