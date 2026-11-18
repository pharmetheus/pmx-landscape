#' Model and data size data from the extractions
#'
#' Keeps the papers whose authors fitted a model of their own with one
#' identified tool, converts the counts to numbers and adds `fixed`
#' (structural plus covariate effects, `NA` when either is unknown), `random`
#' (IIV terms) and `algorithm` (the estimation method with FOCE and FOCE-I,
#' and SAEM stated or default, folded together).
#'
#' @param x Extractions as in `analysis/model_size/extractions.csv`, as
#'   character columns.
#'
#' @return A data frame, one row per paper.
#' @export
modelSizeData <- function(x) {
  d <- x[x$own_fit %in% "yes" & !is.na(x$tool) & !x$tool %in% c("several", "not stated"), , drop = FALSE]
  num <- function(v) suppressWarnings(as.numeric(v))
  counts <- intersect(
    c("n_models", "structural", "covariates", "iiv", "iov", "covariances", "residual", "n_subjects", "n_obs", "year"),
    names(d)
  )
  for (col in counts) d[[col]] <- num(d[[col]])
  d$fixed <- d$structural + d$covariates
  d$random <- d$iiv
  algorithms <- c(
    FO = "FO", FOCE = "FOCE", "FOCE-I" = "FOCE", LAPLACE = "Laplace", SAEM = "SAEM", "SAEM (default)" = "SAEM",
    IMP = "IMP", BAYES = "Bayesian", NPAG = "NPAG", other = "Other", "not stated" = "Not stated"
  )
  d$algorithm <- unname(algorithms[d$method])
  d$algorithm[is.na(d$algorithm)] <- "Not stated"
  rownames(d) <- NULL
  d
}

#' Mean model size per tool
#'
#' @param d As from [modelSizeData()], with `tool` and the measure columns.
#' @param measures Columns to summarise.
#' @param by Grouping column.
#' @param level Confidence level of the t interval for the mean.
#'
#' @return One row per group and measure with `n` (papers with a count),
#'   `mean`, `lower`, `upper` and `median`.
#' @export
modelSizeSummary <- function(d, measures = c("fixed", "random", "structural", "covariates", "iiv"),
                             by = "tool", level = 0.95) {
  measures <- intersect(measures, names(d))
  groups <- unique(d[[by]][!is.na(d[[by]])])
  out <- do.call(rbind, lapply(groups, function(g) {
    do.call(rbind, lapply(measures, function(m) {
      x <- d[[m]][d[[by]] == g]
      x <- x[!is.na(x)]
      n <- length(x)
      half <- if (n > 1) stats::qt(1 - (1 - level) / 2, n - 1) * stats::sd(x) / sqrt(n) else NA_real_
      data.frame(
        group = g, measure = m, n = n, mean = if (n) mean(x) else NA_real_,
        lower = if (n) mean(x) - half else NA_real_, upper = if (n) mean(x) + half else NA_real_,
        median = if (n) stats::median(x) else NA_real_, stringsAsFactors = FALSE
      )
    }))
  }))
  names(out)[names(out) == "group"] <- by
  out
}

#' Ratio of mean model size between two tools
#'
#' A quasi-Poisson regression of a count on the tool, crude or adjusted for
#' analysis type, log number of subjects and publication year. The ratio is
#' the second tool's mean count over the first's, with a Wald interval.
#'
#' @param d As from [modelSizeData()].
#' @param measure The count column.
#' @param adjust Adjust for `analysis`, `log(n_subjects)` and `year`.
#' @param tools The reference tool and the tool compared with it.
#' @param level Confidence level.
#'
#' @return A one-row data frame with `measure`, `adjusted`, `n` (papers
#'   used), `ratio`, `lower` and `upper`.
#' @export
modelSizeRatio <- function(d, measure, adjust = TRUE, tools = c("NONMEM", "Monolix"), level = 0.95) {
  vars <- c(measure, "tool", if (adjust) c("analysis", "n_subjects", "year"))
  d <- d[d$tool %in% tools, vars, drop = FALSE]
  d <- d[stats::complete.cases(d), , drop = FALSE]
  if (adjust) d <- d[d$n_subjects > 0, , drop = FALSE]
  d$tool <- factor(d$tool, levels = tools)
  terms <- "tool"
  if (adjust) {
    if (length(unique(d$analysis)) > 1) terms <- c(terms, "analysis")
    terms <- c(terms, "log(n_subjects)", "year")
  }
  fit <- stats::glm(stats::reformulate(terms, response = measure), data = d, family = stats::quasipoisson())
  est <- stats::coef(summary(fit))[paste0("tool", tools[2]), ]
  z <- stats::qnorm(1 - (1 - level) / 2)
  data.frame(
    measure = measure, adjusted = adjust, n = nrow(d), ratio = exp(est[["Estimate"]]),
    lower = exp(est[["Estimate"]] - z * est[["Std. Error"]]), upper = exp(est[["Estimate"]] + z * est[["Std. Error"]])
  )
}

