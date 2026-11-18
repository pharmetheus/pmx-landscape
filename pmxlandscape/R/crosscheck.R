#' Body and methods text of a JATS article
#'
#' Europe PMC serves open-access full text as JATS XML. The body is all text
#' under `<body>`, which leaves out the reference list (in `<back>`). The
#' methods are the sections whose `sec-type` or title says "method", with the
#' sections nested in them.
#'
#' @param xml The article, as a string or an `xml_document`.
#'
#' @return A list with `body` and `methods` (`""` when there is no methods
#'   section), whitespace collapsed.
#' @export
jatsSections <- function(xml) {
  doc <- if (inherits(xml, "xml_document")) xml else xml2::read_xml(xml)
  doc <- xml2::xml_ns_strip(doc)
  body <- xml2::xml_find_all(doc, "//body")
  isMethods <- paste0(
    "(contains(translate(@sec-type, 'METHOD', 'method'), 'method') or ",
    "contains(translate(title, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), 'method'))"
  )
  methods <- xml2::xml_find_all(doc, paste0("//body//sec[", isMethods, " and not(ancestor::sec[", isMethods, "])]"))
  list(body = jatsText(body), methods = jatsText(methods))
}

sponsorStopWords <- c(
  "inc", "llc", "ltd", "corp", "corporation", "co", "company", "pharmaceuticals", "pharmaceutical", "pharma",
  "therapeutics", "biotech", "biotechnology", "biopharma", "biopharmaceuticals", "biosciences", "holdings", "usa",
  "us", "america", "americas", "ag", "gmbh", "sa", "ab", "plc", "and", "the", "&", "eli", "international", "global",
  "group", "limited", "lp", "north", "sub", "subsidiary", "of", "a",
  # openFDA abbreviations
  "pharms", "pharm", "therap", "theraps", "hlthcare", "hlth", "oncol", "labs", "intl", "inds", "biopharms", "bv", "nv",
  "spa", "as", "biotherap", "biotheraps"
)

#' Short name of a sponsor for affiliation searches
#'
#' Drops legal and generic words ("Inc", "Pharmaceuticals", "Therapeutics")
#' and keeps the first remaining word, or the first two when the first is
#' short ("Novo Nordisk"). Names are title-cased; hyphenated names keep their
#' parts ("Bristol-Myers").
#'
#' @param names Sponsor names, as in openFDA.
#' @param overrides Named character vector: sponsor name to short name, for
#'   names the rule gets wrong.
#'
#' @return The short names.
#' @export
sponsorToken <- function(names, overrides = character(0)) {
  one <- function(x) {
    if (x %in% names(overrides)) {
      return(unname(overrides[[x]]))
    }
    words <- strsplit(stringi::stri_replace_all_regex(x, "[,.()]", " "), "\\s+")[[1]]
    words <- words[words != "" & !tolower(words) %in% sponsorStopWords]
    if (length(words) == 0) {
      return(NA_character_)
    }
    keep <- if (nchar(words[1]) <= 4 && length(words) > 1) words[1:2] else words[1]
    title <- function(w) {
      paste(vapply(strsplit(w, "-")[[1]], function(p) {
        paste0(toupper(substr(p, 1, 1)), tolower(substr(p, 2, nchar(p))))
      }, character(1)), collapse = "-")
    }
    paste(vapply(keep, title, character(1)), collapse = " ")
  }
  unname(vapply(names, one, character(1)))
}

# Registry and catalogue prefixes that look like development codes but are not.
registryPrefixes <- c(
  "UNII", "CHEMBL", "SCHEMBL", "DTXSID", "DTXCID", "BDBM", "HY", "CS", "AKOS", "ZINC", "MFCD", "SY", "BCP", "EX",
  "KS", "AC", "AS", "MLS", "SMR", "STL", "BRD", "CCG", "NCGC", "HMS", "DB", "EINECS", "EC", "CAS", "NSC", "SR", "BIDD"
)

#' Development codes in a synonym list
#'
#' Keeps synonyms shaped like company development codes (letters, then 3 to 7
#' digits, as in "AMG 510", "LY3298176", "ABBV-951"), leaves out registry and
#' catalogue numbers, and keeps one spelling per code.
#'
#' @param synonyms Character vector, for example PubChem synonyms.
#'
#' @return The codes, in the order first seen.
#' @export
codeNames <- function(synonyms) {
  m <- stringi::stri_match_first_regex(synonyms, "^([A-Z]{1,5})[- ]?(\\d{3,7})[A-Z]?$")
  ok <- !is.na(m[, 1]) & !m[, 2] %in% registryPrefixes
  codes <- synonyms[ok]
  codes[!duplicated(gsub("[- ]", "", codes))]
}

saltWords <- c(
  "hydrochloride", "dihydrochloride", "hydrobromide", "sodium", "disodium", "potassium", "dipotassium", "mesylate",
  "dimesylate", "maleate", "tartrate", "bitartrate", "citrate", "fumarate", "hemifumarate", "succinate", "sulfate",
  "phosphate", "acetate", "besylate", "tosylate", "chloride", "bromide", "calcium", "magnesium", "dihydrate",
  "monohydrate", "hemihydrate", "trihydrate", "anhydrous", "hcl", "meglumine", "hydrate", "lysine", "tromethamine"
)

#' Names to search a drug by
#'
#' @param brand Brand name.
#' @param ingredient Active ingredient(s) as FDA lists them ("drospirenone and
#'   estetrol", "lecanemab-irmb", "tivozanib hydrochloride").
#' @param codes Candidate development codes; only code-shaped ones are kept
#'   ([codeNames()]).
#'
#' @return The brand, each ingredient without biologic suffix and salt words,
#'   and the codes, unique.
#' @export
drugSearchNames <- function(brand, ingredient, codes = character(0)) {
  parts <- strsplit(tolower(ingredient), "\\s+and\\s+|,\\s*|/")[[1]]
  parts <- vapply(parts, function(p) {
    p <- sub("-[a-z]{4}$", "", trimws(p)) # biologic suffix, as in lecanemab-irmb
    w <- strsplit(p, "\\s+")[[1]]
    paste(w[!w %in% saltWords], collapse = " ")
  }, character(1), USE.NAMES = FALSE)
  unique(c(brand, parts[parts != ""], codeNames(codes)))
}
