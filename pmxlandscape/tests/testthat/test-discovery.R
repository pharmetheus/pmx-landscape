cuesFile <- test_path("../../../taxonomy/discovery/cues.csv")

found <- function(text, cue = NULL) {
  cues <- readCues(cuesFile)
  if (!is.null(cue)) cues <- cues[cues$cue == cue, ]
  m <- softwareCandidates(text, "x", cues, stop = readLines(test_path("../../../taxonomy/discovery/stopnames.txt")))
  sort(unique(normaliseCandidate(m$raw)))
}

test_that("readCues reads the cue table and rejects a cue without a capture group", {
  cues <- readCues(cuesFile)
  all <- c("vendor", "version", "number", "product", "package", "trademark", "method", "procedure", "function", "url")
  expect_true(all(all %in% cues$cue))
  bad <- withr::local_tempfile(fileext = ".csv")
  write.csv(data.frame(cue = "x", regex = "no group", example = "", note = ""), bad, row.names = FALSE)
  expect_error(readCues(bad), "capture group")
})

test_that("each cue finds the name it is written for", {
  expect_equal(found("Analyses were done in Phoenix NLME (Certara, Princeton, NJ).", "vendor"), "Phoenix NLME")
  expect_equal(found("with MwPharm version 3.6 for dosing", "version"), "MwPharm")
  expect_equal(found("data were analysed with NONMEM 7.5.1 and", "number"), "NONMEM")
  expect_length(found("Clinical Pharmacology 6.2 Summary of Findings", "number"), 0)
  expect_length(found("Carcinogenicity..........................74 and 12.5", "number"), 0)
  expect_equal(found("The WinNonMix software was used", "product"), "WinNonMix")
  expect_equal(found("fitted with the R package nlme and", "package"), "nlme")
  expect_equal(found("using the brms package in R", "package"), "brms")
  expect_equal(found("Simcyp® Simulator was used", "trademark"), "Simcyp")
  expect_equal(found("The model was estimated using P-PHARM and", "method"), "P-PHARM")
  expect_equal(found("fitted with PROC NLMIXED in SAS", "procedure"), "NLMIXED")
  expect_equal(found("using the NLMIXED procedure in SAS", "procedure"), "NLMIXED")
  expect_equal(found("implemented in the nlmefitsa Matlab function [8]", "function"), "nlmefitsa")
  expect_equal(found("fitted with nlme() in R", "function"), "nlme")
  expect_equal(found("see https://www.mathworks.com/help/stats/nlmefit.html for", "url"), "nlmefit")
  expect_equal(found("available at https://cran.r-project.org/package=mapbayr and", "url"), "mapbayr")
  expect_equal(found("code at https://github.com/metrumresearchgroup/bbr.", "url"), "bbr")
})

test_that("the cues leave out the look-alikes", {
  expect_length(found("as shown in Table 2.1 and Figure 3.4, at pH 7.4"), 0)
  expect_length(found("using a two-compartment model with first-order absorption"), 0)
  expect_length(found("version 2 of the protocol was used"), 0)
  expect_length(found("minimising the objective function and the hazard function"), 0)
})

test_that("normaliseCandidate strips versions and trade marks and keeps the name", {
  expect_equal(
    normaliseCandidate(c("NONMEM 7.5.1", "Monolix2024R1", "Simcyp®", "nlmixr2", "PK-Sim", "SAAM II", "Pumas v2.4")),
    c("NONMEM", "Monolix", "Simcyp", "nlmixr", "PK-Sim", "SAAM II", "Pumas")
  )
  expect_equal(candidateKey(c("PK-Sim", "PKSim", "pk sim")), c("pksim", "pksim", "pksim"))
  # an all-lower-case name that also occurs in capitals is kept apart: the R package nlme is not the acronym NLME
  expect_equal(
    candidateKeys(c("nlme", "NLME", "Nlme", "PK-Sim", "pksim")), c("nlme_lc", "nlme", "nlme", "pksim", "pksim")
  )
})