#' Data size per tool
#'
#' @param d As from [modelSizeData()], with `tool`, `n_subjects` and `n_obs`.
#' @param minPapers Tools with fewer papers giving a number of subjects are
#'   left out.
#' @param caption Caption text.
#'
#' @return A ggplot: violins of subjects and observations per tool, on a log
#'   scale, with the median marked and the number of papers under each tool.
#'   One neutral fill for all tools, which are named on the axis.
#' @export
plotDataSize <- function(d, minPapers = 10, caption = NULL) {
  labels <- c(n_subjects = "Subjects in the model's dataset", n_obs = "Observations the model was fitted to")
  long <- do.call(rbind, lapply(names(labels), function(m) {
    data.frame(tool = d$tool, measure = labels[[m]], value = d[[m]], stringsAsFactors = FALSE)
  }))
  long <- long[!is.na(long$value) & long$value > 0, ]
  counts <- table(d$tool[!is.na(d$n_subjects)])
  keep <- names(counts)[counts >= minPapers]
  long <- long[long$tool %in% keep, ]
  order <- names(sort(counts[keep], decreasing = TRUE))
  long$tool <- factor(long$tool, levels = order)
  long$measure <- factor(long$measure, levels = unname(labels))
  n <- stats::aggregate(value ~ tool + measure, long, length)
  # one neutral fill: the tools are named on the axis, and a colour per tool would repeat "Other" grey
  ggplot2::ggplot(long, ggplot2::aes(tool, value)) +
    ggplot2::geom_violin(colour = NA, fill = "#7d8ca3", alpha = 0.8, scale = "width") +
    ggplot2::stat_summary(fun = stats::median, geom = "point", colour = ink[["primary"]], size = 1.8) +
    ggplot2::geom_text(
      data = n, ggplot2::aes(tool, 0.6, label = paste0("n=", value)), inherit.aes = FALSE,
      size = 2.8, colour = ink[["secondary"]]
    ) +
    ggplot2::facet_wrap(~measure, ncol = 1, scales = "free_y") +
    ggplot2::scale_y_log10(labels = function(x) format(x, big.mark = ",", scientific = FALSE, trim = TRUE)) +
    ggplot2::labs(x = NULL, y = NULL, caption = if (!is.null(caption)) wrapCaption(caption)) +
    themeLandscape()
}

#' Model size per tool, overall and for PK only models
#'
#' @param d As from [modelSizeData()], with `tool`, `analysis`, `fixed` and
#'   `random`.
#' @param caption Caption text.
#'
#' @return A ggplot: the distribution of fixed and random effects per tool
#'   (violins), with the mean and its 95% interval, for all models and for PK
#'   only models.
#' @export
plotModelSize <- function(d, caption = NULL) {
  labels <- c(fixed = "Fixed effects", random = "Random effects (IIV)")
  both <- rbind(
    cbind(d[c("tool", "analysis", "fixed", "random")], subgroup = "All models"),
    cbind(d[d$analysis %in% "pk_only", c("tool", "analysis", "fixed", "random")], subgroup = "PK only")
  )
  long <- do.call(rbind, lapply(names(labels), function(m) {
    data.frame(tool = both$tool, subgroup = both$subgroup, measure = labels[[m]], value = both[[m]])
  }))
  long <- long[!is.na(long$value), ]
  tools <- unique(d$tool)
  long$tool <- factor(long$tool, levels = tools)
  long$measure <- factor(long$measure, levels = unname(labels))
  long$subgroup <- factor(long$subgroup, levels = c("All models", "PK only"))
  means <- do.call(rbind, lapply(split(long, list(long$measure, long$subgroup), drop = TRUE), function(x) {
    s <- modelSizeSummary(data.frame(tool = x$tool, value = x$value), measures = "value")
    cbind(s[setdiff(names(s), "measure")], measure = x$measure[1], subgroup = x$subgroup[1])
  }))
  means$tool <- factor(means$tool, levels = tools)
  ggplot2::ggplot(long, ggplot2::aes(tool, value, fill = tool)) +
    ggplot2::geom_violin(colour = NA, alpha = 0.55, scale = "width", adjust = 1.5) +
    ggplot2::geom_pointrange(
      data = means, ggplot2::aes(tool, mean, ymin = lower, ymax = upper), inherit.aes = FALSE,
      colour = ink[["primary"]], size = 0.3, linewidth = 0.6
    ) +
    ggplot2::facet_grid(measure ~ subgroup, scales = "free_y", labeller = ggplot2::label_wrap_gen(22)) +
    ggplot2::scale_fill_manual(values = toolColours(tools), guide = "none") +
    ggplot2::labs(
      x = NULL, y = "Parameters in the final model", caption = if (!is.null(caption)) wrapCaption(caption)
    ) +
    themeLandscape()
}
