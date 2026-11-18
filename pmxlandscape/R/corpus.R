# The corpus layer: one item table and one section table per source (docs/design.md).
# The committed tables carry IDs, URLs, sizes and hashes; the text itself stays in a local
# cache, except where it is in the public domain (FDA reviews, committed under sources/fda).

#' SHA-256 of texts
#'
#' @param x Character vector; each element is hashed as UTF-8 bytes.
#'
#' @return Hexadecimal digests, `NA` where `x` is `NA`.
#' @export
corpusHash <- function(x) {
  vapply(x, function(s) {
    if (is.na(s)) NA_character_ else digest::digest(enc2utf8(s), algo = "sha256", serialize = FALSE)
  }, character(1), USE.NAMES = FALSE)
}

#' Build a section table
#'
#' One row per piece of an item's text, in reading order. Missing text (`NA`) is
#' dropped; empty text is kept, so that an item's parts are all recorded.
#'
#' @param source Source name.
#' @param item_id The source's ID of each item.
#' @param section Name of the part (for example `title`, `abstract`, `body`, `review`).
#' @param part A finer label within the section (for FDA: document and page), or `""`.
#' @param src Where the text came from (`html`, `xml`, `text`, `ocr`, `pdf`).
#' @param text The text.
#'
#' @return A data frame with `source`, `item_id`, `seq` (position within the
#'   item), `section`, `part`, `src`, `nchar`, `hash` and `text`.
#' @export
corpusSections <- function(source, item_id, section, part, src, text) {
  d <- data.frame(
    source = source, item_id = as.character(item_id), section = section, part = part, src = src, text = text,
    stringsAsFactors = FALSE
  )
  d <- d[!is.na(d$text), , drop = FALSE]
  d$seq <- as.integer(stats::ave(seq_len(nrow(d)), d$item_id, FUN = seq_along))
  d$nchar <- nchar(d$text)
  d$hash <- corpusHash(d$text)
  rownames(d) <- NULL
  d[c("source", "item_id", "seq", "section", "part", "src", "nchar", "hash", "text")]
}

#' Build an item table
#'
#' @inheritParams corpusSections
#' @param year The year the item represents, by the source's rule.
#' @param url Where anyone can read the item.
#' @param coverage What text exists for the item.
#' @param retrieved When (and from what) the item was downloaded.
#' @param admitted_by For literature: the base query terms that admitted the item.
#' @param sections The item's section table (from [corpusSections()]); each
#'   item's `hash` is computed from its sections' names, parts and hashes, in
#'   order, and is `NA` for an item without text.
#' @param ... Further source-specific columns, added after the common ones.
#'
#' @return A data frame with `source`, `item_id`, `year`, `url`, `coverage`,
#'   `retrieved`, `admitted_by`, `hash` and any further columns.
#' @export
corpusItems <- function(source, item_id, year, url, coverage, retrieved, admitted_by = NA_character_, sections, ...) {
  it <- data.frame(
    source = source, item_id = as.character(item_id), year = as.integer(year), url = url, coverage = coverage,
    retrieved = retrieved, admitted_by = admitted_by, stringsAsFactors = FALSE
  )
  s <- sections[order(match(sections$item_id, it$item_id), sections$seq), ]
  sig <- vapply(split(paste(s$section, s$part, s$hash, sep = "\t"), factor(s$item_id, levels = unique(s$item_id))),
    paste,
    character(1),
    collapse = "\n"
  )
  it$hash <- unname(corpusHash(sig[it$item_id]))
  extra <- list(...)
  for (n in names(extra)) it[[n]] <- extra[[n]]
  it
}

#' Text of chosen sections, one string per item
#'
#' @param sections A section table with text.
#' @param use The sections to join.
#' @param sep Separator between sections.
#'
#' @return A data frame with `item_id` and `text`, for the items that have at
#'   least one of the sections, in order of first appearance.
#' @export
corpusText <- function(sections, use, sep = "\n") {
  s <- sections[sections$section %in% use, ]
  s <- s[order(match(s$item_id, unique(s$item_id)), s$seq), ]
  text <- vapply(split(s$text, factor(s$item_id, levels = unique(s$item_id))), paste, character(1), collapse = sep)
  data.frame(item_id = names(text), text = unname(text), stringsAsFactors = FALSE)
}

