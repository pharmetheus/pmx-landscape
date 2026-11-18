# Literature: papers naming each tool, by the taxonomy patterns on the local corpus
#
# Run from sources/literature/ after make corpus: Rscript local_search.R
#
# The continuing literature series (Niclas, 2026-10-18) counts papers naming a tool, now found
# by the shared patterns (taxonomy/patterns.json) in the corpus text instead of by the servers'
# search, so the patterns are the same as for PAGE and FDA (case-sensitive where the taxonomy
# says so, reference lists left out):
#   PubMed      title, abstract and keywords (the fields PubMed's [tiab] search reads), every
#               paper of the frozen base set
#   Europe PMC  title, abstract, keywords, body, floats and appendices (not the back matter or the
#               reference list), the base-set papers with an open-access full text
# The published series reads the core of 2021 to 2026 only (the frozen base set); the corpus also
# holds the core of 2016 to 2020, the extension and the tool route (admitted_by, tool_route),
# which go to a file of their own until Niclas approves a README rebuild with them.
# Writes, in the format of ids.csv.gz (so literatureShares() reads either):
#   results/ids_local.csv.gz      source, year, software, id (base set rows: "All (base set)"),
#                                 core 2021 to 2026
#   results/ids_local_all.csv.gz  the same for every corpus item, with `admitted` (core,
#                                 extension or tool: the route and terms that found it first)
#                                 and `tool_route` (the tools the tool route found it by, "" if
#                                 none)
#   results/pbpk_local.csv.gz     the PBPK tools each corpus item names (source, year, software,
#                                 id), by name only: they are not read and open no route
#   results/local_vs_server.csv   per source, year and family: papers by the server queries
#                                 (ids.csv.gz) and by the local search, and the overlap

pkgload::load_all("../../pmxlandscape", quiet = TRUE)

allPatterns <- readPatterns("../../taxonomy/patterns.json")
patterns <- allPatterns[allPatterns$group == "estimation", ]
# PBPK tools are recorded by name only (Niclas, 2026-10-20): they open no route and are not read
pbpkPatterns <- allPatterns[allPatterns$group == "pbpk", ]
pbpk <- list()
sources <- list(
  list(name = "pubmed", label = "PubMed (title/abstract)", sections = c("title", "abstract", "keywords"), coverage = NULL),
  list(name = "epmc", label = "Europe PMC (full text)", sections = c("title", "abstract", "keywords", "body", "floats", "appendix"),
    coverage = "full text")
)
ids <- do.call(rbind, lapply(sources, function(s) {
  x <- corpusRead("../../corpus", s$name, sections = s$sections)
  items <- x$items
  if (!is.null(s$coverage)) items <- items[items$coverage == s$coverage, ]
  t <- corpusText(x$sections[x$sections$item_id %in% items$item_id, ], s$sections, sep = "\n")
  fam <- findSoftware(t$text, patterns, groups = "estimation")
  year <- items$year[match(t$item_id, items$item_id)]
  out <- rbind(
    data.frame(source = s$label, year = items$year, software = "All (base set)", id = items$item_id),
    do.call(rbind, lapply(seq_along(fam), function(i) {
      if (length(fam[[i]]) == 0) NULL else data.frame(source = s$label, year = year[i], software = fam[[i]], id = t$item_id[i])
    }))
  )
  i <- match(out$id, items$item_id)
  out$admitted <- sub(" .*", "", sub(":.*", "", items$admitted_by[i]))
  out$tool_route <- if (is.null(items$tool_route)) "" else ifelse(is.na(items$tool_route[i]), "", items$tool_route[i])
  pb <- findSoftware(t$text, pbpkPatterns, groups = "pbpk")
  pbpk[[s$name]] <<- do.call(rbind, lapply(seq_along(pb), function(i) {
    if (length(pb[[i]]) == 0) NULL else data.frame(source = s$label, year = year[i], software = pb[[i]], id = t$item_id[i])
  }))
  out
}))
ids <- ids[order(ids$source, ids$year, ids$software, ids$id), ]
writeIds <- function(x, f) {
  con <- gzfile(f, "w")
  write.csv(x, con, row.names = FALSE)
  close(con)
}
writeIds(ids, "results/ids_local_all.csv.gz")
pbpk <- do.call(rbind, pbpk)
writeIds(pbpk[order(pbpk$source, pbpk$year, pbpk$software, pbpk$id), ], "results/pbpk_local.csv.gz")
ids <- ids[ids$admitted == "core" & ids$year >= 2021, c("source", "year", "software", "id")]
writeIds(ids, "results/ids_local.csv.gz")

server <- read.csv(gzfile("results/ids.csv.gz"), colClasses = "character")
server <- server[server$source %in% vapply(sources, `[[`, "", "label"), ]
key <- c("source", "year", "software")
grid <- unique(rbind(ids[key], server[server$software != "All (base set)", key]))
grid <- grid[grid$software != "All (base set)", ]
cmp <- do.call(rbind, lapply(seq_len(nrow(grid)), function(i) {
  g <- grid[i, ]
  sel <- function(d) unique(d$id[d$source == g$source & d$year == g$year & d$software == g$software])
  base <- function(d) length(unique(d$id[d$source == g$source & d$year == g$year & d$software == "All (base set)"]))
  a <- sel(server)
  b <- sel(ids)
  data.frame(g, server = length(a), local = length(b), both = length(intersect(a, b)),
    server_base = base(server), local_base = base(ids))
}))
cmp <- cmp[order(cmp$source, cmp$software, cmp$year), ]
write.csv(cmp, "results/local_vs_server.csv", row.names = FALSE)
tot <- aggregate(cbind(server, local, both) ~ source + software, cmp, sum)
print(tot[tot$server + tot$local > 0, ][order(-tot$server[tot$server + tot$local > 0]), ], row.names = FALSE)
