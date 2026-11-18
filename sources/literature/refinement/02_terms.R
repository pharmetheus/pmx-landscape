# Part 2: the papers each candidate term adds to the base set, by queries only
#
# For each term (terms.csv), source and year: the papers the term finds, the increment (those
# not in the frozen base set), and the papers among them that name an unambiguous estimation
# tool (PubMed in the title or abstract, Europe PMC anywhere in the full text, as for the
# base set's tool series). The terms are searched in the base set's own fields: PubMed [tiab],
# Europe PMC title, abstract and keywords with the base set's full-text filter.
#
# Writes results/term_queries.csv (term, source, year, query, tool_query, count, increment,
# increment_naming_tool, run_date) and results/term_ids.csv.gz (term, source, year, id,
# names_tool) for the increments.

source("common.R")

terms <- read.csv("terms.csv", colClasses = "character")
epTerm <- function(alts) {
  a <- strsplit(alts, "|", fixed = TRUE)[[1]]
  paste0("(", paste(outer(c("TITLE", "ABSTRACT", "KW"), a, paste, sep = ":"), collapse = " OR "), ")")
}

grid <- expand.grid(term = terms$term, source = c("PubMed", "Europe PMC"), year = years, stringsAsFactors = FALSE)
res <- lapply(seq_len(nrow(grid)), function(i) {
  g <- grid[i, ]
  t <- terms[terms$term == g$term, ]
  if (g$source == "PubMed") {
    q <- paste0(t$pubmed, " AND ", g$year, "[dp]")
    qt <- paste0(t$pubmed, " AND ", pmTools, " AND ", g$year, "[dp]")
  } else {
    q <- paste0(epTerm(t$epmc), " AND PUB_YEAR:", g$year, " ", epFilter)
    qt <- paste0(epTerm(t$epmc), " AND ", epToolTerms, " AND PUB_YEAR:", g$year, " ", epFilter)
  }
  all <- cachedQuery(q, g$year, g$source)
  tool <- cachedQuery(qt, g$year, g$source)
  inc <- setdiff(all$ids, baseIds[[g$source]])
  list(
    row = data.frame(g, query = q, tool_query = qt, count = all$count, increment = length(inc),
      increment_naming_tool = length(intersect(inc, tool$ids)), run_date = run_date),
    ids = if (length(inc)) data.frame(g, id = inc, names_tool = inc %in% tool$ids)
  )
})
rows <- do.call(rbind, lapply(res, `[[`, "row"))
write.csv(rows, "results/term_queries.csv", row.names = FALSE)
writeGz(do.call(rbind, lapply(res, `[[`, "ids")), "results/term_ids.csv.gz")

tot <- aggregate(cbind(count, increment, increment_naming_tool) ~ term + source, rows, sum)
tot$naming_rate <- round(tot$increment_naming_tool / tot$increment, 3)
print(tot[order(tot$source, -tot$increment), ], row.names = FALSE)
