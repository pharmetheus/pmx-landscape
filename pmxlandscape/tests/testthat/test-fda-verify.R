test_that("fdaVerify reports the same unexplained mentions as 07_verify.py", {
  u <- fdaVerify(miniDir())
  expected <- pythonOutput("verify.txt")
  expect_equal(formatUnexplained(u), utils::head(expected, -1))
  expect_equal(sprintf("%d unexplained software mentions", nrow(u)), utils::tail(expected, 1))
})

test_that("a known exception explains a hit", {
  u <- fdaVerify(miniDir())
  expect_false(any(u$application == "100002" & u$software == "Stan"))
  noExceptions <- fdaReadExceptions(miniDir())[0, ]
  u <- fdaVerify(miniDir(), exceptions = noExceptions)
  expect_true(any(u$application == "100002" & u$software == "Stan"))
})

test_that("a tool recorded in the results explains a hit", {
  u <- fdaVerify(miniDir())
  expect_false(any(u$application == "100001" & u$software == "PsN"))
  res <- fdaReadResults(miniDir())
  res$sponsor_auxiliary_tools[res$application == "100001"] <- ""
  u <- fdaVerify(miniDir(), results = res)
  expect_true(any(u$application == "100001" & u$software == "PsN"))
})

test_that("verification maps pattern names to families before matching", {
  res <- fdaReadResults(miniDir())
  u <- fdaVerify(miniDir(), results = res)
  expect_true(any(u$application == "100002" & u$software == "MATLAB")) # from "SimBiology/MATLAB"
})

test_that("NCA and marker hits are not verified", {
  res <- fdaReadResults(miniDir())
  res$pbpk_nca[res$application == "100001"] <- "Simcyp (PBPK)"
  u <- fdaVerify(miniDir(), results = res)
  expect_false(any(grepl("WinNonlin|marker", u$software)))
})