#' Write a source's corpus tables
#'
#' Writes `<root>/<name>/items.csv` and `<root>/<name>/sections.csv.gz`
#' (without the text) for committing, and the text to the local cache
#' `<root>/cache/<name>.rds`.
#'
#' @param x A list with `items` and `sections`, as the source readers return.
#' @param root The corpus folder.
#' @param name File name of the source (`page`, `pubmed`, `epmc`, `fda`).
#'
#' @return The paths written, invisibly.
#' @export
corpusWrite <- function(x, root, name) {
  dir.create(file.path(root, name), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(root, "cache"), showWarnings = FALSE)
  items <- file.path(root, name, "items.csv")
  sections <- file.path(root, name, "sections.csv.gz")
  cache <- file.path(root, "cache", paste0(name, ".rds"))
  utils::write.csv(x$items, items, row.names = FALSE, fileEncoding = "UTF-8")
  con <- gzfile(sections, "w", encoding = "UTF-8")
  utils::write.csv(x$sections[names(x$sections) != "text"], con, row.names = FALSE)
  close(con)
  saveRDS(x$sections, cache)
  invisible(c(items, sections, cache))
}

#' Read a source's corpus
#'
#' Reads the committed tables and the local text, and stops if any local text
#' does not hash to the committed value, so a classification never reads text
#' other than the text the tables describe.
#'
#' @inheritParams corpusWrite
#' @param sections The sections to return (all when `NULL`).
#'
#' @return A list with `items` (the committed item table) and `sections` (with
#'   `text`).
#' @export
corpusRead <- function(root, name, sections = NULL) {
  items <- utils::read.csv(file.path(root, name, "items.csv"),
    colClasses = c(item_id = "character", url = "character", retrieved = "character", admitted_by = "character"),
    encoding = "UTF-8"
  )
  committed <- utils::read.csv(file.path(root, name, "sections.csv.gz"),
    colClasses = c(item_id = "character", part = "character", hash = "character"), encoding = "UTF-8"
  )
  cache <- file.path(root, "cache", paste0(name, ".rds"))
  if (!file.exists(cache)) stop("No local text for ", name, " (", cache, "); rebuild the corpus first")
  local <- readRDS(cache)
  key <- function(d) paste(d$item_id, d$seq, sep = "#")
  have <- stats::setNames(corpusHash(local$text), key(local))
  bad <- sum(is.na(have[key(committed)]) | have[key(committed)] != committed$hash) +
    length(setdiff(names(have), key(committed)))
  if (bad > 0) {
    stop(bad, " section(s) of the local ", name, " text differ from the committed tables; rebuild the corpus")
  }
  if (!is.null(sections)) local <- local[local$section %in% sections, ]
  list(items = items, sections = local)
}

#' Title, abstract, keywords, authors and affiliations of PubMed records
#'
#' @param xml A PubMed efetch result (`PubmedArticleSet`), as a string or an
#'   `xml_document`.
#'
#' @return A data frame with one row per record: `pmid`, `title`, `abstract`
#'   (the `AbstractText` parts joined by spaces, `""` if none), `keywords` (MeSH
#'   descriptors then author keywords, joined by "; "), `authors` ("Surname
#'   Initials" or a group name, joined by "; ") and `affiliations` (each
#'   distinct affiliation once, in order, one per line).
#' @export
pubmedText <- function(xml) {
  doc <- if (inherits(xml, "xml_document")) xml else xml2::read_xml(xml)
  arts <- xml2::xml_find_all(doc, "//PubmedArticle")
  join <- function(a, path, sep) paste(xml2::xml_text(xml2::xml_find_all(a, path)), collapse = sep)
  authors <- vapply(arts, function(a) {
    au <- xml2::xml_find_all(a, ".//AuthorList/Author")
    nm <- vapply(au, function(x) {
      last <- xml2::xml_find_first(x, "./LastName")
      if (inherits(last, "xml_missing")) {
        return(xml2::xml_text(xml2::xml_find_first(x, "./CollectiveName")))
      }
      ini <- xml2::xml_find_first(x, "./Initials")
      trimws(paste(xml2::xml_text(last), if (inherits(ini, "xml_missing")) "" else xml2::xml_text(ini)))
    }, character(1))
    paste(nm[!is.na(nm)], collapse = "; ")
  }, character(1))
  data.frame(
    pmid = xml2::xml_text(xml2::xml_find_first(arts, "./MedlineCitation/PMID")),
    title = xml2::xml_text(xml2::xml_find_first(arts, ".//ArticleTitle")),
    abstract = vapply(arts, join, character(1), ".//Abstract/AbstractText", " "),
    keywords = vapply(arts, join, character(1), ".//MeshHeadingList//DescriptorName | .//KeywordList/Keyword", "; "),
    authors = authors,
    affiliations = vapply(arts, function(a) {
      aff <- stripEmails(xml2::xml_text(xml2::xml_find_all(a, ".//AuthorList/Author/AffiliationInfo/Affiliation")))
      paste(unique(aff), collapse = "\n")
    }, character(1)),
    stringsAsFactors = FALSE
  )
}

