jats <- '<article><front><article-meta><title-group>
  <article-title>Population pharmacokinetics of examplumab</article-title>
  </title-group></article-meta></front><body>
  <sec><title>Introduction</title><p>Earlier work used Monolix for a related compound.</p></sec>
  <sec sec-type="methods"><title>Methods</title><p>Models were fitted in NONMEM 7.5 with FOCE-I.</p>
    <sec><title>Software</title><p>Diagnostics used PsN and Xpose.</p></sec></sec>
  <sec><title>Results</title><p>The model described the data.</p></sec></body>
  <back><ref-list><ref>
    <mixed-citation>Beal SL. NONMEM Users Guides. Phoenix NLME manual.</mixed-citation>
  </ref></ref-list></back>
  </article>'

test_that("jatsSections gives the body and the methods without the reference list", {
  s <- jatsSections(jats)
  expect_match(s$body, "Monolix")
  expect_match(s$body, "NONMEM 7.5")
  expect_no_match(s$body, "Phoenix|Users Guides")
  expect_match(s$methods, "NONMEM 7.5")
  expect_match(s$methods, "PsN and Xpose") # nested sections belong to their methods section
  expect_no_match(s$methods, "Monolix|described the data")
})

test_that("jatsSections finds methods by title when sec-type is missing", {
  x <- sub(
    '<sec sec-type="methods"><title>Methods</title>', "<sec><title>Materials and methods</title>", jats,
    fixed = TRUE
  )
  expect_match(jatsSections(x)$methods, "NONMEM 7.5")
  expect_equal(jatsSections("<article><body><p>No sections.</p></body></article>")$methods, "")
})

test_that("sponsorToken keeps the distinctive part of a sponsor name", {
  expect_equal(
    sponsorToken(c(
      "MERCK SHARP DOHME LLC", "Vertex Pharmaceuticals Inc", "Eli Lilly and Co", "Novo Nordisk Inc",
      "Bristol-Myers Squibb Co", "JANSSEN BIOTECH INC"
    )),
    c("Merck", "Vertex", "Lilly", "Novo Nordisk", "Bristol-Myers", "Janssen")
  )
})

test_that("sponsorToken drops the abbreviations openFDA uses", {
  expect_equal(
    sponsorToken(c("AVEO PHARMS", "LOXO ONCOL", "VIIV HLTHCARE", "SUN PHARM INDS INC", "ALCON LABS INC", "VIFOR INTL")),
    c("Aveo", "Loxo", "Viiv", "Sun", "Alcon", "Vifor")
  )
})

test_that("sponsorToken applies overrides", {
  expect_equal(sponsorToken("Example Holdings Ltd", overrides = c("Example Holdings Ltd" = "Examplex")), "Examplex")
})

test_that("codeNames keeps development codes from a synonym list", {
  syn <- c(
    "sotorasib", "AMG 510", "AMG-510", "AMG510", "Lumakras", "2296729-00-3", "UNII-2B2VM6UC8G", "CHEMBL4535757",
    "LY3298176", "ABBV-951", "orb1307856", "SCHEMBL12345", "DTXSID901", "BDBM50", "ex-A1234", "HY-114277"
  )
  expect_setequal(codeNames(syn), c("AMG 510", "LY3298176", "ABBV-951"))
})

test_that("drugSearchNames combines brand, ingredient components and codes", {
  n <- drugSearchNames("Nextstellis", "drospirenone and estetrol", codes = "E4")
  expect_setequal(n, c("Nextstellis", "drospirenone", "estetrol"))
  expect_setequal(drugSearchNames("Leqembi", "lecanemab-irmb"), c("Leqembi", "lecanemab"))
  expect_setequal(
    drugSearchNames("Fotivda", "tivozanib hydrochloride", codes = "AV-951"), c("Fotivda", "tivozanib", "AV-951")
  )
})
