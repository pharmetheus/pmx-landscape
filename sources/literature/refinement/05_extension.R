# The extension in the corpus: tool shares (papers naming each estimation tool) with the core
# alone and with core plus extension, by source and year, 2016 to 2026
#
# Run from sources/literature/refinement/ after local_search.R and the relevance reading of the
# new Europe PMC papers naming no tool (classifications/lit_relevance, run.R corpus-import).
# Europe PMC papers without an own fit or outside the field are left out of the base, as in the
# published series: the core of 2021 to 2026 by ../no_tool_decisions.csv, the core of 2016 to
# 2020 and the extension by the corpus reading.
#
# Writes results/extension_shares.csv.

pkgload::load_all("../../../pmxlandscape", quiet = TRUE)

software <- read.csv("../../../taxonomy/software.csv", colClasses = "character")
estimation <- software$family[software$group == "estimation"]
ids <- read.csv(gzfile("../results/ids_local_all.csv.gz"), colClasses = "character")
ids$year <- as.integer(ids$year)
dropped <- function(f, col, values) {
  d <- read.csv(f, colClasses = "character")
  if ("method" %in% names(d)) {
    d <- d[order(d$method == "adjudication"), ]
    d <- d[!duplicated(d$item_id, fromLast = TRUE), ]
    return(d$item_id[d$value %in% values])
  }
  d$id[d[[col]] %in% values]
}
out <- c("not_own_fit", "outside_field")
exclude <- unique(c(
  dropped("../no_tool_decisions.csv", "decision", out),
  dropped("../../../classifications/lit_relevance/corpus_decisions.csv", "value", out)
))
exclude <- setdiff(exclude, ids$id[ids$software %in% estimation])
shares <- function(d, label) cbind(set = label, literatureShares(d, estimation, exclude = intersect(exclude, d$id)))
s <- rbind(shares(ids[ids$admitted == "core", ], "core"), shares(ids, "core and extension"))
w <- reshape(s[c("set", "source", "year", "software", "n", "base_n", "share")], idvar = c("source", "year", "software"),
  timevar = "set", direction = "wide")
names(w) <- sub("\\.core and extension$", "_with_extension", sub("\\.core$", "_core", names(w)))
w$difference <- w$share_with_extension - w$share_core
w <- w[order(w$source, w$software, w$year), ]
write.csv(w, "results/extension_shares.csv", row.names = FALSE)
big <- w[w$software %in% c("NONMEM", "Monolix", "Phoenix NLME", "nlmixr"), ]
print(big[c("source", "year", "software", "n_core", "n_with_extension", "share_core", "share_with_extension")],
  row.names = FALSE, digits = 3)
cat("largest absolute difference in share:", round(max(abs(w$difference), na.rm = TRUE), 3), "\n")
