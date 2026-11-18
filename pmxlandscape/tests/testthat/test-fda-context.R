test_that("fdaContext prints what 06_context.py prints", {
  expect_equal(
    capture.output(fdaContext(miniDir(), 2099, "100002", 1, "NONMEM")),
    pythonOutput("context_100002_p1.txt")
  )
  expect_equal(
    capture.output(fdaContext(miniDir(), 2099, "100001", 3, "Simcyp", before = 60)),
    pythonOutput("context_100001_p3.txt")
  )
})

test_that("fdaContext skips documents without the page or the term", {
  expect_equal(capture.output(fdaContext(miniDir(), 2099, "100003", 9, "NONMEM")), character(0))
  expect_equal(capture.output(fdaContext(miniDir(), 2099, "100003", 1, "NONMEM")), character(0))
})
