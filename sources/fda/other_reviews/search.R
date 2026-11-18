# Search the cached other documents (FDA other reviews, EMA assessment reports) of the FDA
# "not stated" drugs for estimation tools, PsN and NONMEM control-stream syntax, and write
# the hits with context for reading to cache/hits_<source>.txt (not committed) and
# results/hits_<source>.csv (drug, document, page, family; no text).
# Run from sources/fda/: Rscript other_reviews/search.R ema|fda|pilot (pilot: the EMA reports of
# 20 drugs whose FDA review states the tool)
src <- commandArgs(TRUE)[1]
stopifnot(src %in% c("ema", "fda", "pilot"))
out <- if (src == "pilot") "pilot_ema" else src
pat <- jsonlite::fromJSON("../../taxonomy/patterns.json")$patterns
pat <- Filter(function(p) identical(p$group, "estimation") || identical(p$family, "PsN"), pat)
pat[["NONMEM control stream"]] <- list(family = "NONMEM (control stream)",
  regex = "\\$(?:THETA|OMEGA|SIGMA|ERROR|ESTIMATION|SUBROUTINES?)\\b|\\bADVAN\\d{1,2}\\b|\\bNM-?TRAN\\b|\\bMSFO\\b")
pages <- if (src %in% c("ema", "pilot")) {
  d <- read.csv(if (src == "ema") "other_reviews/results/ema_documents.csv" else "other_reviews/results/ema_pilot_documents.csv", colClasses = "character")
  d <- d[d$url != "", ]
  do.call(rbind, lapply(seq_len(nrow(d)), function(i) {
    txt <- pdftools::pdf_text(file.path("other_reviews/cache/ema/pdf", basename(d$url[i])))
    data.frame(drug = d$drug[i], document = sub("\\.pdf$", "", basename(d$url[i])), page = seq_along(txt), text = txt)
  }))
} else {
  d <- read.csv("other_reviews/results/other_documents.csv", colClasses = "character")
  d <- d[d$note == "", ]
  do.call(rbind, lapply(seq_len(nrow(d)), function(i) {
    stem <- paste0(d$application[i], "_", d$document[i])
    f <- sort(list.files(file.path("other_reviews/cache/txt", stem), full.names = TRUE))
    data.frame(drug = d$drug[i], document = stem, page = as.integer(sub("^p(\\d+)\\.txt$", "\\1", basename(f))),
      text = vapply(f, function(x) paste(readLines(x, warn = FALSE), collapse = "\n"), ""))
  }))
}
hits <- list()
ctx <- character(0)
for (i in seq_len(nrow(pages))) {
  t <- pages$text[i]
  for (p in pat) {
    m <- gregexpr(p$regex, t, perl = TRUE)[[1]]
    if (m[1] < 0) next
    hits[[length(hits) + 1]] <- data.frame(pages[i, c("drug", "document", "page")], family = p$family, n = length(m))
    s <- max(1, m[1] - 500)
    ctx <- c(ctx, sprintf("=== %s | %s | page %d | %s (%d)\n%s\n", pages$drug[i], pages$document[i], pages$page[i], p$family, length(m),
      gsub("\\s+", " ", substr(t, s, m[1] + 500))))
  }
}
h <- do.call(rbind, hits)
dir.create("other_reviews/results", showWarnings = FALSE)
write.csv(h, sprintf("other_reviews/results/hits_%s.csv", out), row.names = FALSE)
writeLines(ctx, sprintf("other_reviews/cache/hits_%s.txt", out))
cat("pages:", nrow(pages), " documents:", length(unique(pages$document)), " hits:", nrow(h), " drugs with a hit:", length(unique(h$drug)), "\n")
print(table(h$family))
print(tapply(h$family, h$drug, function(x) paste(sort(unique(x)), collapse = ", ")))
