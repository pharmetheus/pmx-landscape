# Cross-check FDA sponsor software against the sponsor's own publications
#
# Run from sources/fda/crosscheck/: Rscript crosscheck_literature.R
#
# For each drug in the FDA results, finds papers in Europe PMC with one of the
# drug's names in the title (brand name, active ingredient, development codes
# from PubChem) together with popPK wording, and records for each paper whether
# an author is affiliated with the sponsor (openFDA sponsor name) and which
# estimation tools it names: in the methods of open-access full text (JATS XML,
# reference list excluded), else in the body, else in the abstract. The
# software a sponsor's own popPK paper names is a likely, not a verified,
# indication of the software in the submission, so the results are a separate
# evidence tier and never change results/fda_2021_2025_popPK_software.csv.
# Drugs whose tool FDA states are the validation set for the method.
#
# Writes results/ (IDs, flags and tools only; no paper text) and caches the API
# responses and full texts in cache/, which is not committed.

pkgload::load_all("../../../pmxlandscape", quiet = TRUE)
library(httr)

fda_dir <- "../"
cache <- "cache"
out_dir <- "results"
for (d in file.path(cache, c("openfda", "pubchem", "epmc", "fulltext"))) dir.create(d, recursive = TRUE, showWarnings = FALSE)
dir.create(out_dir, showWarnings = FALSE)
run_date <- format(Sys.Date())
ua <- user_agent("PMx Landscape cross-check (contact: niclas.jonsson@pharmetheus.com)")
patterns <- readPatterns("../../../taxonomy/patterns.json")
overrides_file <- "sponsor_overrides.csv"
overrides <- if (file.exists(overrides_file)) {
  o <- read.csv(overrides_file, colClasses = "character")
  stats::setNames(o$short_name, o$sponsor_name)
} else {
  character(0)
}

cached_get <- function(url, file, query = NULL, delay = 0.3, ok404 = FALSE) {
  if (!file.exists(file)) {
    for (attempt in 1:6) { # retry when a service is busy (503) or rate-limits (429)
      Sys.sleep(delay * 2^(attempt - 1))
      r <- GET(url, ua, query = query, timeout(60))
      if (!status_code(r) %in% c(429, 503)) break
    }
    if (ok404 && status_code(r) == 404) {
      writeLines("", file)
      return(file)
    }
    if (status_code(r) != 200) stop("HTTP ", status_code(r), " for ", url)
    writeBin(content(r, as = "raw"), file)
  }
  file
}

# ---- Drugs, sponsors and names ------------------------------------------------

results <- fdaReadResults(fda_dir)
frames <- do.call(rbind, lapply(fdaSurveyedYears(fda_dir), function(y) {
  f <- jsonlite::fromJSON(file.path(fda_dir, "data", y, "frame.json"))
  data.frame(year = as.character(y), application = as.character(f$appl), ingredient = f$ingr)
}))
drugs <- merge(results[c("year", "drug", "application", "category", "sponsor_tool_family", "evidence_strength")],
  frames,
  by = c("year", "application"), all.x = TRUE
)
if (any(is.na(drugs$ingredient))) stop("No ingredient for ", paste(drugs$drug[is.na(drugs$ingredient)], collapse = ", "))

drugs$sponsor <- vapply(drugs$application, function(a) {
  f <- cached_get(
    "https://api.fda.gov/drug/drugsfda.json", file.path(cache, "openfda", paste0(a, ".json")),
    query = list(search = sprintf('application_number:"NDA%s" OR application_number:"BLA%s"', a, a)), ok404 = TRUE
  )
  txt <- paste(readLines(f, warn = FALSE), collapse = "")
  if (!nzchar(txt)) {
    return(NA_character_)
  }
  j <- jsonlite::fromJSON(txt)
  if (length(j$results) == 0) NA_character_ else j$results$sponsor_name[1]
}, character(1))
drugs$sponsor[is.na(drugs$sponsor)] <- paste("application", drugs$application[is.na(drugs$sponsor)]) # see sponsor_overrides.csv
drugs$sponsor_short <- sponsorToken(drugs$sponsor, overrides)

