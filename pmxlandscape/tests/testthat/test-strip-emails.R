test_that("stripEmails removes addresses with their label and tidies the punctuation left behind", {
  expect_equal(
    stripEmails("Dept of Pharmacy, Uppsala University, Sweden. Electronic address: a.berg@example.org."),
    "Dept of Pharmacy, Uppsala University, Sweden."
  )
  expect_equal(stripEmails("Pfizer Inc, Groton, USA (e-mail: x.y@example.com)"), "Pfizer Inc, Groton, USA")
  expect_equal(stripEmails("Firm B, Basel. Email: a@b.ch; c.d@e-f.org."), "Firm B, Basel.")
  expect_equal(stripEmails("Lab A, Uppsala. a_b@lab.example.se\nFirm B, Basel."), "Lab A, Uppsala.\nFirm B, Basel.")
  expect_equal(stripEmails("Hospital X, Udine, Italy federico.p@x.it."), "Hospital X, Udine, Italy.")
  expect_equal(
    stripEmails("University of Warwick, UK (corresponding author e-mail: m.r@dept.example.org), (2) Oxford, UK"),
    "University of Warwick, UK, (2) Oxford, UK"
  )
})

test_that("stripEmails changes nothing away from the address", {
  expect_equal(
    stripEmails("Clovis Oncology, Inc., 5500 Flatiron Pkwy, Boulder, CO, USA.. Note  two. jx@example.com"),
    "Clovis Oncology, Inc., 5500 Flatiron Pkwy, Boulder, CO, USA.. Note  two."
  )
  expect_equal(stripEmails("CINTESIS@RISE, Porto. a@b.pt"), "CINTESIS@RISE, Porto.")
})

test_that("stripEmails leaves text without an address, and missing values, as they are", {
  x <- c("St. John's College, Oxford, UK.. ", "Lab @ Home, Sweden", NA, "")
  expect_identical(stripEmails(x), x)
})

test_that("stripEmails is idempotent", {
  x <- "Example Pharma AB, Sweden. E-mail address: someone@example.com"
  expect_identical(stripEmails(stripEmails(x)), stripEmails(x))
})
