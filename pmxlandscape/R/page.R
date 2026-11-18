#' Parse a PAGE abstract page
#'
#' Splits an abstract page from page-meeting.org into its parts. The abstract
#' is the list of elements in `article div.content-cleanse`: authors,
#' affiliations, the body, a `References:` paragraph, the citation
#' (`Reference: PAGE 32 (2024) Abstr 11246`), the session and a link to a PDF
#' poster or presentation. Menus, headers and footers are not part of it.
#'
#' The layout was read from a handful of pages in September 2026; check new
#' meetings against it. Many PAGE 2025 abstracts give their reference list
#' without a `References:` heading, as a paragraph starting "[1] Author" or
#' "1. Surname, I.", sometimes appended to the last paragraph; the body is
#' cut where such a list starts.
#'
#' @param html The page, as a string or an `xml_document`.
#' @param baseUrl Used to make the PDF link absolute.
#'
#' @return A one-row data frame with `abstract_no`, `year`, `title`,
#'   `authors`, `affiliations`, `body` (with list items, without authors,
#'   affiliations and references), `session`, `software_demo` (`TRUE` for the
#'   Software Demonstration session, whose abstracts are about a tool rather
#'   than its use) and `pdf_url` (`NA` when the page links no PDF file). All
#'   are `NA` (and `software_demo` `FALSE`) if the page lacks the abstract
#'   layout.
#' @export
pageParseAbstract <- function(html, baseUrl = "https://www.page-meeting.org") {
  doc <- if (inherits(html, "xml_document")) html else xml2::read_html(html)
  out <- data.frame(
    abstract_no = NA_integer_, year = NA_integer_, title = NA_character_, authors = NA_character_,
    affiliations = NA_character_, body = NA_character_, session = NA_character_, software_demo = FALSE,
    pdf_url = NA_character_, stringsAsFactors = FALSE
  )
  box <- rvest::html_element(doc, "article div.content-cleanse")
  if (inherits(box, "xml_missing")) {
    return(out)
  }
  parts <- rvest::html_children(box)
  text <- stringi::stri_trim_both(collapseSpace(rvest::html_text2(parts)))
  parts <- parts[text != ""]
  text <- text[text != ""]

  citation <- which(stringi::stri_detect_regex(text, "^Reference:\\s*PAGE"))[1]
  references <- setdiff(which(stringi::stri_detect_regex(text, "^References?\\s*:")), citation)
  bodyEnd <- min(c(references, citation, length(text) + 1), na.rm = TRUE) - 1
  if (bodyEnd >= 3) out$body <- cutReferenceList(paste(text[3:bodyEnd], collapse = "\n"))
  if (length(text) >= 1) out$authors <- text[1]
  if (length(text) >= 2) out$affiliations <- stripEmails(text[2])
  if (!is.na(citation)) {
    m <- stringi::stri_match_first_regex(text[citation], "PAGE\\s*\\d+\\s*\\((\\d{4})\\)\\s*Abstr\\s*(\\d+)")
    out$year <- as.integer(m[, 2])
    out$abstract_no <- as.integer(m[, 3])
    following <- text[citation + 1]
    if (!is.na(following) && !startsWith(following, "PDF")) out$session <- following
  }
  demo <- stringi::stri_detect_regex(out$session, "software demonstration", case_insensitive = TRUE)
  out$software_demo <- demo %in% TRUE
  title <- rvest::html_element(doc, "h1")
  if (!inherits(title, "xml_missing")) out$title <- stringi::stri_trim_both(collapseSpace(rvest::html_text2(title)))
  links <- rvest::html_attr(rvest::html_elements(box, "a"), "href")
  pdf <- links[stringi::stri_detect_regex(links, "pdf_abstracts/[^/]+\\.pdf$", case_insensitive = TRUE) %in% TRUE]
  if (length(pdf) > 0) out$pdf_url <- xml2::url_absolute(pdf[1], baseUrl)
  out
}

