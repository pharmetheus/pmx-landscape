# Synthetic PAGE abstracts and FDA results for the lag analysis.
pageRows <- function(year, n, estimation, affiliation_type = "industry", software_demo = FALSE,
                     pdf_estimation = "", estimation_source = NULL) {
  if (is.null(estimation_source)) {
    estimation_source <- ifelse(estimation != "", "abstract", ifelse(pdf_estimation != "", "pdf", "none"))
  }
  data.frame(
    year = rep(year, n), affiliation_type = affiliation_type, software_demo = software_demo,
    estimation = estimation, pdf_estimation = pdf_estimation, estimation_source = estimation_source
  )
}

test_that("pageShares counts abstracts per family among those naming any estimation tool", {
  a <- rbind(
    pageRows(2020, 3, "NONMEM"), pageRows(2020, 1, "NONMEM; Monolix"), pageRows(2020, 2, ""),
    pageRows(2020, 1, "", pdf_estimation = "Monolix"), pageRows(2020, 5, "Pumas", software_demo = TRUE),
    pageRows(2020, 2, "NONMEM", affiliation_type = "academia")
  )
  s <- pageShares(a, groups = list(sponsor = c("industry", "CRO")))
  nm <- s[s$family == "NONMEM", ]
  expect_equal(nm$n, 4L) # 3 + 1; academia and the software demos are not in the sponsor group
  expect_equal(nm$n_any, 5L) # 4 in the abstract + 1 from a PDF decided "used"
  expect_equal(nm$n_abstracts, 7L) # the 2 naming no tool count here, the demos do not
  expect_equal(s$n[s$family == "Monolix"], 2L)
  expect_equal(nm$share, 4 / 5)
  expect_equal(nm$share_all, 4 / 7)
  expect_false("Pumas" %in% s$family)
  all <- pageShares(a, groups = list(all = NULL))
  expect_equal(all$n[all$family == "NONMEM"], 6L) # academia included
})

test_that("pageShares survives a CSV round trip with empty PDF columns", {
  a <- rbind(pageRows(2020, 1, "NONMEM"), pageRows(2020, 1, ""))
  f <- withr::local_tempfile(fileext = ".csv")
  utils::write.csv(a, f, row.names = FALSE)
  s <- pageShares(utils::read.csv(f), groups = list(all = NULL))
  expect_equal(s$family, "NONMEM")
  expect_equal(s$n_any, 1L)
})

test_that("pageShares leaves out abstracts whose PDF could not be read", {
  a <- rbind(pageRows(2020, 2, "NONMEM"), pageRows(2020, 1, "", estimation_source = "unknown"))
  s <- pageShares(a, groups = list(all = NULL))
  expect_equal(s$n_abstracts, 2L)
})

test_that("pageShares refuses to count while a PDF hit is pending", {
  a <- rbind(pageRows(2020, 1, "NONMEM"), pageRows(2020, 1, "", estimation_source = "pending"))
  expect_error(pageShares(a), "pending")
})

test_that("fdaToolCounts counts drugs with a stated tool by approval year", {
  r <- data.frame(
    year = c("2021", "2021", "2021", "2022"),
    category = c("Tool stated", "Tool stated (indirect)", "No popPK analysis in review", "Tool stated"),
    sponsor_tool_family = c("NONMEM", "Monolix", "", "NONMEM")
  )
  f <- fdaToolCounts(r)
  expect_equal(f$n[f$year == 2021 & f$family == "NONMEM"], 1L)
  expect_equal(f$n_any[f$year == 2021 & f$family == "NONMEM"], 2L)
  expect_equal(f$n[f$year == 2022 & f$family == "Monolix"], 0L)
})

# PAGE shares following a logistic trend, and FDA shares equal to PAGE lagged by `lag` years.
synthetic <- function(lag, slope = -0.25) {
  p <- function(y) stats::plogis(2 + slope * (y - 2016))
  page <- data.frame(year = 2012:2026, family = "NONMEM", n_any = 2000L)
  page$n <- as.integer(round(page$n_any * p(page$year)))
  fda <- data.frame(year = 2021:2025, family = "NONMEM", n_any = 4000L)
  fda$n <- as.integer(round(fda$n_any * p(fda$year - lag)))
  list(page = page, fda = fda)
}

test_that("estimateLag recovers a known lag", {
  for (lag in c(0, 2, 4)) {
    d <- synthetic(lag)
    prof <- estimateLag(d$fda, fitTrend(d$page, "NONMEM"), lags = 0:5, family = "NONMEM")
    expect_equal(prof$lag[which.max(prof$loglik)], lag, label = paste("lag", lag))
    expect_equal(max(prof$rel_lik), 1)
  }
})

test_that("a flat PAGE trend gives a flat lag profile", {
  d <- synthetic(3, slope = 0)
  prof <- estimateLag(d$fda, fitTrend(d$page, "NONMEM"), lags = 0:5, family = "NONMEM")
  expect_true(all(prof$rel_lik > 0.99))
})

test_that("fitTrend and estimateLag use only the family asked for", {
  d <- synthetic(2)
  other <- d$page
  other$family <- "Monolix"
  other$n <- other$n_any - other$n
  page <- rbind(d$page, other)
  fda <- rbind(d$fda, transform(d$fda, family = "Monolix", n = n_any - n))
  prof <- estimateLag(fda, fitTrend(page, "NONMEM"), lags = 0:5)
  expect_equal(prof$lag[which.max(prof$loglik)], 2)
  expect_lt(stats::coef(fitTrend(page, "NONMEM")$fit)[["year"]], 0)
})

test_that("estimateLag marks lags that need PAGE years after the fitted range", {
  d <- synthetic(0)
  d$page <- d$page[d$page$year <= 2023, ]
  prof <- estimateLag(d$fda, fitTrend(d$page, "NONMEM"), lags = 0:3, family = "NONMEM")
  expect_equal(prof$extrapolated, c(TRUE, TRUE, FALSE, FALSE)) # 2025 - 1 = 2024 > 2023
})

test_that("estimateLag marks lags that need PAGE years outside the fitted range", {
  d <- synthetic(2)
  d$page <- d$page[d$page$year >= 2018, ]
  prof <- estimateLag(d$fda, fitTrend(d$page, "NONMEM"), lags = 0:5, family = "NONMEM")
  expect_equal(prof$extrapolated, c(FALSE, FALSE, FALSE, FALSE, TRUE, TRUE)) # 2021 - 4 = 2017 < 2018
})

test_that("projectShares follows the lagged trend and marks extrapolation", {
  d <- synthetic(2)
  fit <- fitTrend(d$page, "NONMEM")
  pr <- projectShares(fit, lag = 2, years = 2026:2030)
  expect_equal(pr$year, 2026:2030)
  expect_equal(pr$share, stats::plogis(2 - 0.25 * (pr$year - 2 - 2016)), tolerance = 0.01)
  expect_equal(pr$extrapolated, pr$year - 2 > 2026)
  expect_true(all(pr$lower <= pr$share & pr$share <= pr$upper))
  link <- stats::predict(fit$fit, newdata = data.frame(year = 2026 - 2), type = "link", se.fit = TRUE)
  expect_equal(pr$upper[1], stats::plogis(link$fit + stats::qnorm(0.975) * link$se.fit), ignore_attr = TRUE)
})
