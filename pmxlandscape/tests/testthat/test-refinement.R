test_that("wilson gives the Wilson score interval", {
  w <- wilson(8, 10)
  ref <- stats::prop.test(8, 10, correct = FALSE)$conf.int # the Wilson interval without correction
  expect_equal(c(w$lower, w$upper), as.numeric(ref), tolerance = 1e-10)
  expect_equal(w$share, 0.8)
  w0 <- wilson(0, 30)
  expect_equal(w0$lower, 0)
  expect_equal(w0$upper, as.numeric(stats::prop.test(0, 30, correct = FALSE)$conf.int)[2], tolerance = 1e-10)
  expect_true(is.na(wilson(0, 0)$share))
})

test_that("recallTable counts the reference items the query found, by group", {
  x <- data.frame(source = c("A", "A", "A", "B", "B"), found = c(TRUE, FALSE, TRUE, TRUE, TRUE))
  r <- recallTable(x, "source")
  expect_equal(r$source, c("A", "B"))
  expect_equal(r$reference, c(3L, 2L))
  expect_equal(r$found, c(2L, 2L))
  expect_equal(r$recall, c(2 / 3, 1))
  expect_equal(r$lower[1], wilson(2, 3)$lower)
})

test_that("chapman gives the bias-corrected capture-recapture estimate and its interval", {
  # n1 = 50 marked, n2 = 40 caught, m = 10 recaptured: (51 * 41) / 11 - 1
  e <- chapman(50, 40, 10)
  expect_equal(e$estimate, 51 * 41 / 11 - 1)
  se <- sqrt(51 * 41 * 40 * 30 / (11^2 * 12))
  expect_equal(e$se, se)
  expect_equal(e$lower, e$estimate - stats::qnorm(0.975) * se)
  expect_error(chapman(10, 5, 6), "cannot exceed")
})

test_that("stratifiedRecall weights each stratum's relevant share by its size", {
  r <- stratifiedRecall(nIn = 400, xIn = 30, sIn = 60, nOut = 800, xOut = 20, sOut = 100, seed = 1)
  pIn <- 30 / 60
  pOut <- 20 / 100
  expect_equal(r$recall, 400 * pIn / (400 * pIn + 800 * pOut))
  expect_true(r$lower < r$recall && r$recall < r$upper)
  expect_equal(r$relevant, 400 * pIn + 800 * pOut)
  expect_equal(stratifiedRecall(400, 30, 60, 800, 0, 100, seed = 1)$recall, 1)
  expect_identical(stratifiedRecall(400, 30, 60, 800, 20, 100, seed = 1), r) # the same seed, the same interval
})
