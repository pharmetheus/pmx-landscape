# Colours and shapes follow the tool family in every figure. The hues are steps
# of the dataviz reference palette; shapes and direct labels are the secondary
# encoding, so identity never rests on colour alone.
toolPalette <- c(
  NONMEM = "#2a78d6", Monolix = "#eb6834", "Phoenix NLME" = "#1baf7a", Pumas = "#4a3aa7", nlmixr = "#e87ba4",
  Other = "#8a8984"
)
toolShapes <- c(NONMEM = 16, Monolix = 17, "Phoenix NLME" = 15, Pumas = 18, nlmixr = 8, Other = 1)
ink <- c(primary = "#0b0b0b", secondary = "#52514e", grid = "#e8e7e3")

#' Colours of tool families
#'
#' @param families Tool family names.
#'
#' @return A named vector of colours, one per family. Families without a colour
#'   of their own get the colour of "Other".
#' @export
toolColours <- function(families) {
  cols <- toolPalette[families]
  cols[is.na(cols)] <- toolPalette[["Other"]]
  stats::setNames(unname(cols), families)
}

shapesFor <- function(families) {
  s <- toolShapes[families]
  s[is.na(s)] <- toolShapes[["Other"]]
  stats::setNames(unname(s), families)
}

themeLandscape <- function() {
  ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      plot.background = ggplot2::element_rect(fill = "#ffffff", colour = NA),
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.x = ggplot2::element_blank(),
      panel.grid.major.y = ggplot2::element_line(colour = ink[["grid"]], linewidth = 0.3),
      text = ggplot2::element_text(colour = ink[["primary"]]),
      axis.text = ggplot2::element_text(colour = ink[["secondary"]]),
      plot.title = ggplot2::element_text(face = "bold"),
      plot.caption = ggplot2::element_text(colour = ink[["secondary"]], hjust = 0),
      strip.text = ggplot2::element_text(face = "bold", hjust = 0),
      legend.position = "top", legend.justification = "left"
    )
}

# Direct labels at the last point of each series, in text ink beside the coloured
# marker, moved apart vertically where they would overlap.
endLabels <- function(data, x, y, label, facet = NULL) {
  keys <- c(label, facet)
  last <- do.call(rbind, lapply(split(data, data[keys], drop = TRUE), function(d) d[which.max(d[[x]]), ]))
  ggrepel::geom_text_repel(
    data = last, ggplot2::aes(x = .data[[x]], y = .data[[y]], label = .data[[label]]),
    hjust = 0, nudge_x = 0.25, direction = "y", size = 3, colour = ink[["secondary"]], segment.colour = ink[["grid"]],
    min.segment.length = 0, box.padding = 0.15, xlim = c(-Inf, Inf), inherit.aes = FALSE, seed = 1
  )
}

wrapCaption <- function(x, width = 120) paste(strwrap(x, width), collapse = "\n")

oneRowLegend <- function() {
  ggplot2::guides(
    colour = ggplot2::guide_legend(nrow = 1, byrow = TRUE), shape = ggplot2::guide_legend(nrow = 1, byrow = TRUE)
  )
}

