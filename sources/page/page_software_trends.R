# Software named in PAGE meeting abstracts, per meeting year
#
# Run from sources/page/:
#   Rscript page_software_trends.R                  # pilot: 25 random abstracts, writes pilot/
#   PAGE_MODE=full Rscript page_software_trends.R   # meetings in `years`, writes results/
#   PAGE_MODE=full PAGE_SITEMAP_DATE=2026-09-26 Rscript page_software_trends.R
#                                                   # the same, from the sitemaps cached on that date:
#                                                   # re-classifies the cached pages after a taxonomy change
#
# Uses the pmxlandscape package in this repository and the shared taxonomy
# (taxonomy/patterns.json, software.csv and affiliation_rules.csv).
#
# 1. Reads the abstract URLs from the site's sitemaps (allowed by robots.txt).
#    The sitemaps list abstracts in abstract-number order but carry no year.
#    The full run bisects that order for the first abstract two years before
#    the first year wanted, checks a random sample of earlier pages to confirm
#    none of them is from a wanted year (it stops if one is), and keeps the
#    abstracts whose own citation line gives a wanted year.
# 2. Downloads each page politely (one request every 1.5 s, with a contact
#    address in the user agent) and caches it in page_cache/. The cache is not
#    committed: the pages are PAGE's content. Runs resume from the cache.
# 3. Parses each page: year and abstract number from the citation line, the
#    abstract body without authors, affiliations and reference list, the
#    session (software_demo flags the Software Demonstration session), and the
#    first author's affiliation, classified as industry, academia, regulator,
#    CRO or vendor (classifyFirstAuthor(); affiliation_step says which
#    fallback decided).
# 4. Flags the software families each abstract body names. Only where the
#    body names no estimation tool and the page links a PDF poster or
#    presentation is that PDF downloaded and searched (text layer, OCR for
#    image-only pages). PDF hits are not counted until read: each abstract and
#    estimation tool found only in a PDF needs a decision (used, cited or
#    other, with a reason) in pdf_decisions.csv. The snippets to read are in
#    review/pdf_review.csv, which is not committed. Only "used" counts.
#    estimation_source says where the counted tools were found: abstract,
#    pdf, pending (a PDF hit not yet decided), unknown (the PDF could not be
#    read; left out of the shares) or none. A PDF that cannot be downloaded
#    counts as a failed page, so the run stops and can be retried.
# 5. Writes one row per abstract (IDs, classifications and flags, no abstract
#    text) and run_info.txt. Shares are computed from that file by
#    pmxlandscape, which refuses to count while any PDF hit is pending.

pkgload::load_all("../../pmxlandscape", quiet = TRUE)
library(httr)

mode <- Sys.getenv("PAGE_MODE", "pilot")
stopifnot(mode %in% c("pilot", "full"))
pilot_n <- 25
# Meetings for the full run (there was no meeting in 2020): 2016 to 2026 match the other
# sources; the earlier years are for the lag analysis against the FDA series.
years <- 2006:2026
margin_years <- 2 # start the full run this many years before min(years)
check_n <- 40 # pages sampled before the start to confirm the sitemap order
delay_s <- 1.5
cache_dir <- "page_cache"
out_dir <- if (mode == "full") "results" else "pilot"
ua <- user_agent("PMx Landscape survey of PAGE abstracts (contact: niclas.jonsson@pharmetheus.com)")

patterns <- readPatterns("../../taxonomy/patterns.json")
software <- read.csv("../../taxonomy/software.csv", colClasses = "character")
rules <- readAffiliationRules("../../taxonomy/affiliation_rules.csv")

