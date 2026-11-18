#' Shares of PAGE abstracts naming each estimation tool
#'
#' Counts, per affiliation group and meeting year, the abstracts naming each
#' estimation tool family: in the abstract, or else in its PDF where the hit
#' was read and decided "used". Software Demonstration abstracts are left out
#' by default, being about a tool rather than its use.
#'
#' @param abstracts PAGE results, as in `sources/page/results/page_abstracts.csv`.
#' @param groups Named list of affiliation types per group; `NULL` means all
#'   abstracts.
#' @param excludeDemos Leave out the Software Demonstration session.
#'
#' Abstracts whose PDF had to be searched but could not be read
#' (`estimation_source == "unknown"`) are left out, since whether they name a
#' tool is not known.
#'
#' @return One row per group, year and family with `n` (abstracts naming the
#'   family), `n_any` (abstracts naming any estimation tool), `n_abstracts`,
#'   `share` (`n / n_any`, comparable to the FDA share of identifiable tools)
#'   and `share_all` (`n / n_abstracts`). Stops if any PDF hit is still
#'   pending a decision.
#' @export
pageShares <- function(abstracts, groups = list(all = NULL, sponsor = c("industry", "CRO"), academia = "academia"),
                       excludeDemos = TRUE) {
  pending <- sum(abstracts$estimation_source == "pending")
  if (pending > 0) stop(pending, " abstracts have PDF hits pending a decision; record them in pdf_decisions.csv first")
  unknown <- abstracts$estimation_source == "unknown"
  if (any(unknown)) message(sum(unknown), " abstracts with an unreadable PDF are left out")
  abstracts <- abstracts[!unknown, , drop = FALSE]
  if (excludeDemos) abstracts <- abstracts[!(abstracts$software_demo %in% TRUE), , drop = FALSE]
  # read.csv() turns an all-empty column into logical NA
  blank <- function(x) ifelse(is.na(x), "", as.character(x))
  estimation <- blank(abstracts$estimation)
  tools <- ifelse(estimation != "", estimation, blank(abstracts$pdf_estimation))
  tools <- lapply(strsplit(tools, "; ", fixed = TRUE), function(x) x[x != ""])
  out <- lapply(names(groups), function(g) {
    inGroup <- if (is.null(groups[[g]])) rep(TRUE, nrow(abstracts)) else abstracts$affiliation_type %in% groups[[g]]
    families <- unique(unlist(tools[inGroup]))
    do.call(rbind, lapply(sort(unique(abstracts$year[inGroup])), function(y) {
      rows <- which(inGroup & abstracts$year == y)
      n <- vapply(families, function(f) sum(vapply(tools[rows], function(t) f %in% t, logical(1))), integer(1))
      data.frame(
        group = g, year = as.integer(y), family = families, n = unname(n),
        n_any = sum(lengths(tools[rows]) > 0), n_abstracts = length(rows), stringsAsFactors = FALSE
      )
    }))
  })
  out <- do.call(rbind, out)
  out$share <- out$n / out$n_any
  out$share_all <- out$n / out$n_abstracts
  out
}

#' Sponsor tool counts per FDA approval year
#'
#' @param results The FDA results table, as from [fdaReadResults()].
#'
#' @return One row per approval year and sponsor tool family with `n` (drugs
#'   using the family) and `n_any` (drugs with an identifiable tool, stated or
#'   indirect).
#' @export
fdaToolCounts <- function(results) {
  stated <- startsWith(results$category, "Tool stated")
  families <- unique(results$sponsor_tool_family[stated])
  years <- sort(unique(as.integer(results$year)))
  out <- expand.grid(family = families, year = years, stringsAsFactors = FALSE)[c("year", "family")]
  out$n <- mapply(function(y, f) {
    sum(stated & results$year == y & results$sponsor_tool_family == f)
  }, out$year, out$family)
  out$n_any <- vapply(out$year, function(y) sum(stated & results$year == y), integer(1))
  out
}

#' Logistic trend of one tool's share over time
#'
#' Fits `logit(share) = a + b * year` to yearly counts, with a quasi-binomial
#' dispersion so the intervals allow for year-to-year noise beyond binomial.
#'
#' @param counts Data frame with `year`, `family`, `n` and `n_any`, as from
#'   [pageShares()] (one group) or [fdaToolCounts()].
#' @param family The tool family.
#'
#' @return A list of class `pmxTrend` with the fit, the family and the range of
#'   years fitted.
#' @export
fitTrend <- function(counts, family) {
  d <- counts[counts$family == family, , drop = FALSE]
  if (nrow(d) < 3) stop("Need at least 3 years of counts for ", family)
  fit <- stats::glm(cbind(n, n_any - n) ~ year, family = stats::quasibinomial(), data = d)
  structure(list(fit = fit, family = family, years = range(d$year)), class = "pmxTrend")
}

