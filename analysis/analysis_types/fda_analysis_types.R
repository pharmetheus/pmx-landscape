# Analysis types for the FDA sponsor tools
#
# Run from analysis/analysis_types/: Rscript fda_analysis_types.R
#
# For each drug whose FDA review names the sponsor's estimation tool (stated
# or indirect), takes the text within `window` characters of every mention of
# that tool family in the cached review text (OCR pages included) and
# classifies each window with taxonomy/analysis_types.csv. The drug's types
# are the union over its windows ("PK only" only if no window has a higher
# type). Mentions can also sit in the FDA reviewer's own
# analyses, which describe the same submission. Writes IDs and
# classifications to results/; a reading sample with text goes to review/.
#
# The keyword rules proved unreliable on FDA reviews (dense, mixed analyses,
# template text, analyses done in R next to NONMEM ones), so the final types
# come from reading: fda_decisions.csv holds one decision per drug (Claude Sonnet 5
# readers with a written rubric, checked by Claude on a random 15%). The
# keyword types are kept as keyword_types for comparison.

pkgload::load_all("../../pmxlandscape", quiet = TRUE)

fda_dir <- "../../sources/fda"
window <- 800 # characters either side of a tool mention; wider windows took in analyses done with other tools
types <- readAnalysisTypes("../../taxonomy/analysis_types.csv")
patterns <- readPatterns(file.path(fda_dir, "config", "patterns.json"))
family_of <- c("NONMEM (name expanded)" = "NONMEM")
patterns$family <- ifelse(patterns$name %in% names(family_of), family_of[patterns$name], patterns$name)

results <- fdaReadResults(fda_dir)
drugs <- results[startsWith(results$category, "Tool stated"), ]
docs <- lapply(stats::setNames(fdaSurveyedYears(fda_dir), fdaSurveyedYears(fda_dir)), function(y) {
  jsonlite::read_json(file.path(fda_dir, "data", y, "docs.json"))
})

windows_for <- function(year, appl, family) {
  rx <- patterns$regex[patterns$family == family & patterns$group == "estimation"]
  texts <- character(0)
  for (r in docs[[year]][[appl]]) {
    pages <- fdaReadPages(fda_dir, year, r$text_file)
    for (k in seq_len(nrow(pages))) {
      for (p in rx) {
        loc <- stringi::stri_locate_all_regex(pages$text[k], p, omit_no_match = TRUE)[[1]]
        for (j in seq_len(nrow(loc))) {
          texts <- c(texts, stringi::stri_sub(pages$text[k], max(1, loc[j, 1] - window), loc[j, 2] + window))
        }
      }
    }
  }
  collapseSpace(texts)
}

evidence <- list()
items <- do.call(rbind, lapply(seq_len(nrow(drugs)), function(i) {
  w <- windows_for(drugs$year[i], drugs$application[i], drugs$sponsor_tool_family[i])
  cl <- classifyAnalysis(if (length(w) == 0) NA_character_ else w, types)
  t <- unique(unlist(cl$types))
  if (length(t) > 1) t <- setdiff(t, "PK only") # PK only only when nothing higher applies to any mention
  # the windows behind each type, for the reading sample
  evidence[[drugs$application[i]]] <<- vapply(t, function(ty) {
    k <- which(vapply(cl$types, function(x) ty %in% x, logical(1)))
    paste(sprintf("[%s] %s", ty, utils::head(w[k], 2)), collapse = " || ")
  }, character(1))
  data.frame(
    source = "FDA", id = drugs$application[i], year = as.integer(drugs$year[i]), drug = drugs$drug[i],
    tools = drugs$sponsor_tool_family[i], evidence_strength = drugs$evidence_strength[i],
    n_mentions = length(w), level = if (length(t) == 0) NA_integer_ else max(types$level[match(t, types$type)]),
    types = paste(t, collapse = "; "), text = paste(w, collapse = " || "), stringsAsFactors = FALSE
  )
}))

dir.create("results", showWarnings = FALSE)
dir.create("review", showWarnings = FALSE)
items$keyword_types <- items$types
items$keyword_level <- items$level
if (file.exists("fda_decisions.csv")) {
  dec <- read.csv("fda_decisions.csv", colClasses = "character")
  m <- match(items$id, dec$id)
  by_level <- stats::setNames(types$type, types$level)
  items$types <- ifelse(is.na(m), "", vapply(strsplit(dec$types[m], ";"), function(x) {
    paste(by_level[trimws(x)], collapse = "; ")
  }, character(1)))
  items$types[is.na(m)] <- ""
  items$level <- as.integer(dec$level[m])
  # "PK only" only when nothing higher applies (readers often listed popPK next to a higher type)
  higher <- !is.na(items$level) & items$level > 1
  items$types[higher] <- vapply(strsplit(items$types[higher], "; ", fixed = TRUE), function(x) {
    paste(setdiff(x, "PK only"), collapse = "; ")
  }, character(1))
  items$types_from <- ifelse(is.na(m), "no decision", "reading")
}
write.csv(items[setdiff(names(items), "text")], "results/fda_items.csv", row.names = FALSE)
items$types <- lapply(strsplit(items$types, "; ", fixed = TRUE), function(x) x[x != ""])
write.csv(typeByTool(items), "results/fda_type_by_tool.csv", row.names = FALSE)

set.seed(11)
per <- lapply(c(types$type, "none"), function(t) {
  has <- if (t == "none") lengths(items$types) == 0 else vapply(items$types, function(x) t %in% x, logical(1))
  w <- which(has)
  w[sample.int(length(w), min(10, length(w)))]
})
s <- items[unique(unlist(per)), ]
write.csv(data.frame(
  source = "FDA", id = s$id, drug = s$drug, tools = s$tools, types = vapply(s$types, paste, "", collapse = "; "),
  level = s$level,
  evidence = vapply(s$id, function(a) paste(evidence[[a]], collapse = " |||| "), character(1))
), "review/fda_sample.csv", row.names = FALSE)

# All drugs' windows for reading (deduplicated, capped), not committed
write.csv(data.frame(
  id = items$id, drug = items$drug, year = items$year, tool = items$tools,
  windows = vapply(strsplit(items$text, " || ", fixed = TRUE), function(w) {
    substr(paste(unique(w), collapse = " || "), 1, 12000)
  }, character(1))
), "review/fda_windows.csv", row.names = FALSE)

cat("drugs with a stated sponsor tool:", nrow(items), " without any mention window:", sum(items$n_mentions == 0), "\n")
print(table(factor(items$level, levels = 1:7), useNA = "ifany"))
