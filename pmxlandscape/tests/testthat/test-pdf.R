# Small PDFs made on the fly: one with a text layer, one that is only an image.
textPdf <- function(lines) {
  f <- withr::local_tempfile(fileext = ".pdf", .local_envir = parent.frame())
  grDevices::pdf(f)
  for (page in lines) {
    graphics::plot.new()
    graphics::text(0.5, 0.5, page, cex = 2)
  }
  grDevices::dev.off()
  f
}

imagePdf <- function(word) {
  png <- withr::local_tempfile(fileext = ".png", .local_envir = parent.frame())
  grDevices::png(png, width = 1600, height = 400)
  graphics::par(mar = rep(0, 4))
  graphics::plot.new()
  graphics::text(0.5, 0.5, word, cex = 12)
  grDevices::dev.off()
  f <- withr::local_tempfile(fileext = ".pdf", .local_envir = parent.frame())
  grDevices::pdf(f, width = 8, height = 2)
  graphics::par(mar = rep(0, 4))
  graphics::plot.new()
  graphics::rasterImage(png::readPNG(png), 0, 0, 1, 1)
  grDevices::dev.off()
  f
}

test_that("pdfPages reads the text layer page by page", {
  skip_if_not_installed("pdftools")
  pg <- pdfPages(textPdf(c(
    "Models were fitted in Monolix\nwith the SAEM algorithm, in 2023",
    "Simulations used mrgsolve\nwith 1000 replicates of the trial"
  )))
  expect_equal(pg$page, 1:2)
  expect_equal(pg$src, c("text", "text"))
  expect_match(pg$text[1], "Monolix")
  expect_match(pg$text[2], "mrgsolve")
})

test_that("pdfPages falls back to OCR for pages without a text layer", {
  skip_if_not_installed("pdftools")
  skip_if_not_installed("png")
  skip_if(Sys.which("tesseract") == "", "tesseract not installed")
  pg <- pdfPages(imagePdf("NONMEM"))
  expect_equal(pg$src, "ocr")
  expect_match(pg$text, "NONMEM")
  expect_equal(pdfPages(imagePdf("NONMEM"), ocr = FALSE)$src, "text")
})

test_that("pdfPages stops when an image-only page needs OCR and tesseract is missing", {
  skip_if_not_installed("pdftools")
  skip_if_not_installed("png")
  f <- imagePdf("NONMEM")
  withr::local_envvar(PATH = "")
  expect_error(pdfPages(f), "tesseract")
})
