extractions <- function() {
  data.frame(
    id = paste0("MED:", 1:6), year = c("2021", "2022", "2023", "2024", "2025", "2026"),
    own_fit = c("yes", "yes", "yes", "no", "yes", "yes"),
    tool = c("NONMEM", "Monolix", "NONMEM", NA, "several", "Monolix"),
    method = c("FOCE-I", "SAEM (default)", "SAEM", NA, "FOCE-I", "SAEM"),
    analysis = c("pk_only", "pk_only", "pkpd", NA, "pk_only", "pkpd"),
    structural = c("4", "5", "6", NA, "4", "NA"), covariates = c("2", "1", "0", NA, "1", "2"),
    iiv = c("2", "4", "3", NA, "2", "3"), n_subjects = c("100", "40", "250", NA, "60", "30"),
    n_obs = c("800", "300", "NA", NA, "500", "200"), stringsAsFactors = FALSE
  )
}

test_that("modelSizeData keeps the authors' own fits with one tool and adds fixed and random effect counts", {
  d <- modelSizeData(extractions())
  expect_equal(d$id, c("MED:1", "MED:2", "MED:3", "MED:6"))
  expect_equal(d$fixed, c(6, 6, 6, NA)) # structural + covariates; NA when either is unknown
  expect_equal(d$random, c(2, 4, 3, 3))
  expect_equal(d$algorithm, c("FOCE", "SAEM", "SAEM", "SAEM")) # FOCE-I and SAEM (default) folded
  expect_true(is.numeric(d$n_subjects) && is.na(d$n_obs[3]))
})

test_that("modelSizeSummary gives the mean with a t interval per tool, over the papers with a count", {
  d <- data.frame(tool = rep(c("NONMEM", "Monolix"), each = 4), fixed = c(4, 6, 8, 10, 5, 7, NA, 9), random = 2)
  s <- modelSizeSummary(d, measures = "fixed")
  n <- s[s$tool == "NONMEM", ]
  expect_equal(n$n, 4)
  expect_equal(n$mean, 7)
  expect_equal(n$lower, 7 - stats::qt(0.975, 3) * stats::sd(c(4, 6, 8, 10)) / 2)
  expect_equal(s$n[s$tool == "Monolix"], 3)
  expect_equal(s$median[s$tool == "Monolix"], 7)
})

test_that("modelSizeRatio recovers a tool ratio, and the adjusted ratio removes a difference due to analysis type", {
  set.seed(1)
  n <- 4000
  tool <- sample(c("NONMEM", "Monolix"), n, replace = TRUE)
  # Monolix papers are more often PK/PD, and PK/PD models are larger; the tool itself has no effect
  analysis <- ifelse(stats::runif(n) < ifelse(tool == "Monolix", 0.7, 0.3), "pkpd", "pk_only")
  n_subjects <- round(exp(stats::rnorm(n, 4, 1)))
  year <- sample(2021:2026, n, replace = TRUE)
  fixed <- stats::rpois(n, 5 * ifelse(analysis == "pkpd", 1.6, 1))
  d <- data.frame(tool, analysis, n_subjects, year, fixed)
  crude <- modelSizeRatio(d, "fixed", adjust = FALSE)
  adjusted <- modelSizeRatio(d, "fixed", adjust = TRUE)
  expect_gt(crude$ratio, 1.15)
  expect_lt(abs(adjusted$ratio - 1), 0.05)
  expect_true(adjusted$lower < 1 && adjusted$upper > 1)
  # a real tool effect of 1.5 is recovered
  d$fixed <- stats::rpois(n, 5 * ifelse(d$tool == "Monolix", 1.5, 1))
  r <- modelSizeRatio(d, "fixed", adjust = TRUE)
  expect_lt(abs(r$ratio - 1.5), 0.08)
  expect_equal(r$n, n)
})

test_that("plotDataSize draws one violin per tool with enough papers, on a log scale", {
  d <- data.frame(
    tool = rep(c("NONMEM", "Monolix", "Pumas"), c(30, 20, 3)),
    n_subjects = round(exp(stats::rnorm(53, 4, 1))), n_obs = round(exp(stats::rnorm(53, 6, 1)))
  )
  b <- ggplot2::ggplot_build(plotDataSize(d, minPapers = 10))
  expect_equal(nrow(unique(b$data[[1]][c("PANEL", "group")])), 4) # two tools in each of two measures
  expect_equal(b$layout$panel_params[[1]]$y$scale$trans$name, "log-10")
})

test_that("plotModelSize shows each tool's counts per measure, overall and PK only", {
  d <- data.frame(
    tool = rep(c("NONMEM", "Monolix"), each = 20), analysis = rep(c("pk_only", "pkpd"), 20),
    fixed = stats::rpois(40, 6), random = stats::rpois(40, 3)
  )
  p <- plotModelSize(d)
  b <- ggplot2::ggplot_build(p)
  expect_equal(nrow(b$layout$layout), 4) # fixed and random, overall and PK only
  expect_setequal(unique(as.character(p$data$subgroup)), c("All models", "PK only"))
})

test_that("modelSizeSummary leaves out rows without a group", {
  d <- data.frame(tool = c("NONMEM", NA, "Monolix"), fixed = c(4, 5, 6))
  s <- modelSizeSummary(d, measures = "fixed")
  expect_setequal(s$tool, c("NONMEM", "Monolix"))
})
