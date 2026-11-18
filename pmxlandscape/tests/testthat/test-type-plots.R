test_that("lumpTypes merges joint models into time-to-event, or keeps only PK only against the rest", {
  x <- list(
    "PK only", c("Joint models", "Non-continuous endpoints, time-to-event"), "Full Bayesian hierarchical models",
    character(0)
  )
  d <- lumpTypes(x, "detailed")
  expect_equal(d[[2]], "Non-continuous endpoints, time-to-event, joint models")
  expect_equal(d[[3]], "Full Bayesian hierarchical models")
  s <- lumpTypes(x, "simple")
  expect_equal(s, list("PK only", "Any type other than PK only", "Any type other than PK only", character(0)))
})

test_that("plotTypeSpread draws one bar per type and source", {
  s <- data.frame(
    source = c("A", "A", "B"), type = c("PK only", "QSP, PBPK", "PK only"), share = c(0.6, 0.1, 0.8),
    n = c(6L, 1L, 8L), n_tool = c(10L, 10L, 10L)
  )
  b <- ggplot2::ggplot_build(plotTypeSpread(s))
  expect_equal(nrow(b$data[[1]]), 3)
  expect_equal(length(unique(b$data[[1]]$PANEL)), 2)
})

test_that("plotTypeLift draws a point and interval per tool and type, on a log scale", {
  l <- data.frame(
    tool = c("NONMEM", "Monolix"), type = "PK only", ratio = c(1.5, 0.8), lower = c(1.2, 0.6),
    upper = c(1.9, 1.1), n = c(100L, 20L), n_tool = c(200L, 60L)
  )
  b <- ggplot2::ggplot_build(plotTypeLift(l))
  expect_equal(nrow(b$data[[2]]), 2)
  expect_equal(b$layout$panel_params[[1]]$x$scale$trans$name, "log-10")
})
