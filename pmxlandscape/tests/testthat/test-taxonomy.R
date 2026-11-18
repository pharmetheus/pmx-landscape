# The shared taxonomy in taxonomy/ at the repository root.

taxonomy <- function() {
  utils::read.csv(repoFile("taxonomy", "software.csv"), colClasses = "character", na.strings = character(0))
}
sharedPatterns <- function() readPatterns(repoFile("taxonomy", "patterns.json"))

test_that("every pattern family is in software.csv, and every software.csv family has a pattern", {
  tax <- taxonomy()
  p <- sharedPatterns()
  p <- p[p$group != "marker", ]
  expect_setequal(unique(p$family), tax$family)
  expect_false(anyDuplicated(tax$family) > 0)
})

test_that("pattern groups agree with the taxonomy", {
  tax <- taxonomy()
  p <- sharedPatterns()
  p <- p[p$group != "marker", ]
  expect_equal(p$group, tax$group[match(p$family, tax$family)])
})

test_that("the shared patterns include OpenPMX and the BUGS family", {
  p <- sharedPatterns()
  find <- function(text) p$family[stringi::stri_detect_regex(text, p$regex)]
  expect_equal(find("fitted in OpenPMX 1.0"), "OpenPMX")
  for (name in c("WinBUGS 1.4", "OpenBUGS", "MultiBUGS", "PKBugs", "JAGS 4.3")) {
    expect_equal(find(paste("estimated with", name)), "BUGS", label = name)
  }
  expect_length(find("bugs in the code"), 0)
})

test_that("the shared patterns include PhysPK, PoPy and SAAM II from PAGE's software list", {
  p <- sharedPatterns()
  find <- function(text) p$family[stringi::stri_detect_regex(text, p$regex)]
  expect_equal(find("simulated in PhysPK 2.4"), "PhysPK")
  expect_equal(find("estimated with PoPy 1.0"), "PoPy")
  expect_equal(find("fitted in SAAM II"), "SAAM II")
  expect_equal(find("fitted in SAAM"), "SAAM II")
})

test_that("the shared patterns include the USC*PACK family and InsightRX from the PAGE pilot", {
  p <- sharedPatterns()
  find <- function(text) p$family[stringi::stri_detect_regex(text, p$regex)]
  for (name in c("USC*PACK", "USC PACK", "USCPACK", "MM-USCPACK", "BigWinPops")) {
    expect_equal(find(paste("modelled with", name, "software")), "USC*PACK", label = name)
  }
  expect_equal(find("Pmetrics 2.0"), "Pmetrics") # its successor stays a separate family
  expect_equal(find("the InsightRX Nova MIPD platform"), "InsightRX")
  expect_equal(p$group[p$family == "InsightRX"], "auxiliary")
})

test_that("in the FDA text the shared patterns find every FDA hit, and every extra hit is decided", {
  dir <- realFdaDir()
  shared <- fdaSearch(dir, patterns = sharedPatterns())
  fda <- fdaSearch(dir)
  key <- function(h) paste(h$year, h$appl, h$doc, h$page, h$sw, h$snip)
  expect_true(all(key(fda[fda$sw != "Simcyp", ]) %in% key(shared)))
  # The FDA pattern is case-sensitive; the shared one also finds simcyp, SimCyp, SimCYP and SIMCYP.
  expect_equal(sum(shared$sw == "Simcyp") - sum(fda$sw == "Simcyp"), 14)
  # Hits of the families added after the FDA survey are explained by the record or decided in
  # sources/fda/results/shared_family_decisions.csv (read 2026-10-18).
  added <- utils::read.csv(file.path(dir, "results", "shared_family_decisions.csv"), colClasses = "character")
  exceptions <- rbind(fdaReadExceptions(dir), added[c("year", "application", "software", "reason")])
  expect_equal(nrow(fdaVerify(dir, hits = shared, exceptions = exceptions)), 0)
  expect_gt(nrow(fdaVerify(dir, hits = shared)), 0) # without the decisions the new hits are unexplained
})

test_that("the shared patterns find the 2024 literature's Monolix and Phoenix NLME spellings, and MATLAB NLME", {
  p <- sharedPatterns()
  est <- p[p$group == "estimation", ]
  find <- function(text) est$family[stringi::stri_detect_regex(text, est$regex)]
  expect_equal(find("using nonlinear mixed-effects modelling (MonolixSuite software, version 2023R1)"), "Monolix")
  expect_equal(find("estimated in Monolix2024R1"), "Monolix")
  expect_equal(find("fitted using Phoenix software version 8.3.4 for NLME"), "Phoenix NLME")
  expect_equal(find("Phoenix® NLME™ 8.3"), "Phoenix NLME")
  expect_equal(find("modelled using Phoenix® NLMETM 8.3"), "Phoenix NLME") # PAGE abstracts flatten the trade mark sign
  expect_equal(find("the nlmefitsa Matlab function"), "MATLAB NLME")
  expect_equal(find("sbiofitmixed in SimBiology"), "MATLAB NLME")
  expect_length(find("non-compartmental analysis in Phoenix WinNonlin 8.3"), 0)
  expect_equal(p$family[p$group == "nca" & stringi::stri_detect_regex("Phoenix 8.3.4 for NLME", p$regex)], character(0))
})