# Cut a text where an unheaded reference list starts: "[1]" or "1." followed by an author in one of
# the forms reference lists use: surname and initials ("Raje N,", "Le Tourneau C,", "Macheras P."),
# initials and surname ("H Yun,", "S. Sudfeld et al."), or surname, comma, initials ("Ogami, C.").
# An inline "[1]" and item lists numbered [1], [2] ("[1] The IgG domain binds") do not match.
cutReferenceList <- function(text) {
  surname <- "\\p{Lu}[\\p{Ll}'-]+(?:\\s\\p{Lu}[\\p{Ll}'-]+)?"
  initials <- "\\p{Lu}{1,3}\\.?(?:\\s?\\p{Lu}\\.)?"
  author <- paste0(
    "(?:", surname, "\\s+", initials, "[,.]|", initials, "\\s+", surname, "(?:,|\\s+et al|\\s+and\\b)|",
    surname, ",\\s+", initials, ")"
  )
  start <- paste0("(?:^|(?<=\\s))(?:\\[1\\]|1\\.)\\s+", author)
  at <- stringi::stri_locate_first_regex(text, start)[1, 1]
  if (is.na(at)) text else stringi::stri_trim_right(substr(text, 1, at - 1))
}

#' Keep only the tools an abstract used
#'
#' Applies the role reading (`sources/page/role_decisions.csv`): of the tools an
#' abstract names, only those read as `used` count; a comparator or a tool
#' mentioned in passing does not. An abstract left without a used tool names
#' none (`estimation_source` `"none"`). Abstracts without a reading are
#' unchanged.
#'
#' @param abstracts PAGE results, as in `sources/page/results/page_abstracts.csv`.
#' @param decisions Data frame with `abstract_no` and `roles`, the latter as
#'   `Tool=role` pairs separated by ";" (roles `used`, `comparator`,
#'   `mentioned`).
#'
#' @return `abstracts` with `estimation` holding the used tools and
#'   `pdf_estimation` emptied where a reading applies.
#' @export
pageUsedTools <- function(abstracts, decisions) {
  pairs <- lapply(strsplit(decisions$roles, ";", fixed = TRUE), function(p) trimws(sub("\\s*=\\s*", "=", p)))
  roles <- unlist(lapply(pairs, function(p) sub("^.*=", "", p)))
  bad <- setdiff(roles, c("used", "comparator", "mentioned"))
  if (length(bad) > 0) stop("unknown role in the decisions: ", paste(unique(bad), collapse = ", "))
  used <- vapply(pairs, function(p) paste(sub("=[^=]*$", "", p[grepl("=used$", p)]), collapse = "; "), "")
  m <- match(as.character(abstracts$abstract_no), as.character(decisions$abstract_no))
  has <- !is.na(m)
  abstracts$estimation[has] <- used[m[has]]
  abstracts$pdf_estimation[has] <- ""
  abstracts$estimation_source[has & used[m] == ""] <- "none"
  abstracts
}

#' Apply the tool use classification to the PAGE abstracts
#'
#' Replaces the tools each abstract names in its body with what the tool use
#' tags (`classifications/tool_use/tags.csv`) say: with `used = TRUE`, only
#' the tools read or ruled `used`; with `used = FALSE`, every tool the body
#' names. An abstract whose body has no used tool keeps the tools of its poster
#' (`pdf_estimation`, decided in `sources/page/pdf_decisions.csv`) or names
#' none. Abstracts without tags are unchanged.
#'
#' @param abstracts PAGE results, as in `sources/page/results/page_abstracts.csv`.
#' @param tags Tool use tags with `source`, `item_id`, `label` and `value`.
#' @param used Whether to keep only the used tools.
#'
#' @return `abstracts` with `estimation`, `pdf_estimation` and
#'   `estimation_source` updated where tags apply.
#' @export
pageToolUse <- function(abstracts, tags, used = TRUE) {
  tags <- tags[tags$source == "PAGE", , drop = FALSE]
  all <- as.character(abstracts$abstract_no)
  tagged <- all %in% as.character(tags$item_id)
  keep <- if (used) tags[tags$value == "used", , drop = FALSE] else tags
  tools <- vapply(all, function(a) paste(unique(keep$label[keep$item_id == a]), collapse = "; "), "", USE.NAMES = FALSE)
  named <- tagged & nzchar(tools)
  noUse <- tagged & !nzchar(tools)
  pdf <- !is.na(abstracts$pdf_estimation) & nzchar(abstracts$pdf_estimation)
  abstracts$estimation[tagged] <- tools[tagged]
  abstracts$estimation_source[named] <- "abstract"
  abstracts$pdf_estimation[named] <- ""
  abstracts$estimation_source[noUse] <- ifelse(pdf[noUse], "pdf", "none")
  abstracts
}