trendLink <- function(trend, years) {
  stats::predict(trend$fit, newdata = data.frame(year = years), type = "link", se.fit = TRUE)
}

#' How many years FDA submissions lag behind PAGE
#'
#' Assumes that the share of a tool among FDA approvals in year t equals the
#' PAGE trend at year t - L, with no other offset, and gives the binomial
#' log-likelihood of the FDA counts for each lag L. Exploratory: with a
#' separate level for the FDA series, a shift in time along a logit-linear
#' trend could not be told from a shift in level, so the lag is identified
#' only under this assumption.
#'
#' @param fdaCounts FDA counts, as from [fdaToolCounts()].
#' @param trend PAGE trend, as from [fitTrend()].
#' @param lags Lags to evaluate, in years.
#' @param family The tool family; by default the trend's.
#'
#' @return One row per lag with `loglik`, `rel_lik` (likelihood relative to
#'   the best lag) and `extrapolated` (`TRUE` if any year t - L lies outside
#'   the PAGE years the trend was fitted on).
#' @export
estimateLag <- function(fdaCounts, trend, lags = 0:5, family = trend$family) {
  d <- fdaCounts[fdaCounts$family == family, , drop = FALSE]
  prof <- do.call(rbind, lapply(lags, function(lag) {
    source <- d$year - lag
    p <- stats::plogis(trendLink(trend, source)$fit)
    data.frame(
      lag = lag, loglik = sum(stats::dbinom(d$n, d$n_any, p, log = TRUE)),
      extrapolated = any(source < trend$years[1] | source > trend$years[2])
    )
  }))
  prof$rel_lik <- exp(prof$loglik - max(prof$loglik))
  prof[c("lag", "loglik", "rel_lik", "extrapolated")]
}

#' Projected FDA shares from the PAGE trend
#'
#' The share expected among FDA approvals in each year, read off the PAGE
#' trend `lag` years earlier.
#'
#' @param trend PAGE trend, as from [fitTrend()].
#' @param lag Lag in years, as from [estimateLag()].
#' @param years Approval years to project.
#' @param level Confidence level of the interval.
#'
#' @return One row per year with `share`, `lower`, `upper` and `extrapolated`
#'   (`TRUE` when year - lag lies outside the PAGE years fitted).
#' @export
projectShares <- function(trend, lag, years, level = 0.95) {
  source <- years - lag
  link <- trendLink(trend, source)
  z <- stats::qnorm(1 - (1 - level) / 2)
  data.frame(
    year = years, share = stats::plogis(link$fit), lower = stats::plogis(link$fit - z * link$se.fit),
    upper = stats::plogis(link$fit + z * link$se.fit),
    extrapolated = source < trend$years[1] | source > trend$years[2]
  )
}

#' Literature shares from stored IDs
#'
#' Tool shares per source and year from the IDs the literature run stores:
#' among all base-set papers (`share_all`) and among the papers naming at least
#' one estimation tool (`share`), the latter comparable with the FDA share of
#' drugs with an identifiable tool. A paper can name several tools, so `share`
#' can sum to more than 1.
#'
#' @param ids As in `sources/literature/results/ids.csv.gz`: `source`, `year`,
#'   `software` (`"All (base set)"` for the base set) and `id`.
#' @param estimation The estimation tool families.
#' @param group Optional named vector: paper id to group (for example the
#'   first author's affiliation type); papers without a group are dropped.
#' @param exclude Optional IDs to remove from the base set, for example papers
#'   read and found not to report a pharmacometric analysis of their own. Only
#'   papers naming no estimation tool can be excluded, unless `excludeNamed`;
#'   IDs not in the base set are ignored.
#' @param excludeNamed `TRUE` when every paper was read for relevance (the
#'   relevance codebook version 2, from 2026-10-20), so that papers naming a
#'   tool can be excluded too, and their tools leave the counts.
#'
#' @return One row per source, year, group (if given) and estimation family
#'   with `n`, `n_any`, `base_n`, `share` and `share_all`.
#' @export
literatureShares <- function(ids, estimation, group = NULL, exclude = NULL, excludeNamed = FALSE) {
  ids$id <- as.character(ids$id)
  if (length(exclude) > 0) {
    named <- intersect(exclude, ids$id[ids$software %in% estimation])
    if (length(named) > 0 && !excludeNamed) {
      stop("An excluded paper names an estimation tool: ", paste(named, collapse = ", "))
    }
    ids <- ids[!ids$id %in% exclude, , drop = FALSE]
  }
  ids$group <- if (is.null(group)) "all" else unname(group[ids$id])
  ids <- ids[!is.na(ids$group), , drop = FALSE]
  cells <- unique(ids[c("source", "year", "group")])
  # a family named anywhere in a source and group is reported in all its years, as 0 where not named
  named <- split(ids$software[ids$software %in% estimation], paste(ids$source, ids$group)[ids$software %in% estimation])
  out <- do.call(rbind, lapply(seq_len(nrow(cells)), function(i) {
    d <- ids[ids$source == cells$source[i] & ids$year == cells$year[i] & ids$group == cells$group[i], , drop = FALSE]
    base <- unique(d$id[d$software == "All (base set)"])
    tool <- d[d$software %in% estimation & d$id %in% base, , drop = FALSE]
    fams <- intersect(estimation, unique(named[[paste(cells$source[i], cells$group[i])]]))
    if (length(fams) == 0) {
      return(NULL)
    }
    data.frame(
      source = cells$source[i], year = cells$year[i], group = cells$group[i], software = fams,
      n = vapply(fams, function(f) length(unique(tool$id[tool$software == f])), integer(1), USE.NAMES = FALSE),
      n_any = length(unique(tool$id)), base_n = length(base), stringsAsFactors = FALSE
    )
  }))
  out$share <- out$n / out$n_any
  out$share_all <- out$n / out$base_n
  out <- out[order(out$source, out$group, out$software, out$year), ]
  if (is.null(group)) out$group <- NULL
  rownames(out) <- NULL
  out
}

