# The fixture is a small invented FDA source folder. Its hits.json files, its
# summary CSV and the files in fda-mini-python/ were written by the Python
# scripts in sources/fda/scripts, so the tests below check parity with them.
miniDir <- function() test_path("fixtures", "fda-mini")

pythonOutput <- function(name) readLines(test_path("fixtures", "fda-mini-python", name), encoding = "UTF-8")

# The real FDA folder is only present in a checkout of the repository, not in
# an installed or R CMD check copy of the package.
realFdaDir <- function() {
  dir <- normalizePath(test_path("..", "..", "..", "sources", "fda"), mustWork = FALSE)
  skip_if_not(dir.exists(file.path(dir, "data")), "sources/fda not found (not a repository checkout)")
  dir
}

# The way 07_verify.py prints one unexplained mention, for comparing output.
formatUnexplained <- function(u) {
  if (nrow(u) == 0) {
    return(character(0))
  }
  pages <- vapply(u$pages, function(p) paste(utils::head(p, 8), collapse = ", "), character(1))
  sprintf("UNEXPLAINED %s %s (%s): %s on pages [%s]", u$year, u$drug, u$application, u$software, pages)
}

# A file at the repository root, such as the shared taxonomy.
repoFile <- function(...) {
  path <- normalizePath(test_path("..", "..", "..", ...), mustWork = FALSE)
  skip_if_not(file.exists(path), paste(file.path(...), "not found (not a repository checkout)"))
  path
}