test_that("the shared patterns find the forms the version 5 readers listed as unlisted tools", {
  p <- sharedPatterns()
  found <- function(x) findSoftware(x, p)[[1]]
  expect_true("Phoenix NLME" %in% found("fitted in NONMEM and Phoenix, respectively"))
  expect_true("Phoenix NLME" %in% found("platforms such as Monolix, Phoenix, R"))
  expect_false("Phoenix (unspecified)" %in% found("platforms such as Monolix, Phoenix, R"))
  expect_true("Phoenix (unspecified)" %in% found("NCA was done in Phoenix 8.3"))
  expect_false("Phoenix NLME" %in% found("NONMEM was run at a site in Phoenix, AZ"))
  expect_true("S-ADAPT" %in% found("the MCPEM algorithm in the SADAPT program"))
  expect_true("S-ADAPT" %in% found("modelled using MATLAB and ADAPT."))
  expect_true("S-ADAPT" %in% found("the ADAPT-TRAN program"))
  expect_false("S-ADAPT" %in% found("data from the ADAPT Phase 3 study"))
  expect_false("S-ADAPT" %in% found("the ADAPT-sepsis trial and ADAPT Pharma"))
  expect_true("BUGS" %in% found("tools such as NONMEM and BUGS"))
  expect_true("NLMIXED" %in% found("SAS (version 9.04, proc nlmixed)"))
  expect_true("saemix" %in% found("estimated with SAEMIX"))
  expect_true("Stan/Torsten" %in% found("performed in STAN using HMC"))
  expect_true("nlme" %in% found("the NLME function in SPLUS"))
  expect_false("nlme" %in% found("NLME models in NONMEM"))
})

test_that("the shared patterns include the families of the second discovery round", {
  p <- sharedPatterns()
  found <- function(x) findSoftware(x, p)[[1]]
  expect_true("MwPharm" %in% found("using MW\\Pharm 3.83 (Mediware)"))
  expect_true("MwPharm" %in% found("simulated using MwPharm++"))
  expect_true("fit4NM" %in% found("internal validation (fit4NM 3.3.3)"))
  expect_false("fit4NM" %in% found("pump program, http://fit4NM.org/d_asanpump"))
  expect_true("DAISY" %in% found("identifiability in DAISY"))
  expect_true("openNCA" %in% found("a validated system, openNCA version 2.4"))
  expect_true("VCM-TDM" %in% found("using VCM-TDM software"))
  expect_true("caffsim" %in% found("we developed the caffsim R package"))
})

test_that("the shared patterns include the families and name forms of the third discovery round", {
  p <- sharedPatterns()
  found <- function(x) findSoftware(x, p)[[1]]
  expect_true("Monolix" %in% found("Model fitting was performed using MonolixR2019b."))
  expect_true("Monolix" %in% found("written in MonolixTM 2020R1"))
  expect_true("nlmixr" %in% found("estimated with nlmixr2est version 2.1.3"))
  expect_true("MonolixSuite tools" %in% found("simulations were run with RsSimulx"))
  expect_true("FME" %in% found("Identifiability analysis using the FME package in R"))
  expect_true("FME" %in% found("the R packages FME and minpack.lm were used"))
  expect_true("FME" %in% found("deSolve [ 32 ], FME [ 29 ], pksensi [ 27 ]"))
  expect_false("FME" %in% found("using the full model estimation (FME) approach"))
  expect_false("FME" %in% found("Wagenlehner FME, Bausch K"))
  expect_true("ubiquity" %in% found("tools in R, such as mrgsolve, PKPDsim, and ubiquity, with"))
  expect_false("ubiquity" %in% found("the ubiquity of user-friendly software tools"))
  expect_true("MicLab" %in% found("using MicLab 2.70 (Medimatics)"))
  expect_true("PKSolver" %in% found("NCA was performed with the Excel add-in PK solver"))
  expect_true("PKSolver" %in% found("estimated using the Excel PKsolver add-in software"))
})

test_that("the PK-Sim family finds the OSP Suite written as one word, as the R package is", {
  p <- sharedPatterns()
  found <- function(x) findSoftware(x, p)[[1]]
  expect_true("PK-Sim" %in% found("simulations were run with the ospsuite R package"))
  expect_true("PK-Sim" %in% found("using OSPSuite version 11"))
  expect_true("PK-Sim" %in% found("the OSP Suite 11"))
  expect_false("PK-Sim" %in% found("a hospsuite reference"))
})
