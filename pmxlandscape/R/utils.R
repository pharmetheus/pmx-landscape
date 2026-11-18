# The characters Python's str.isspace() accepts, which is what `\s` matches in
# the Python pipeline. ICU's `\s` (used by stringi) lacks \v, \x1c to \x1f and
# \x85, and the FDA text contains \x1c to \x1f, so snippets need this class to
# come out as the Python scripts wrote them.
pySpace <- "[\\x09-\\x0d\\x1c-\\x1f\\x85\\p{Z}]"

collapseSpace <- function(x) stringi::stri_replace_all_regex(x, paste0(pySpace, "+"), " ")

# Whole file as one UTF-8 string, without newline translation.
readText <- function(path) {
  s <- rawToChar(readBin(path, "raw", file.size(path)))
  Encoding(s) <- "UTF-8"
  s
}

# First-appearance counts, as Python's Counter reports them.
countInOrder <- function(x) {
  levels <- unique(x)
  data.frame(family = levels, n = as.integer(table(factor(x, levels = levels))), stringsAsFactors = FALSE)
}

# One CSV line as Python's csv.writer writes it (minimal quoting).
csvLine <- function(x) {
  x <- as.character(x)
  quote <- grepl("[,\"\r\n]", x)
  x[quote] <- paste0("\"", gsub("\"", "\"\"", x[quote], fixed = TRUE), "\"")
  paste(x, collapse = ",")
}
