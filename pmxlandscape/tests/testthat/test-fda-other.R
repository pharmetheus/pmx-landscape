otherResults <- function() {
  data.frame(
    year = "2021", drug = c("A", "B", "C"), application = c("1", "2", "3"),
    sponsor_tool_family = c("NONMEM", "", ""), sponsor_popPK_software = c("NONMEM 7.4", "", ""),
    evidence_strength = c("stated", "", ""), sponsor_evidence_pages = c("explicit p10", "", ""),
    category = c("Tool stated", "popPK present, software not stated", "popPK present, software not stated"),
    stringsAsFactors = FALSE
  )
}
otherDecisions <- function() {
  data.frame(
    application = c("2", "3"), family = "NONMEM", evidence_strength = c("stated", "indirect"),
    source = c("EMA assessment report", "FDA other review"), document = c("x-epar", "3_otherR"), page = c("5", "31"),
    reason = "r", stringsAsFactors = FALSE
  )
}

test_that("fdaApplyOtherEvidence moves not-stated drugs to stated or indirect and records the source", {
  r <- fdaApplyOtherEvidence(otherResults(), otherDecisions())
  expect_equal(r$category, c("Tool stated", "Tool stated", "Tool stated (indirect)"))
  expect_equal(r$sponsor_tool_family, c("NONMEM", "NONMEM", "NONMEM"))
  expect_equal(r$evidence_strength, c("stated", "stated", "indirect"))
  expect_equal(r$evidence_source, c("FDA review", "EMA assessment report", "FDA other review"))
  expect_equal(r$sponsor_evidence_pages[2], "EMA assessment report x-epar p5")
})

test_that("fdaApplyOtherEvidence refuses to change a drug whose FDA review states the tool", {
  d <- otherDecisions()
  d$application[1] <- "1"
  expect_error(fdaApplyOtherEvidence(otherResults(), d), "not stated")
})

test_that("fdaApplyOtherEvidence refuses unknown drugs, strengths and duplicate rows", {
  d <- otherDecisions()
  expect_error(fdaApplyOtherEvidence(otherResults(), rbind(d, d[1, ])), "once")
  d$evidence_strength[1] <- "likely"
  expect_error(fdaApplyOtherEvidence(otherResults(), d), "evidence_strength")
  d <- otherDecisions()
  d$application[1] <- "9"
  expect_error(fdaApplyOtherEvidence(otherResults(), d), "not in the FDA results")
})

revisionResults <- function() {
  r <- otherResults()
  r$sponsor_tool_family[3] <- "NONMEM"
  r$sponsor_popPK_software[3] <- "NONMEM"
  r$evidence_strength[3] <- "indirect, template phrase only"
  r$sponsor_evidence_pages[3] <- "indirect (final NONMEM data file) p7"
  r$category[3] <- "Tool stated (indirect)"
  r
}
revisions <- function() {
  data.frame(
    application = c("2", "3"), family = "NONMEM", from = c("", "indirect, template phrase only"),
    to = "indirect", pages = c("reviewer ran the Applicant's model in NONMEM p40", "reviewer ran it p9"),
    reason = "r", stringsAsFactors = FALSE
  )
}

test_that("fdaApplyRevisions moves template-only and not-stated drugs and keeps the earlier evidence", {
  r <- fdaApplyRevisions(revisionResults(), revisions())
  expect_equal(r$category, c("Tool stated", "Tool stated (indirect)", "Tool stated (indirect)"))
  expect_equal(r$evidence_strength, c("stated", "indirect", "indirect"))
  expect_equal(r$sponsor_tool_family, c("NONMEM", "NONMEM", "NONMEM"))
  expect_equal(r$sponsor_popPK_software[2], "NONMEM")
  expect_equal(r$sponsor_evidence_pages[2], "reviewer ran the Applicant's model in NONMEM p40")
  expect_equal(r$sponsor_evidence_pages[3], "indirect (final NONMEM data file) p7; reviewer ran it p9")
  expect_equal(r$revision, c("", "r", "r"))
})

test_that("fdaApplyRevisions can add evidence without changing the strength", {
  d <- revisions()[2, ]
  d$from <- d$to <- "indirect"
  res <- revisionResults()
  res$evidence_strength[3] <- "indirect"
  r <- fdaApplyRevisions(res, d)
  expect_equal(r$evidence_strength[3], "indirect")
  expect_equal(r$sponsor_evidence_pages[3], "indirect (final NONMEM data file) p7; reviewer ran it p9")
})

test_that("fdaApplyRevisions refuses a revision written against another state of the record", {
  d <- revisions()
  d$from[2] <- "indirect"
  expect_error(fdaApplyRevisions(revisionResults(), d), "record has")
  d <- revisions()
  d$family[2] <- "Monolix"
  expect_error(fdaApplyRevisions(revisionResults(), d), "tool")
})

test_that("fdaApplyRevisions refuses unknown drugs, strengths and duplicate rows", {
  d <- revisions()
  expect_error(fdaApplyRevisions(revisionResults(), rbind(d, d[1, ])), "once")
  d$to[1] <- "likely"
  expect_error(fdaApplyRevisions(revisionResults(), d), "strength")
  d <- revisions()
  d$application[1] <- "9"
  expect_error(fdaApplyRevisions(revisionResults(), d), "not in the FDA results")
})
