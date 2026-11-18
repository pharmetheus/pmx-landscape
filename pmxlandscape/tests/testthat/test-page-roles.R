roleAbstracts <- function() {
  data.frame(
    abstract_no = c("1", "2", "3", "4"), year = "2024", affiliation_type = "academia", software_demo = FALSE,
    estimation = c("NONMEM; Monolix", "NONMEM", "", "Monolix"), pdf_estimation = c("", "", "Pumas", ""),
    estimation_source = c("abstract", "abstract", "pdf", "abstract"), stringsAsFactors = FALSE
  )
}
roleDecisions <- function() {
  data.frame(
    abstract_no = c("1", "2", "3"),
    roles = c("NONMEM=used;Monolix=comparator", "NONMEM=mentioned", "Pumas=used"), stringsAsFactors = FALSE
  )
}

test_that("pageUsedTools keeps only the tools read as used, and an abstract with none names no tool", {
  u <- pageUsedTools(roleAbstracts(), roleDecisions())
  expect_equal(u$estimation, c("NONMEM", "", "Pumas", "Monolix"))
  expect_equal(u$estimation_source, c("abstract", "none", "pdf", "abstract")) # 4 has no reading and is unchanged
  expect_equal(u$pdf_estimation, c("", "", "", ""))
})

test_that("pageShares counts the used tools after pageUsedTools", {
  s <- pageShares(pageUsedTools(roleAbstracts(), roleDecisions()), groups = list(all = NULL))
  expect_equal(unique(s$n_any), 3) # abstracts 1, 3 and 4
  expect_equal(s$n[s$family == "Monolix"], 1) # only abstract 4; in 1 Monolix is a comparator
})

test_that("pageUsedTools stops on a role it does not know", {
  d <- roleDecisions()
  d$roles[1] <- "NONMEM=unsure"
  expect_error(pageUsedTools(roleAbstracts(), d), "unknown role")
})

test_that("pageUsedTools keeps tool names that contain spaces", {
  a <- roleAbstracts()[1, ]
  a$estimation <- "Phoenix NLME; Stan/Torsten"
  d <- data.frame(abstract_no = "1", roles = "Phoenix NLME=used; Stan/Torsten=comparator")
  expect_equal(pageUsedTools(a, d)$estimation, "Phoenix NLME")
})

test_that("pageToolUse takes the tools from the tool use tags, and the poster tools where the body has none used", {
  a <- roleAbstracts()
  a <- rbind(a, transform(a[3, ], abstract_no = "5", pdf_estimation = "NONMEM"))
  tags <- data.frame(
    source = "PAGE", item_id = c("1", "1", "2", "4", "5", "6"),
    label = c("NONMEM", "Monolix", "NONMEM", "nlme", "nlme", "NONMEM"),
    value = c("used", "comparator", "mentioned", "used", "mentioned", "used")
  )
  u <- pageToolUse(a, tags)
  expect_equal(u$abstract_no, c("1", "2", "3", "4", "5"))
  expect_equal(u$estimation, c("NONMEM", "", "", "nlme", ""))
  expect_equal(u$estimation_source, c("abstract", "none", "pdf", "abstract", "pdf"))
  expect_equal(u$pdf_estimation, c("", "", "Pumas", "", "NONMEM")) # 3 and 5 keep their poster tools
  n <- pageToolUse(a, tags, used = FALSE) # naming: every tool the body names
  expect_equal(n$estimation, c("NONMEM; Monolix", "NONMEM", "", "nlme", "nlme"))
  expect_equal(n$estimation_source, c("abstract", "abstract", "pdf", "abstract", "abstract"))
})
