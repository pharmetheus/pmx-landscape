jatsXml <- '<?xml version="1.0"?>
<article><front><article-meta>
  <article-id pub-id-type="pmid">111</article-id><article-id pub-id-type="pmcid">PMC999</article-id>
  <title-group><article-title>An invented <italic>population</italic> model</article-title></title-group>
  <abstract><p>Background text.</p><p>Results text.</p></abstract>
  <kwd-group><kwd>pharmacometrics</kwd><kwd>NONMEM</kwd></kwd-group>
 </article-meta></front>
 <body>
  <sec><title>Introduction</title><p>Tools exist.</p></sec>
  <sec sec-type="methods"><title>Methods</title><p>Fitted in NONMEM 7.5.</p>
   <sec><title>Software</title><p>PsN was used.</p></sec></sec>
  <table-wrap><caption><p>Table 1</p></caption><table><tr><td>CL 5</td></tr></table></table-wrap>
 </body>
 <back>
  <ack><p>We thank Certara.</p></ack>
  <app-group><app><title>Appendix A</title><p>Control stream.</p></app></app-group>
  <ref-list><ref><mixed-citation>Beal SL. NONMEM users guide.</mixed-citation></ref></ref-list>
 </back>
 <floats-group><fig><caption><p>Figure 1 VPC</p></caption></fig></floats-group>
</article>'

pubmedArticles <- '<?xml version="1.0"?>
<PubmedArticleSet>
 <PubmedArticle><MedlineCitation><PMID Version="1">111</PMID>
  <Article><ArticleTitle>A <i>population</i> PK model</ArticleTitle>
   <Abstract><AbstractText Label="AIMS">To model.</AbstractText>
    <AbstractText Label="METHODS">NONMEM was used.</AbstractText></Abstract>
   <AuthorList><Author><LastName>First</LastName><Initials>A</Initials>
    <AffiliationInfo><Affiliation>Example University, Sweden.</Affiliation></AffiliationInfo></Author>
    <Author><LastName>Second</LastName><Initials>BC</Initials>
    <AffiliationInfo><Affiliation>Certara, USA.</Affiliation></AffiliationInfo></Author></AuthorList>
  </Article>
  <MeshHeadingList><MeshHeading><DescriptorName>Models, Biological</DescriptorName></MeshHeading></MeshHeadingList>
  <KeywordList><Keyword>pharmacometrics</Keyword></KeywordList>
 </MedlineCitation></PubmedArticle>
 <PubmedArticle><MedlineCitation><PMID Version="1">222</PMID>
  <Article><ArticleTitle>A letter without an abstract</ArticleTitle></Article>
 </MedlineCitation></PubmedArticle>
</PubmedArticleSet>'