test_that("candidateTable counts items per source, the first year and the known family", {
  mentions <- data.frame(
    source = c("PAGE", "PAGE", "PAGE", "PubMed"), id = c("1", "1", "2", "9"),
    cue = c("version", "vendor", "version", "product"), raw = c("NONMEM 7.4", "NONMEM", "Fitwellix 3.6", "Fitwellix")
  )
  meta <- data.frame(source = c("PAGE", "PAGE", "PubMed"), id = c("1", "2", "9"), year = c(2010L, 2012L, 2015L))
  patterns <- readPatterns(test_path("../../../taxonomy/patterns.json"))
  tab <- candidateTable(mentions, meta, patterns)
  nm <- tab[tab$key == "nonmem", ]
  expect_equal(c(nm$items, nm$items_PAGE, nm$first_year), c(1L, 1L, 2010L)) # one item, two mentions
  expect_equal(nm$known_family, "NONMEM")
  mw <- tab[tab$key == "fitwellix", ]
  expect_equal(c(mw$items, mw$items_PAGE, mw$items_PubMed, mw$first_year), c(2L, 1L, 1L, 2012L))
  expect_equal(mw$known_family, "")
  expect_equal(mw$cues, "product; version")
})

test_that("toolInclusion counts distinct items per family and source and applies the rule", {
  mentions <- data.frame(
    source = c("PAGE", "PAGE", "PAGE", "PAGE", "PubMed", "PAGE", "PAGE"),
    id = c("1", "1", "2", "3", "9", "4", "5"),
    key = c("rxode", "rxode2", "rxode", "rxode", "rxode", "wnm", "sas")
  )
  decisions <- data.frame(
    key = c("rxode", "rxode2", "wnm", "sas"), decision = c("auxiliary", "auxiliary", "estimation", "general"),
    family = c("RxODE", "RxODE", "WinNonMix", "SAS")
  )
  registries <- data.frame(key = "wnm", registry = "page_estimation")
  inc <- toolInclusion(mentions, decisions, registries, minItems = 3)
  rx <- inc[inc$family == "RxODE", ]
  expect_equal(c(rx$items_PAGE, rx$items_PubMed), c(3L, 1L)) # item 1 named twice, counted once
  expect_true(rx$in_scope)
  wn <- inc[inc$family == "WinNonMix", ]
  expect_true(wn$in_scope) # one item, but on a registry
  expect_false("SAS" %in% inc$family) # general-purpose software is not a search family
  expect_false(toolInclusion(mentions, decisions, registries[0, ], minItems = 3)$in_scope[inc$family == "WinNonMix"])
})

test_that("toolInclusion admits a registry family only once it occurs in an item", {
  mentions <- data.frame(source = "PAGE", id = "1", key = "wnm")
  decisions <- data.frame(
    key = c("wnm", "be"), decision = c("estimation", "auxiliary"), family = c("WinNonMix", "BE")
  )
  registries <- data.frame(key = c("wnm", "be"), registry = "cran_pk")
  inc <- toolInclusion(mentions, decisions, registries, minItems = 3)
  expect_equal(inc$in_scope[inc$family == "WinNonMix"], TRUE)
  expect_equal(inc$in_scope[inc$family == "BE"], FALSE) # listed, but in no item
  inc0 <- toolInclusion(mentions, decisions, registries, minItems = 3, registryMinItems = 0)
  expect_equal(inc0$in_scope[inc0$family == "BE"], TRUE)
})

test_that("taxonomyCheck lists families to add and taxonomy families without a reason to stay", {
  inc <- data.frame(
    family = c("RxODE", "WinNonMix", "Rare"), group = c("auxiliary", "estimation", "estimation"),
    in_scope = c(TRUE, TRUE, FALSE)
  )
  software <- data.frame(
    family = c("RxODE", "FERX", "Rare", "SAS"), group = c("auxiliary", "estimation", "estimation", "other")
  )
  keep <- data.frame(family = "FERX", reason = "in the FDA survey list")
  chk <- taxonomyCheck(inc, software, keep)
  expect_equal(chk$family[chk$action == "add"], "WinNonMix")
  expect_equal(chk$family[chk$action == "keep"], "FERX")
  expect_equal(chk$family[chk$action == "review"], "Rare") # in the taxonomy, below the rule, no reason recorded
  expect_false("SAS" %in% chk$family) # general-purpose families are outside the rule
})
