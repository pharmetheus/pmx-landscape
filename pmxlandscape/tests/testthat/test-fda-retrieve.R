# Invented pages with the layout of FDA's novel approvals page, an openFDA drugsfda answer and a
# Drugs@FDA table of contents (TOC), as read by sources/fda/scripts/01_frame.py and 02_retrieve.py.
approvalsHtml <- '<html><body><table>
 <tr><th>No.</th><th>Drug Name</th><th>Active Ingredient</th><th>Approval Date</th><th>Use</th></tr>
 <tr><td>2.</td><td>
  <a href="https://www.accessdata.fda.gov/scripts/cder/daf/index.cfm?ApplNo=761999">Drugb</a></td>
  <td>examplemab</td><td>1/15/2099</td><td>To treat a disease</td></tr>
 <tr><td>1.</td><td><a href="https://www.accessdata.fda.gov/drugsatfda_docs/label/2099/219999s000lbl.pdf">Druga</a></td>
  <td>exampletinib <b>tablets</b></td><td>1/10/2099</td><td>To treat another</td></tr>
 <tr><td>3.</td><td>Drugc</td><td>exampleparin</td><td>2/1/2099</td><td>Use</td></tr>
 <tr><td>4.</td><td>Drugd</td><td>none</td><td>2/2/2099</td><td>Use</td></tr>
 <tr><td colspan="4">A note row</td></tr>
</table><table><tr><td>a</td><td>b</td><td>c</td><td>d</td></tr></table></body></html>'

openFdaJson <- '{"results": [{"submissions": [
 {"submission_type": "ORIG", "application_docs": [
   {"type": "Review", "url": "https://www.accessdata.fda.gov/drugsatfda_docs/nda/2099/219999Orig1s000TOC.cfm"},
   {"type": "Label", "url": "https://www.accessdata.fda.gov/label.pdf"},
   {"type": "Review", "url": "https://www.accessdata.fda.gov/drugsatfda_docs/nda/2098/219999Orig2s000TOC.cfm"}]},
 {"submission_type": "SUPPL", "application_docs": [
   {"type": "Review", "url": "https://www.accessdata.fda.gov/drugsatfda_docs/nda/2100/219999s001TOC.cfm"}]},
 {"submission_type": "ORIG"}]}]}'

tocHtml <- '<html><script>
var pdfBaseName = "219999Orig1s000";
var pdfFiles = { approvLtr: 1, clinPharmR: 1, integratedR: 0, multidisciplineR: 1, otherR: 0 }; // END EDIT
</script></html>'

test_that("fdaParseApprovals reads the frame as 01_frame.py does", {
  overrides <- list(Drugc = list(appl = "888888", source = "openFDA generic-name lookup (exampleparin)"))
  f <- fdaParseApprovals(approvalsHtml, overrides)
  expect_equal(f$no, 1:4)
  expect_equal(f$name, c("Druga", "Drugb", "Drugc", "Drugd"))
  expect_equal(f$ingr[1], "exampletinib tablets")
  expect_equal(f$appl, c("219999", "761999", "888888", NA))
  expect_equal(f$label, c(
    "https://www.accessdata.fda.gov/drugsatfda_docs/label/2099/219999s000lbl.pdf", "Drugs@FDA link",
    "openFDA generic-name lookup (exampleparin)", NA
  ))
})

test_that("fdaReviewTocs keeps the review TOCs of original submissions, sorted", {
  expect_equal(fdaReviewTocs(openFdaJson), c(
    "https://www.accessdata.fda.gov/drugsatfda_docs/nda/2098/219999Orig2s000TOC.cfm",
    "https://www.accessdata.fda.gov/drugsatfda_docs/nda/2099/219999Orig1s000TOC.cfm"
  ))
  expect_equal(fdaReviewTocs('{"error": {"code": "NOT_FOUND"}}'), character(0))
})

test_that("fdaParseToc reads the PDF base name and the flagged documents", {
  t <- fdaParseToc(tocHtml, "https://www.accessdata.fda.gov/drugsatfda_docs/nda/2099/219999Orig1s000TOC.cfm")
  expect_equal(t$base, "219999Orig1s000")
  expect_equal(t$flags, c("approvLtr", "clinPharmR", "multidisciplineR"))
  expect_equal(t$note, "")
  toc <- "https://www.accessdata.fda.gov/drugsatfda_docs/nda/2099/219999Orig1s000TOC.cfm"
  u <- fdaParseToc("<html>moved</html>", toc)
  expect_equal(u$base, "219999Orig1s000")
  expect_match(u$note, "base taken from TOC URL")
})

test_that("fdaReviewUrls lists the probes in the order 02_retrieve.py makes them", {
  u <- fdaReviewUrls("219999Orig1s000", c(2099, 2100))
  expect_equal(nrow(u), 6)
  expect_equal(u$type[1:3], c("clinPharmR", "integratedR", "multidisciplineR"))
  expect_equal(u$folder_year, rep(c(2099, 2100), each = 3))
  expect_equal(u$url[2], "https://www.accessdata.fda.gov/drugsatfda_docs/nda/2099/219999Orig1s000IntegratedR.pdf")
})

test_that("fdaImageOnlyPages finds near-empty pages and ignores the page after the last form feed", {
  f <- withr::local_tempfile(fileext = ".txt")
  long <- strrep("Population pharmacokinetic analysis. ", 3)
  writeBin(charToRaw(paste0(long, "\f", "  12  \n", "\f", long, "\f", "\f")), f)
  expect_equal(fdaImageOnlyPages(f), c(2L, 4L))
})

test_that("fdaCompilationFrame takes one year of CDER's NME and new biologic compilation as the frame", {
  x <- data.frame(
    "Proprietary  Name" = c("Druga", "Drugb", "Older"), "Active Ingredient/Moiety" = c("a-mab", "b-tinib", "c"),
    "Application Number(1)" = c(761999, 21999, 18000),
    "FDA Approval Date" = as.POSIXct(c("2019-05-02", "2019-01-10", "1999-01-01"), tz = "UTC"),
    "Approval Year" = c(2019, 2019, 1999), check.names = FALSE
  )
  f <- fdaCompilationFrame(x, 2019)
  expect_equal(f$name, c("Drugb", "Druga"))
  expect_equal(f$appl, c("021999", "761999"))
  expect_equal(f$no, 1:2)
  expect_equal(f$date, c("1/10/2019", "5/2/2019"))
  expect_equal(unique(f$label), "CDER NME and new biologic compilation")
})

test_that("fdaApplByBrand takes the application whose original approval has the frame's date", {
  json <- '{"results": [
   {"application_number": "NDA219998", "submissions": [
     {"submission_type": "ORIG", "submission_status": "AP", "submission_status_date": "20980301"}]},
   {"application_number": "BLA761999", "submissions": [
     {"submission_type": "SUPPL", "submission_status": "AP", "submission_status_date": "20990115"},
     {"submission_type": "ORIG", "submission_status": "AP", "submission_status_date": "20990115"}]}]}'
  expect_equal(fdaApplByBrand(json, "1/15/2099"), "761999")
  expect_true(is.na(fdaApplByBrand(json, "1/16/2099")))
  expect_true(is.na(fdaApplByBrand('{"error": {"code": "NOT_FOUND"}}', "1/15/2099")))
})
