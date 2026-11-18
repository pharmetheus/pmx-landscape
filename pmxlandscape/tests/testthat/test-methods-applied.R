test_that("pageMethodology marks methodology sessions by topic, with or without the prefix", {
  s <- c(
    "Poster: Methodology - Estimation Methods", "Poster: New Modelling Approaches", "Poster: Study Design",
    "Poster: Model evaluation", "Poster: Covariate/Variability Model Building", "Poster: Methodology- PBPK",
    "Poster: Drug/Disease Modelling - Oncology", "Poster: Methodology – AI/Machine Learning", NA
  )
  expect_equal(pageMethodology(s), c(TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE, FALSE))
})

test_that("methodsApplied counts methodology and applied items per group and year", {
  items <- data.frame(
    year = c(2020L, 2020L, 2021L, 2021L), tools = c("Pumas", "Pumas; NONMEM", "Pumas", "NONMEM"),
    methodology = c(TRUE, FALSE, TRUE, TRUE)
  )
  m <- methodsApplied(items, groups = c("Pumas", "NONMEM"))
  p20 <- m[m$group == "Pumas" & m$year == 2020, ]
  expect_equal(c(p20$methods, p20$applied), c(1L, 1L))
  expect_equal(m$methods[m$group == "NONMEM" & m$year == 2021], 1L)
  expect_equal(m$applied[m$group == "NONMEM" & m$year == 2021], 0L)
})

test_that("plotMethodsApplied stacks methods and applied counts in one panel per group", {
  m <- data.frame(
    group = rep(c("A", "B"), each = 2), year = rep(2020:2021, 2), methods = c(1L, 2L, 0L, 3L),
    applied = c(0L, 1L, 2L, 2L)
  )
  b <- ggplot2::ggplot_build(plotMethodsApplied(m))
  expect_equal(length(unique(b$data[[1]]$PANEL)), 2)
  expect_equal(sum(b$data[[1]]$ymax - b$data[[1]]$ymin), sum(m$methods + m$applied))
})
