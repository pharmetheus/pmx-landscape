# FDA retrieval in R: frame, review documents and PDFs (the R port of scripts/01_frame.py
# and 02_retrieve.py)
#
# Run from sources/fda/: Rscript retrieve.R [years]   (default 2016 to 2025; resumable; 2026 for the
# window of the last 12 full months ending at least 3 months before the run, decided 2026-10-20)
#
# Per year:
# 1. Frame: FDA's "Novel Drug Approvals for <year>" page (CDER), application numbers from
#    the label or Drugs@FDA links, else config/frame_overrides.json. For years whose page
#    FDA no longer serves (before 2021), CDER's NME and new biologic compilation.
# 2. Review documents: openFDA drugsfda gives the review tables of contents (TOC) of the
#    original submissions; each TOC page gives the PDF base name; the Clinical Pharmacology,
#    Integrated and Multi-Discipline reviews are probed (HEAD) in the folders of the
#    approval year, the next year and the TOC's own year; config/doc_overrides.json last.
# 3. Downloads: every document found, and for the surveyed years (those with a
#    data/<year>/docs.json) every document of the committed record, to cache/pdf/<year>/,
#    named by the record's text file where it has one.
# About one request per second: accessdata.fda.gov fails silently on faster bursts.
#
# Writes:
#   retrieval/<year>/frame.json      the frame as read now (frame_source.txt: where from)
#   retrieval/<year>/docs.json       the documents found now (same format as data/<year>/docs.json)
#   retrieval/<year>/log.csv         per application: TOCs, bases, notes
#   retrieval/<year>/downloads.csv   per PDF: url, file, status, bytes, sha256, date
#   retrieval/<year>/compare.txt     surveyed years: differences from the committed frame and documents
#   cache/<year>/                    pages, openFDA answers, TOCs and PDFs (not committed)

pkgload::load_all("../../pmxlandscape", quiet = TRUE)

years <- as.integer(commandArgs(trailingOnly = TRUE))
if (length(years) == 0) years <- 2016:2025
ua <- "pmx-software-landscape (research; niclas.jonsson@pharmetheus.com)"
run_date <- format(Sys.Date())
frame_overrides <- jsonlite::read_json("config/frame_overrides.json")
compilation_url <- "https://www.fda.gov/media/177921/download?attachment"
doc_overrides <- jsonlite::read_json("config/doc_overrides.json")

# GET or HEAD with retries, as common.py's get(): 200 and 404 are answers, anything else is retried
fetch <- function(url, head = FALSE, tries = 5, timeout = 180) {
  req <- httr2::request(gsub(" ", "%20", url)) |>
    httr2::req_user_agent(ua) |>
    httr2::req_timeout(timeout) |>
    httr2::req_error(is_error = function(r) FALSE)
  if (head) req <- httr2::req_method(req, "HEAD")
  r <- NULL
  for (i in seq_len(tries)) {
    r <- tryCatch(httr2::req_perform(req), error = function(e) NULL)
    if (!is.null(r) && httr2::resp_status(r) %in% c(200, 404)) {
      return(r)
    }
    Sys.sleep(3 * i)
  }
  r
}
cached_text <- function(url, file, delay = 0.5) {
  if (file.exists(file)) {
    return(readText(file))
  }
  Sys.sleep(delay)
  r <- fetch(url)
  if (is.null(r) || httr2::resp_status(r) != 200) {
    return(NA_character_)
  }
  writeBin(httr2::resp_body_raw(r), file)
  readText(file)
}
status_of <- function(r) if (is.null(r)) NA_integer_ else httr2::resp_status(r)

