#' Wilson score interval for a share
#'
#' @param x Number of successes.
#' @param n Number of trials.
#' @param level Confidence level.
#'
#' @return A data frame with `share`, `lower` and `upper` (`NA` when `n` is 0).
#' @export
wilson <- function(x, n, level = 0.95) {
  z <- stats::qnorm(1 - (1 - level) / 2)
  p <- ifelse(n > 0, x / n, NA_real_)
  centre <- (p + z^2 / (2 * n)) / (1 + z^2 / n)
  half <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / (1 + z^2 / n)
  data.frame(share = p, lower = pmax(centre - half, 0), upper = pmin(centre + half, 1))
}

#' Recall of a query on a reference set
#'
#' The share of the reference items the query found, by group, with a Wilson
#' interval. Used to measure the literature base query against reference sets
#' found without its terms (`sources/literature/refinement`).
#'
#' @param x Data frame of reference items with a logical column `found` and the
#'   grouping columns.
#' @param by Names of the grouping columns.
#' @param level Confidence level.
#'
#' @return A data frame with the groups, `reference` (items), `found`, `recall`,
#'   `lower` and `upper`.
#' @export
recallTable <- function(x, by, level = 0.95) {
  key <- interaction(x[by], drop = TRUE, lex.order = TRUE)
  g <- x[!duplicated(key), by, drop = FALSE]
  g <- g[order(g[[by[1]]]), , drop = FALSE]
  k <- interaction(g[by], drop = TRUE, lex.order = TRUE)
  ref <- as.integer(table(key)[as.character(k)])
  found <- as.integer(tapply(x$found, key, sum)[as.character(k)])
  w <- wilson(found, ref, level)
  out <- data.frame(g, reference = ref, found = found, recall = w$share, lower = w$lower, upper = w$upper)
  rownames(out) <- NULL
  out
}

#' Capture-recapture estimate of a population (Chapman)
#'
#' The bias-corrected Lincoln-Petersen estimate of how many items exist, from
#' two searches: `n1` items found by the first, `n2` by the second, `m` by
#' both. It assumes the two searches find items independently, which two
#' literature searches rarely do, so it is a rough estimate.
#'
#' @param n1,n2 Items found by each search.
#' @param m Items found by both.
#' @param level Confidence level of the normal-approximation interval.
#'
#' @return A data frame with `estimate`, `se`, `lower` and `upper`.
#' @export
chapman <- function(n1, n2, m, level = 0.95) {
  if (any(m > pmin(n1, n2))) stop("the overlap m cannot exceed either search's count")
  est <- (n1 + 1) * (n2 + 1) / (m + 1) - 1
  se <- sqrt((n1 + 1) * (n2 + 1) * (n1 - m) * (n2 - m) / ((m + 1)^2 * (m + 2)))
  z <- stats::qnorm(1 - (1 - level) / 2)
  data.frame(estimate = est, se = se, lower = est - z * se, upper = est + z * se)
}

#' Recall of a query estimated from samples of two strata
#'
#' A reference set is split into the papers the query found (`nIn`) and those
#' it missed (`nOut`); a sample of each stratum is read for relevance (`xIn`
#' relevant of `sIn` read, `xOut` of `sOut`). The recall among relevant papers
#' is `nIn * pIn / (nIn * pIn + nOut * pOut)`. The interval comes from drawing
#' each stratum's share from its Jeffreys posterior, Beta(x + 1/2, s - x + 1/2).
#'
#' @param nIn,nOut Papers in each stratum of the reference set.
#' @param xIn,xOut Relevant papers in each stratum's sample.
#' @param sIn,sOut Papers read in each stratum's sample.
#' @param level Interval level.
#' @param draws Number of draws for the interval.
#' @param seed Seed for the draws, so the interval is the same on every run.
#'
#' @return A data frame with `relevant` (estimated relevant papers in the
#'   reference set), `recall`, `lower` and `upper`.
#' @export
stratifiedRecall <- function(nIn, xIn, sIn, nOut, xOut, sOut, level = 0.95, draws = 10000, seed = 20261019) {
  pIn <- xIn / sIn
  pOut <- if (sOut > 0) xOut / sOut else 0
  est <- nIn * pIn / (nIn * pIn + nOut * pOut)
  # the caller's random stream is left as it was
  env <- globalenv()
  old <- if (exists(".Random.seed", envir = env)) get(".Random.seed", envir = env) else NULL
  on.exit(if (is.null(old)) rm(".Random.seed", envir = env) else assign(".Random.seed", old, envir = env))
  set.seed(seed)
  dIn <- stats::rbeta(draws, xIn + 0.5, sIn - xIn + 0.5)
  dOut <- if (sOut > 0) stats::rbeta(draws, xOut + 0.5, sOut - xOut + 0.5) else rep(0, draws)
  r <- nIn * dIn / (nIn * dIn + nOut * dOut)
  q <- stats::quantile(r, c((1 - level) / 2, 1 - (1 - level) / 2), names = FALSE)
  data.frame(relevant = nIn * pIn + nOut * pOut, recall = est, lower = q[1], upper = q[2])
}