drugs$codes <- vapply(seq_len(nrow(drugs)), function(i) {
  parts <- drugSearchNames(drugs$drug[i], drugs$ingredient[i])[-1]
  codes <- unlist(lapply(parts, function(p) {
    f <- cached_get(
      paste0("https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/name/", utils::URLencode(p, reserved = TRUE), "/synonyms/JSON"),
      file.path(cache, "pubchem", paste0(gsub("[^A-Za-z0-9]", "_", p), ".json")),
      delay = 0.25, ok404 = TRUE
    )
    txt <- paste(readLines(f, warn = FALSE), collapse = "")
    if (!nzchar(txt)) {
      return(character(0))
    }
    codeNames(unlist(jsonlite::fromJSON(txt)$InformationList$Information$Synonym))
  }))
  paste(utils::head(unique(codes), 6), collapse = "; ")
}, character(1))
drugs$names <- vapply(seq_len(nrow(drugs)), function(i) {
  paste(drugSearchNames(drugs$drug[i], drugs$ingredient[i], strsplit(drugs$codes[i], "; ")[[1]]), collapse = "; ")
}, character(1))

# ---- Papers ---------------------------------------------------------------------

# popPK wording in the title or the abstract; the drug's name must be in the title
poppk_terms <- c(
  '"population pharmacokinetic"', '"population pharmacokinetics"', '"population PK"', "popPK", "pharmacometric*",
  '"exposure-response"', '"exposure response"', '"model-informed"', '"model-based"'
)
poppk_title <- paste(c(paste0("TITLE:", poppk_terms), paste0("ABSTRACT:", poppk_terms)), collapse = " OR ")
epmc_papers <- function(i) {
  names <- strsplit(drugs$names[i], "; ")[[1]]
  variants <- unique(c(names, gsub("[- ]", "", names[grepl("\\d", names)])))
  q <- sprintf("TITLE:(%s) AND (%s)", paste0('"', variants, '"', collapse = " OR "), poppk_title)
  f <- cached_get("https://www.ebi.ac.uk/europepmc/webservices/rest/search",
    file.path(cache, "epmc", paste0(drugs$year[i], "_", drugs$application[i], "_ta.json")),
    query = list(query = q, resultType = "core", format = "json", pageSize = 100), delay = 0.2
  )
  r <- jsonlite::fromJSON(f, simplifyVector = FALSE)$resultList$result
  if (length(r) == 0) {
    return(NULL)
  }
  do.call(rbind, lapply(r, function(p) {
    affs <- unlist(lapply(p$authorList$author, function(a) {
      c(a$affiliation, unlist(lapply(a$authorAffiliationDetailsList$authorAffiliation, `[[`, "affiliation")))
    }))
    data.frame(
      year = drugs$year[i], application = drugs$application[i], id = paste0(p$source, ":", p$id),
      pmid = if (is.null(p$pmid)) NA_character_ else p$pmid, pmcid = if (is.null(p$pmcid)) NA_character_ else p$pmcid,
      pub_year = as.integer(p$pubYear), open_access = identical(p$isOpenAccess, "Y"),
      affiliations = paste(unique(affs), collapse = " | "),
      abstract = if (is.null(p$abstractText)) "" else p$abstractText, stringsAsFactors = FALSE
    )
  }))
}
papers <- do.call(rbind, lapply(seq_len(nrow(drugs)), epmc_papers))
sponsor_of <- stats::setNames(drugs$sponsor_short, paste(drugs$year, drugs$application))
papers$sponsor_author <- mapply(function(key, aff) {
  s <- sponsor_of[[key]]
  if (is.na(s)) {
    return(FALSE)
  }
  # Alternatives separated by "|" (from sponsor_overrides.csv); a hyphen also matches a space
  alts <- strsplit(s, "|", fixed = TRUE)[[1]]
  alts <- stringi::stri_replace_all_regex(alts, "-", "[- ]")
  stringi::stri_detect_regex(aff, paste0("\\b(?:", paste(alts, collapse = "|"), ")\\b"), case_insensitive = TRUE)
}, paste(papers$year, papers$application), papers$affiliations)

# ---- Software named in each paper ----------------------------------------------------

tools_in <- function(text) paste(findSoftware(text, patterns, groups = "estimation")[[1]], collapse = "; ")
papers$tools <- ""
papers$tools_from <- "none"
for (k in seq_len(nrow(papers))) {
  if (papers$open_access[k] && !is.na(papers$pmcid[k])) {
    f <- file.path(cache, "fulltext", paste0(papers$pmcid[k], ".xml"))
    ok <- tryCatch(
      {
        cached_get(paste0("https://www.ebi.ac.uk/europepmc/webservices/rest/", papers$pmcid[k], "/fullTextXML"), f, delay = 0.2)
        TRUE
      },
      error = function(e) FALSE
    )
    if (ok) {
      s <- jatsSections(xml2::read_xml(f))
      if (nzchar(t <- tools_in(s$methods))) {
        papers$tools[k] <- t
        papers$tools_from[k] <- "methods"
        next
      }
      if (nzchar(t <- tools_in(s$body))) {
        papers$tools[k] <- t
        papers$tools_from[k] <- "body"
        next
      }
    }
  }
  if (nzchar(t <- tools_in(papers$abstract[k]))) {
    papers$tools[k] <- t
    papers$tools_from[k] <- "abstract"
  }
}

