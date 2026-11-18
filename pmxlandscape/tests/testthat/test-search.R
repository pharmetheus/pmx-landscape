test_that("findSoftware returns each family once per text, in pattern order", {
  p <- readPatterns(file.path(miniDir(), "config", "patterns.json"))
  found <- findSoftware(c("NONMEM and PsN, then NONMEM again", "Monolix", "nothing here", NA), p)
  expect_equal(found, list(c("NONMEM", "PsN"), "Monolix", character(0), character(0)))
})

test_that("findSoftware leaves out the popPK marker and keeps only the groups asked for", {
  p <- readPatterns(file.path(miniDir(), "config", "patterns.json"))
  text <- "A popPK model in NONMEM with PsN; PBPK in Simcyp"
  expect_equal(findSoftware(text, p)[[1]], c("NONMEM", "PsN", "Simcyp"))
  expect_equal(findSoftware(text, p, groups = "estimation")[[1]], "NONMEM")
})
