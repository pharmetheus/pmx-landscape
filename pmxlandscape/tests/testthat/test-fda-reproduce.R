# Reproduces the published FDA results from the cached text in sources/fda.
# Runs only in a repository checkout; the full search takes a minute or two.

fdaHits <- local({
  cache <- NULL
  function(dir) {
    if (is.null(cache)) cache <<- fdaSearch(dir)
    cache
  }
})

test_that("the R search reproduces every shipped hits.json exactly", {
  dir <- realFdaDir()
  hits <- fdaHits(dir)
  for (y in fdaSurveyedYears(dir)) {
    yearHits <- hits[hits$year == y, , drop = FALSE]
    rownames(yearHits) <- NULL
    expect_identical(yearHits, fdaReadHits(dir, y), label = paste("hits for", y))
  }
})

test_that("the R search leaves 0 unexplained software mentions", {
  dir <- realFdaDir()
  expect_equal(nrow(fdaVerify(dir, hits = fdaHits(dir))), 0)
})

test_that("the R summary is byte-identical to the shipped summary CSV", {
  dir <- realFdaDir()
  out <- withr::local_tempfile(fileext = ".csv")
  fdaSummary(dir, file = out)
  expected <- file.path(dir, "results", "summary_sponsor_by_year.csv")
  expect_identical(readBin(out, "raw", 1e6), readBin(expected, "raw", 1e6))
})

test_that("the published FDA headline numbers hold", {
  s <- fdaSummary(realFdaDir())
  tab <- s$sponsorByYear
  count <- function(label) tab$All[tab$sponsor_category == label]
  expect_equal(count("Total"), 238L)
  expect_equal(count("NONMEM, stated"), 113L)
  expect_equal(count("NONMEM, indirect"), 10L)
  expect_equal(count("NONMEM, indirect, template phrase only"), 13L)
  expect_equal(count("popPK present, software not stated"), 63L)
  expect_equal(count("No popPK analysis in review"), 27L)
  expect_equal(
    stats::setNames(s$sponsorTools$n, s$sponsorTools$family)[c("NONMEM", "Monolix", "Phoenix NLME", "Pumas")],
    c(NONMEM = 136L, Monolix = 8L, `Phoenix NLME` = 3L, Pumas = 1L)
  )
})