#' The sponsor's data analysis software in FDA reviews, by approval year or period
#'
#' @param results The FDA results table, as from [fdaReadResults()].
#' @param by The column that gives each drug's bar: `year` (the approval year)
#'   or a period label such as the one from [fdaPeriodOf()].
#' @param scale `count` for the number of drugs, `percent` for each group's
#'   share of the bar's drugs.
#'
#' @return A ggplot: stacked bars of drugs per year or period by sponsor group
#'   (NONMEM, other tool, software not stated, no popPK analysis).
#' @export
plotFdaSponsor <- function(results, by = "year", scale = c("count", "percent")) {
  scale <- match.arg(scale)
  stated <- startsWith(results$category, "Tool stated")
  others <- sort(unique(results$sponsor_tool_family[stated & results$sponsor_tool_family != "NONMEM"]))
  otherLabel <- paste0("Other tool (", paste(others, collapse = ", "), ")")
  group <- ifelse(stated & results$sponsor_tool_family == "NONMEM", "NONMEM",
    ifelse(stated, otherLabel, ifelse(results$category == "popPK present, software not stated", "Software not stated",
      ifelse(results$category == "No popPK analysis in review", "No popPK analysis",
        ifelse(results$category == "No tool identified in review", "No tool identified", "Review not posted")
      )
    ))
  )
  levels <- c(
    "NONMEM", otherLabel, "Software not stated", "No popPK analysis", "No tool identified", "Review not posted"
  )
  d <- as.data.frame(table(x = results[[by]], group = factor(group, levels = levels)), stringsAsFactors = FALSE)
  d <- d[d$Freq > 0, ]
  d$x <- factor(d$x, levels = sort(unique(as.character(results[[by]]))))
  d$group <- factor(d$group, levels = levels)
  fills <- stats::setNames(c("#2a78d6", "#eb6834", "#1baf7a", "#4a3aa7", "#c9a227", "#8a8984"), levels)
  percent <- scale == "percent"
  ggplot2::ggplot(d, ggplot2::aes(x = x, y = Freq, fill = group)) +
    ggplot2::geom_col(
      position = if (percent) ggplot2::position_fill(reverse = TRUE) else ggplot2::position_stack(reverse = TRUE),
      width = 0.6, colour = "#ffffff", linewidth = 0.6
    ) +
    ggplot2::scale_fill_manual(values = fills, drop = TRUE, name = NULL) +
    (if (percent) ggplot2::scale_y_continuous(labels = function(v) paste0(round(100 * v), "%"), expand = c(0, 0))) +
    ggplot2::labs(
      title = "The sponsor's data analysis software in FDA reviews", x = NULL,
      y = if (percent) {
        paste("Share of the", if (by == "year") "year's" else "period's", "approvals")
      } else {
        "Drugs"
      },
      caption = paste(
        "CDER novel approvals by", if (by == "year") "approval year." else "twelve-month period of approval.",
        "Analyses were typically done 1 to 3 years earlier."
      )
    ) +
    themeLandscape() +
    # more than four groups do not fit one legend row
    (if (length(unique(d$group)) > 4) ggplot2::guides(fill = ggplot2::guide_legend(nrow = 2, byrow = TRUE)))
}

#' Sponsor popPK tools in FDA reviews
#'
#' @inheritParams plotFdaSponsor
#'
#' @return One row per sponsor tool family with `drugs`, `share` (of drugs with
#'   an identifiable tool) and `share_excluding_template` (the same without
#'   drugs whose only evidence is the FDA template phrase).
#' @export
fdaToolTable <- function(results) {
  stated <- results[startsWith(results$category, "Tool stated"), ]
  noTemplate <- stated[stated$evidence_strength != "indirect, template phrase only", ]
  tab <- as.data.frame(table(family = stated$sponsor_tool_family), stringsAsFactors = FALSE)
  tab <- tab[order(-tab$Freq, tab$family), ]
  data.frame(
    family = tab$family, drugs = as.integer(tab$Freq), share = tab$Freq / nrow(stated),
    share_excluding_template = vapply(tab$family, function(f) sum(noTemplate$sponsor_tool_family == f), integer(1)) /
      nrow(noTemplate),
    row.names = NULL, stringsAsFactors = FALSE
  )
}

