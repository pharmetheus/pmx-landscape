# Publication trends for pharmacometric software, 2021-2026
#
# Run from sources/literature/: Rscript publication_trends.R
#
# The run of 2026-09-28 (2021 to 2026) is frozen. Earlier years are added to files of their
# own, without touching the frozen ones: LIT_YEARS=2016-2020 Rscript publication_trends.R
# writes results/*_2016_2020.*; a paper already in the frozen base set (a PubMed paper dated
# both 2020 and 2021 stays in 2021) is left out of the new years and counted in run_info.
#
# Counts papers mentioning each software within a base set of pop-PK /
# pharmacometric papers, per publication year, and computes each tool's share.
# Every query's matching IDs are stored with the counts, so the numbers can be
# re-derived and the same papers revisited (for example for affiliations),
# although PubMed and Europe PMC keep indexing and a re-run drifts.
#
# Sources:
#   PubMed     - title/abstract only (consistent over time, underestimates use).
#                [dp] matches both the electronic and the print publication
#                date, so a paper can match two years; each PMID is kept only
#                in the earliest year it matches (its first publication).
#   Europe PMC - base terms in the title, abstract or keywords; tools in the
#                full text of articles with full text available (HAS_FT:Y),
#                preprints excluded (NOT SRC:PPR, from September 2026). The
#                search covers the article text but not its reference list
#                (checked September 2026: of 419 open-access papers citing the
#                PsN paper, titled "Perl-speaks-NONMEM", 256 match that
#                phrase). A tool named anywhere in the text counts, including
#                the introduction. Section searches (METHODS:, TITLE:,
#                ABSTRACT:, KW:) restrict a term to one part of the paper.
#
# Tool names are the families in taxonomy/software.csv, and the queries follow
# its variants (September 2026: Monolix* for MonolixSuite and versioned names,
# Phoenix NLME by proximity, the Stan interfaces, S-ADAPT, Pmetrics, NLMIXED and
# MATLAB's NLME functions). A bare "Stan" is not searched: both services ignore
# case, and it is also a first name.
#
# Writes to results/:
#   counts.csv     one row per source, year and query: the query string, the
#                  hit count reported by the service, the number of IDs kept
#                  (after the PubMed one-year rule)
#   shares.csv     share of the base set per tool, source and year
#   ids.csv.gz     the IDs behind every count (PMIDs; Europe PMC source:id)
#   run_info.txt   run date and checks

library(rentrez)
library(europepmc)

span <- Sys.getenv("LIT_YEARS", "2021-2026")
years <- seq(as.integer(sub("-.*", "", span)), as.integer(sub(".*-", "", span))) # 2026 is partial: flag it
suffix <- if (span == "2021-2026") "" else paste0("_", sub("-", "_", span))
out_dir <- "results"
dir.create(out_dir, showWarnings = FALSE)
run_date <- format(Sys.Date())

# ---- Search terms ----------------------------------------------------------

pm_base <- paste0(
  '("population pharmacokinetic*"[tiab] OR pharmacometric*[tiab] OR ',
  '"nonlinear mixed effects"[tiab] OR "non-linear mixed effects"[tiab])'
)
pm_tools <- c(
  "NONMEM"       = '("NONMEM"[tiab] OR "NON-MEM"[tiab] OR NONMEN[tiab] OR NONMEMS[tiab] OR NONMENE[tiab])', # misprints as in the taxonomy
  "Monolix"      = "Monolix*[tiab]", # MonolixSuite, Monolix2024R1
  "Phoenix NLME" = '"Phoenix NLME"[tiab:~5]', # Phoenix followed by NLME within a few words
  "nlmixr"       = 'nlmixr*[tiab]',
  "Pumas"        = '"Pumas"[tiab]',
  "Stan/Torsten" = "(Torsten[tiab] OR RStan[tiab] OR CmdStan[tiab] OR CmdStanR[tiab] OR PyStan[tiab])",
  "saemix"       = '"saemix"[tiab]',
  "FERX"         = '"Ferx"[tiab]',
  "S-ADAPT"      = '("S-ADAPT"[tiab] OR "ADAPT 5"[tiab] OR "ADAPT II"[tiab] OR "ADAPT V"[tiab])',
  "Pmetrics"     = "Pmetrics[tiab]",
  "NLMIXED"      = "NLMIXED[tiab]",
  "MATLAB NLME"  = "(nlmefit[tiab] OR nlmefitsa[tiab] OR sbiofitmixed[tiab])",
  "BUGS"         = '(WinBUGS[tiab] OR OpenBUGS[tiab] OR MultiBUGS[tiab] OR PKBugs[tiab] OR JAGS[tiab])',
  "OpenPMX"      = '"OpenPMX"[tiab]',
  "PhysPK"       = '"PhysPK"[tiab]',
  "PoPy"         = '"PoPy"[tiab]',
  "SAAM II"      = '("SAAM II"[tiab] OR SAAM2[tiab] OR SAAM[tiab])',
  "USC*PACK"     = '("USC PACK"[tiab] OR USCPACK[tiab] OR "MM-USCPACK"[tiab] OR BigWinPops[tiab])',
  "InsightRX"    = '"InsightRX"[tiab]'
)