# ---- Per drug ---------------------------------------------------------------------------

infer <- function(p) {
  fams <- unique(unlist(strsplit(p$tools[p$tools != ""], "; ")))
  if (length(fams) == 0) "" else paste(sort(fams), collapse = "; ")
}
per_drug <- do.call(rbind, lapply(seq_len(nrow(drugs)), function(i) {
  p <- papers[papers$year == drugs$year[i] & papers$application == drugs$application[i], , drop = FALSE]
  sp <- p[p$sponsor_author, , drop = FALSE]
  y <- as.integer(drugs$year[i])
  near <- sp[sp$pub_year >= y - 4 & sp$pub_year <= y + 2, , drop = FALSE] # "near the submission": approval -4 to +2
  data.frame(
    n_papers = nrow(p), n_sponsor_papers = nrow(sp), n_sponsor_with_tool = sum(sp$tools != ""),
    tools_sponsor = infer(sp), tools_sponsor_near = infer(near),
    tools_sponsor_other_years = infer(sp[!sp$id %in% near$id, , drop = FALSE]),
    tools_other = infer(p[!p$sponsor_author, , drop = FALSE]),
    ids = paste(sp$id[sp$tools != ""], collapse = "; ")
  )
}))
drugs <- cbind(drugs, per_drug)
single <- function(x) x != "" & !grepl(";", x)
drugs$evidence <- ifelse(single(drugs$tools_sponsor_near), "sponsor paper near submission",
  ifelse(drugs$tools_sponsor_near == "" & single(drugs$tools_sponsor_other_years), "sponsor paper, other years",
    ifelse(drugs$tools_sponsor != "", "sponsor papers name several tools",
      ifelse(drugs$tools_other != "", "other authors only", "none")
    )
  )
)
drugs$inferred <- ifelse(drugs$evidence == "sponsor paper near submission", drugs$tools_sponsor_near,
  ifelse(drugs$evidence == "sponsor paper, other years", drugs$tools_sponsor_other_years, "")
)

# ---- Output ---------------------------------------------------------------------------

keep_drugs <- c(
  "year", "drug", "application", "category", "sponsor_tool_family", "evidence_strength", "ingredient", "sponsor",
  "sponsor_short", "codes", "names", "n_papers", "n_sponsor_papers", "n_sponsor_with_tool", "tools_sponsor",
  "tools_sponsor_near", "tools_sponsor_other_years", "tools_other", "inferred", "evidence", "ids"
)
write.csv(drugs[order(drugs$year, drugs$drug), keep_drugs], file.path(out_dir, "crosscheck_drugs.csv"), row.names = FALSE)
write.csv(papers[c("year", "application", "id", "pmid", "pmcid", "pub_year", "open_access", "sponsor_author", "tools", "tools_from")],
  file.path(out_dir, "crosscheck_papers.csv"),
  row.names = FALSE
)

known <- drugs[startsWith(drugs$category, "Tool stated") & drugs$inferred != "", ]
tier_check <- vapply(c("sponsor paper near submission", "sponsor paper, other years"), function(t) {
  k <- known[known$evidence == t, ]
  sprintf("%s: %d of %d agree", t, sum(k$inferred == k$sponsor_tool_family), nrow(k))
}, character(1))
unknown <- drugs[drugs$category == "popPK present, software not stated", ]
info <- c(
  paste("run_date:", run_date),
  paste("drugs:", nrow(drugs), " papers found:", nrow(papers), " with a sponsor author:", sum(papers$sponsor_author)),
  paste("drugs missing from openFDA (sponsor from sponsor_overrides.csv):", sum(startsWith(drugs$sponsor, "application "))),
  paste(
    "validation (FDA tool stated, single tool in sponsor papers):", nrow(known), "drugs,",
    sum(known$inferred == known$sponsor_tool_family), "agree with FDA"
  ),
  paste("  by evidence tier:", paste(tier_check, collapse = "; ")),
  paste("not stated in FDA review:", nrow(unknown), "drugs; evidence:",
    paste(names(table(unknown$evidence)), table(unknown$evidence), sep = ": ", collapse = ", ")),
  paste("inferred for not-stated drugs:", paste(names(table(unknown$inferred[unknown$inferred != ""])),
    table(unknown$inferred[unknown$inferred != ""]), sep = ": ", collapse = ", "))
)
writeLines(info, file.path(out_dir, "run_info.txt"))
cat(info, sep = "\n")
