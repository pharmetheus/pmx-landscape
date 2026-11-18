# FDA "not stated" drugs: which review documents does each Drugs@FDA table of contents list,
# beyond the three types already read (ClinPharmR, IntegratedR, MultidisciplineR)?
#
# Run from sources/fda/other_reviews/: Rscript discover.R
# Writes cache/toc/<appl>.html and results/toc_documents.csv. About 1 request per second.

res <- read.csv("../results/fda_2021_2025_popPK_software.csv", colClasses = "character")
ns <- res[grepl("not stated", res$category, ignore.case = TRUE), ]
dir.create("cache/toc", recursive = TRUE, showWarnings = FALSE)
dir.create("results", showWarnings = FALSE)
`%||%` <- function(a, b) if (is.null(a)) b else a
ua <- "pmx-software-landscape (research; niclas.jonsson@pharmetheus.com)"
fetch <- function(url) {
  Sys.sleep(1)
  resp <- httr2::request(url) |>
    httr2::req_user_agent(ua) |>
    httr2::req_retry(max_tries = 4) |>
    httr2::req_error(is_error = function(r) FALSE) |>
    httr2::req_perform()
  if (httr2::resp_status(resp) != 200) stop("HTTP ", httr2::resp_status(resp), " for ", url)
  httr2::resp_body_string(resp)
}
out <- list()
for (i in seq_len(nrow(ns))) {
  appl <- ns$application[i]
  prefix <- if (grepl("^(761|125)", appl)) "BLA" else "NDA"
  j <- jsonlite::fromJSON(fetch(sprintf('https://api.fda.gov/drug/drugsfda.json?search=application_number:"%s%s"&limit=5', prefix, appl)),
    simplifyVector = FALSE
  )
  tocs <- unique(unlist(lapply(j$results, function(r) {
    lapply(r$submissions, function(s) {
      if (!identical(s$submission_type, "ORIG")) return(NULL)
      vapply(Filter(function(d) identical(d$type, "Review") && grepl("TOC", d$url), s$application_docs %||% list()), `[[`, "", "url")
    })
  })))
  for (u in tocs) {
    f <- file.path("cache/toc", paste0(appl, "_", basename(u), ".html"))
    t <- if (file.exists(f)) paste(readLines(f, warn = FALSE), collapse = "\n") else { x <- fetch(u); writeLines(x, f); x }
    base <- regmatches(t, regexpr('var pdfBaseName = "[^"]+"', t))
    base <- if (length(base)) sub('var pdfBaseName = "([^"]+)"', "\\1", base) else NA_character_
    k <- regexpr("var pdfFiles", t)
    flags <- character(0)
    if (k > 0) {
      block <- substr(t, k, k + 4000)
      m <- regmatches(block, gregexpr("(\\w+):\\s*1\\b", block))[[1]]
      flags <- sub(":.*", "", m)
    }
    out[[length(out) + 1]] <- data.frame(
      year = ns$year[i], drug = ns$drug[i], application = appl, toc = u, base = base,
      documents = paste(flags, collapse = "; ")
    )
  }
  if (!length(tocs)) out[[length(out) + 1]] <- data.frame(year = ns$year[i], drug = ns$drug[i], application = appl, toc = "", base = NA, documents = "")
  cat(i, ns$drug[i], length(tocs), "TOC\n")
}
d <- do.call(rbind, out)
write.csv(d, "results/toc_documents.csv", row.names = FALSE)
cat("drugs:", length(unique(d$application)), " TOCs:", sum(d$toc != ""), "\n")
print(sort(table(unlist(strsplit(d$documents, "; "))), decreasing = TRUE))
