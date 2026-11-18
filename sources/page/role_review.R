# PAGE abstracts: reading set for tool role and analysis type
#
# Run from sources/page/ after page_software_trends.R: Rscript role_review.R
#
# Every abstract outside the Software Demonstration session that names an
# estimation tool, in its body or (read and decided) in its poster PDF. Writes
# the title and body (authors, affiliations and references left out) with the
# tools to review/role_review.csv (not committed: the text is PAGE's). Each
# abstract is read following role_rubric.md; the decisions go to
# role_decisions.csv (IDs, roles, types and short notes only).

pkgload::load_all("../../pmxlandscape", quiet = TRUE)

page <- read.csv("results/page_abstracts.csv", colClasses = "character")
page <- page[page$software_demo == "FALSE" & page$estimation_source %in% c("abstract", "pdf"), ]
page_file <- function(url) {
  file.path("page_cache", paste0(gsub("[^A-Za-z0-9-]", "_", basename(sub("/$", "", url))), ".html"))
}
parsed <- lapply(page$url, function(u) pageParseAbstract(xml2::read_html(page_file(u), encoding = "UTF-8")))
page$title <- vapply(parsed, `[[`, "", "title")
page$body <- vapply(parsed, `[[`, "", "body")
page$tools_named <- ifelse(page$estimation_source == "abstract", page$estimation,
  vapply(strsplit(page$pdf_estimation, "; ", fixed = TRUE), function(t) paste0(t, " (from poster: used)", collapse = "; "), "")
)
write.csv(page[c("abstract_no", "year", "session", "tools_named", "title", "body")], "review/role_review.csv", row.names = FALSE)
decided <- if (file.exists("role_decisions.csv")) read.csv("role_decisions.csv", colClasses = "character")$abstract_no else character(0)
cat("abstracts to read:", nrow(page), " already decided:", sum(page$abstract_no %in% decided), "\n")
print(table(page$year))