for (y in years) {
  cache <- file.path("cache", y)
  out <- file.path("retrieval", y)
  for (d in file.path(cache, c("openfda", "toc", "pdf"))) dir.create(d, recursive = TRUE, showWarnings = FALSE)
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  cat("==", y, "\n")

  # ---- 1. Frame ----
  page <- cached_text(sprintf("https://www.fda.gov/drugs/novel-drug-approvals-fda/novel-drug-approvals-%d", y),
    file.path(cache, "novel_approvals_page.html"),
    delay = 1
  )
  if (!is.na(page)) {
    frame <- fdaParseApprovals(page, frame_overrides[[as.character(y)]] %||% list())
    # The 2026 page links neither labels nor Drugs@FDA: look the brand name up in openFDA and take the
    # application approved on the page's date
    for (i in which(is.na(frame$appl))) {
      j <- cached_text(sprintf(
        'https://api.fda.gov/drug/drugsfda.json?search=products.brand_name:"%s"&limit=20',
        toupper(frame$name[i])
      ), file.path(cache, "openfda", paste0("brand_", gsub("\\W", "_", frame$name[i]), ".json")))
      if (is.na(j)) next
      frame$appl[i] <- fdaApplByBrand(j, frame$date[i])
      if (!is.na(frame$appl[i])) frame$label[i] <- "openFDA brand-name lookup"
    }
    frame_source <- sprintf("FDA, Novel Drug Approvals for %d (fetched %s)", y, run_date)
  } else {
    # FDA no longer serves the pages before 2021 (October 2026); its NME and new biologic compilation lists the
    # same approvals (checked against the 2021 to 2025 frames)
    comp <- file.path("cache", "compilation.xlsx")
    if (!file.exists(comp)) {
      r <- fetch(compilation_url)
      if (is.null(r) || httr2::resp_status(r) != 200) stop("could not fetch the approvals page or the compilation for ", y)
      writeBin(httr2::resp_body_raw(r), comp)
    }
    frame <- fdaCompilationFrame(as.data.frame(suppressWarnings(readxl::read_excel(comp))), y)
    frame_source <- sprintf(
      "CDER NME and new biologic compilation, %s (fetched %s, sha256 %s)", compilation_url,
      format(file.mtime(comp), "%Y-%m-%d"), digest::digest(file = comp, algo = "sha256")
    )
  }
  writeLines(frame_source, file.path(out, "frame_source.txt"))
  jsonlite::write_json(frame, file.path(out, "frame.json"), auto_unbox = TRUE, pretty = TRUE, na = "null")
  cat(nrow(frame), "drugs;", sum(is.na(frame$appl)), "without an application number\n")

  # ---- 2. Review documents ----
  log_file <- file.path(out, "log.csv")
  log <- if (file.exists(log_file)) read.csv(log_file, colClasses = "character") else NULL
  docs_file <- file.path(out, "docs.json")
  docs <- if (file.exists(docs_file)) jsonlite::read_json(docs_file) else list()
  overrides <- doc_overrides[[as.character(y)]] %||% list()
  for (appl in frame$appl[!is.na(frame$appl)]) {
    if (!is.null(log) && appl %in% log$appl) next
    prefix <- if (grepl("^(761|125)", appl)) "BLA" else "NDA"
    j <- cached_text(sprintf('https://api.fda.gov/drug/drugsfda.json?search=application_number:"%s%s"&limit=5', prefix, appl),
      file.path(cache, "openfda", paste0(appl, ".json")),
      delay = 0.5
    )
    tocs <- if (is.na(j)) character(0) else fdaReviewTocs(j)
    notes <- if (length(tocs) == 0) "no TOC in openFDA" else character(0)
    bases <- character(0)
    flags <- character(0)
    for (k in seq_along(tocs)) {
      t <- cached_text(tocs[k], file.path(cache, "toc", sprintf("%s_%d.html", appl, k)), delay = 0.5)
      p <- fdaParseToc(if (is.na(t)) "" else t, tocs[k])
      if (!is.na(p$base)) bases <- c(bases, p$base)
      if (nzchar(p$note)) notes <- c(notes, p$note)
      if (length(p$flags)) flags <- p$flags # as 02_retrieve.py: the last TOC with flags wins
    }
    if (length(bases) == 0) bases <- paste0(appl, "Orig1s000")
    folder_years <- sort(unique(c(y, y + 1, as.integer(unlist(stringi::stri_match_all_regex(tocs, "/nda/(\\d{4})/")) |>
      grep(pattern = "^\\d{4}$", value = TRUE)))))
    probes <- fdaReviewUrls(bases, folder_years)
    found <- probes[vapply(probes$url, function(u) {
      Sys.sleep(0.6)
      r <- fetch(u, head = TRUE)
      !is.null(r) && httr2::resp_status(r) == 200 && grepl("pdf", tolower(httr2::resp_header(r, "Content-Type") %||% ""))
    }, logical(1)), ]
    missing <- setdiff(intersect(names(fdaDocTypes), flags), found$type)
    if (length(missing)) notes <- c(notes, sprintf("TOC lists %s but the file was not found (broken link)", paste(missing, collapse = ", ")))
    recs <- lapply(seq_len(nrow(found)), function(i) {
      list(
        type = found$type[i], folder_year = as.character(found$folder_year[i]), url = gsub(" ", "%20", found$url[i]),
        text_file = sprintf("txt/%s_%s_%s_%d.txt", appl, found$type[i], found$folder_year[i], i - 1)
      )
    })
    for (ov in overrides[[appl]] %||% list()) {
      if (any(vapply(recs, function(r) r$url == gsub(" ", "%20", ov$url), logical(1)))) next
      recs[[length(recs) + 1]] <- list(
        type = ov$type, folder_year = ov$folder_year, url = gsub(" ", "%20", ov$url),
        text_file = sprintf("txt/%s_%s_%s_%d.txt", appl, ov$type, ov$folder_year, length(recs))
      )
      notes <- c(notes, paste("manual override:", ov$reason))
    }
    docs[[appl]] <- recs
    log <- rbind(log, data.frame(
      appl = appl, toc = paste(tocs, collapse = " "), bases = paste(bases, collapse = " "),
      flags = paste(flags, collapse = " "), notes = paste(notes, collapse = "; "), checked = run_date
    ))
    write.csv(log, log_file, row.names = FALSE)
    jsonlite::write_json(docs, docs_file, auto_unbox = TRUE, pretty = TRUE)
    cat(appl, vapply(recs, function(r) paste(r$type, r$folder_year), ""), notes, "\n")
  }

  # ---- 3. Downloads ----
  committed_file <- file.path("data", y, "docs.json")
  committed <- if (file.exists(committed_file)) jsonlite::read_json(committed_file) else list()
  want <- do.call(rbind, lapply(list(committed, docs), function(dd) {
    do.call(rbind, lapply(names(dd), function(a) {
      do.call(rbind, lapply(dd[[a]], function(r) data.frame(appl = a, url = r$url, stem = sub("\\.txt$", "", basename(r$text_file)))))
    }))
  }))
  want <- want[!duplicated(want$url), ] # the committed record's file names first
  dl_file <- file.path(out, "downloads.csv")
  dl <- if (file.exists(dl_file)) read.csv(dl_file, colClasses = "character") else NULL
  for (i in seq_len(nrow(want))) {
    if (!is.null(dl) && want$url[i] %in% dl$url[dl$status == "200"]) next
    f <- file.path(cache, "pdf", paste0(want$stem[i], ".pdf"))
    Sys.sleep(1)
    r <- fetch(want$url[i])
    ok <- !is.null(r) && httr2::resp_status(r) == 200 && identical(httr2::resp_body_raw(r)[1:4], charToRaw("%PDF"))
    if (ok) writeBin(httr2::resp_body_raw(r), f)
    if (!is.null(dl)) dl <- dl[dl$url != want$url[i], , drop = FALSE]
    dl <- rbind(dl, data.frame(
      appl = want$appl[i], url = want$url[i], file = basename(f), status = as.character(if (ok) 200L else status_of(r)),
      bytes = if (ok) as.character(file.size(f)) else "", sha256 = if (ok) digest::digest(file = f, algo = "sha256") else "",
      date = run_date
    ))
    write.csv(dl, dl_file, row.names = FALSE)
  }
  cat(sum(dl$status == "200"), "of", nrow(want), "PDFs downloaded\n")

  # ---- Comparison with the committed record (surveyed years) ----
  if (length(committed)) {
    old_frame <- jsonlite::read_json(file.path("data", y, "frame.json"), simplifyVector = TRUE)
    key <- function(f) paste(f$name, f$appl)
    urls <- function(dd) sort(unlist(lapply(dd, function(x) vapply(x, `[[`, "", "url"))))
    lines <- c(
      paste("compared:", run_date),
      sprintf("frame: %d drugs now, %d in the record", nrow(frame), nrow(old_frame)),
      paste("in the record only:", paste(setdiff(key(old_frame), key(frame)), collapse = ", ")),
      paste("found now only:", paste(setdiff(key(frame), key(old_frame)), collapse = ", ")),
      sprintf("documents: %d found now, %d in the record", length(urls(docs)), length(urls(committed))),
      paste("in the record only:", paste(setdiff(urls(committed), urls(docs)), collapse = " ")),
      paste("found now only:", paste(setdiff(urls(docs), urls(committed)), collapse = " "))
    )
    writeLines(lines, file.path(out, "compare.txt"))
    cat(lines, sep = "\n")
  }
}
