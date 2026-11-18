test_that("literatureShares counts papers naming any estimation tool as the union of tool IDs", {
  ids <- data.frame(
    source = "PubMed", year = 2021L,
    software = c(rep("All (base set)", 10), "NONMEM", "NONMEM", "Monolix", "Monolix", "InsightRX"),
    id = c(as.character(1:10), "1", "2", "2", "3", "4")
  )
  s <- literatureShares(ids, estimation = c("NONMEM", "Monolix"))
  expect_equal(s$base_n, c(10L, 10L))
  expect_equal(s$n_any, c(3L, 3L)) # papers 1, 2 and 3; InsightRX is not an estimation tool
  expect_equal(s$n[s$software == "NONMEM"], 2L)
  expect_equal(s$share[s$software == "NONMEM"], 2 / 3)
  expect_equal(s$share_all[s$software == "Monolix"], 2 / 10)
})

test_that("literatureShares splits by group when a group column is given", {
  ids <- data.frame(
    source = "PubMed", year = 2021L, software = c("All (base set)", "All (base set)", "NONMEM", "NONMEM"),
    id = c("1", "2", "1", "2")
  )
  groups <- c("1" = "sponsor", "2" = "academia")
  s <- literatureShares(ids, estimation = "NONMEM", group = groups)
  expect_equal(s$group, c("academia", "sponsor"))
  expect_equal(s$n_any, c(1L, 1L))
})

test_that("literatureShares reports 0 for a family in years where it is not named", {
  ids <- data.frame(
    source = "PubMed", year = c(2021L, 2021L, 2021L, 2022L, 2022L),
    software = c("All (base set)", "NONMEM", "Monolix", "All (base set)", "NONMEM"),
    id = c("1", "1", "1", "2", "2")
  )
  s <- literatureShares(ids, estimation = c("NONMEM", "Monolix"))
  expect_equal(s$n[s$software == "Monolix" & s$year == 2022], 0L)
})

test_that("shareTable gives totals, papers naming a tool and each family's count and share per year", {
  s <- data.frame(
    year = c(2021L, 2021L, 2022L, 2022L), family = c("NONMEM", "Monolix", "NONMEM", "Monolix"),
    n = c(8L, 3L, 9L, 0L), n_any = c(10L, 10L, 9L, 9L), total = c(100L, 100L, 90L, 90L)
  )
  t <- shareTable(s, totalLabel = "All papers", anyLabel = "Naming a tool")
  expect_equal(names(t), c(" ", "2021", "2022"))
  expect_equal(t[[" "]], c("All papers", "Naming a tool", "NONMEM", "Monolix"))
  expect_equal(t[["2021"]], c("100", "10 (10%)", "8 (80%)", "3 (30%)"))
  expect_equal(t[["2022"]], c("90", "9 (10%)", "9 (100%)", "0"))
  small <- data.frame(year = 2021L, family = "NONMEM", n = 1L, n_any = 400L, total = 800L)
  expect_equal(shareTable(small)[["2021"]][3], "1 (<1%)")
})

test_that("literatureShares removes excluded papers from the base set, and only papers naming no tool", {
  ids <- data.frame(
    source = "Europe PMC", year = 2024L,
    software = c(rep("All (base set)", 10), "NONMEM", "NONMEM", "Monolix"),
    id = c(paste0("MED:", 1:10), "MED:1", "MED:2", "MED:3")
  )
  s <- literatureShares(ids, estimation = c("NONMEM", "Monolix"), exclude = c("MED:5", "MED:6", "MED:99"))
  expect_equal(unique(s$base_n), 8L)
  expect_equal(unique(s$n_any), 3L)
  expect_equal(s$share_all[s$software == "NONMEM"], 2 / 8)
  expect_error(
    literatureShares(ids, estimation = c("NONMEM", "Monolix"), exclude = "MED:1"),
    "names an estimation tool"
  )
})

test_that("literatureShares can exclude papers that name a tool, when every paper was read", {
  ids <- data.frame(
    source = "Europe PMC", year = 2024L,
    software = c(rep("All (base set)", 10), "NONMEM", "NONMEM", "Monolix"),
    id = c(paste0("MED:", 1:10), "MED:1", "MED:2", "MED:3")
  )
  s <- literatureShares(ids, estimation = c("NONMEM", "Monolix"), exclude = c("MED:1", "MED:5"), excludeNamed = TRUE)
  expect_equal(unique(s$base_n), 8L)
  expect_equal(unique(s$n_any), 2L)
  expect_equal(s$n[s$software == "NONMEM"], 1L)
  expect_equal(s$share[s$software == "Monolix"], 1 / 2)
})

test_that("literatureUsedIds keeps the base set and adds the tools the tool use tags read as used", {
  ids <- data.frame(
    source = c(rep("PubMed (title/abstract)", 3), "Europe PMC (full text)"),
    year = c("2021", "2021", "2021", "2022"),
    software = c("All (base set)", "All (base set)", "NONMEM", "All (base set)"),
    id = c("1", "2", "1", "MED:9")
  )
  tags <- data.frame(
    source = c("PubMed", "PubMed", "Europe PMC", "Europe PMC", "PAGE"), item_id = c("1", "2", "MED:9", "MED:8", "1"),
    label = c("NONMEM", "Monolix", "Pumas", "NONMEM", "NONMEM"), value = c("used", "mentioned", "used", "used", "used")
  )
  u <- literatureUsedIds(ids, tags)
  expect_equal(nrow(u[u$software == "All (base set)", ]), 3)
  tools <- u[u$software != "All (base set)", ]
  expect_equal(paste(tools$source, tools$year, tools$software, tools$id), c(
    "PubMed (title/abstract) 2021 NONMEM 1", "Europe PMC (full text) 2022 Pumas MED:9"
  ))
})
