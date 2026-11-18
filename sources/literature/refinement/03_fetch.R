# Samples for the relevance reading, and their text
#
# The base set (R0, 2021 to 2025): 60 papers per source. Reference sets (01_reference.R): per set, source and stratum (in the base set or not), a
# random sample of 60 papers in the base set and 100 outside it (all when fewer). Candidate
# terms (02_terms.R): per term and source, a random sample of 40 papers of the increment. The
# seed is fixed, so the samples are the same on every run.
#
# Text: PubMed title and abstract from efetch XML; Europe PMC the open-access full text (the
# reading takes the methods, or the body when there is no methods section), or the title and
# abstract of the record when no full text is served. Files already cached for the base set
# (../cache) are reused.
#
# Writes results/sample.csv (set, source, stratum, population, id, year) and the refinement
# corpus corpus/pubmed and corpus/epmc (tables committed, text in corpus/cache, not committed).

source("common.R")
pkgload::load_all("../../../pmxlandscape", quiet = TRUE)
seed <- 20261019

ref <- read.csv(gzfile("results/reference_ids.csv.gz"), colClasses = c(year = "integer", in_base = "logical"))
ref$stratum <- ifelse(ref$in_base, "in base", "not in base")
terms <- read.csv(gzfile("results/term_ids.csv.gz"), colClasses = c(year = "integer", names_tool = "logical"))
terms$set <- paste("term:", terms$term)
terms$stratum <- "increment"
# R0: the base set itself (2021 to 2025), for the share of relevant papers in it
b <- read.csv(gzfile("../results/ids.csv.gz"), colClasses = "character")
b <- b[b$software == "All (base set)" & b$year %in% years, ]
base <- data.frame(set = "R0 base set", source = ifelse(startsWith(b$source, "PubMed"), "PubMed", "Europe PMC"),
  stratum = "in base", id = b$id, year = as.integer(b$year))
pool <- rbind(base, ref[c("set", "source", "stratum", "id", "year")], terms[c("set", "source", "stratum", "id", "year")])

size <- c("in base" = 60, "not in base" = 100, increment = 40)
set.seed(seed)
sample <- do.call(rbind, lapply(split(pool, list(pool$set, pool$source, pool$stratum), drop = TRUE), function(d) {
  d <- d[!duplicated(d$id), ]
  k <- min(nrow(d), size[[d$stratum[1]]])
  cbind(d[sort(sample.int(nrow(d), k)), ], population = nrow(d))
}))
sample <- sample[order(sample$set, sample$source, sample$stratum, sample$id), c("set", "source", "stratum", "population", "id", "year")]
write.csv(sample, "results/sample.csv", row.names = FALSE)
items <- sample[!duplicated(paste(sample$source, sample$id)), c("source", "id", "year")]
cat(nrow(sample), "sampled rows;", nrow(items), "distinct papers\n")
print(table(items$source))

# ---- PubMed ----
pm <- items[items$source == "PubMed", c("id", "year")]
pmDir <- file.path("cache", "pubmed")
dir.create(pmDir, recursive = TRUE, showWarnings = FALSE)
batches <- split(pm$id, ceiling(seq_along(pm$id) / 200))
for (b in batches) {
  f <- file.path(pmDir, sprintf("pubmed_%s-%s_n%d.xml", b[1], b[length(b)], length(b)))
  if (!file.exists(f)) {
    Sys.sleep(0.4)
    writeLines(rentrez::entrez_fetch(db = "pubmed", id = b, rettype = "xml"), f)
  }
}
pmFiles <- list.files(pmDir, pattern = "\\.xml$", full.names = TRUE)
corpusWrite(pubmedCorpus(pmFiles, pm), "corpus", "pubmed")

# ---- Europe PMC ----
ep <- items[items$source == "Europe PMC", c("id", "year")]
recDir <- file.path("cache", "epmc_records")
dir.create(recDir, recursive = TRUE, showWarnings = FALSE)
src <- sub(":.*", "", ep$id)
ext <- sub("^[^:]*:", "", ep$id)
groups <- split(seq_along(ep$id), ceiling(seq_along(ep$id) / 50))
recs <- unlist(lapply(groups, function(g) {
  q <- paste0("(", paste0("(EXT_ID:", ext[g], " AND SRC:", src[g], ")", collapse = " OR "), ")")
  f <- getCached("https://www.ebi.ac.uk/europepmc/webservices/rest/search",
    file.path(recDir, sprintf("rec_%s_%s_n%d.json", ext[g[1]], ext[g[length(g)]], length(g))),
    query = list(query = q, resultType = "core", format = "json", pageSize = 100)
  )
  if (is.na(f$file)) stop("could not fetch Europe PMC records (HTTP ", f$status, ")")
  jsonlite::read_json(f$file)$resultList$result
}), recursive = FALSE)
val <- function(r, k) if (is.null(r[[k]])) "" else as.character(r[[k]])
records <- data.frame(
  id = vapply(recs, function(r) paste0(r$source, ":", r$id), ""),
  pmcid = vapply(recs, val, "", "pmcid"),
  title = vapply(recs, val, "", "title"),
  abstract = stringi::stri_trim_both(gsub("<[^>]+>", " ", vapply(recs, val, "", "abstractText"))),
  keywords = vapply(recs, function(r) paste(unlist(r$keywordList$keyword), collapse = "; "), "")
)
records <- records[!duplicated(records$id) & records$id %in% ep$id, ]
ftDir <- file.path("cache", "fulltext")
dir.create(ftDir, recursive = TRUE, showWarnings = FALSE)
baseFt <- file.path("..", "cache", "fulltext")
status <- vapply(seq_len(nrow(records)), function(i) {
  p <- records$pmcid[i]
  if (!nzchar(p)) {
    return("no PMCID")
  }
  if (file.exists(file.path(baseFt, paste0(p, ".xml"))) || file.exists(file.path(ftDir, paste0(p, ".xml")))) {
    return("cached")
  }
  f <- getCached(sprintf("https://www.ebi.ac.uk/europepmc/webservices/rest/%s/fullTextXML", p),
    file.path(ftDir, paste0(p, ".xml")),
    delay = 0.2
  )
  if (is.na(f$file)) paste("not served: HTTP", f$status) else "fetched"
}, "")
write.csv(data.frame(id = records$id, pmcid = records$pmcid, status = status), "results/fulltext_status.csv", row.names = FALSE)
want <- paste0(records$pmcid[nzchar(records$pmcid)], ".xml")
ftFiles <- c(file.path(ftDir, want), file.path(baseFt, want))
corpusWrite(epmcCorpus(ftFiles[file.exists(ftFiles)], ep, records), "corpus", "epmc")
print(table(status))