test_that("corpusHash gives the SHA-256 of the UTF-8 text", {
  expect_equal(corpusHash("abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
  expect_equal(corpusHash(c("abc", "é")), c(corpusHash("abc"), corpusHash(enc2utf8("é"))))
  expect_true(is.na(corpusHash(NA_character_)))
})

test_that("corpusSections numbers the sections per item, drops missing text and keeps empty text", {
  s <- corpusSections(
    "PAGE", c("1", "1", "1", "2"), c("title", "body", "poster", "body"), "", "html",
    c("T", "", NA, "B2")
  )
  expect_equal(s$item_id, c("1", "1", "2"))
  expect_equal(s$seq, c(1L, 2L, 1L))
  expect_equal(s$section, c("title", "body", "body"))
  expect_equal(s$nchar, c(1L, 0L, 2L))
  expect_equal(s$hash, corpusHash(c("T", "", "B2")))
})

test_that("corpusItems hashes each item from its sections, in order", {
  s <- corpusSections("PAGE", c("1", "1", "2"), c("title", "body", "body"), "", "html", c("T", "B", "B2"))
  it <- corpusItems("PAGE", c("2", "1"), c(2020L, 2021L), c("u2", "u1"), "abstract page", "2026-09-26", sections = s)
  expect_equal(names(it)[1:8], c("source", "item_id", "year", "url", "coverage", "retrieved", "admitted_by", "hash"))
  expect_equal(it$item_id, c("2", "1"))
  s2 <- s
  s2$text[2] <- "changed"
  s2$hash <- corpusHash(s2$text)
  it2 <- corpusItems("PAGE", c("2", "1"), c(2020L, 2021L), c("u2", "u1"), "abstract page", "2026-09-26", sections = s2)
  expect_equal(it2$hash[1], it$hash[1])
  expect_false(it2$hash[2] == it$hash[2])
  expect_true(is.na(it$admitted_by[1]))
})

test_that("corpusText joins the chosen sections of each item in order", {
  s <- corpusSections(
    "PubMed", c("1", "1", "1", "2"), c("title", "keywords", "abstract", "title"), "", "xml",
    c("T1", "K", "A1", "T2")
  )
  t <- corpusText(s, c("title", "abstract"), sep = " ")
  expect_equal(t$item_id, c("1", "2"))
  expect_equal(t$text, c("T1 A1", "T2"))
})

test_that("pubmedText returns title, abstract, keywords, authors and affiliations per record", {
  p <- pubmedText(pubmedArticles)
  expect_equal(p$pmid, c("111", "222"))
  expect_equal(p$title, c("A population PK model", "A letter without an abstract"))
  expect_equal(p$abstract, c("To model. NONMEM was used.", ""))
  expect_equal(p$keywords[1], "Models, Biological; pharmacometrics")
  expect_equal(p$authors[1], "First A; Second BC")
  expect_equal(p$affiliations[1], "Example University, Sweden.\nCertara, USA.")
  expect_equal(p$affiliations[2], "")
})

test_that("jatsParts splits an article into named parts and leaves out the reference list", {
  p <- jatsParts(jatsXml)
  expect_equal(p$section, c("title", "abstract", "keywords", "body", "methods", "floats", "appendix", "back"))
  get <- function(s) p$text[p$section == s]
  expect_equal(get("title"), "An invented population model")
  expect_equal(get("keywords"), "pharmacometrics; NONMEM")
  expect_match(get("body"), "Tools exist.*NONMEM 7.5.*PsN was used.*CL 5")
  expect_equal(get("methods"), jatsSections(jatsXml)$methods)
  expect_equal(get("body"), jatsSections(jatsXml)$body)
  expect_equal(get("floats"), "Figure 1 VPC")
  expect_match(get("appendix"), "Control stream")
  expect_equal(get("back"), "We thank Certara.")
  expect_false(any(grepl("users guide", p$text)))
})

test_that("pageCorpus reads abstract pages into items and sections, with the URL from the sitemap", {
  dir <- withr::local_tempdir()
  writeLines(pageTwoAuthors, file.path(dir, "an-invented-abstract.html"))
  writeLines(pageOneAuthor, file.path(dir, "old-one.html"))
  writeLines("<html><body>no abstract here</body></html>", file.path(dir, "broken.html"))
  urls <- paste0("https://www.page-meeting.org/Abstracts/", c("an-invented-abstract", "old-one"), "/")
  x <- pageCorpus(list.files(dir, full.names = TRUE), urls = urls)
  expect_equal(sort(x$items$item_id), c("898", "99999"))
  i <- x$items[x$items$item_id == "99999", ]
  expect_equal(i$year, 2024L)
  expect_equal(i$url, urls[1])
  expect_equal(i$coverage, "abstract page")
  expect_equal(i$session, "Poster: Methodology - Model evaluation")
  # poster links often carry an author's name in the file name, so the item table says only
  # whether there is a poster
  expect_false("pdf_url" %in% names(x$items))
  expect_equal(x$items$has_poster[match(c("99999", "898"), x$items$item_id)], c(TRUE, FALSE))
  s <- x$sections[x$sections$item_id == "99999", ]
  expect_equal(s$section, c("title", "authors", "affiliations", "body"))
  expect_false(any(grepl("Beal", s$text)))
  expect_equal(x$skipped, "broken.html")
})

test_that("pubmedCorpus keeps the first record of each base-set PMID", {
  dir <- withr::local_tempdir()
  writeLines(pubmedArticles, file.path(dir, "pubmed_1.xml"))
  writeLines(pubmedArticles, file.path(dir, "pubmed_2.xml"))
  base <- data.frame(id = c("111", "333"), year = c("2021", "2022"))
  x <- pubmedCorpus(list.files(dir, full.names = TRUE), base = base)
  expect_equal(x$items$item_id, c("111", "333"))
  expect_equal(x$items$coverage, c("title and abstract", "none"))
  expect_equal(x$items$url[1], "https://pubmed.ncbi.nlm.nih.gov/111/")
  expect_equal(unique(x$sections$item_id), "111")
  expect_equal(x$sections$section, c(
    "title", "abstract", "keywords", "authors", "affiliations", "author_affiliations", "author_affiliations"
  ))
  aa <- x$sections[x$sections$section == "author_affiliations", ]
  expect_equal(aa$part, c("a001", "a002"))
  expect_equal(aa$text, c("Example University, Sweden.", "Certara, USA."))
})

pubmedThreeAuthors <- '<?xml version="1.0"?>
<PubmedArticleSet>
 <PubmedArticle><MedlineCitation><PMID Version="1">444</PMID>
  <Article><ArticleTitle>Three authors</ArticleTitle>
   <AuthorList><Author><LastName>One</LastName><Initials>A</Initials>
    <AffiliationInfo><Affiliation>Lab A, Uppsala.</Affiliation></AffiliationInfo>
    <AffiliationInfo><Affiliation>Firm B, Basel.</Affiliation></AffiliationInfo></Author>
    <Author><LastName>Two</LastName><Initials>B</Initials></Author>
    <Author><CollectiveName>A study group</CollectiveName>
    <AffiliationInfo><Affiliation>Clinic C.</Affiliation></AffiliationInfo></Author></AuthorList>
  </Article>
 </MedlineCitation></PubmedArticle>
 <PubmedArticle><MedlineCitation><PMID Version="1">222</PMID>
  <Article><ArticleTitle>No authors</ArticleTitle></Article>
 </MedlineCitation></PubmedArticle>
</PubmedArticleSet>'

test_that("pubmedAuthorAffiliations gives each author's affiliations by position, without names", {
  a <- pubmedAuthorAffiliations(pubmedThreeAuthors)
  expect_equal(names(a), c("pmid", "author", "affiliation"))
  expect_equal(a$pmid, rep("444", 3))
  expect_equal(a$author, 1:3)
  expect_equal(a$affiliation, c("Lab A, Uppsala.\nFirm B, Basel.", "", "Clinic C."))
  expect_false(any(grepl("One|Two|study group", unlist(a))))
})

epmcRecordJson <- '{"resultList": {"result": [
 {"id": "555", "source": "MED", "authorList": {"author": [
   {"fullName": "Doe J", "authorAffiliationDetailsList": {"authorAffiliation": [
     {"affiliation": "Lab A, Uppsala."}, {"affiliation": "Firm B, Basel."}]}},
   {"fullName": "Roe R"}]}},
 {"id": "PMC999", "source": "PMC"}
]}}'