#' Remove e-mail addresses from affiliation texts
#'
#' Affiliations sometimes carry an author's work e-mail address ("Electronic
#' address: name@uni.se"). The address names a person, not an organisation, so
#' it is removed, with a label in front of it ("Electronic address:", "E-mail:")
#' and the punctuation it leaves behind. Text without an address is returned
#' unchanged, so the function can be applied again without effect.
#'
#' @param x Character vector of affiliation texts.
#'
#' @return `x` without e-mail addresses.
#' @export
stripEmails <- function(x) {
  address <- "[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\\.[A-Za-z0-9-]+)*\\.[A-Za-z]{2,}"
  email <- "(?:[Ee]lectronic address|[Ee]-?mail(?: address(?:es)?)?)"
  label <- paste0("(?:(?:[Cc]orresponding author\\s*)?", email, "\\s*:?\\s*|[Cc]orresponding author\\s*:?\\s*)?")
  hit <- stringi::stri_detect_regex(x, address) %in% TRUE
  # Mark each removed address, then tidy only around the marks: an emptied bracket goes, and of
  # the punctuation on either side of a mark one is kept
  y <- stringi::stri_replace_all_regex(x[hit], paste0(label, address, "(?:\\s*[;,]\\s*", address, ")*"), "\u0001")
  y <- stringi::stri_replace_all_regex(y, "[ \\t]*\\(\\s*\u0001\\s*\\)", "")
  y <- stringi::stri_replace_all_regex(y, "([.,;:])[ \\t]*\u0001[ \\t]*[.,;]?", "$1")
  x[hit] <- stringi::stri_replace_all_regex(y, "[ \\t]*\u0001[ \\t]*([.,;]?)", "$1")
  x
}

