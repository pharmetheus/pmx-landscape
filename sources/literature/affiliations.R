# First-author affiliation types for the PubMed series
#
# Run from sources/literature/ after publication_trends.R:
#   Rscript affiliations.R
#
# Fetches the PubMed records of the stored base-set PMIDs (results/ids.csv.gz)
# in batches of 200, takes the first author's first listed affiliation,
# classifies it with taxonomy/affiliation_rules.csv (regulator, CRO, vendor,
# industry, academia, otherwise unclassified) and tabulates each tool's share
# by affiliation type. The XML is cached in cache/ and a sample for reading is
# written to review/; neither is committed. Europe PMC is not covered yet.
#
# LIT_YEARS=2016-2020 does the same for the earlier years' base set (results/ids_2016_2020.csv.gz),
# writing files with that suffix.
#
# Writes to results/:
#   pubmed_affiliations.csv   pmid, year and affiliation type (no affiliation text)
#   shares_by_affiliation.csv share of each type's base-set papers per tool and year

pkgload::load_all("../../pmxlandscape", quiet = TRUE)
library(rentrez)

rules <- readAffiliationRules("../../taxonomy/affiliation_rules.csv")
span <- Sys.getenv("LIT_YEARS")
suffix <- if (nzchar(span)) paste0("_", sub("-", "_", span)) else ""
outFile <- function(name) file.path("results", paste0(name, suffix, ".csv"))
ids <- read.csv(gzfile(paste0("results/ids", suffix, ".csv.gz")), colClasses = "character")
pm <- ids[ids$source == "PubMed (title/abstract)", ]
base <- unique(pm[pm$software == "All (base set)", c("year", "id")])
dir.create("cache", showWarnings = FALSE)
dir.create("review", showWarnings = FALSE)

batches <- split(sort(unique(base$id)), ceiling(seq_along(unique(base$id)) / 200))
affiliations <- do.call(rbind, lapply(seq_along(batches), function(b) {
  ids_b <- batches[[b]] # the file name changes if the batch does
  f <- file.path("cache", sprintf("pubmed_%s-%s_n%d.xml", ids_b[1], ids_b[length(ids_b)], length(ids_b)))
  if (!file.exists(f)) {
    Sys.sleep(0.4)
    xml <- entrez_fetch(db = "pubmed", id = batches[[b]], rettype = "xml", parsed = FALSE)
    writeLines(xml, f, useBytes = TRUE)
  }
  doc <- xml2::read_xml(f)
  a <- pubmedFirstAffiliation(doc)
  # book documents (reports on the NCBI Bookshelf) have no author affiliations in this form
  book <- intersect(batches[[b]], xml2::xml_text(xml2::xml_find_all(doc, "//PubmedBookArticle/BookDocument/PMID")))
  a <- rbind(a, data.frame(pmid = book, affiliation = rep(NA_character_, length(book))))
  missing <- setdiff(batches[[b]], a$pmid)
  if (length(missing) > 0) stop("Batch ", b, " lacks records for PMIDs ", paste(missing, collapse = ", "))
  a[a$pmid %in% batches[[b]], ]
}))
affiliations$affiliation_type <- classifyAffiliation(affiliations$affiliation, rules)
affiliations$affiliation_type[is.na(affiliations$affiliation_type)] <- "no affiliation"
out <- merge(base, affiliations, by.x = "id", by.y = "pmid")
names(out)[names(out) == "id"] <- "pmid"
out <- out[order(out$year, out$pmid), ]
write.csv(out[c("pmid", "year", "affiliation_type")], outFile("pubmed_affiliations"), row.names = FALSE)

# A sample per type to read, with the affiliation text (not committed)
set.seed(3)
sample_rows <- do.call(rbind, lapply(split(out, out$affiliation_type), function(d) d[sample(nrow(d), min(30, nrow(d))), ]))
write.csv(sample_rows[c("pmid", "year", "affiliation_type", "affiliation")], paste0("review/affiliation_sample", suffix, ".csv"), row.names = FALSE)

# Shares by affiliation type: tool papers of a type among base-set papers of that type
tools <- pm[pm$software != "All (base set)", c("year", "software", "id")]
tools$affiliation_type <- out$affiliation_type[match(paste(tools$year, tools$id), paste(out$year, out$pmid))]
base_n <- as.data.frame(table(year = out$year, affiliation_type = out$affiliation_type), stringsAsFactors = FALSE)
names(base_n)[3] <- "base_n"
n <- as.data.frame(table(year = tools$year, software = tools$software, affiliation_type = tools$affiliation_type),
  stringsAsFactors = FALSE
)
names(n)[4] <- "n"
shares <- merge(n, base_n, by = c("year", "affiliation_type"))
shares$share_pct <- 100 * shares$n / shares$base_n
shares$partial_year <- shares$year == "2026"
shares <- shares[order(shares$software, shares$affiliation_type, shares$year), ]
write.csv(shares, outFile("shares_by_affiliation"), row.names = FALSE)

cat("PubMed base-set papers:", nrow(out), " by affiliation type:\n")
print(table(out$affiliation_type))
