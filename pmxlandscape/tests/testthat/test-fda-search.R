test_that("readPatterns keeps the order, names and groups of patterns.json", {
  p <- readPatterns(file.path(miniDir(), "config", "patterns.json"))
  expect_equal(p$name[1:3], c("NONMEM", "Monolix", "Phoenix NLME"))
  expect_equal(p$group[p$name == "Simcyp"], "pbpk")
  expect_equal(p$regex[p$name == "Monolix"], "(?i:\\bmonolix\\b)")
})

test_that("readPatterns takes the family from the pattern name when a pattern has none", {
  p <- readPatterns(file.path(miniDir(), "config", "patterns.json"))
  expect_equal(p$family, p$name)
})

test_that("fdaYears lists the numeric year folders in order", {
  expect_equal(fdaYears(miniDir()), c(2098L, 2099L))
})

test_that("fdaReadPages substitutes OCR text and keeps the page after the last form feed", {
  pg <- fdaReadPages(miniDir(), 2099, "txt/100001_integratedR_2099.txt")
  expect_equal(pg$page, 1:4)
  expect_equal(pg$src, c("text", "ocr", "text", "text"))
  expect_equal(pg$text[2], "Table 3. Software: Monolix 2021R1\n\x1f popPK model")
  expect_equal(pg$text[4], "")
})

test_that("fdaSearch reproduces the Python hits for every fixture year, in order", {
  for (y in fdaYears(miniDir())) {
    expected <- fdaReadHits(miniDir(), y)
    expect_identical(fdaSearch(miniDir(), years = y), expected)
  }
})

test_that("snippets collapse Python whitespace, including the \\x1c to \\x1f separators", {
  h <- fdaSearch(miniDir(), years = 2099)
  expect_equal(
    h$snip[1],
    paste(
      "Applicant's Position: the population pharmacokinetic analysis used NONMEM 7.4 with PsN.",
      "gaps and lines. NONMEM again."
    )
  )
  expect_false(any(grepl("[\x1c-\x1f]", h$snip)))
})

test_that("snippets extend 220 characters either side of the match", {
  h <- fdaSearch(miniDir(), years = 2099)
  simcyp <- h[h$sw == "Simcyp", ]
  expect_equal(nchar(simcyp$snip), 220 + nchar("Simcyp") + 220)
})

test_that("case-insensitive groups, misprints and exclusions behave as in patterns.json", {
  h <- fdaSearch(miniDir(), years = 2099)
  nonmem <- h[h$appl == "100002" & h$sw == "NONMEM" & h$doc == "100002_clinPharmR_2099", ]
  expect_equal(nrow(nonmem), 2) # "nonmem" and the misprint "NONMEMS"
  expect_false("Phoenix (unspecified)" %in% h$sw) # "Phoenix, AZ" and "Phoenix WinNonlin" are excluded
  expect_true("Phoenix NLME" %in% h$sw) # "Phoenix(R) NLME"
})

test_that("fdaSurveyedYears leaves out years without a decision record, which fdaYears keeps", {
  dir <- withr::local_tempdir()
  file.copy(miniDir(), dir, recursive = TRUE)
  fda <- file.path(dir, "fda-mini")
  dir.create(file.path(fda, "data", "2101", "txt"), recursive = TRUE)
  writeLines("{}", file.path(fda, "data", "2101", "docs.json"))
  expect_equal(fdaYears(fda), c(2098L, 2099L, 2101L))
  expect_equal(fdaSurveyedYears(fda), c(2098L, 2099L))
  expect_equal(unique(fdaSearch(fda)$year), unique(fdaSearch(miniDir())$year))
})