#' Counts and shares per year as a table
#'
#' @param shares Data frame with `year`, `family`, `n` (items naming the
#'   family), `n_any` (items naming any estimation tool) and `total` (all
#'   items), one row per year and family.
#' @param totalLabel,anyLabel Row labels for the totals.
#' @param families Row order; by default by total count.
#'
#' @return A data frame with a first column of row labels and one column per
#'   year: the total, the items naming a tool with their share of the total,
#'   and each family's count with its share of the items naming a tool.
#' @export
shareTable <- function(shares, totalLabel = "All", anyLabel = "Naming an estimation tool", families = NULL) {
  years <- sort(unique(shares$year))
  if (is.null(families)) families <- names(sort(tapply(shares$n, shares$family, sum), decreasing = TRUE))
  cellPct <- function(n, d) {
    p <- ifelse(n / d < 0.005, "<1", formatC(100 * n / d, format = "f", digits = 0))
    ifelse(n == 0, "0", sprintf("%d (%s%%)", n, p))
  }
  cols <- lapply(years, function(y) {
    d <- shares[shares$year == y, , drop = FALSE]
    total <- d$total[1]
    nAny <- d$n_any[1]
    n <- vapply(families, function(f) if (f %in% d$family) as.integer(d$n[d$family == f][1]) else 0L, integer(1))
    c(as.character(total), cellPct(nAny, total), cellPct(n, nAny))
  })
  out <- data.frame(c(totalLabel, anyLabel, families), stringsAsFactors = FALSE)
  names(out) <- " "
  for (i in seq_along(years)) out[[as.character(years[i])]] <- cols[[i]]
  out
}

#' Papers using each tool, as literature IDs
#'
#' The literature's second series (Niclas, 2026-10-18): the base set of `ids`
#' with, for each paper, the tools the tool use classification read or ruled
#' `used`, in the format of `sources/literature/results/ids.csv.gz`, so
#' [literatureShares()] reads it as it reads the naming series.
#'
#' @param ids Literature IDs with `source`, `year`, `software` and `id`; only
#'   the base-set rows (`"All (base set)"`) are used.
#' @param tags Tool use tags with `source` (`PubMed`, `Europe PMC`),
#'   `item_id`, `label` and `value`.
#'
#' @return The base-set rows of `ids` and one row per paper and used tool.
#' @export
literatureUsedIds <- function(ids, tags) {
  labels <- c("PubMed" = "PubMed (title/abstract)", "Europe PMC" = "Europe PMC (full text)")
  base <- ids[ids$software == "All (base set)", , drop = FALSE]
  t <- tags[tags$value == "used" & tags$source %in% names(labels), , drop = FALSE]
  t$source <- unname(labels[t$source])
  k <- match(paste(t$source, t$item_id), paste(base$source, base$id))
  t <- t[!is.na(k), , drop = FALSE]
  used <- data.frame(source = t$source, year = base$year[k[!is.na(k)]], software = t$label, id = t$item_id)
  out <- rbind(base[c("source", "year", "software", "id")], unique(used))
  rownames(out) <- NULL
  out
}
