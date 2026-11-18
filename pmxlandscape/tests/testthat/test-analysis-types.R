types <- function() readAnalysisTypes(repoFile("taxonomy", "analysis_types.csv"))

test_that("classifyAnalysis assigns every matching type and the highest level", {
  x <- c(
    "A population pharmacokinetic model of drug X in children.",
    "An exposure-response analysis of efficacy with an Emax model.",
    "A repeated time-to-event model for seizures.",
    "A joint model of tumour size and overall survival.",
    "Fully Bayesian estimation with MCMC in Stan.",
    "A neural ODE compared with a machine learning model.",
    "A PBPK model predicted the interaction.",
    "Study design for a new method.",
    NA
  )
  r <- classifyAnalysis(x, types())
  expect_equal(r$level, c(1L, 2L, 3L, 4L, 5L, 6L, 7L, NA, NA))
  expect_equal(r$types[[1]], "PK only")
  expect_true(all(c("Joint models", "Non-continuous endpoints, time-to-event") %in% r$types[[4]]))
  expect_equal(r$types[[8]], character(0))
})

test_that("PK only is given only when no higher type matches", {
  r <- classifyAnalysis("Population pharmacokinetics and exposure-response of drug X.", types())
  expect_false("PK only" %in% r$types[[1]])
  expect_equal(r$level, 2L)
})

test_that("plain Bayesian estimation for dosing is not a full Bayesian hierarchical model", {
  r <- classifyAnalysis("Bayesian forecasting of vancomycin clearance for dose individualisation.", types())
  expect_false("Full Bayesian hierarchical models" %in% r$types[[1]])
})

test_that("typeByTool counts items per tool and type, with each type's share among the tool's items", {
  items <- data.frame(id = 1:4, tools = c("NONMEM", "NONMEM; Monolix", "Monolix", "NONMEM"))
  items$types <- list(
    "PK only", c("Joint models", "Non-continuous endpoints, time-to-event"), "Joint models", character(0)
  )
  t <- typeByTool(items)
  j <- t[t$tool == "Monolix" & t$type == "Joint models", ]
  expect_equal(j$n, 2L)
  expect_equal(j$n_tool, 2L)
  expect_equal(j$share, 1)
  expect_equal(t$n_tool[t$tool == "NONMEM"][1], 3L)
  all <- t[t$tool == "All" & t$type == "Joint models", ]
  expect_equal(all$n, 2L)
  expect_equal(all$n_tool, 4L)
})

# Cases from the reading check of September 2026, with invented texts.
test_that("background, future-work and literature sentences do not count", {
  r <- classifyAnalysis(paste(
    "A population pharmacokinetic model was developed for drug X.",
    "Future work could combine this with deep learning.",
    "Previous studies used PBPK models for this drug."
  ), types())
  expect_equal(r$types[[1]], "PK only")
  r2 <- classifyAnalysis("In this study we previously developed a PBPK model and now extend it.", types())
  expect_true("QSP, PBPK" %in% r2$types[[1]])
})

test_that("target attainment alone is not a PK/PD response model", {
  r <- classifyAnalysis("PK/PD target attainment was simulated against the MIC breakpoint for cefazolin.", types())
  expect_false("PK/PD, exposure-response, disease progression" %in% r$types[[1]])
  r2 <- classifyAnalysis(
    "A PK/PD model with an Emax effect on bacterial kill; target attainment was also assessed.", types()
  )
  expect_true("PK/PD, exposure-response, disease progression" %in% r2$types[[1]])
})

test_that("joint models need an event, and parent-metabolite joint fits are not joint models", {
  typesOf <- function(x) classifyAnalysis(x, types())$types[[1]]
  expect_true("Joint models" %in% typesOf("A joint model of tumour size and overall survival."))
  expect_false("Joint models" %in% typesOf("Parent and metabolite were described in a joint model."))
  expect_false("Joint models" %in% classifyAnalysis(
    "Tumour size was modelled first; its predictions then entered a separate survival model.", types()
  )$types[[1]])
})

test_that("MAP estimation and empirical Bayes are not full Bayesian hierarchical models", {
  expect_false("Full Bayesian hierarchical models" %in% classifyAnalysis(
    "The posterior distribution of clearance was used for MAP dose individualisation in TDM.", types()
  )$types[[1]])
  expect_true("Full Bayesian hierarchical models" %in% classifyAnalysis(
    "Population parameters were estimated by MCMC with informative priors.", types()
  )$types[[1]])
})

test_that("viral load and glucose-insulin models are continuous responses", {
  pkpd <- "PK/PD, exposure-response, disease progression"
  expect_true(pkpd %in% classifyAnalysis("A viral load model of HIV decline.", types())$types[[1]])
  expect_true("PK/PD, exposure-response, disease progression" %in% classifyAnalysis(
    "A glucose-insulin model of the OGTT.", types()
  )$types[[1]])
})

test_that("tool names are never evidence of an analysis type", {
  r <- classifyAnalysis(
    c("Models were fitted in Stan.", "Models were fitted in WinBUGS.", "Monolix and NONMEM were compared."), types()
  )
  expect_false(any(vapply(r$types, function(x) "Full Bayesian hierarchical models" %in% x, logical(1))))
})

test_that("typeLift compares a tool's share of a type with the items not naming the tool", {
  items <- data.frame(id = 1:6, tools = c("Stan", "Stan", "NONMEM", "NONMEM", "NONMEM", "NONMEM"))
  items$types <- list("Bayes", "PK", "Bayes", "PK", "PK", "PK")
  l <- typeLift(items)
  b <- l[l$tool == "Stan" & l$type == "Bayes", ]
  expect_equal(b$share_tool, 1 / 2)
  expect_equal(b$share_rest, 1 / 4)
  expect_equal(b$ratio, 2)
  expect_true(b$lower < 2 && b$upper > 2)
  expect_true(is.na(l$ratio[l$tool == "Stan" & l$type == "PK"]) == FALSE)
})

# From the FDA reading check (September 2026)
test_that("abbreviation-list definitions of type terms do not count", {
  x <- "Abbreviations: CL, clearance; MCMC, Markov chain Monte Carlo; V, volume. Parameters were estimated with FOCE-I."
  expect_false("Full Bayesian hierarchical models" %in% classifyAnalysis(x, types())$types[[1]])
  y <- "Parameters were estimated by Markov chain Monte Carlo (MCMC) sampling."
  expect_true("Full Bayesian hierarchical models" %in% classifyAnalysis(y, types())$types[[1]])
})

test_that("change from baseline is a continuous response", {
  x <- "An NLME model described percent change from baseline in EASI over time."
  expect_true("PK/PD, exposure-response, disease progression" %in% classifyAnalysis(x, types())$types[[1]])
})

test_that("categorical covariates are inputs, not a categorical outcome", {
  x <- "Categorical covariates tested were sex and race; continuous covariates were weight and age."
  expect_false("Non-continuous endpoints, time-to-event" %in% classifyAnalysis(x, types())$types[[1]])
  y <- "An ordered categorical model described pain scores."
  expect_true("Non-continuous endpoints, time-to-event" %in% classifyAnalysis(y, types())$types[[1]])
})
