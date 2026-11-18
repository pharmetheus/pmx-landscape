# EMA assessment reports for the FDA "not stated" drugs: find each matched product's public
# (or withdrawal/refusal) assessment report and download it with its text.
# Run from sources/fda/ after the match step; writes other_reviews/cache/ema/ and
# other_reviews/results/ema_documents.csv. One request every 4 s (EMA answers faster bursts with 429).
ua <- "pmx-software-landscape (research; niclas.jonsson@pharmetheus.com)"
get <- function(url) {
  Sys.sleep(4)
  r <- httr2::request(url) |> httr2::req_user_agent(ua) |> httr2::req_retry(max_tries = 6, backoff = function(i) 30 * i) |>
    httr2::req_timeout(300) |> httr2::req_error(is_error = function(r) FALSE) |> httr2::req_perform()
  if (httr2::resp_status(r) != 200) stop("HTTP ", httr2::resp_status(r), " for ", url)
  r
}
e <- readRDS("other_reviews/cache/ema/medicines.rds")
e <- e[e$Category == "Human", ]
mt <- readRDS("other_reviews/cache/ema/match.rds")
dir.create("other_reviews/cache/ema/pdf", showWarnings = FALSE)
dir.create("other_reviews/cache/ema/txt", showWarnings = FALSE)
out <- list()
for (i in seq_len(nrow(mt$ns))) {
  for (k in mt$hit[[i]]) {
    page <- e$Medicine.URL[k]
    pf <- file.path("other_reviews/cache/ema/pages", paste0(basename(page), ".html"))
    dir.create(dirname(pf), showWarnings = FALSE)
    if (!file.exists(pf)) writeLines(httr2::resp_body_string(get(page)), pf)
    h <- paste(readLines(pf, warn = FALSE), collapse = "\n")
    links <- unique(regmatches(h, gregexpr('href="[^"]*/documents/assessment-report/[^"]*\\.pdf"', h))[[1]])
    links <- sub('^href="', "", sub('"$', "", links))
    links <- ifelse(startsWith(links, "http"), links, paste0("https://www.ema.europa.eu", links))
    keep <- links[grepl("public-assessment-report|withdrawal-assessment-report|refusal-public-assessment-report|assessment-report_en", links) &
      !grepl("variation|procedural-steps|referral|psusa", links)]
    for (u in keep) {
      stem <- sub("\\.pdf$", "", basename(u))
      pdf <- file.path("other_reviews/cache/ema/pdf", paste0(stem, ".pdf"))
      if (!file.exists(pdf)) writeBin(httr2::resp_body_raw(get(u)), pdf)
      txt <- pdftools::pdf_text(pdf)
      writeLines(txt, file.path("other_reviews/cache/ema/txt", paste0(stem, ".txt")))
      out[[length(out) + 1]] <- data.frame(
        year = mt$ns$year[i], drug = mt$ns$drug[i], application = mt$ns$application[i],
        ema_product = e$Name.of.medicine[k], ema_status = e$Medicine.status[k], url = u, pages = length(txt),
        text_pages = sum(nchar(gsub("\\s", "", txt)) >= 50)
      )
    }
    if (!length(keep)) {
      out[[length(out) + 1]] <- data.frame(
        year = mt$ns$year[i], drug = mt$ns$drug[i], application = mt$ns$application[i],
        ema_product = e$Name.of.medicine[k], ema_status = e$Medicine.status[k], url = "", pages = NA, text_pages = NA
      )
    }
    cat(mt$ns$drug[i], "->", e$Name.of.medicine[k], length(keep), "reports\n")
  }
}
d <- do.call(rbind, out)
write.csv(d, "other_reviews/results/ema_documents.csv", row.names = FALSE)
cat("DONE products:", length(unique(paste(d$drug, d$ema_product))), " reports:", sum(d$url != ""), "\n")