#' Each author's affiliations in PubMed records, by position
#'
#' Names are not returned: an author is identified only by its position in the
#' author list (collective names count as authors).
#'
#' @inheritParams pubmedText
#'
#' @return A data frame with one row per author: `pmid`, `author` (1, 2, ...)
#'   and `affiliation` (the author's affiliations, one per line, `""` if none).
#' @export
pubmedAuthorAffiliations <- function(xml) {
  doc <- if (inherits(xml, "xml_document")) xml else xml2::read_xml(xml)
  arts <- xml2::xml_find_all(doc, "//PubmedArticle")
  out <- lapply(arts, function(a) {
    au <- xml2::xml_find_all(a, ".//AuthorList/Author")
    if (length(au) == 0) {
      return(NULL)
    }
    data.frame(
      pmid = xml2::xml_text(xml2::xml_find_first(a, "./MedlineCitation/PMID")),
      author = seq_along(au),
      affiliation = vapply(au, function(x) {
        paste(stripEmails(xml2::xml_text(xml2::xml_find_all(x, "./AffiliationInfo/Affiliation"))), collapse = "\n")
      }, character(1)),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, out)
  if (is.null(out)) out <- data.frame(pmid = character(0), author = integer(0), affiliation = character(0))
  out
}

#' Each author's affiliations in Europe PMC core records, by position
#'
#' @param results The `resultList$result` list of a Europe PMC search with
#'   `resultType=core`, as [jsonlite::read_json()] returns it.
#'
#' @return A data frame with one row per author: `id` (`<source>:<id>`),
#'   `author` (1, 2, ...) and `affiliation` (one per line, `""` if none).
#'   Names are not returned.
#' @export
epmcAuthorAffiliations <- function(results) {
  out <- lapply(results, function(r) {
    au <- r$authorList$author
    if (length(au) == 0) {
      return(NULL)
    }
    data.frame(
      id = paste0(r$source, ":", r$id),
      author = seq_along(au),
      affiliation = vapply(au, function(x) {
        a <- x$authorAffiliationDetailsList$authorAffiliation
        paste(stripEmails(vapply(a, function(y) if (is.null(y$affiliation)) "" else y$affiliation, character(1))),
          collapse = "\n"
        )
      }, character(1)),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, out)
  if (is.null(out)) out <- data.frame(id = character(0), author = integer(0), affiliation = character(0))
  out
}

#' Author lists of Europe PMC core records
#'
#' @inheritParams epmcAuthorAffiliations
#'
#' @return A data frame with `id` (`<source>:<id>`) and `authors` (each
#'   author's `fullName`, joined by "; ", as PubMed's `authors` section), for
#'   records with an author list. Kept only in the local corpus cache, where
#'   it lets [affiliationTags()] keep author names out of what is stored.
#' @export
epmcAuthors <- function(results) {
  out <- lapply(results, function(r) {
    au <- r$authorList$author
    if (length(au) == 0) {
      return(NULL)
    }
    nm <- vapply(au, function(x) if (is.null(x$fullName)) "" else x$fullName, character(1))
    data.frame(
      id = paste0(r$source, ":", r$id), authors = paste(nm[nzchar(nm)], collapse = "; "), stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, out)
  if (is.null(out)) out <- data.frame(id = character(0), authors = character(0))
  out
}

#' Named parts of a JATS article
#'
#' Splits a Europe PMC full text into the parts the corpus keeps: `title`,
#' `abstract`, `keywords`, `body` (everything under `<body>`, tables and
#' captions included), `methods` (the outermost methods sections, a part of
#' the body, as in [jatsSections()]), `floats` (figures and tables placed
#' outside the body), `appendix` and `back` (acknowledgements, notes and
#' declarations). The reference list is left out.
#'
#' @param xml The article, as a string or an `xml_document`.
#'
#' @return A data frame with `section` and `text`, one row per part, `""` where
#'   the article lacks it.
#' @export
jatsParts <- function(xml) {
  doc <- if (inherits(xml, "xml_document")) xml else xml2::read_xml(xml)
  doc <- xml2::xml_ns_strip(doc)
  find <- function(path) xml2::xml_find_all(doc, path)
  s <- jatsSections(doc)
  data.frame(
    section = c("title", "abstract", "keywords", "body", "methods", "floats", "appendix", "back"),
    text = c(
      jatsText(find("//front//article-meta//title-group/article-title")[1]),
      jatsText(find("//front//abstract")),
      paste(stringi::stri_trim_both(collapseSpace(xml2::xml_text(find("//front//kwd")))), collapse = "; "),
      s$body,
      s$methods,
      jatsText(find("//floats-group")),
      jatsText(find("//back/app-group | //back/app")),
      jatsText(find("//back/*[not(self::ref-list) and not(self::app-group) and not(self::app)]"))
    ),
    stringsAsFactors = FALSE
  )
}

# All text under the nodes, each node's text nodes joined by spaces, whitespace collapsed.
jatsText <- function(nodes) {
  nodes <- nodes[!vapply(nodes, inherits, logical(1), "xml_missing")]
  if (length(nodes) == 0) {
    return("")
  }
  parts <- vapply(nodes, function(n) {
    paste(xml2::xml_text(xml2::xml_find_all(n, ".//text()")), collapse = " ")
  }, character(1))
  stringi::stri_trim_both(collapseSpace(paste(parts, collapse = " ")))
}

fileDate <- function(f) format(file.mtime(f), "%Y-%m-%d")

#' The PAGE corpus
#'
#' Reads cached abstract pages with [pageParseAbstract()]. Each abstract becomes
#' an item with the sections `title`, `authors`, `affiliations`, `body` and,
#' where its poster or slides PDF is cached, `poster` (one part per PDF page).
#' Pages without the abstract layout are skipped; an abstract number found in
#' more than one file keeps the first file.
#'
#' @param files The cached HTML files, in the order to read them.
#' @param urls The abstract URLs from the sitemaps; a file is matched to its URL
#'   by the name the PAGE run gives it.
#' @param posterDir Folder of cached poster PDFs, or `NULL` to leave posters out.
#' @param ocr Passed to [pdfPages()] for posters.
#'
#' @return A list with `items` (with the extra columns `session`,
#'   `software_demo` and `has_poster`, whether the page links a poster or slides; the link itself is
#'   left out, since its file name often carries an author's name), `sections`, `skipped` (files without the
#'   layout) and `duplicates` (files whose abstract number came earlier).
#' @export
pageCorpus <- function(files, urls = character(0), posterDir = NULL, ocr = TRUE) {
  p <- do.call(rbind, lapply(files, function(f) pageParseAbstract(xml2::read_html(f, encoding = "UTF-8"))))
  p$file <- files
  skipped <- basename(files[is.na(p$year)])
  p <- p[!is.na(p$year), ]
  duplicates <- basename(p$file[duplicated(p$abstract_no)])
  p <- p[!duplicated(p$abstract_no), ]
  id <- as.character(p$abstract_no)
  urlFile <- paste0(gsub("[^A-Za-z0-9-]", "_", basename(sub("/$", "", urls))), ".html")
  url <- urls[match(basename(p$file), urlFile)]
  n <- nrow(p)
  parts <- c("title", "authors", "affiliations", "body")
  sections <- corpusSections(
    "PAGE", rep(id, each = 4), rep(parts, n), "", "html",
    as.vector(rbind(p$title, p$authors, p$affiliations, p$body))
  )
  poster <- rep(FALSE, n)
  if (!is.null(posterDir)) {
    pdf <- ifelse(is.na(p$pdf_url), NA_character_, file.path(posterDir, basename(p$pdf_url)))
    has <- which(!is.na(pdf) & file.exists(pdf))
    extra <- lapply(has, function(i) {
      pg <- tryCatch(pdfPages(pdf[i], ocr = ocr), error = function(e) NULL)
      if (is.null(pg)) {
        return(NULL)
      }
      data.frame(item_id = id[i], part = sprintf("p%04d", pg$page), src = paste0("pdf ", pg$src), text = pg$text)
    })
    poster[has] <- !vapply(extra, is.null, logical(1))
    extra <- do.call(rbind, extra)
    if (!is.null(extra)) {
      cols <- c("item_id", "section", "part", "src", "text")
      s <- rbind(sections[cols], data.frame(extra[c("item_id", "part", "src", "text")], section = "poster")[cols])
      s <- s[order(match(s$item_id, id)), ]
      sections <- corpusSections("PAGE", s$item_id, s$section, s$part, s$src, s$text)
    }
  }
  items <- corpusItems("PAGE", id, p$year, url, ifelse(poster, "abstract page and poster", "abstract page"),
    fileDate(p$file),
    sections = sections, session = p$session, software_demo = p$software_demo, has_poster = !is.na(p$pdf_url)
  )
  list(items = items, sections = sections, skipped = skipped, duplicates = duplicates)
}

#' The PubMed corpus
#'
#' Reads cached efetch XML with [pubmedText()] and keeps the first record of
#' each PMID in the base set. Base-set PMIDs without a record get an item with
#' coverage `none`.
#'
#' @param files The cached XML files, in the order to read them.
#' @param base Data frame with the base set's `id` (PMID) and `year`.
#'
#' @return A list with `items` and `sections` (`title`, `abstract`, `keywords`,
#'   `authors`, `affiliations`, then one `author_affiliations` section per
#'   author, parts `a001`, `a002`, ..., from [pubmedAuthorAffiliations()]).
#' @export
pubmedCorpus <- function(files, base) {
  docs <- lapply(files, xml2::read_xml)
  rec <- do.call(rbind, lapply(seq_along(files), function(i) cbind(pubmedText(docs[[i]]), file = files[i])))
  aff <- do.call(rbind, lapply(seq_along(files), function(i) {
    cbind(pubmedAuthorAffiliations(docs[[i]]), file = files[i])
  }))
  rec <- rec[!duplicated(rec$pmid) & rec$pmid %in% base$id, ]
  aff <- aff[paste(aff$pmid, aff$file) %in% paste(rec$pmid, rec$file), ]
  base <- base[!duplicated(base$id), ]
  rec <- rec[order(match(rec$pmid, base$id)), ]
  parts <- c("title", "abstract", "keywords", "authors", "affiliations")
  s <- rbind(
    data.frame(
      item_id = rep(rec$pmid, each = length(parts)), section = rep(parts, nrow(rec)), part = "",
      text = as.vector(t(as.matrix(rec[parts])))
    ),
    data.frame(
      item_id = aff$pmid, section = rep("author_affiliations", nrow(aff)),
      part = sprintf("a%03d", aff$author), text = aff$affiliation
    )
  )
  s <- s[order(match(s$item_id, base$id)), ]
  sections <- corpusSections("PubMed", s$item_id, s$section, s$part, "xml", s$text)
  m <- match(base$id, rec$pmid)
  coverage <- ifelse(is.na(m), "none", ifelse(nzchar(rec$abstract[m]), "title and abstract", "title only"))
  items <- corpusItems("PubMed", base$id, base$year, paste0("https://pubmed.ncbi.nlm.nih.gov/", base$id, "/"), coverage,
    ifelse(is.na(m), NA_character_, fileDate(rec$file[m])),
    sections = sections
  )
  list(items = items, sections = sections)
}

#' The Europe PMC corpus
#'
#' Reads cached JATS full texts with [jatsParts()] and matches each to the base
#' set by its PMID (`MED:`) or PMCID (`PMC:`). A base-set paper without a full
#' text gets its title, abstract and keywords from its Europe PMC record when
#' `records` has it (coverage `title and abstract (record)`), and coverage
#' `none` otherwise.
#'
#' @param files The cached full-text files, in the order to read them.
#' @param base Data frame with the base set's `id` (`MED:<pmid>` or
#'   `PMC:<pmcid>`) and `year`.
#' @param records Optional data frame with the records' `id`, `title`,
#'   `abstract` and `keywords`.
#' @param affiliations Optional data frame of each author's affiliations, from
#'   [epmcAuthorAffiliations()] (`id`, `author`, `affiliation`); added to every
#'   base-set item as one `author_affiliations` section per author (parts `a001`,
#'   `a002`, ..., `src` `json`), after its other sections.
#' @param authors Optional data frame of author lists, from [epmcAuthors()]
#'   (`id`, `authors`); added as an `authors` section before the affiliations.
#'
#' @return A list with `items`, `sections` and `unreadable` (files that do not
#'   parse).
#' @export
epmcCorpus <- function(files, base, records = NULL, affiliations = NULL, authors = NULL) {
  base <- base[!duplicated(base$id), ]
  unreadable <- character(0)
  found <- lapply(files, function(f) {
    doc <- tryCatch(xml2::xml_ns_strip(xml2::read_xml(f)), error = function(e) NULL)
    if (is.null(doc)) {
      unreadable <<- c(unreadable, basename(f))
      return(NULL)
    }
    idOf <- function(type) {
      xml2::xml_text(xml2::xml_find_first(doc, sprintf("//front//article-id[@pub-id-type='%s']", type)))
    }
    hit <- match(c(paste0("MED:", idOf("pmid")), paste0("PMC:", idOf("pmcid"))), base$id)
    if (all(is.na(hit))) {
      return(NULL)
    }
    cbind(item_id = base$id[hit[!is.na(hit)][1]], jatsParts(doc), file = f)
  })
  s <- do.call(rbind, found)
  first <- s$file == s$file[match(s$item_id, s$item_id)]
  s <- s[first, ]
  s <- s[order(match(s$item_id, base$id)), ]
  fileOf <- stats::setNames(s$file, s$item_id)[!duplicated(s$item_id)]
  s <- data.frame(item_id = s$item_id, section = s$section, part = "", src = "xml", text = s$text)
  fromRecord <- character(0)
  if (!is.null(records)) {
    r <- records[records$id %in% setdiff(base$id, names(fileOf)) & !duplicated(records$id), ]
    fromRecord <- r$id
    parts <- c("title", "abstract", "keywords")
    s <- rbind(s, data.frame(
      item_id = rep(r$id, each = 3), section = rep(parts, nrow(r)), part = "", src = "json",
      text = as.vector(t(as.matrix(r[parts])))
    ))
  }
  if (!is.null(authors)) {
    a <- authors[authors$id %in% base$id & !duplicated(authors$id), ]
    s <- rbind(s, data.frame(
      item_id = a$id, section = rep("authors", nrow(a)), part = "", src = "json", text = a$authors
    ))
  }
  if (!is.null(affiliations)) {
    a <- affiliations[affiliations$id %in% base$id, ]
    a <- a[!duplicated(paste(a$id, a$author)), ]
    s <- rbind(s, data.frame(
      item_id = a$id, section = rep("author_affiliations", nrow(a)), part = sprintf("a%03d", a$author), src = "json",
      text = a$affiliation
    ))
  }
  s <- s[order(match(s$item_id, base$id)), ]
  sections <- corpusSections("Europe PMC", s$item_id, s$section, s$part, s$src, s$text)
  full <- base$id %in% names(fileOf)
  items <- corpusItems("Europe PMC", base$id, base$year,
    paste0("https://europepmc.org/article/", sub(":", "/", base$id, fixed = TRUE)),
    ifelse(full, "full text", ifelse(base$id %in% fromRecord, "title and abstract (record)", "none")),
    ifelse(full, fileDate(fileOf[base$id]), NA_character_),
    sections = sections
  )
  list(items = items, sections = sections, unreadable = unreadable)
}

#' The FDA corpus
#'
#' One item per drug (application) in the decision record, with one `review`
#' section per page of each review document, in `docs.json` order; the part
#' names the document and the PDF page, and `src` says whether the page is the
#' text layer or OCR (see [fdaReadPages()]). Applications in `docs.json`
#' without a row in the record are skipped.
#'
#' @inheritParams fdaYears
#'
#' @return A list with `items` (with the extra columns `drug` and `documents`,
#'   the review URLs), `sections` and `skipped`.
#' @export
fdaCorpus <- function(fdaDir) {
  results <- fdaReadResults(fdaDir)
  rows <- list()
  for (y in fdaYears(fdaDir)) {
    docs <- jsonlite::read_json(file.path(fdaDir, "data", y, "docs.json"))
    for (appl in names(docs)) {
      for (d in docs[[appl]]) {
        pg <- fdaReadPages(fdaDir, y, d$text_file)
        stem <- sub("\\.txt$", "", basename(d$text_file))
        rows[[length(rows) + 1]] <- data.frame(
          item_id = appl, part = sprintf("%s p%04d", stem, pg$page), src = pg$src, text = pg$text, url = d$url
        )
      }
    }
  }
  s <- do.call(rbind, rows)
  ids <- unique(s$item_id)
  # years without a decision record (2026 on): year and drug from the year's frame
  framed <- do.call(rbind, lapply(fdaYears(fdaDir), function(y) {
    f <- file.path(fdaDir, "data", y, "frame.json")
    if (!file.exists(f)) {
      return(NULL)
    }
    fr <- jsonlite::read_json(f)
    data.frame(
      application = vapply(fr, function(e) as.character(e$appl %||% NA_character_), character(1)),
      drug = vapply(fr, function(e) as.character(e$name %||% NA_character_), character(1)), year = as.character(y)
    )
  }))
  if (!is.null(framed)) {
    framed <- framed[!is.na(framed$application) & !framed$application %in% results$application, ]
    results <- rbind(results[c("application", "drug", "year")], framed)
  }
  r <- results[match(ids, results$application), ]
  skipped <- ids[is.na(r$year) | r$year == ""]
  keep <- setdiff(ids, skipped)
  s <- s[s$item_id %in% keep, ]
  sections <- corpusSections("FDA", s$item_id, "review", s$part, s$src, s$text)
  r <- results[match(keep, results$application), ]
  hasOcr <- tapply(s$src == "ocr", factor(s$item_id, levels = keep), any)
  items <- corpusItems("FDA", keep, r$year,
    paste0("https://www.accessdata.fda.gov/scripts/cder/daf/index.cfm?event=overview.process&ApplNo=", keep),
    ifelse(hasOcr[keep], "review text and OCR", "review text"), "not recorded (original Python run)",
    sections = sections, drug = r$drug,
    documents = vapply(keep, function(a) paste(unique(s$url[s$item_id == a]), collapse = "; "), character(1),
      USE.NAMES = FALSE
    )
  )
  list(items = items, sections = sections, skipped = skipped)
}
