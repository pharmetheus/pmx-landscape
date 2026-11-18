test_that("fdaReadingRecord turns applicant-use readings into record rows, one per drug", {
  d <- data.frame(
    item_id = c("1", "1", "2", "3"), label = c("NONMEM", "Stan/Torsten", "Monolix", "NONMEM"),
    value = c("indirect", "none", "template", "none")
  )
  frame <- data.frame(
    appl = c("1", "2", "3", "4"), name = c("A", "B", "C", "D"),
    date = c("1/5/2026", "2/1/2026", "3/1/2026", "4/1/2026")
  )
  r <- fdaReadingRecord(d, frame, 2026)
  expect_equal(r$application, c("1", "2", "3", "4"))
  expect_equal(r$sponsor_tool_family, c("NONMEM", "Monolix", NA, NA))
  expect_equal(r$evidence_strength, c("indirect", "indirect, template phrase only", NA, NA))
  none <- "No tool identified in review"
  expect_equal(r$category, c("Tool stated (indirect)", "Tool stated (indirect)", none, none))
  expect_equal(r$approval_date, as.Date(c("2026-01-05", "2026-02-01", "2026-03-01", "2026-04-01")))
  # a stated tool wins over indirect evidence for another one
  d2 <- data.frame(item_id = c("1", "1"), label = c("Monolix", "NONMEM"), value = c("indirect", "stated"))
  expect_equal(fdaReadingRecord(d2, frame[1, ], 2026)$sponsor_tool_family, "NONMEM")
})

test_that("fdaPeriods ends at the latest June or December at least three months past", {
  p <- fdaPeriods(as.Date("2026-10-20"), first = as.Date("2020-07-01"))
  expect_equal(p$label, c("2020/21", "2021/22", "2022/23", "2023/24", "2024/25", "2025/26"))
  expect_equal(p$start[1], as.Date("2020-07-01"))
  expect_equal(p$end[6], as.Date("2026-06-30"))
  # until the end of March 2027 the periods run July to June
  expect_equal(tail(fdaPeriods(as.Date("2027-03-31"))$label, 1), "2025/26")
  # from April 2027 they are calendar years, ending in December 2026
  p <- fdaPeriods(as.Date("2027-04-01"), first = as.Date("2021-01-01"))
  expect_equal(p$label, as.character(2021:2026))
  expect_equal(p$end[6], as.Date("2026-12-31"))
  # from October 2027 they run July to June again
  expect_equal(tail(fdaPeriods(as.Date("2027-09-30"))$label, 1), "2026")
  expect_equal(tail(fdaPeriods(as.Date("2027-10-01"))$label, 1), "2026/27")
  # a period starting before `first` is left out
  expect_equal(fdaPeriods(as.Date("2027-04-01"), first = as.Date("2020-07-01"))$label[1], "2021")
})

test_that("fdaPeriodOf gives each date its period, NA outside them", {
  p <- fdaPeriods(as.Date("2026-10-20"), first = as.Date("2020-07-01"))
  d <- as.Date(c("2020-06-30", "2020-07-01", "2021-06-30", "2021-07-01", "2026-06-30", "2026-07-01"))
  expect_equal(fdaPeriodOf(d, p), c(NA, "2020/21", "2020/21", "2021/22", "2025/26", NA))
})
