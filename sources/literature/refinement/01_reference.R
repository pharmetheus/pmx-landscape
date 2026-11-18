# Part 1: reference sets found without the base terms, for the recall of the base query
#
#   R1  core journals: every paper of J Pharmacokinet Pharmacodyn and CPT Pharmacometrics Syst
#       Pharmacol, 2021 to 2025, without errata, editorials, comments and retractions. PubMed
#       (all records) and Europe PMC (the open-access full texts the Europe PMC base could
#       reach).
#   R2  tool-anchored: papers naming an unambiguous estimation tool, Europe PMC in the methods
#       section of the full text, PubMed in the title or abstract.
#
# Writes results/reference_queries.csv (set, source, year, query, count, n_ids, run_date) and
# results/reference_ids.csv.gz (set, source, year, id, in_base).

source("common.R")

pmJournals <- '("J Pharmacokinet Pharmacodyn"[ta] OR "CPT Pharmacometrics Syst Pharmacol"[ta])'
pmNotes <- paste0(
  'NOT (erratum[pt] OR "published erratum"[pt] OR editorial[pt] OR comment[pt] OR ',
  '"retraction of publication"[pt] OR "retracted publication"[pt])'
)
epJournals <- '(ISSN:"1567-567X" OR ISSN:"1573-8744" OR ISSN:"2163-8306")'
epNotes <- 'AND NOT PUB_TYPE:"Published Erratum" AND NOT PUB_TYPE:"Editorial" AND NOT PUB_TYPE:"Comment"'

sets <- list(
  list(set = "R1 core journals", source = "PubMed", q = function(y) paste0(pmJournals, " AND ", y, "[dp] ", pmNotes)),
  list(set = "R1 core journals", source = "Europe PMC", q = function(y) {
    paste(epJournals, "AND PUB_YEAR:", y, epFilter, epNotes)
  }),
  list(set = "R2 tool-anchored", source = "PubMed", q = function(y) paste0(pmTools, " AND ", y, "[dp]")),
  list(set = "R2 tool-anchored", source = "Europe PMC", q = function(y) {
    paste0("METHODS:", epToolTerms, " AND PUB_YEAR:", y, " ", epFilter)
  })
)

runs <- do.call(rbind, lapply(sets, function(s) {
  do.call(rbind, lapply(years, function(y) {
    q <- gsub("PUB_YEAR: ", "PUB_YEAR:", s$q(y), fixed = TRUE)
    r <- cachedQuery(q, y, s$source)
    data.frame(set = s$set, source = s$source, year = y, query = q, count = r$count, n_ids = length(r$ids),
      run_date = run_date, ids = I(list(r$ids)))
  }))
}))
write.csv(runs[setdiff(names(runs), "ids")], "results/reference_queries.csv", row.names = FALSE)

ids <- do.call(rbind, lapply(seq_len(nrow(runs)), function(i) {
  x <- runs$ids[[i]]
  if (length(x) == 0) {
    return(NULL)
  }
  data.frame(set = runs$set[i], source = runs$source[i], year = runs$year[i], id = x,
    in_base = x %in% baseIds[[runs$source[i]]])
}))
writeGz(ids, "results/reference_ids.csv.gz")
print(aggregate(cbind(papers = 1, in_base = in_base) ~ set + source, ids, sum))