run_date <- format(Sys.Date())
sitemap_date <- Sys.getenv("PAGE_SITEMAP_DATE", run_date)
sitemap_dir <- file.path(cache_dir, "sitemaps", sitemap_date)
if (sitemap_date != run_date && !dir.exists(sitemap_dir)) stop("No sitemaps cached for ", sitemap_date)
dir.create(sitemap_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(out_dir, showWarnings = FALSE)

fetch <- function(url, file) {
  if (!file.exists(file)) {
    Sys.sleep(delay_s)
    resp <- tryCatch(GET(url, ua, timeout(60)), error = function(e) NULL)
    if (is.null(resp) || status_code(resp) != 200) {
      message("Failed (", if (is.null(resp)) "no response" else paste("HTTP", status_code(resp)), "): ", url)
      return(NA_character_)
    }
    writeBin(content(resp, as = "raw"), file)
  }
  file
}

page_file <- function(url) file.path(cache_dir, paste0(gsub("[^A-Za-z0-9-]", "_", basename(sub("/$", "", url))), ".html"))

parse_url <- function(url) {
  f <- fetch(url, page_file(url))
  parsed <- pageParseAbstract(if (is.na(f)) "<html></html>" else xml2::read_html(f, encoding = "UTF-8"))
  cbind(url = url, fetched = !is.na(f), parsed)
}

# ---- 1. Abstract URLs from the sitemaps --------------------------------------

sitemap_locs <- function(url) {
  f <- fetch(url, file.path(sitemap_dir, basename(url)))
  if (is.na(f)) stop("Could not fetch the sitemap ", url)
  xml2::xml_text(xml2::xml_find_all(xml2::xml_ns_strip(xml2::read_xml(f)), "//url/loc|//sitemap/loc"))
}
child_maps <- sitemap_locs("https://www.page-meeting.org/sitemap_index.xml")
abstract_maps <- grep("abstracts_cpt-sitemap", child_maps, value = TRUE)
urls <- unique(unlist(lapply(abstract_maps, sitemap_locs)))
urls <- urls[!grepl("/Abstracts/?$", urls)] # the archive's index page
n_pages <- length(urls)
cat(length(abstract_maps), "abstract sitemaps,", n_pages, "abstract pages\n")
selection <- character(0)

if (mode == "pilot") {
  set.seed(1)
  urls <- sample(urls, min(pilot_n, length(urls)))
} else {
  year_at <- function(i) {
    y <- parse_url(urls[i])$year
    if (is.na(y)) stop("No year on ", urls[i], ", needed to locate the start of the run")
    y
  }
  first_wanted <- min(years) - margin_years
  lo <- 1L
  hi <- length(urls)
  while (lo < hi) { # first position whose year is >= first_wanted, assuming year order
    mid <- (lo + hi) %/% 2L
    if (year_at(mid) >= first_wanted) hi <- mid else lo <- mid + 1L
  }
  start <- lo
  set.seed(2)
  before <- sort(sample(seq_len(start - 1L), min(check_n, start - 1L)))
  before_years <- vapply(before, year_at, integer(1))
  if (any(before_years >= min(years))) {
    stop(
      "The sitemap is not in year order: pages before position ", start, " include years ",
      paste(unique(before_years[before_years >= min(years)]), collapse = ", "), ". Select by another route."
    )
  }
  selection <- c(
    paste0("selection: sitemap positions ", start, " to ", length(urls), " (first abstract from ", first_wanted,
           " or later, found by bisection)"),
    paste0("order check: ", length(before), " random pages before position ", start, " have years ",
           min(before_years), " to ", max(before_years), ", none from ", min(years), " or later")
  )
  cat(selection, sep = "\n")
  urls <- urls[start:length(urls)]
}

# ---- 2 and 3. Download, cache and parse ---------------------------------------

abstracts <- do.call(rbind, lapply(seq_along(urls), function(i) {
  if (i %% 100 == 0) cat("Processed", i, "of", length(urls), "\n")
  parse_url(urls[i])
}))
n_failed <- sum(!abstracts$fetched)
no_layout <- abstracts$fetched & is.na(abstracts$year)
n_no_layout <- sum(no_layout)
if (n_no_layout > 0) message(n_no_layout, " pages have no abstract layout (no citation year), e.g. ", abstracts$url[no_layout][1])
if (mode == "full") {
  outside <- table(abstracts$year[!abstracts$year %in% years], useNA = "ifany")
  abstracts <- abstracts[abstracts$year %in% years, ]
}

abstracts$first_author <- trimws(stringi::stri_extract_first_regex(abstracts$authors, "^[^,(]*"))
first_author <- classifyFirstAuthor(abstracts$authors, abstracts$affiliations, rules)
abstracts$main_affiliation <- first_author$affiliation
abstracts$affiliation_type <- first_author$affiliation_type
abstracts$affiliation_step <- first_author$step

# ---- 4. Software named in the abstract body ------------------------------------

found <- findSoftware(abstracts$body, patterns)
group_of <- setNames(software$group, software$family)
for (g in c("estimation", "auxiliary", "pbpk", "nca")) {
  abstracts[[g]] <- vapply(found, function(f) paste(f[group_of[f] == g], collapse = "; "), character(1))
}
abstracts$pdf_needed <- abstracts$estimation == "" & !is.na(abstracts$pdf_url)
# the link stays local: its file name often carries an author's name
abstracts$has_poster <- !is.na(abstracts$pdf_url)

# ---- 4b. PDF posters and presentations, only where the abstract names no tool ----

pdf_dir <- file.path(cache_dir, "pdf")
dir.create(pdf_dir, showWarnings = FALSE)
abstracts$pdf_status <- ifelse(abstracts$pdf_needed, NA_character_, "not searched")
abstracts$pdf_other <- ""
pdf_hits <- list()
for (i in which(abstracts$pdf_needed)) {
  f <- fetch(abstracts$pdf_url[i], file.path(pdf_dir, basename(abstracts$pdf_url[i])))
  pages <- if (is.na(f)) NULL else tryCatch(pdfPages(f), error = function(e) NULL)
  if (is.null(pages)) {
    abstracts$pdf_status[i] <- if (is.na(f)) "download failed" else "unreadable"
    if (is.na(f)) n_failed <- n_failed + 1L
    next
  }
  abstracts$pdf_status[i] <- if (all(pages$src == "ocr")) "ocr" else if (any(pages$src == "ocr")) "text and ocr" else "text"
  text <- paste(pages$text, collapse = "\n")
  other <- findSoftware(text, patterns, groups = c("auxiliary", "pbpk", "nca"))[[1]]
  abstracts$pdf_other[i] <- paste(other, collapse = "; ") # not read, not counted as popPK software
  m <- findMatches(text, patterns, groups = "estimation")
  if (nrow(m) > 0) pdf_hits[[length(pdf_hits) + 1]] <- cbind(abstract_no = abstracts$abstract_no[i], m)
}

# One row per abstract and estimation tool found in a PDF, with the snippets to read
decisions <- readDecisions("pdf_decisions.csv")
no_hits <- data.frame(abstract_no = integer(0), family = character(0), snip = character(0))
hits <- do.call(rbind, c(list(no_hits), lapply(pdf_hits, `[`, c("abstract_no", "family", "snip"))))
hits$citation_like <- looksLikeCitation(hits$snip)
review <- unique(hits[c("abstract_no", "family")])
review$n_matches <- integer(nrow(review))
review$all_citation_like <- logical(nrow(review))
review$snippets <- character(nrow(review))
for (j in seq_len(nrow(review))) {
  h <- hits[hits$abstract_no == review$abstract_no[j] & hits$family == review$family[j], ]
  review$n_matches[j] <- nrow(h)
  review$all_citation_like[j] <- all(h$citation_like)
  review$snippets[j] <- paste(utils::head(h$snip, 5), collapse = " || ")
}
review$decision <- applyDecisions(review, decisions)
dir.create("review", showWarnings = FALSE)
write.csv(review, file.path("review", if (mode == "full") "pdf_review.csv" else "pdf_review_pilot.csv"), row.names = FALSE)
if (mode == "full") {
  unused <- decisions[!paste(decisions$abstract_no, decisions$family) %in% paste(review$abstract_no, review$family), ]
  if (nrow(unused) > 0) message(nrow(unused), " decision(s) in pdf_decisions.csv match no PDF hit in this run")
}

used <- review[review$decision == "used", ]
abstracts$pdf_estimation <- vapply(abstracts$abstract_no, function(a) {
  paste(used$family[used$abstract_no %in% a], collapse = "; ")
}, character(1))
abstracts$pdf_pending <- vapply(abstracts$abstract_no, function(a) {
  sum(review$abstract_no %in% a & review$decision == "pending")
}, integer(1))
abstracts$estimation_source <- ifelse(abstracts$estimation != "", "abstract",
  ifelse(abstracts$pdf_estimation != "", "pdf", ifelse(abstracts$pdf_pending > 0, "pending",
    ifelse(abstracts$pdf_status %in% c("unreadable", "download failed"), "unknown", "none")
  ))
)
n_pending <- sum(review$decision == "pending")

# ---- 5. Output -------------------------------------------------------------------

keep <- c(
  "abstract_no", "year", "url", "fetched", "session", "software_demo", "affiliation_type", "affiliation_step", "estimation",
  "auxiliary", "pbpk", "nca", "has_poster", "pdf_needed", "pdf_status", "pdf_estimation", "pdf_pending", "pdf_other",
  "estimation_source"
)
write.csv(abstracts[keep], file.path(out_dir, "page_abstracts.csv"), row.names = FALSE)
writeLines(c(
  paste("run_date:", run_date), paste("sitemaps from:", sitemap_date), paste("mode:", mode), paste("abstract pages in sitemaps:", n_pages), selection,
  paste("pages processed:", length(urls)), paste("pages and PDFs that could not be fetched:", n_failed),
  paste("pages without the abstract layout (no citation year):", n_no_layout),
  paste("abstracts whose PDF could not be read (left out of the shares):", sum(abstracts$pdf_status == "unreadable")),
  if (mode == "full") {
    c(
      paste("years kept:", paste(range(years), collapse = " to ")),
      paste("abstracts kept:", nrow(abstracts)),
      paste("processed pages outside the years (year: n):", paste(names(outside), outside, sep = ": ", collapse = ", "))
    )
  },
  paste("affiliation decided by (step: n):", paste(names(table(abstracts$affiliation_step, useNA = "ifany")),
    table(abstracts$affiliation_step, useNA = "ifany"), sep = ": ", collapse = ", ")),
  paste("PDFs searched:", sum(abstracts$pdf_needed)), paste("PDF hits awaiting a decision:", n_pending)
), file.path(out_dir, "run_info.txt"))
cat(readLines(file.path(out_dir, "run_info.txt")), sep = "\n")

if (mode == "pilot") {
  # For checking by eye: includes names and affiliations, so pilot/ is not committed.
  write.csv(abstracts[c(keep[1:2], "first_author", "main_affiliation", keep[-(1:2)])],
    file.path(out_dir, "pilot_check.csv"),
    row.names = FALSE
  )
  cat("\nPages without a year:", sum(is.na(abstracts$year)), "  without a body:", sum(is.na(abstracts$body)), "\n")
  cat("Affiliation types:\n")
  print(table(abstracts$affiliation_type, useNA = "ifany"))
  cat("Where the estimation tools were found:\n")
  print(table(abstracts$estimation_source))
}
if (n_failed > 0) stop(n_failed, " pages or PDFs could not be fetched; run again to retry them (the rest is cached)")