test_that("epmcAuthorAffiliations reads each author's affiliations from Europe PMC core records", {
  res <- jsonlite::parse_json(epmcRecordJson)$resultList$result
  a <- epmcAuthorAffiliations(res)
  expect_equal(names(a), c("id", "author", "affiliation"))
  expect_equal(a$id, c("MED:555", "MED:555"))
  expect_equal(a$author, 1:2)
  expect_equal(a$affiliation, c("Lab A, Uppsala.\nFirm B, Basel.", ""))
})

test_that("epmcAuthors gives each record's author list as PubMed's authors section does", {
  res <- jsonlite::parse_json(epmcRecordJson)$resultList$result
  a <- epmcAuthors(res)
  expect_equal(a$id, "MED:555")
  expect_equal(a$authors, "Doe J; Roe R")
})

test_that("epmcCorpus adds the authors' affiliations by position to full-text and record items", {
  dir <- withr::local_tempdir()
  writeLines(jatsXml, file.path(dir, "PMC999.xml"))
  base <- data.frame(id = c("PMC:PMC999", "MED:555"), year = c("2023", "2024"))
  rec <- data.frame(id = "MED:555", title = "Record title", abstract = "Record abstract", keywords = "PK")
  aff <- data.frame(id = c("MED:555", "MED:555", "PMC:PMC999"), author = c(1L, 2L, 1L), affiliation = c("A", "", "C"))
  au <- data.frame(id = "MED:555", authors = "Doe J; Roe R")
  x <- epmcCorpus(list.files(dir, full.names = TRUE), base = base, records = rec, affiliations = aff, authors = au)
  r <- x$sections[x$sections$item_id == "MED:555", ]
  expect_equal(r$section, c("title", "abstract", "keywords", "authors", "author_affiliations", "author_affiliations"))
  expect_equal(r$part, c("", "", "", "", "a001", "a002"))
  expect_equal(r$text[4:6], c("Doe J; Roe R", "A", ""))
  f <- x$sections[x$sections$item_id == "PMC:PMC999", ]
  expect_equal(tail(f$section, 1), "author_affiliations")
  expect_equal(tail(f$text, 1), "C")
  expect_equal(f$section[seq_len(nrow(f) - 1)], jatsParts(jatsXml)$section)
})

