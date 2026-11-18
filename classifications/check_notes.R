# Notes that repeat their item's text
#
# Run from the repository root: Rscript classifications/check_notes.R [--withhold]
#
# The notes of the decision files are published, the text of most sources is not (literature and
# conference abstracts). This check compares every note with the whole local text of its item (all
# sections of the corpus, posters included) and lists the notes that share a run of 8 or more words
# with it (case, punctuation and spacing ignored). With --withhold, such notes are replaced by
# "(withheld: repeats the item's text)" in the files, as withholdQuotes() does when decisions are
# written. FDA review text is in the public domain and is not checked. Needs the local corpus text
# (make corpus).

pkgload::load_all("pmxlandscape", quiet = TRUE)

withhold <- "--withhold" %in% commandArgs(trailingOnly = TRUE)
n <- 8
label <- "(withheld: repeats the item's text)"
src <- c("PAGE" = "page", "PubMed" = "pubmed", "Europe PMC" = "epmc")

# file, the item source (a column name or a fixed source), the ID column and the note column
files <- list(
  list("sources/page/role_decisions.csv", "PAGE", "abstract_no", "note"),
  list("sources/page/pdf_decisions.csv", "PAGE", "abstract_no", "reason"),
  list("analysis/model_size/extractions.csv", "Europe PMC", "id", "note"),
  list("analysis/ai_ml/decisions.csv", "source", "id", "note"),
  list("sources/literature/no_tool_decisions.csv", "Europe PMC", "id", "reason")
)
for (f in list.files("classifications", "\\.csv$", recursive = TRUE, full.names = TRUE)) {
  if (grepl("/cache/", f)) next
  h <- names(read.csv(f, nrows = 1, check.names = FALSE))
  if (!all(c("source", "item_id") %in% h)) next
  for (col in intersect(h, c("note", "note_first", "note_check"))) files[[length(files) + 1]] <- list(f, "source", "item_id", col)
}

texts <- list()
textOf <- function(source) {
  if (is.null(texts[[source]])) {
    x <- corpusRead("corpus", src[[source]])
    s <- x$sections[!x$sections$section %in% c("authors", "affiliations", "author_affiliations"), ]
    texts[[source]] <<- tapply(s$text, s$item_id, paste, collapse = " ")
  }
  texts[[source]]
}
words <- function(s) {
  w <- strsplit(tolower(stringi::stri_replace_all_regex(s, "[^\\p{L}\\p{N}]+", " ")), " ", fixed = TRUE)[[1]]
  w[nzchar(w)]
}
repeats <- function(note, text) {
  w <- words(note)
  if (length(w) < n || is.na(text)) {
    return(FALSE)
  }
  t <- paste0(" ", paste(words(text), collapse = " "), " ")
  runs <- vapply(seq_len(length(w) - n + 1), function(k) paste0(" ", paste(w[k:(k + n - 1)], collapse = " "), " "), "")
  any(stringi::stri_detect_fixed(t, runs))
}

found <- 0
for (job in files) {
  f <- job[[1]]
  x <- read.csv(f, colClasses = "character", check.names = FALSE, na.strings = character(0))
  source <- if (job[[2]] %in% names(x)) x[[job[[2]]]] else rep(job[[2]], nrow(x))
  id <- x[[job[[3]]]]
  note <- x[[job[[4]]]]
  hit <- vapply(seq_len(nrow(x)), function(i) {
    if (!source[i] %in% names(src) || note[i] == label) {
      return(FALSE)
    }
    repeats(note[i], textOf(source[i])[id[i]])
  }, logical(1))
  if (any(hit)) {
    found <- found + sum(hit)
    cat(f, job[[4]], ":", sum(hit), "notes repeat 8 or more words of their item\n")
    if (withhold) {
      # replace whole quoted fields only, so the file keeps its format
      s <- readLines(f, encoding = "UTF-8")
      for (v in unique(note[hit])) {
        q <- paste0('"', gsub('"', '""', v, fixed = TRUE), '"')
        s <- gsub(q, paste0('"', label, '"'), s, fixed = TRUE)
      }
      writeLines(s, f, useBytes = TRUE)
    }
  }
}
cat(found, "notes in all", if (withhold) "withheld" else "", "\n")
