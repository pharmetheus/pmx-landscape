test_that("findMatches returns one row per match with a snippet of the given width", {
  p <- readPatterns(file.path(miniDir(), "config", "patterns.json"))
  text <- c("We fitted it in NONMEM 7.4 here. Beal SL. NONMEM Users Guides.", "Nothing", NA)
  m <- findMatches(text, p, groups = "estimation", width = 10)
  expect_equal(m$text, c(1L, 1L))
  expect_equal(m$family, c("NONMEM", "NONMEM"))
  expect_equal(m$snip[1], "ted it in NONMEM 7.4 here.") # characters 7 to 32: 10 either side
  expect_equal(nrow(findMatches("Nothing", p)), 0)
})

test_that("findMatches collapses whitespace in snippets", {
  p <- readPatterns(file.path(miniDir(), "config", "patterns.json"))
  expect_equal(findMatches("Fitted\n\n  in   Monolix", p, width = 20)$snip, "Fitted in Monolix")
})

test_that("looksLikeCitation flags reference-list style text only", {
  x <- c(
    "[3] Beal SL, Sheiner LB. NONMEM Users Guides. Ellicott City, 2009.",
    "Smith J et al. Monolix compared with NONMEM. J Pharmacokinet Pharmacodyn 2015;42:1-10",
    "Jones A. A NONMEM model. doi:10.1000/xyz",
    "Parameters were estimated in NONMEM 7.5 and simulations were run in R",
    "Models were fitted in Monolix 2021R1 (Lixoft, Antony, France).",
    NA
  )
  expect_equal(looksLikeCitation(x), c(TRUE, TRUE, TRUE, FALSE, FALSE, FALSE))
})

test_that("each citation cue is enough on its own", {
  x <- c(
    "Smith J et al. used Monolix", "see the NONMEM Users Guide for", "doi:10.1000/xyz",
    "Clin Pharmacol 2015; 12 NONMEM",
    "vol 42:1-10 NONMEM", "[3] Beal SL NONMEM"
  )
  expect_equal(looksLikeCitation(x), rep(TRUE, 6))
})

test_that("readDecisions accepts only the agreed decisions and no duplicates", {
  f <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("abstract_no,family,decision,reason", "1,NONMEM,used,states the estimation tool"), f)
  d <- readDecisions(f)
  expect_equal(d$abstract_no, 1L)
  expect_equal(d$decision, "used")
  writeLines(c("abstract_no,family,decision,reason", "1,NONMEM,maybe,x"), f)
  expect_error(readDecisions(f), "maybe")
  writeLines(c("abstract_no,family,decision,reason", "1,NONMEM,used,x", "1,NONMEM,cited,y"), f)
  expect_error(readDecisions(f), "more than one decision")
  writeLines(c("abstract_no,family,decision,reason", "1,NONMEM,used,"), f)
  expect_error(readDecisions(f), "reason")
})

test_that("applyDecisions marks undecided hits as pending", {
  hits <- data.frame(abstract_no = c(1L, 1L, 2L), family = c("NONMEM", "Monolix", "NONMEM"))
  decisions <- data.frame(
    abstract_no = c(1L, 2L), family = c("NONMEM", "NONMEM"), decision = c("used", "cited"), reason = c("a", "b")
  )
  expect_equal(applyDecisions(hits, decisions), c("used", "pending", "cited"))
})
