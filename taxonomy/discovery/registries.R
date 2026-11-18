# Registry snapshots: dated lists of software names from lists other people keep
#
# Run from taxonomy/discovery/: Rscript registries.R
#
# Fetches each list (one request each, with a contact address), keeps the page in cache/ (not
# committed: the lists are their owners' content) and writes the names only, with the URL and
# date, to registries/<registry>_<date>.csv. discover.R adds every name to the candidates, so a
# listed tool is read even when the corpora name it rarely.
#
# Lists (October 2026):
#   page_estimation  PAGE, Parameter estimation software: the product names in bold. Link
#                    labels that are bold too (support pages, archives) are left out by name.
#   page_support     PAGE, Support software and resources: the bold names of the "Support
#                    tools" part, before "Resources" (journals, regulators, archives).
#   cran_pk          CRAN Task View Pharmacokinetics (its source on GitHub): every pkg() name.

library(httr)
ua <- user_agent("PMx Landscape survey (contact: niclas.jonsson@pharmetheus.com)")
dir.create("cache/registries", recursive = TRUE, showWarnings = FALSE)
dir.create("registries", showWarnings = FALSE)
fetched <- format(Sys.Date())

get <- function(url, file) {
  path <- file.path("cache/registries", file)
  if (!file.exists(path)) {
    Sys.sleep(2)
    r <- GET(url, ua, timeout(60))
    if (status_code(r) != 200) stop("HTTP ", status_code(r), " for ", url)
    writeBin(content(r, as = "raw"), path)
  }
  path
}
bold <- function(path) {
  doc <- xml2::read_html(path)
  box <- rvest::html_element(doc, "article")
  if (inherits(box, "xml_missing")) box <- rvest::html_element(doc, "main")
  if (inherits(box, "xml_missing")) stop("no article or main element in ", path)
  stringi::stri_trim_both(rvest::html_text2(rvest::html_elements(box, "h2, strong")))
}

lists <- list()

url <- "https://www.page-meeting.org/about-us/parameter-estimation-software/"
x <- bold(get(url, "page_estimation.html"))
not_names <- c("Software and Support", "Net Archive", "Repository at ICON/GloboMax", "in French")
lists$page_estimation <- data.frame(name = setdiff(x, not_names), url = url)

url <- "https://www.page-meeting.org/about-us/support-software-and-resources/"
x <- bold(get(url, "page_support.html"))
from <- match("Support tools", x)
to <- match("Resources", x)
if (is.na(from) || is.na(to) || to <= from) stop("the support page no longer has a Support tools part before Resources")
lists$page_support <- data.frame(name = setdiff(x[(from + 1):(to - 1)], "Support tools"), url = url)

url <- "https://raw.githubusercontent.com/cran-task-views/Pharmacokinetics/main/Pharmacokinetics.md"
md <- readLines(get(url, "cran_pk.md"), warn = FALSE)
pk <- unique(unlist(lapply(stringi::stri_match_all_regex(md, 'pkg\\("([^"]+)"'), function(m) m[, 2])))
lists$cran_pk <- data.frame(name = pk[!is.na(pk)], url = url)

for (r in names(lists)) {
  d <- cbind(registry = r, lists[[r]], fetched = fetched)
  write.csv(d, file.path("registries", sprintf("%s_%s.csv", r, fetched)), row.names = FALSE)
  cat(r, ":", nrow(d), "names\n")
}
