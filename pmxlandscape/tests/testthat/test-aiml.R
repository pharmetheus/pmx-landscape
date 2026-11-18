termsFile <- function(rows) {
  f <- withr::local_tempfile(fileext = ".csv", .local_envir = parent.frame())
  write.csv(rows, f, row.names = FALSE)
  f
}

test_that("readAiMlTerms reads the taxonomy and rejects an unknown group or a broken regex", {
  terms <- readAiMlTerms(test_path("../../../taxonomy/ai_ml_terms.csv"))
  expect_setequal(unique(terms$group), c("ML", "AI"))
  expect_equal(terms$family, terms$term)
  bad <- data.frame(group = "DL", term = "x", regex = "x", pubmed = "", epmc = "", note = "")
  expect_error(readAiMlTerms(termsFile(bad)), "group")
  bad$group <- "ML"
  bad$regex <- "(unclosed"
  expect_error(readAiMlTerms(termsFile(bad)), "regex")
})

test_that("the AI and GPT patterns match the method, not the look-alikes", {
  terms <- readAiMlTerms(test_path("../../../taxonomy/ai_ml_terms.csv"))
  rx <- setNames(terms$regex, terms$term)
  hit <- function(term, x) stringi::stri_detect_regex(x, rx[[term]])
  expect_equal(hit("AI", c("AI-based dosing", "AI/ML", "Ai Lin", "said", "TRAIL")), c(TRUE, TRUE, FALSE, FALSE, FALSE))
  expect_equal(hit("ChatGPT and GPT", c("ChatGPT", "GPT-4o", "serum GPT and GOT")), c(TRUE, TRUE, FALSE))
  expect_equal(hit("neural ODEs", c("neural ODEs", "neural ordinary differential equations")), c(TRUE, TRUE))
  expect_equal(hit("support vector machines", c("an SVM", "svm")), c(TRUE, FALSE))
})

hits <- data.frame(
  source = "PAGE", id = c("1", "1", "2", "3", "4", "4"), year = c(2010L, 2010L, 2010L, 2012L, 2012L, 2012L),
  group = c("ML", "AI", "ML", "AI", "AI", "AI"),
  term = c("neural networks", "AI", "machine learning", "AI", "AI", "expert systems")
)
decisions <- data.frame(
  source = "PAGE", id = c("1", "1", "2", "3", "4", "4"),
  term = c("neural networks", "AI", "machine learning", "AI", "AI", "expert systems"),
  decision = c("used", "mentioned", "mentioned", "not", "not", "mentioned"), note = "", decided_by = "test"
)

test_that("aiMlDecide refuses hits without a decision and decisions it does not know", {
  expect_error(aiMlDecide(hits, decisions[-1, ]), "1 hit")
  d <- decisions
  d$decision[1] <- "maybe"
  expect_error(aiMlDecide(hits, d), "maybe")
  expect_equal(aiMlDecide(hits, decisions)$decision, decisions$decision)
})

test_that("aiMlShares counts an item once per group, leaves out 'not' and gives 0 for a year without hits", {
  base <- data.frame(source = "PAGE", year = 2010:2012, n = c(10L, 20L, 40L))
  s <- aiMlShares(aiMlDecide(hits, decisions), base)
  ml10 <- s[s$group == "ML" & s$year == 2010, ]
  expect_equal(c(ml10$mentioned, ml10$used), c(2L, 1L)) # item 1 used, item 2 mentioned
  ai10 <- s[s$group == "AI" & s$year == 2010, ]
  expect_equal(c(ai10$mentioned, ai10$used), c(1L, 0L)) # item 1 also counts for AI
  ai12 <- s[s$group == "AI" & s$year == 2012, ]
  expect_equal(ai12$mentioned, 1L) # item 3 is 'not'; item 4 counts once through expert systems
  expect_equal(s$mentioned[s$group == "ML" & s$year == 2011], 0L)
  expect_equal(ai12$share_mentioned, 1 / 40)
  expect_true(all(s$used <= s$mentioned))
  expect_error(aiMlShares(aiMlDecide(hits, decisions), base[base$year != 2012, ]), "base")
})

test_that("aiMlFirst gives the first year mentioned and used, with every item of that year", {
  f <- aiMlFirst(aiMlDecide(hits, decisions))
  ml <- f[f$group == "ML", ]
  expect_equal(c(ml$first_mentioned, ml$first_used), c(2010L, 2010L))
  expect_equal(ml$ids_mentioned, "1; 2")
  expect_equal(ml$ids_used, "1")
  ai <- f[f$group == "AI", ]
  expect_equal(ai$first_mentioned, 2010L)
  expect_equal(ai$ids_mentioned, "1")
  expect_true(is.na(ai$first_used))
  byTerm <- aiMlFirst(aiMlDecide(hits, decisions), by = "term")
  expect_equal(byTerm$first_mentioned[byTerm$term == "expert systems"], 2012L)
  expect_equal(byTerm$first_mentioned[byTerm$term == "AI"], 2010L)
})

test_that("keepEarliestYear keeps each ID only in the first year it appears", {
  ids <- data.frame(id = c("a", "a", "b", "c", "c"), year = c(2001L, 2000L, 2003L, 2005L, 2005L), what = 1:5)
  k <- keepEarliestYear(ids)
  expect_equal(k$what, c(2L, 3L, 4L, 5L))
})

test_that("plotAiMlShares draws mentioned and used per group, one panel per source", {
  s <- data.frame(
    source = rep(c("PAGE", "PubMed"), each = 4), year = rep(c(2020L, 2020L, 2021L, 2021L), 2),
    group = rep(c("ML", "AI"), 4), mentioned = c(2L, 1L, 4L, 2L, 1L, 0L, 3L, 1L),
    used = c(1L, 0L, 2L, 1L, 0L, 0L, 1L, 0L),
    base_n = 100L
  )
  s$share_mentioned <- s$mentioned / s$base_n
  s$share_used <- s$used / s$base_n
  b <- ggplot2::ggplot_build(plotAiMlShares(s))
  lines <- b$data[[1]]
  expect_equal(length(unique(lines$PANEL)), 2)
  expect_equal(length(unique(lines$group)), 4) # ML and AI, mentioned and used
  expect_equal(sort(unique(round(lines$y, 6))), sort(unique(round(100 * c(s$share_mentioned, s$share_used), 6))))
})

test_that("plotAiMlUsed shows only the used share, sources together, one panel per group, in the years asked", {
  s <- expand.grid(source = c("PAGE", "PubMed", "Europe PMC"), year = 2014:2018, group = c("ML", "AI"))
  s$base_n <- 100L
  s$used <- seq_len(nrow(s)) %% 5L
  s$mentioned <- s$used + 1L
  s$share_used <- s$used / s$base_n
  s$share_mentioned <- s$mentioned / s$base_n
  b <- ggplot2::ggplot_build(plotAiMlUsed(s, years = 2016:2018))
  lines <- b$data[[1]]
  expect_equal(length(unique(lines$PANEL)), 2)
  expect_equal(length(unique(lines$group)), 3)
  expect_equal(range(lines$x), c(2016, 2018))
  kept <- s[s$year >= 2016, ]
  expect_equal(sort(round(lines$y, 6)), sort(round(100 * kept$share_used, 6)))
})