test_that("epmcCorpus matches full texts to the base set by PMID or PMCID", {
  dir <- withr::local_tempdir()
  writeLines(jatsXml, file.path(dir, "PMC999.xml"))
  base <- data.frame(id = c("PMC:PMC999", "MED:555"), year = c("2023", "2024"))
  x <- epmcCorpus(list.files(dir, full.names = TRUE), base = base)
  expect_equal(x$items$item_id, c("PMC:PMC999", "MED:555"))
  expect_equal(x$items$coverage, c("full text", "none"))
  expect_equal(x$items$url, c("https://europepmc.org/article/PMC/PMC999", "https://europepmc.org/article/MED/555"))
  expect_equal(unique(x$sections$item_id), "PMC:PMC999")
  rec <- data.frame(
    id = c("MED:555", "PMC:PMC999"), title = c("Record title", "Ignored"), abstract = c("Record abstract", "x"),
    keywords = c("PK", "")
  )
  y <- epmcCorpus(list.files(dir, full.names = TRUE), base = base, records = rec)
  expect_equal(y$items$coverage, c("full text", "title and abstract (record)"))
  r <- y$sections[y$sections$item_id == "MED:555", ]
  expect_equal(r$section, c("title", "abstract", "keywords"))
  expect_equal(r$src, rep("json", 3))
  expect_equal(y$sections[y$sections$item_id == "PMC:PMC999", ], x$sections[x$sections$item_id == "PMC:PMC999", ])
})

test_that("fdaCorpus makes one item per drug and one section per review page, OCR marked", {
  x <- fdaCorpus(miniDir())
  expect_setequal(x$items$item_id, c("099001", "100001", "100002", "100003"))
  s <- x$sections[x$sections$item_id == "100001", ]
  pages <- fdaReadPages(miniDir(), 2099, "txt/100001_integratedR_2099.txt")
  expect_equal(s$text, pages$text)
  expect_equal(s$src, pages$src)
  expect_equal(s$part[2], "100001_integratedR_2099 p0002")
  two <- x$sections[x$sections$item_id == "100002", ]
  expect_equal(unique(sub(" p[0-9]+$", "", two$part)), c("100002_clinPharmR_2099", "100002_multidisciplineR_2100"))
})

