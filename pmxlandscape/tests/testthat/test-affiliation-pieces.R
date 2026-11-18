test_that("pageAffiliations splits a numbered affiliation line into its institutions", {
  expect_equal(
    pageAffiliations("(1) Dept A, Uni X, (2) Pharma Y AB, (3) Certara, USA"),
    c("Dept A, Uni X", "Pharma Y AB", "Certara, USA")
  )
  expect_equal(pageAffiliations("1Dept A, Uni X; 2Pharma Y AB"), c("Dept A, Uni X", "Pharma Y AB"))
})

test_that("pageAffiliations keeps an unnumbered line whole, split only at semicolons", {
  expect_equal(pageAffiliations("Medicines Evaluation Board, Utrecht"), "Medicines Evaluation Board, Utrecht")
  expect_equal(
    pageAffiliations("Pharmetheus AB, Uppsala; Pfizer, Groton"),
    c("Pharmetheus AB, Uppsala", "Pfizer, Groton")
  )
  expect_equal(pageAffiliations(NA_character_), character(0))
})