#' Share of popPK papers naming each tool
#'
#' @param shares Literature shares, as from [literatureShares()].
#' @param measure `"share"` (of papers naming any estimation tool) or
#'   `"share_all"` (of all base-set papers).
#' @param minPapers Families with fewer papers than this in every year and
#'   source are left out, and named in the caption.
#' @param partialNote Caption text about the partial last year.
#' @param families Families to consider (for example the estimation tools);
#'   `NULL` for all.
#' @param denominator Caption text saying what the shares are of.
#' @param log Log scale for the shares (`TRUE`) or linear, from 0 to 100% in quarters.
#' @param title The chart's title, for example for papers using rather than naming each tool.
#'
#' @return A ggplot, one panel per source, PubMed first.
#' @export
plotLiteratureShares <- function(shares, measure = c("share", "share_all"), minPapers = 10,
                                 partialNote = "2026 is partial.", families = NULL, denominator = NULL, log = TRUE,
                                 title = "Share of pharmacometric papers naming each tool") {
  measure <- match.arg(measure)
  if (!is.null(families)) shares <- shares[shares$software %in% families, ]
  maxN <- tapply(shares$n, shares$software, max)
  keep <- names(maxN)[maxN >= minPapers]
  omitted <- setdiff(unique(shares$software), keep)
  d <- shares[shares$software %in% keep & shares$n > 0, ]
  d$share <- d[[measure]]
  d$software <- factor(d$software, levels = keep[order(-maxN[keep])])
  d$source <- factor(d$source, levels = sort(unique(d$source), decreasing = TRUE)) # PubMed, then Europe PMC
  caption <- paste(
    denominator, if (log) "Log scale.", partialNote,
    if (length(omitted) > 0) {
      paste0(paste(sort(omitted), collapse = ", "), " omitted: under ", minPapers, " papers a year.")
    }
  )
  ggplot2::ggplot(d, ggplot2::aes(year, share, colour = software, shape = software)) +
    ggplot2::geom_line(linewidth = 0.7) +
    ggplot2::geom_point(size = 2) +
    endLabels(d, "year", "share", "software", "source") +
    ggplot2::facet_wrap(~source) +
    (if (log) {
      ggplot2::scale_y_log10(
        breaks = c(0.001, 0.003, 0.01, 0.03, 0.1, 0.3, 0.5, 1),
        labels = function(x) paste0(format(100 * x, drop0trailing = TRUE, trim = TRUE), "%")
      )
    } else {
      ggplot2::scale_y_continuous(
        breaks = seq(0, 1, 0.25), labels = function(x) paste0(round(100 * x), "%"), limits = c(0, 1)
      )
    }) +
    ggplot2::scale_x_continuous(breaks = sort(unique(d$year)), expand = ggplot2::expansion(mult = c(0.03, 0.3))) +
    ggplot2::scale_colour_manual(values = toolColours(levels(d$software)), name = NULL) +
    ggplot2::scale_shape_manual(values = shapesFor(levels(d$software)), name = NULL) +
    ggplot2::labs(
      title = title, x = NULL,
      y = if (measure == "share") "Share of papers naming a tool" else "Share of papers", caption = wrapCaption(caption)
    ) +
    oneRowLegend() +
    themeLandscape()
}

#' Share of PAGE abstracts naming each tool
#'
#' @param shares PAGE shares, as from [pageShares()].
#' @param measure `"share_all"` (of all abstracts) or `"share"` (of abstracts
#'   naming any estimation tool).
#' @param minAbstracts Families named by fewer abstracts than this in every
#'   year and group are left out, and named in the caption.
#' @param groupLabels Panel titles for the groups.
#' @param caption Extra caption text.
#' @param title,xlab Plot title and x-axis label.
#' @param unit What is counted, for the caption.
#'
#' @return A ggplot, one panel per group.
#' @export
plotPageShares <- function(shares, measure = c("share_all", "share"), minAbstracts = 5,
                           groupLabels = c(all = "All abstracts", sponsor = "Industry and CRO", academia = "Academia"),
                           caption = NULL, title = "Share of PAGE abstracts naming each tool",
                           xlab = "PAGE meeting year", unit = "abstracts") {
  measure <- match.arg(measure)
  maxN <- tapply(shares$n, shares$family, max)
  keep <- names(maxN)[maxN >= minAbstracts]
  omitted <- setdiff(unique(shares$family), keep)
  d <- shares[shares$family %in% keep, ]
  d$y <- d[[measure]]
  d$family <- factor(d$family, levels = keep[order(-maxN[keep])])
  labels <- ifelse(d$group %in% names(groupLabels), groupLabels[d$group], d$group)
  d$panel <- factor(labels, levels = unique(c(groupLabels[names(groupLabels) %in% d$group], labels)))
  ylab <- if (measure == "share_all") "Share of abstracts" else "Share of abstracts naming a tool"
  ggplot2::ggplot(d, ggplot2::aes(year, y, colour = family, shape = family)) +
    ggplot2::geom_line(linewidth = 0.7) +
    ggplot2::geom_point(size = 2) +
    endLabels(d, "year", "y", "family", "panel") +
    ggplot2::facet_wrap(~panel) +
    ggplot2::scale_y_continuous(labels = function(x) paste0(round(100 * x), "%"), limits = c(0, NA)) +
    ggplot2::scale_x_continuous(
      breaks = seq(min(d$year), max(d$year), by = 2), expand = ggplot2::expansion(mult = c(0.03, 0.3))
    ) +
    ggplot2::scale_colour_manual(values = toolColours(levels(d$family)), name = NULL) +
    ggplot2::scale_shape_manual(values = shapesFor(levels(d$family)), name = NULL) +
    ggplot2::labs(
      title = title, x = xlab, y = ylab,
      caption = wrapCaption(paste(c(caption, if (length(omitted) > 0) {
        paste0(paste(sort(omitted), collapse = ", "), " omitted: fewer than ", minAbstracts, " ", unit, " a year.")
      }), collapse = " "))
    ) +
    oneRowLegend() +
    themeLandscape()
}