test_that("fdaCorpus takes year and drug from the frame for a year without a decision record", {
  dir <- withr::local_tempdir()
  file.copy(miniDir(), dir, recursive = TRUE)
  fda <- file.path(dir, "fda-mini")
  y <- file.path(fda, "data", "2101")
  dir.create(file.path(y, "txt"), recursive = TRUE)
  writeLines(
    c("Page one of the review.", "\fPage two names NONMEM."),
    file.path(y, "txt", "101001_integratedR_2101.txt")
  )
  jsonlite::write_json(list("101001" = list(list(
    type = "integratedR", folder_year = "2101", url = "https://example.org/101001.pdf",
    text_file = "txt/101001_integratedR_2101.txt"
  ))), file.path(y, "docs.json"), auto_unbox = TRUE)
  entry <- list(no = 1, name = "Drugz", ingr = "examplezumab", date = "3/1/2101", label = "x", appl = "101001")
  jsonlite::write_json(list(entry),
    file.path(y, "frame.json"),
    auto_unbox = TRUE
  )
  x <- fdaCorpus(fda)
  expect_true("101001" %in% x$items$item_id)
  expect_equal(x$items$year[x$items$item_id == "101001"], 2101L)
  expect_equal(x$items$drug[x$items$item_id == "101001"], "Drugz")
  expect_setequal(setdiff(x$items$item_id, "101001"), c("099001", "100001", "100002", "100003"))
})

test_that("corpusWrite and corpusRead round-trip, and a changed local text is refused", {
  root <- withr::local_tempdir()
  x <- fdaCorpus(miniDir())
  corpusWrite(x, root, "fda")
  expect_true(file.exists(file.path(root, "fda", "items.csv")))
  expect_true(file.exists(file.path(root, "fda", "sections.csv.gz")))
  expect_false("text" %in% names(utils::read.csv(file.path(root, "fda", "sections.csv.gz"))))
  y <- corpusRead(root, "fda")
  expect_equal(y$sections$text, x$sections$text)
  expect_equal(y$items$hash, x$items$hash)
  expect_equal(unique(corpusRead(root, "fda", sections = "review")$sections$section), "review")
  # the committed tables are byte-identical on a rebuild
  before <- tools::md5sum(file.path(root, "fda", c("items.csv", "sections.csv.gz")))
  corpusWrite(fdaCorpus(miniDir()), root, "fda")
  expect_equal(unname(tools::md5sum(file.path(root, "fda", c("items.csv", "sections.csv.gz")))), unname(before))
  local <- readRDS(file.path(root, "cache", "fda.rds"))
  local$text[1] <- "tampered"
  saveRDS(local, file.path(root, "cache", "fda.rds"))
  expect_error(corpusRead(root, "fda"), "1 section")
})

test_that("the affiliation readers drop e-mail addresses", {
  xml <- sub("Example University, Sweden.", "Example University, Sweden. Electronic address: first@example.se.",
    pubmedArticles,
    fixed = TRUE
  )
  expect_equal(pubmedText(xml)$affiliations[1], "Example University, Sweden.\nCertara, USA.")
  expect_equal(pubmedAuthorAffiliations(xml)$affiliation[1], "Example University, Sweden.")

  res <- jsonlite::parse_json(sub("Lab A, Uppsala.", "Lab A, Uppsala. doe@lab-a.se", epmcRecordJson, fixed = TRUE))
  expect_equal(epmcAuthorAffiliations(res$resultList$result)$affiliation[1], "Lab A, Uppsala.\nFirm B, Basel.")

  html <- sub("(3) Certara, USA", "(3) Certara, USA (a@example.com)", pageTwoAuthors, fixed = TRUE)
  expect_equal(
    pageParseAbstract(html)$affiliations,
    "(1) Department of Pharmacy, Example University, Sweden, (2) Example Pharma AB, Sweden, (3) Certara, USA"
  )
})