# The base terms must be in the title, abstract or keywords (from September 2026):
# anywhere in the full text they also caught papers that mention population PK only
# in passing. The tools are still searched in the full text.
ep_terms <- c(
  '"population pharmacokinetic"', '"population pharmacokinetics"', "pharmacometric*",
  '"nonlinear mixed effects"', '"non-linear mixed effects"'
)
ep_base <- paste0(
  "(", paste(outer(c("TITLE", "ABSTRACT", "KW"), ep_terms, paste, sep = ":"), collapse = " OR "), ") ",
  "AND HAS_FT:Y AND NOT SRC:PPR"
)
ep_tools <- c(
  "NONMEM"       = '("NONMEM" OR "NON-MEM" OR NONMEN OR NONMEMS OR NONMENE)',
  "Monolix"      = "Monolix*",
  "Phoenix NLME" = '"Phoenix NLME"~5',
  "nlmixr"       = "(nlmixr OR nlmixr2)",
  "Pumas"        = '"Pumas"',
  "Stan/Torsten" = "(Torsten OR RStan OR CmdStan OR CmdStanR OR PyStan)",
  "saemix"       = '"saemix"',
  "FERX"         = '"Ferx"',
  "S-ADAPT"      = '("S-ADAPT" OR "ADAPT 5" OR "ADAPT II" OR "ADAPT V")',
  "Pmetrics"     = "Pmetrics",
  "NLMIXED"      = "NLMIXED",
  "MATLAB NLME"  = "(nlmefit OR nlmefitsa OR sbiofitmixed)",
  "BUGS"         = "(WinBUGS OR OpenBUGS OR MultiBUGS OR PKBugs OR JAGS)",
  "OpenPMX"      = '"OpenPMX"',
  "PhysPK"       = '"PhysPK"',
  "PoPy"         = '"PoPy"',
  "SAAM II"      = '("SAAM II" OR SAAM2 OR SAAM)',
  "USC*PACK"     = '("USC PACK" OR USCPACK OR "MM-USCPACK" OR BigWinPops)',
  "InsightRX"    = '"InsightRX"'
)

# ---- Retrieval ----------------------------------------------------------------

# PubMed returns at most 9,999 IDs per search, so larger sets are split by month.
pm_ids <- function(q, year) {
  Sys.sleep(0.4) # stay under PubMed's 3 requests/second without an API key
  n <- as.numeric(entrez_search(db = "pubmed", term = q, retmax = 0)$count)
  if (n == 0) {
    return(list(count = 0, ids = character(0)))
  }
  if (n <= 9999) {
    Sys.sleep(0.4)
    return(list(count = n, ids = entrez_search(db = "pubmed", term = q, retmax = 9999)$ids))
  }
  ids <- unlist(lapply(1:12, function(m) {
    last <- format(seq(as.Date(sprintf("%d-%02d-01", year, m)), by = "month", length.out = 2)[2] - 1, "%Y/%m/%d")
    qm <- sprintf('%s AND ("%d/%02d/01"[dp] : "%s"[dp])', sub(sprintf(" AND %d\\[dp\\]", year), "", q), year, m, last)
    Sys.sleep(0.4)
    r <- entrez_search(db = "pubmed", term = qm, retmax = 9999)
    if (as.numeric(r$count) > 9999) stop("More than 9,999 PubMed records in one month for: ", qm)
    r$ids
  }))
  list(count = n, ids = unique(ids))
}

# Europe PMC answers bursts with HTTP 503 now and then; europepmc retries only briefly
with_retry <- function(f, tries = 10) {
  for (k in seq_len(tries)) {
    r <- tryCatch(f(), error = function(e) e)
    if (!inherits(r, "error")) {
      return(r)
    }
    if (k == tries || !grepl("503|502|500|429|Timeout|timed out", conditionMessage(r))) stop(r)
    message("Europe PMC error (", conditionMessage(r), "); retrying in ", 15 * k, " s")
    Sys.sleep(15 * k)
  }
}

ep_ids <- function(q, year) {
  Sys.sleep(0.2)
  n <- as.numeric(with_retry(function() epmc_hits(q)))
  if (n == 0) {
    return(list(count = 0, ids = character(0)))
  }
  # synonym = FALSE: epmc_search() otherwise expands the query with synonyms and
  # returns more records than epmc_hits() counts (europepmc 0.4.1)
  r <- with_retry(function() epmc_search(q, output = "id_list", limit = n + 100, synonym = FALSE, verbose = FALSE))
  list(count = n, ids = unique(paste0(r$source, ":", r$id)))
}

