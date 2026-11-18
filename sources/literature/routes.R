# Literature: tool shares by route into the frame (development run, from 2026-10-21)
#
# Run from sources/literature/ after local_search.R, classifications/lit_relevance/run_v2.R import
# and the tool use tags: Rscript routes.R
#
# Every corpus paper was read for a model fit of its own (relevance codebook version 2), and only
# papers read as own_fit are counted. Each paper records how it was found: the term route (the
# field's names for the method: the core and the extension, `admitted`) and the tool route (an
# estimation tool made for pharmacometric work named in the title and abstract or in the methods,
# `tool_route`). A paper found by both routes is in both. The shares are shown for the term route,
# the tool route and both routes together, for papers naming each tool (the local search) and
# papers using it (the tool use classification).
#
# Writes:
#   results/route_shares.csv   source, route, measure (naming, using), period, software, n, n_any,
#                              base_n, share, share_all
#   results/route_counts.csv   papers per source, route and relevance value
# Development run results: the numbers may change at the production run.

pkgload::load_all("../../pmxlandscape", quiet = TRUE)

software <- read.csv("../../taxonomy/software.csv", colClasses = "character")
estimation <- unique(software$family[software$group == "estimation"])
ids <- read.csv(gzfile("results/ids_local_all.csv.gz"), colClasses = "character")
ids$year <- as.integer(ids$year)
rel <- read.csv("../../classifications/lit_relevance/decisions_v2.csv", colClasses = "character")
labels <- c("PubMed" = "PubMed (title/abstract)", "Europe PMC" = "Europe PMC (full text)")
rel$source <- unname(labels[rel$source])
key <- function(source, id) paste(source, id)
base <- ids[ids$software == "All (base set)", ]
base$value <- rel$value[match(key(base$source, base$id), key(rel$source, rel$item_id))]
base$term <- base$admitted %in% c("core", "extension")
base$tool <- base$tool_route != ""
# papers with no text in the corpus (2 PubMed records without title or abstract) were not read
base$value[is.na(base$value)] <- "no text"
stopifnot(sum(base$value == "no text") <= 2)

routeOf <- list(term = base$term, tool = base$tool, both = base$term | base$tool)
counts <- do.call(rbind, lapply(names(routeOf), function(r) {
  b <- base[routeOf[[r]], ]
  cbind(route = r, as.data.frame(table(source = b$source, value = b$value), responseName = "papers"))
}))
write.csv(counts, "results/route_counts.csv", row.names = FALSE)

tags <- read.csv("../../classifications/tool_use/tags.csv", colClasses = "character")
periods <- c("2016 to 2020" = 2016, "2021 to 2025" = 2021, "2026" = 2026)
period <- function(y) names(periods)[findInterval(y, periods)]
out <- do.call(rbind, lapply(names(routeOf), function(r) {
  keep <- base[routeOf[[r]] & base$value == "own_fit", ]
  d <- ids[key(ids$source, ids$id) %in% key(keep$source, keep$id), c("source", "year", "software", "id")]
  d$year <- period(d$year)
  used <- literatureUsedIds(d, tags)
  rbind(
    cbind(route = r, measure = "naming", literatureShares(d, estimation)),
    cbind(route = r, measure = "using", literatureShares(used, estimation))
  )
}))
names(out)[names(out) == "year"] <- "period"
write.csv(out, "results/route_shares.csv", row.names = FALSE)

show <- out[out$period == "2021 to 2025" & out$software %in% c("NONMEM", "Monolix", "Phoenix NLME", "nlmixr", "Pumas"), ]
show$share <- round(100 * show$share)
print(reshape(show[c("source", "measure", "route", "software", "share")],
  idvar = c("source", "measure", "software"), timevar = "route", direction = "wide"
), row.names = FALSE)
print(counts[counts$route == "both", ], row.names = FALSE)
