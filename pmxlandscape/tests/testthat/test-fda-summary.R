test_that("fdaSummary writes the same summary CSV as 08_summarize.py, byte for byte", {
  out <- withr::local_tempfile(fileext = ".csv")
  fdaSummary(miniDir(), file = out)
  expected <- file.path(miniDir(), "results", "summary_sponsor_by_year.csv")
  expect_identical(readBin(out, "raw", 1e5), readBin(expected, "raw", 1e5))
})

test_that("fdaSummary gives the tool family shares that 08_summarize.py prints", {
  s <- fdaSummary(miniDir())
  printed <- pythonOutput("summarize.txt")
  expect_equal(s$sponsorTools$family, c("Monolix", "NONMEM", "Phoenix NLME"))
  expect_equal(s$sponsorTools$n, c(1L, 1L, 1L))
  expect_match(printed[grep("identifiable sponsor tool", printed)], "tool: 3 ", fixed = TRUE)
  expect_equal(sprintf("%.0f%%", s$sponsorTools$share), rep("33%", 3))
  # the FDA reviewer's own tools are attribution only; no tally of them is published
  expect_named(s, c("sponsorByYear", "sponsorTools"))
})

test_that("the sponsor table labels stated tools by family and evidence strength", {
  s <- fdaSummary(miniDir())$sponsorByYear
  expect_equal(s$sponsor_category, c(
    "Monolix, stated", "NONMEM, stated", "No popPK analysis in review", "Phoenix NLME, stated", "Total"
  ))
  expect_equal(s$`2099`, c(0L, 1L, 1L, 1L, 3L))
  expect_equal(s$share_all, c("25.0%", "25.0%", "25.0%", "25.0%", "100%"))
})