run_source <- function(base, tools, year_filter, retrieve, source) {
  grid <- expand.grid(software = c("All (base set)", names(tools)), year = years, stringsAsFactors = FALSE)
  grid$query <- mapply(function(y, s) {
    q <- paste0(base, " AND ", year_filter(y))
    if (s != "All (base set)") q <- paste0(q, " AND ", tools[[s]])
    q
  }, grid$year, grid$software)
  # each query's result is cached for the run date, so a run stopped by a service error resumes
  query_dir <- file.path("cache", "queries", run_date)
  dir.create(query_dir, recursive = TRUE, showWarnings = FALSE)
  got <- mapply(function(q, y) {
    f <- file.path(query_dir, paste0(digest::digest(q), ".rds"))
    if (file.exists(f)) {
      return(readRDS(f))
    }
    r <- retrieve(q, y)
    saveRDS(r, f)
    r
  }, grid$query, grid$year, SIMPLIFY = FALSE)
  grid$count <- vapply(got, `[[`, numeric(1), "count")
  grid$n_ids <- vapply(got, function(g) length(g$ids), integer(1))
  grid$source <- source
  ids <- do.call(rbind, lapply(seq_along(got), function(i) {
    if (length(got[[i]]$ids) == 0) {
      return(NULL)
    }
    data.frame(source = source, year = grid$year[i], software = grid$software[i], id = got[[i]]$ids)
  }))
  list(counts = grid[c("source", "year", "software", "query", "count", "n_ids")], ids = ids)
}

pm <- run_source(pm_base, pm_tools, function(y) paste0(y, "[dp]"), pm_ids, "PubMed (title/abstract)")
ep <- run_source(ep_base, ep_tools, function(y) paste0("PUB_YEAR:", y), ep_ids, "Europe PMC (full text)")

counts <- rbind(pm$counts, ep$counts)
counts$run_date <- run_date
ids <- rbind(pm$ids, ep$ids)
raw_mismatch <- counts[counts$count != counts$n_ids, ]

# PubMed: keep each PMID in the earliest year of its base-set matches only
is_pm <- ids$source == "PubMed (title/abstract)"
first_year <- tapply(ids$year[is_pm & ids$software == "All (base set)"], ids$id[is_pm & ids$software == "All (base set)"], min)
later <- is_pm & ids$year > first_year[ids$id]
later[is.na(later)] <- FALSE
n_moved <- length(unique(ids$id[later & ids$software == "All (base set)"]))
ids <- ids[!later, ]
# Earlier years: papers already in the frozen base set stay where they are
n_frozen <- 0
if (nzchar(suffix)) {
  frozen <- read.csv(gzfile(file.path(out_dir, "ids.csv.gz")), colClasses = "character")
  frozen <- frozen[frozen$software == "All (base set)", ]
  dup <- paste(ids$source, ids$id) %in% paste(frozen$source, frozen$id)
  n_frozen <- length(unique(ids$id[dup & ids$software == "All (base set)"]))
  ids <- ids[!dup, ]
}
counts$n_ids <- mapply(function(src, y, sw) sum(ids$source == src & ids$year == y & ids$software == sw),
  counts$source, counts$year, counts$software
)

# A tool's papers must be part of the base set of the same source and year
base_ids <- ids[ids$software == "All (base set)", ]
outside <- ids[ids$software != "All (base set)" &
  !paste(ids$source, ids$year, ids$id) %in% paste(base_ids$source, base_ids$year, base_ids$id), ]

shares <- do.call(rbind, lapply(split(counts, paste(counts$source, counts$year)), function(d) {
  base_n <- d$n_ids[d$software == "All (base set)"]
  d <- d[d$software != "All (base set)", ]
  data.frame(
    source = d$source, year = d$year, software = d$software, n = d$n_ids, base_n = base_n,
    share_pct = 100 * d$n_ids / base_n, partial_year = d$year == 2026
  )
}))
shares <- shares[order(shares$source, shares$software, shares$year), ]

# ---- Output ------------------------------------------------------------------

outFile <- function(name, ext) file.path(out_dir, paste0(name, suffix, ext))
write.csv(counts, outFile("counts", ".csv"), row.names = FALSE)
write.csv(shares, outFile("shares", ".csv"), row.names = FALSE)
gz <- gzfile(outFile("ids", ".csv.gz"), "w")
write.csv(ids, gz, row.names = FALSE)
close(gz)
mismatch <- raw_mismatch
info <- c(
  paste("run_date:", run_date),
  paste("years:", paste(range(years), collapse = " to "), if (2026 %in% years) "(2026 partial)"),
  paste("queries:", nrow(counts)),
  paste("queries whose retrieved IDs differ from the reported count:", nrow(mismatch)),
  paste("PubMed base-set papers matching more than one year, kept only in the earliest:", n_moved),
  if (nzchar(suffix)) paste("base-set papers already in the frozen 2021 to 2026 set, left out:", n_frozen),
  if (nrow(mismatch) > 0) paste0("  ", mismatch$source, " ", mismatch$year, " ", mismatch$software, ": ", mismatch$count, " reported, ", mismatch$n_ids, " stored"),
  paste("tool IDs outside the base set of the same source and year:", nrow(outside))
)
writeLines(info, outFile("run_info", ".txt"))
cat(info, sep = "\n")
if (nrow(mismatch) > 0 || nrow(outside) > 0) stop("Retrieval checks failed; see ", outFile("run_info", ".txt"))
