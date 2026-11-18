test_that("toolColours fixes a colour per family and folds other families into Other", {
  expect_equal(toolColours("NONMEM")[["NONMEM"]], "#2a78d6")
  # the colour follows the entity, not its position
  expect_equal(toolColours(c("Pumas", "Monolix"))[["Monolix"]], toolColours("Monolix")[["Monolix"]])
  expect_equal(toolColours("SAAM II")[["SAAM II"]], toolColours("Other")[["Other"]])
})

test_that("plotFdaSponsor stacks drugs per approval year by sponsor group", {
  b <- ggplot2::ggplot_build(plotFdaSponsor(fdaReadResults(miniDir())))$data[[1]]
  expect_equal(sum(b$ymax[b$x == 1] - b$ymin[b$x == 1]), 1) # 2098: one drug
  expect_equal(sum(b$ymax[b$x == 2] - b$ymin[b$x == 2]), 3) # 2099: three drugs
  expect_equal(length(unique(b$fill[b$x == 2])), 3) # NONMEM, other tool, no popPK analysis
})

test_that("plotFdaSponsor draws periods and percentages of each period's drugs", {
  r <- fdaReadResults(miniDir())
  r$period <- ifelse(r$year == "2098", "2097/98", "2098/99")
  b <- ggplot2::ggplot_build(plotFdaSponsor(r, by = "period"))$data[[1]]
  expect_equal(sum(b$ymax[b$x == 2] - b$ymin[b$x == 2]), 3)
  p <- plotFdaSponsor(r, by = "period", scale = "percent")
  b <- ggplot2::ggplot_build(p)$data[[1]]
  # each bar is the whole period: its parts add up to one
  expect_equal(as.vector(tapply(b$ymax - b$ymin, b$x, sum)), c(1, 1))
  expect_equal(sort(round(b$ymax[b$x == 2] - b$ymin[b$x == 2], 3)), c(0.333, 0.333, 0.333))
  expect_equal(levels(p$data$x), c("2097/98", "2098/99"))
  # a drug with no tool and an undecided population PK analysis has its own group
  r$category[1] <- "No tool identified in review"
  b <- ggplot2::ggplot_build(plotFdaSponsor(r, by = "period"))$data[[1]]
  expect_equal(nrow(b), 4)
})

test_that("fdaToolTable gives shares with and without template-only cases", {
  r <- fdaReadResults(miniDir())
  extra <- r[r$drug == "Drug A", ]
  extra$drug <- "Drug T"
  extra$evidence_strength <- "indirect, template phrase only"
  extra$category <- "Tool stated (indirect)"
  tab <- fdaToolTable(rbind(r, extra))
  expect_equal(tab$family, c("NONMEM", "Monolix", "Phoenix NLME"))
  expect_equal(tab$drugs, c(2L, 1L, 1L))
  expect_equal(tab$share, c(0.5, 0.25, 0.25))
  expect_equal(tab$share_excluding_template, c(1, 1, 1) / 3)
})

litShares <- function() {
  grid <- expand.grid(
    year = 2021:2026, software = c("NONMEM", "Monolix", "saemix"),
    source = c("PubMed (title/abstract)", "Europe PMC (full text)"), stringsAsFactors = FALSE
  )
  grid$base_n <- 1000L
  grid$n <- ifelse(grid$software == "NONMEM", 120L, ifelse(grid$software == "Monolix", 30L, 4L))
  grid$share_all <- grid$n / grid$base_n
  grid$share <- grid$n / 150L
  grid
}

test_that("plotLiteratureShares leaves out families under 10 papers in every year, on a log scale", {
  p <- plotLiteratureShares(litShares())
  b <- ggplot2::ggplot_build(p)
  expect_setequal(unique(b$plot$data$software), c("NONMEM", "Monolix"))
  expect_match(p$labels$caption, "saemix")
  expect_equal(b$layout$panel_params[[1]]$y$scale$trans$name, "log-10")
})

test_that("plotLiteratureShares plots the share asked for", {
  d <- ggplot2::ggplot_build(plotLiteratureShares(litShares(), measure = "share"))$data[[1]]
  expect_equal(sort(unique(round(10^d$y, 4))), sort(unique(round(c(120, 30) / 150, 4))))
  d <- ggplot2::ggplot_build(plotLiteratureShares(litShares(), measure = "share_all"))$data[[1]]
  expect_equal(sort(unique(round(10^d$y, 4))), c(0.03, 0.12))
})

test_that("plotPageShares shows one panel per affiliation group", {
  s <- data.frame(
    group = rep(c("sponsor", "academia"), each = 4), year = rep(c(2020L, 2021L), 4),
    family = rep(rep(c("NONMEM", "Monolix"), each = 2), 2), n = 10L, n_any = 20L, n_abstracts = 40L
  )
  s$share <- s$n / s$n_any
  s$share_all <- s$n / s$n_abstracts
  b <- ggplot2::ggplot_build(plotPageShares(s, measure = "share_all"))
  expect_equal(length(unique(b$data[[1]]$PANEL)), 2)
  expect_equal(unique(b$data[[1]]$y), 0.25)
})

test_that("plotLagProfile draws one point per lag", {
  prof <- data.frame(lag = 0:5, loglik = -(0:5), rel_lik = exp(-(0:5)), extrapolated = c(rep(FALSE, 5), TRUE))
  b <- ggplot2::ggplot_build(plotLagProfile(prof))
  expect_equal(nrow(b$data[[1]]), 6)
})

test_that("plotProjection shows PAGE, observed FDA shares and the lagged projection", {
  page <- data.frame(year = 2012:2026, family = "NONMEM", n_any = 200L)
  page$n <- as.integer(round(page$n_any * stats::plogis(2 - 0.2 * (page$year - 2016))))
  fda <- data.frame(year = 2021:2025, family = "NONMEM", n_any = 30L, n = 27L)
  trend <- fitTrend(page, "NONMEM")
  p <- plotProjection(page, trend, fda, lag = 2, years = 2021:2030)
  b <- ggplot2::ggplot_build(p)
  series <- unique(unlist(lapply(b$plot$layers, function(l) unique(l$data$series))))
  expect_setequal(series[!is.na(series)], c("PAGE, industry and CRO", "FDA approvals", "Projected from PAGE"))
})

test_that("plotLiteratureShares can use a linear scale", {
  b <- ggplot2::ggplot_build(plotLiteratureShares(litShares(), measure = "share", log = FALSE))
  expect_equal(b$layout$panel_params[[1]]$y$scale$trans$name, "identity")
  expect_equal(sort(unique(round(b$data[[1]]$y, 4))), sort(unique(round(c(120, 30) / 150, 4))))
})

test_that("plotLiteratureShares on a linear scale runs from 0 to 100% in quarters, under the title given", {
  p <- plotLiteratureShares(litShares(), measure = "share", log = FALSE, title = "Share of papers using each tool")
  b <- ggplot2::ggplot_build(p)
  expect_equal(b$layout$panel_params[[1]]$y$breaks, c(0, 0.25, 0.5, 0.75, 1))
  expect_equal(p$labels$title, "Share of papers using each tool")
  expect_equal(plotLiteratureShares(litShares())$labels$title, "Share of pharmacometric papers naming each tool")
})