#' Likelihood profile of the lag
#'
#' @param profile As from [estimateLag()].
#'
#' @return A ggplot of the relative likelihood per lag; lags that need PAGE
#'   years outside the data are drawn open.
#' @export
plotLagProfile <- function(profile) {
  profile$kind <- ifelse(profile$extrapolated, "needs PAGE years outside the data", "within the PAGE years")
  ggplot2::ggplot(profile, ggplot2::aes(lag, rel_lik)) +
    ggplot2::geom_point(ggplot2::aes(shape = kind), size = 3, colour = ink[["primary"]]) +
    ggplot2::geom_line(colour = ink[["secondary"]], linewidth = 0.5) +
    ggplot2::scale_shape_manual(
      values = c("within the PAGE years" = 16, "needs PAGE years outside the data" = 1),
      name = NULL
    ) +
    ggplot2::scale_x_continuous(breaks = profile$lag) +
    ggplot2::scale_y_continuous(limits = c(0, 1)) +
    ggplot2::labs(x = "Lag (years)", y = "Relative likelihood") +
    themeLandscape()
}

#' PAGE trend, FDA shares and the projection
#'
#' @param page PAGE counts for one group and family (`year`, `n`, `n_any`).
#' @param trend PAGE trend, as from [fitTrend()].
#' @param fda FDA counts for the same family, as from [fdaToolCounts()].
#' @param lag Lag in years.
#' @param years Approval years to project.
#'
#' @return A ggplot of the share over time: PAGE (points and fitted trend),
#'   FDA approvals (points with 95% binomial intervals) and the FDA share
#'   projected from PAGE `lag` years earlier (line and band, dashed where it is
#'   an extrapolation).
#' @export
plotProjection <- function(page, trend, fda, lag, years) {
  page$series <- "PAGE, industry and CRO"
  page$share <- page$n / page$n_any
  fitted <- projectShares(trend, 0, seq(trend$years[1], trend$years[2]))
  fitted$series <- "PAGE, industry and CRO"
  fda$series <- "FDA approvals"
  fda$share <- fda$n / fda$n_any
  ci <- t(mapply(function(x, n) stats::binom.test(x, n)$conf.int, fda$n, fda$n_any))
  fda$lower <- ci[, 1]
  fda$upper <- ci[, 2]
  proj <- projectShares(trend, lag, years)
  proj$series <- "Projected from PAGE"
  cols <- c(
    "PAGE, industry and CRO" = ink[["secondary"]], "FDA approvals" = "#2a78d6", "Projected from PAGE" = "#eb6834"
  )
  ggplot2::ggplot(mapping = ggplot2::aes(year, share, colour = series)) +
    ggplot2::geom_ribbon(
      data = proj, ggplot2::aes(ymin = lower, ymax = upper, fill = series), colour = NA, alpha = 0.15,
      show.legend = FALSE
    ) +
    ggplot2::geom_line(data = fitted, linewidth = 0.7) +
    ggplot2::geom_point(data = page, size = 1.8, shape = 1) +
    ggplot2::geom_line(data = proj, ggplot2::aes(linetype = extrapolated), linewidth = 0.9) +
    ggplot2::geom_pointrange(data = fda, ggplot2::aes(ymin = lower, ymax = upper), size = 0.4) +
    ggplot2::scale_colour_manual(values = cols, name = NULL) +
    ggplot2::scale_fill_manual(values = cols, guide = "none") +
    ggplot2::scale_linetype_manual(values = c(`FALSE` = "solid", `TRUE` = "dashed"), guide = "none") +
    ggplot2::scale_y_continuous(labels = function(x) paste0(round(100 * x), "%")) +
    ggplot2::labs(x = NULL, y = paste("Share naming", trend$family)) +
    themeLandscape()
}

