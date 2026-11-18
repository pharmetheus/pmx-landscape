pubmedXml <- '<?xml version="1.0"?>
<PubmedArticleSet>
 <PubmedArticle><MedlineCitation><PMID Version="1">111</PMID>
  <Article><AuthorList>
  <Author><LastName>First</LastName>
   <AffiliationInfo><Affiliation>Dept A, Example University, Sweden.</Affiliation></AffiliationInfo>
   <AffiliationInfo><Affiliation>Example Pharma AB, Sweden.</Affiliation></AffiliationInfo></Author>
  <Author><LastName>Second</LastName>
   <AffiliationInfo><Affiliation>Certara, USA.</Affiliation></AffiliationInfo></Author>
 </AuthorList></Article></MedlineCitation></PubmedArticle>
 <PubmedArticle><MedlineCitation><PMID Version="1">222</PMID><Article><AuthorList>
  <Author><CollectiveName>Example Study Group</CollectiveName></Author>
  <Author><LastName>Person</LastName>
   <AffiliationInfo><Affiliation>Office of Clinical Pharmacology, FDA.</Affiliation></AffiliationInfo></Author>
 </AuthorList></Article></MedlineCitation></PubmedArticle>
 <PubmedArticle><MedlineCitation><PMID Version="1">333</PMID><Article><AuthorList>
  <Author><LastName>NoAffiliation</LastName></Author>
 </AuthorList></Article></MedlineCitation></PubmedArticle>
</PubmedArticleSet>'

test_that("pubmedFirstAffiliation takes the first listed affiliation of the first named author", {
  a <- pubmedFirstAffiliation(pubmedXml)
  expect_equal(a$pmid, c("111", "222", "333"))
  expect_equal(a$affiliation, c("Dept A, Example University, Sweden.", "Office of Clinical Pharmacology, FDA.", NA))
})

test_that("pubmedFirstAffiliation keeps only the first of several institutions packed into one field", {
  xml <- '<?xml version="1.0"?><PubmedArticleSet><PubmedArticle><MedlineCitation><PMID Version="1">444</PMID>
    <Article><AuthorList><Author><LastName>First</LastName><AffiliationInfo><Affiliation>Example Pharma, Frankfurt,
    Germany (A.F., B.S.); and Certara, Princeton, New Jersey (C.T.) a.first@example.com.</Affiliation></AffiliationInfo>
    </Author></AuthorList></Article></MedlineCitation></PubmedArticle></PubmedArticleSet>'
  expect_equal(pubmedFirstAffiliation(xml)$affiliation, "Example Pharma, Frankfurt, Germany (A.F., B.S.)")
})

test_that("pubmedAffiliations returns every author's affiliations, split into institutions", {
  a <- pubmedAffiliations(pubmedXml)
  expect_equal(a$pmid, c("111", "111", "111", "222"))
  expect_equal(a$affiliation, c(
    "Dept A, Example University, Sweden.", "Example Pharma AB, Sweden.", "Certara, USA.",
    "Office of Clinical Pharmacology, FDA."
  ))
  xml <- '<?xml version="1.0"?><PubmedArticleSet><PubmedArticle><MedlineCitation><PMID Version="1">444</PMID>
    <Article><AuthorList><Author><LastName>First</LastName><AffiliationInfo><Affiliation>Example Pharma, Frankfurt,
    Germany (A.F., B.S.); and Certara, Princeton, New Jersey (C.T.) a.first@example.com.</Affiliation></AffiliationInfo>
    </Author><Author><LastName>Second</LastName><AffiliationInfo><Affiliation>Example Pharma, Frankfurt,
    Germany (A.F., B.S.)</Affiliation></AffiliationInfo></Author></AuthorList></Article></MedlineCitation>
    </PubmedArticle></PubmedArticleSet>'
  expect_equal(
    pubmedAffiliations(xml)$affiliation,
    c("Example Pharma, Frankfurt, Germany (A.F., B.S.)", "Certara, Princeton, New Jersey (C.T.)")
  )
})
