#' pmxlandscape: software mentions for the PMx Landscape
#'
#' Search, verification and summaries for the sources in the PMx Software
#' Landscape repository. Each source keeps its inputs under `sources/<name>/`
#' in the repository; the functions in this package take that folder as an
#' argument rather than bundling the data.
#'
#' @keywords internal
"_PACKAGE"

#' @importFrom ggplot2 .data
NULL

# Column names used inside ggplot2::aes()
utils::globalVariables(c(
  "Freq", "extrapolated", "family", "kind", "lag", "lower", "n", "ratio", "rel_lik", "series", "share", "software",
  "tool", "type", "upper", "value", "y", "year"
))