#' Methodology and applied abstracts per year
#'
#' @param counts As from [methodsApplied()].
#' @param caption Caption text.
#'
#' @return A ggplot: stacked bars of methodology and applied abstracts per
#'   year, one panel per group with its own scale.
#' @export
plotMethodsApplied <- function(counts, caption = NULL) {
  long <- rbind(
    data.frame(group = counts$group, year = counts$year, kind = "Methodology sessions", n = counts$methods),
    data.frame(group = counts$group, year = counts$year, kind = "Applied sessions", n = counts$applied)
  )
  long$kind <- factor(long$kind, levels = c("Methodology sessions", "Applied sessions"))
  long$group <- factor(long$group, levels = unique(counts$group))
  ggplot2::ggplot(long, ggplot2::aes(year, n, fill = kind)) +
    ggplot2::geom_col(width = 0.8, colour = "#ffffff", linewidth = 0.3) +
    ggplot2::facet_wrap(~group, scales = "free_y") +
    ggplot2::scale_y_continuous(breaks = function(l) unique(floor(pretty(l)))) +
    ggplot2::scale_fill_manual(
      values = c("Methodology sessions" = "#8a8984", "Applied sessions" = "#2a78d6"), name = NULL
    ) +
    ggplot2::labs(x = "PAGE meeting year", y = "Abstracts", caption = if (!is.null(caption)) wrapCaption(caption)) +
    themeLandscape()
}

#' Spread of analysis types per source
#'
#' @param spread Data frame with `source`, `type` and `share` (of the source's
#'   items), one row per source and type.
#' @param caption Caption text.
#'
#' @return A ggplot: horizontal bars of the share of items with each type,
#'   one panel per source, types in level order.
#' @export
plotTypeSpread <- function(spread, caption = NULL) {
  order <- c(lumpedTypes, "Any type other than PK only")
  spread$type <- factor(spread$type, levels = rev(unique(c(order[order %in% spread$type], spread$type))))
  spread$source <- factor(spread$source, levels = unique(spread$source))
  ggplot2::ggplot(spread, ggplot2::aes(share, type)) +
    ggplot2::geom_col(fill = "#2a78d6", width = 0.7) +
    ggplot2::geom_text(ggplot2::aes(label = paste0(round(100 * share), "%")),
      hjust = -0.15, size = 3, colour = ink[["secondary"]]
    ) +
    ggplot2::facet_wrap(~source, nrow = 1) +
    ggplot2::scale_x_continuous(
      breaks = c(0, 0.25, 0.5, 0.75), labels = function(x) paste0(round(100 * x), "%"),
      expand = ggplot2::expansion(mult = c(0, 0.25))
    ) +
    ggplot2::labs(
      x = "Share of items naming an estimation tool", y = NULL, caption = if (!is.null(caption)) wrapCaption(caption)
    ) +
    themeLandscape() +
    ggplot2::theme(
      panel.grid.major.y = ggplot2::element_blank(), panel.grid.major.x = ggplot2::element_line(colour = ink[["grid"]]),
      panel.spacing.x = ggplot2::unit(1.5, "lines")
    )
}

#' Over- and under-representation of analysis types per tool
#'
#' @param lift As from [typeLift()], for the tools and types to show.
#' @param caption Caption text.
#'
#' @return A ggplot: the ratio of each tool's share of a type to the other
#'   tools' share, with its 95% interval, on a log scale, one panel per type.
#' @export
plotTypeLift <- function(lift, caption = NULL) {
  lift <- lift[!is.na(lift$ratio), , drop = FALSE]
  tools <- unique(lift$tool)
  lift$tool <- factor(lift$tool, levels = rev(tools))
  lift$type <- factor(lift$type, levels = unique(c(lumpedTypes[lumpedTypes %in% lift$type], lift$type)))
  ggplot2::ggplot(lift, ggplot2::aes(ratio, tool, colour = tool)) +
    ggplot2::geom_vline(xintercept = 1, colour = ink[["secondary"]], linewidth = 0.4) +
    ggplot2::geom_pointrange(ggplot2::aes(xmin = lower, xmax = upper), size = 0.35, linewidth = 0.6) +
    ggplot2::facet_wrap(~type, ncol = 3, labeller = ggplot2::label_wrap_gen(28)) +
    ggplot2::scale_x_log10(breaks = c(0.1, 0.3, 1, 3, 10, 30), labels = function(x) format(x, drop0trailing = TRUE)) +
    ggplot2::scale_colour_manual(values = toolColours(tools), guide = "none") +
    ggplot2::labs(
      x = "Ratio: the tool's share of the type against the other tools' share (log scale)", y = NULL,
      caption = if (!is.null(caption)) wrapCaption(caption)
    ) +
    themeLandscape() +
    ggplot2::theme(
      panel.grid.major.x = ggplot2::element_line(colour = ink[["grid"]]), panel.grid.major.y = ggplot2::element_blank()
    )
}

