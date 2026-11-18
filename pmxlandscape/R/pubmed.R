#' First author's affiliation from PubMed XML
#'
#' For each record in a PubMed `efetch` XML result, the first listed
#' affiliation of the first author with a name. A group author
#' (`CollectiveName`) listed first is skipped. Some records pack several
#' institutions into one field, separated by semicolons; only the text before
#' the first semicolon is kept.
#'
#' @param xml The XML, as a string or an `xml_document`.
#'
#' @return A data frame with `pmid` and `affiliation` (`NA` where the record
#'   gives none).
#' @export
pubmedFirstAffiliation <- function(xml) {
  doc <- if (inherits(xml, "xml_document")) xml else xml2::read_xml(xml)
  records <- xml2::xml_find_all(doc, "//PubmedArticle")
  pmid <- xml2::xml_text(xml2::xml_find_first(records, "./MedlineCitation/PMID"))
  path <- ".//AuthorList/Author[LastName][1]/AffiliationInfo[1]/Affiliation"
  aff <- xml2::xml_text(xml2::xml_find_first(records, path))
  aff <- stringi::stri_trim_both(stringi::stri_replace_first_regex(collapseSpace(aff), ";.*$", ""))
  data.frame(pmid = pmid, affiliation = aff, stringsAsFactors = FALSE)
}

#' Every affiliation in PubMed XML, one row per institution
#'
#' For each record in a PubMed `efetch` XML result, the affiliations of all
#' authors. A field that packs several institutions together, separated by
#' semicolons, is split; a leading "and" and email addresses are dropped, and
#' an institution repeated within a record is kept once. Which author holds
#' which affiliation is not kept: the result answers which institutions a
#' record names.
#'
#' @inheritParams pubmedFirstAffiliation
#'
#' @return A data frame with `pmid` and `affiliation`; records without any
#'   affiliation have no row.
#' @export
pubmedAffiliations <- function(xml) {
  doc <- if (inherits(xml, "xml_document")) xml else xml2::read_xml(xml)
  records <- xml2::xml_find_all(doc, "//PubmedArticle")
  rows <- lapply(records, function(r) {
    pmid <- xml2::xml_text(xml2::xml_find_first(r, "./MedlineCitation/PMID"))
    aff <- xml2::xml_text(xml2::xml_find_all(r, ".//AuthorList/Author/AffiliationInfo/Affiliation"))
    aff <- splitInstitutions(aff)
    if (length(aff)) data.frame(pmid = pmid, affiliation = aff, stringsAsFactors = FALSE) else NULL
  })
  out <- do.call(rbind, rows)
  if (is.null(out)) data.frame(pmid = character(0), affiliation = character(0), stringsAsFactors = FALSE) else out
}

# Split affiliation fields at semicolons, drop a leading "and" and email addresses, keep each piece once.
splitInstitutions <- function(x) {
  x <- unlist(strsplit(collapseSpace(x[!is.na(x)]), ";", fixed = TRUE))
  x <- stringi::stri_replace_all_regex(x, "\\S+@\\S+", "")
  x <- stringi::stri_replace_first_regex(stringi::stri_trim_both(x), "^and\\s+", "")
  x <- stringi::stri_replace_all_regex(stringi::stri_trim_both(x), "\\s+([.,])$", "$1")
  unique(x[x != ""])
}
