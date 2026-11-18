# The measures: recall of the base query, the base set's relevant share, a capture-recapture
# estimate, and the yield of each candidate term
#
# Relevant = `own_fit` in the relevance reading (classifications/lit_relevance); `unclear`
# papers are left out of the shares. Without the reading (no decisions.csv yet), only the
# measures from the queries are written.
#
# Writes results/recall.csv, results/base_relevance.csv, results/capture_recapture.csv and
# results/term_yield.csv.

source("common.R")
pkgload::load_all("../../../pmxlandscape", quiet = TRUE)

ref <- read.csv(gzfile("results/reference_ids.csv.gz"), colClasses = c(year = "integer", in_base = "logical"))
q <- read.csv("results/term_queries.csv")
sample <- read.csv("results/sample.csv", colClasses = "character")
decFile <- "../../../classifications/lit_relevance/decisions.csv"
dec <- if (file.exists(decFile)) read.csv(decFile, colClasses = "character") else NULL
if (!is.null(dec)) {
  # the latest decision per paper (an adjudication replaces the reading)
  dec <- dec[order(dec$method == "adjudication"), ]
  dec <- dec[!duplicated(paste(dec$source, dec$item_id), fromLast = TRUE), ]
  sample$value <- dec$value[match(paste(sample$source, sample$id), paste(dec$source, dec$item_id))]
}
read <- function(d) {
  v <- d$value[!is.na(d$value) & d$value != "unclear"]
  c(x = sum(v == "own_fit"), s = length(v), unclear = sum(d$value %in% "unclear"), unread = sum(is.na(d$value)))
}

# ---- recall on the reference sets ----
recall <- do.call(rbind, lapply(split(ref, list(ref$set, ref$source), drop = TRUE), function(d) {
  nIn <- sum(d$in_base)
  nOut <- sum(!d$in_base)
  row <- data.frame(set = d$set[1], source = d$source[1], papers = nrow(d), in_base = nIn, share_in_base = nIn / nrow(d))
  if (is.null(dec)) {
    return(row)
  }
  s <- sample[sample$set == d$set[1] & sample$source == d$source[1], ]
  a <- read(s[s$stratum == "in base", ])
  b <- read(s[s$stratum == "not in base", ])
  r <- stratifiedRecall(nIn, a[["x"]], a[["s"]], nOut, b[["x"]], b[["s"]])
  cbind(row,
    read_in_base = a[["s"]], relevant_in_base = a[["x"]], read_not_in_base = b[["s"]], relevant_not_in_base = b[["x"]],
    unclear = a[["unclear"]] + b[["unclear"]], r
  )
}))
write.csv(recall, "results/recall.csv", row.names = FALSE)
print(recall, row.names = FALSE)

# ---- terms ----
tot <- aggregate(cbind(count, increment, increment_naming_tool) ~ term + source, q, sum)
tot$naming_rate <- tot$increment_naming_tool / tot$increment
if (!is.null(dec)) {
  y <- do.call(rbind, lapply(seq_len(nrow(tot)), function(i) {
    s <- sample[sample$set == paste("term:", tot$term[i]) & sample$source == tot$source[i], ]
    a <- read(s)
    w <- wilson(a[["x"]], a[["s"]])
    data.frame(read = a[["s"]], relevant = a[["x"]], unclear = a[["unclear"]], relevant_share = w$share,
      relevant_lower = w$lower, relevant_upper = w$upper,
      relevant_per_year = tot$increment[i] * w$share / length(years))
  }))
  tot <- cbind(tot, y)
  tot$proposed <- tot$relevant_per_year >= 20 & tot$relevant_share >= 0.5
}
tot <- tot[order(tot$source, -tot$increment), ]
write.csv(tot, "results/term_yield.csv", row.names = FALSE)
print(tot, row.names = FALSE, digits = 2)

if (!is.null(dec)) {
  # ---- the base set's relevant share (R0) ----
  base <- do.call(rbind, lapply(c("PubMed", "Europe PMC"), function(src) {
    a <- read(sample[sample$set == "R0 base set" & sample$source == src, ])
    n <- sum(sample$population[sample$set == "R0 base set" & sample$source == src][1] |> as.integer())
    cbind(data.frame(source = src, base_papers = n, read = a[["s"]], relevant = a[["x"]], unclear = a[["unclear"]]),
      wilson(a[["x"]], a[["s"]]))
  }))
  write.csv(base, "results/base_relevance.csv", row.names = FALSE)
  print(base, row.names = FALSE)

  # ---- capture-recapture: keyword search (base set) against tool-anchored search (R2) ----
  cr <- do.call(rbind, lapply(c("PubMed", "Europe PMC"), function(src) {
    r2 <- recall[recall$set == "R2 tool-anchored" & recall$source == src, ]
    b <- base[base$source == src, ]
    n1 <- b$base_papers * b$share
    m <- r2$in_base * r2$relevant_in_base / r2$read_in_base
    n2 <- r2$relevant
    cbind(data.frame(source = src, keyword_relevant = n1, tool_relevant = n2, both = m), chapman(n1, n2, m),
      keyword_share_of_estimate = n1 / chapman(n1, n2, m)$estimate)
  }))
  write.csv(cr, "results/capture_recapture.csv", row.names = FALSE)
  print(cr, row.names = FALSE)
}