#' Share of items mentioning and using AI or machine learning, per year
#'
#' @param shares Data frame as from [aiMlShares()].
#' @param caption Caption text.
#'
#' @return A ggplot: one panel per source, the percentage of the base set per
#'   year mentioning each group (solid) and using it (dashed), ML and AI in
#'   their own colours and shapes.
#' @export
plotAiMlShares <- function(shares, caption = NULL) {
  long <- rbind(
    data.frame(shares[c("source", "year", "group")], measure = "Mentioned or used", pct = 100 * shares$share_mentioned),
    data.frame(shares[c("source", "year", "group")], measure = "Used", pct = 100 * shares$share_used)
  )
  long$group <- factor(long$group, levels = c("ML", "AI"), labels = c("Machine learning", "AI"))
  long$measure <- factor(long$measure, levels = c("Mentioned or used", "Used"))
  long$source <- factor(long$source, levels = unique(shares$source))
  long$series <- interaction(long$group, long$measure)
  ggplot2::ggplot(long, ggplot2::aes(year, pct, colour = group, linetype = measure, group = series)) +
    ggplot2::geom_line(linewidth = 0.6) +
    ggplot2::geom_point(ggplot2::aes(shape = group), size = 1.4) +
    ggplot2::facet_wrap(~source, ncol = 1, scales = "free_y") +
    ggplot2::scale_colour_manual(values = c("Machine learning" = "#2a78d6", AI = "#eb6834"), name = NULL) +
    ggplot2::scale_shape_manual(values = c("Machine learning" = 16, AI = 17), name = NULL) +
    ggplot2::scale_linetype_manual(values = c("Mentioned or used" = "solid", Used = "22"), name = NULL) +
    ggplot2::labs(x = "Year", y = "Share of the base set (%)", caption = if (!is.null(caption)) wrapCaption(caption)) +
    themeLandscape()
}

#' Share of items using AI or machine learning per year, the sources together
#'
#' @inheritParams plotAiMlShares
#' @param years Years to show.
#'
#' @return A ggplot: one panel per group (machine learning, AI), the
#'   percentage of each source's base set read as using it, one line per
#'   source with its own colour and shape and a label at its last point.
#' @export
plotAiMlUsed <- function(shares, years, caption = NULL) {
  d <- shares[shares$year %in% years, ]
  d$pct <- 100 * d$share_used
  d$group <- factor(d$group, levels = c("ML", "AI"), labels = c("Machine learning", "AI"))
  d$source <- factor(d$source, levels = intersect(c("PAGE", "PubMed", "Europe PMC"), unique(d$source)))
  cols <- c(PAGE = "#008300", PubMed = "#4a3aa7", "Europe PMC" = "#e34948")
  ggplot2::ggplot(d, ggplot2::aes(year, pct, colour = source, group = source)) +
    ggplot2::geom_line(linewidth = 0.7) +
    ggplot2::geom_point(ggplot2::aes(shape = source), size = 2) +
    endLabels(d, "year", "pct", "source", facet = "group") +
    ggplot2::facet_wrap(~group) +
    ggplot2::scale_colour_manual(values = cols, name = NULL) +
    ggplot2::scale_shape_manual(values = c(PAGE = 16, PubMed = 17, "Europe PMC" = 15), name = NULL) +
    ggplot2::scale_x_continuous(
      breaks = rev(seq(max(d$year), min(d$year), by = -3)), expand = ggplot2::expansion(mult = c(0.03, 0.3))
    ) +
    ggplot2::coord_cartesian(clip = "off") +
    ggplot2::labs(
      x = NULL, y = "Share of the base set using it (%)", caption = if (!is.null(caption)) wrapCaption(caption)
    ) +
    themeLandscape()
}
