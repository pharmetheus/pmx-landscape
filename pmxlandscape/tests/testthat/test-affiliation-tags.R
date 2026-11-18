affRules <- function() readAffiliationRules(repoFile("taxonomy", "affiliation_rules.csv"))

litSections <- function() {
  corpusSections(
    "PubMed",
    c("1", "1", "1", "1", "2", "2", "3"),
    c("title", "authors", "author_affiliations", "author_affiliations", "title", "author_affiliations", "title"),
    c("", "", "a001", "a002", "", "a001", ""),
    "xml",
    c(
      "A model", "Larsson A; Moreau B",
      "Department of Pharmacy, Uppsala University, Uppsala, Sweden. a.larsson@example.org; Novartis Pharma AG, Basel",
      "Clinical Pharmacology, Certara, Princeton, USA.",
      "Another", "", "No authors"
    )
  )
}

test_that("affiliationTags gives the first author's type and organisation and any-author flags", {
  t <- affiliationTags(litSections(), affRules(), "PubMed")
  expect_equal(t$item_id, c("1", "2", "3"))
  expect_equal(t$first_author_type, c("academia", "no affiliation", "no affiliation"))
  expect_equal(t$first_author_organisation[1], "Uppsala University")
  expect_equal(t$any_industry, c(TRUE, FALSE, FALSE))
  expect_equal(t$any_cro, c(TRUE, FALSE, FALSE))
  expect_equal(t$organisations[1], "Uppsala University; Novartis Pharma AG; Certara")
  expect_equal(t$named_organisations[1], "Novartis; Certara")
  expect_true(is.na(t$organisations[2]))
})

test_that("affiliationTags names the first author's organisation only when a naming rule found it", {
  t <- affiliationTags(litSections(), affRules(), "PubMed")
  # Uppsala University is found by the general academic words, not by a rule that names it
  expect_true(is.na(t$first_author_named[1]))
  s <- corpusSections(
    "PAGE", c("7", "7"), c("authors", "affiliations"), "", "html",
    c("Anna Ek (1), Bo Lind (2)", "(1) Pfizer Inc, Groton, USA, (2) Uppsala University, Sweden")
  )
  expect_equal(affiliationTags(s, affRules(), "PAGE")$first_author_named, "Pfizer")
})

test_that("affiliationTags never stores e-mail addresses or author surnames", {
  s <- corpusSections(
    "PubMed", c("9", "9", "9"), c("authors", "author_affiliations", "author_affiliations"), c("", "a001", "a002"),
    "xml",
    c(
      "Holmgren K; Berg L", "Holmgren Pharmacometrics Consulting, Lund, Sweden. k@example.se",
      "Berg Consulting AB, Stockholm"
    )
  )
  t <- affiliationTags(s, affRules(), "PubMed")
  expect_equal(t$first_author_type, "CRO")
  expect_true(is.na(t$first_author_organisation))
  expect_true(is.na(t$organisations))
  expect_equal(t$withheld, 2L)
  expect_false(any(grepl("Holmgren|Berg|@", unlist(t))))
})

test_that("affiliationTags reads PAGE abstracts from the numbered affiliation line", {
  s <- corpusSections(
    "PAGE", c("7", "7"), c("authors", "affiliations"), "", "html",
    c("Anna Ek (1), Bo Lind (2)", "(1) Pfizer Inc, Groton, USA, (2) Uppsala University, Sweden")
  )
  t <- affiliationTags(s, affRules(), "PAGE")
  expect_equal(t$first_author_type, "industry")
  expect_equal(t$first_author_organisation, "Pfizer Inc")
  expect_true(t$any_industry)
  expect_false(t$any_cro)
  expect_equal(t$organisations, "Pfizer Inc; Uppsala University")
  expect_equal(t$named_organisations, "Pfizer")
})

test_that("affiliationTags returns the classified text only when asked", {
  expect_false("first_author_affiliation" %in% names(affiliationTags(litSections(), affRules(), "PubMed")))
  t <- affiliationTags(litSections(), affRules(), "PubMed", text = TRUE)
  expect_match(t$first_author_affiliation[1], "^Department of Pharmacy, Uppsala University")
  expect_true(is.na(t$first_author_affiliation[2]))
})

test_that("affiliationTags prefers the institution to a department or faculty", {
  s <- corpusSections(
    "PubMed", c("5", "5"), c("author_affiliations", "author_affiliations"), c("a001", "a002"), "xml",
    c(
      paste(
        "Department of Pharmacy Practice, Faculty of Pharmaceutical Sciences, Chulalongkorn University,",
        "Bangkok, Thailand."
      ),
      "University of Oxford, Nuffield Department of Medicine, Oxford, UK"
    )
  )
  t <- affiliationTags(s, affRules(), "PubMed")
  expect_equal(t$first_author_organisation, "Chulalongkorn University")
  expect_equal(t$organisations, "Chulalongkorn University; University of Oxford")
})

test_that("affiliationTags keeps a company's name with its legal suffix", {
  s <- corpusSections(
    "PubMed", "6", "author_affiliations", "a001", "xml", "Clinical Pharmacology, BeiGene, Inc., Cambridge, MA"
  )
  expect_equal(affiliationTags(s, affRules(), "PubMed")$first_author_organisation, "BeiGene, Inc")
})
