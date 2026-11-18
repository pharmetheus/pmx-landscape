# The API route of step 4: reading requests sent to the Anthropic Message Batches API. The key
# is read from ANTHROPIC_API_KEY (set in ~/.Renviron) and is never printed or saved.

apiKey <- function() {
  k <- Sys.getenv("ANTHROPIC_API_KEY")
  if (!nzchar(k)) stop("ANTHROPIC_API_KEY is not set (put it in ~/.Renviron)")
  k
}

apiCall <- function(path, body = NULL, method = if (is.null(body)) "GET" else "POST", url = NULL) {
  req <- httr2::request(url %||% paste0("https://api.anthropic.com/v1/", path)) |>
    httr2::req_headers("x-api-key" = apiKey(), "anthropic-version" = "2023-06-01", .redact = "x-api-key") |>
    httr2::req_method(method) |>
    httr2::req_timeout(300) |>
    httr2::req_retry(max_tries = 5, is_transient = function(r) httr2::resp_status(r) %in% c(429, 500, 502, 503, 529)) |>
    httr2::req_error(is_error = function(r) FALSE)
  if (!is.null(body)) req <- httr2::req_body_json(req, body, auto_unbox = TRUE, null = "null")
  r <- httr2::req_perform(req)
  if (httr2::resp_status(r) >= 300) {
    msg <- tryCatch(httr2::resp_body_json(r)$error$message, error = function(e) "")
    detail <- if (nzchar(msg %||% "")) paste(":", msg) else ""
    stop("Anthropic API ", method, " ", path, ": HTTP ", httr2::resp_status(r), detail)
  }
  r
}

# Cost from the usage the API reports, at batch rates: cache reads at a tenth of the input
# price, cache writes (one-hour) at twice it.
usageCost <- function(usage, model, prices = apiPrices) {
  p <- prices[prices$model == model, ]
  if (nrow(p) == 0) stop("no price recorded for ", model)
  (usage$input_tokens * p$input + usage$cache_read_input_tokens * p$input * 0.1 +
    usage$cache_creation_input_tokens * p$input * 2 + usage$output_tokens * p$output) / 1e6 / 2
}

#' Estimate the cost of reading requests
#'
#' Counts the input tokens of a sample of requests with the API's free
#' counting endpoint and prices all requests at the batch rate, with
#' `outputPerRequest` output tokens each and no caching (an upper bound for
#' the input). Sends no reading.
#'
#' @param requests Requests from [readingRequests()].
#' @inheritParams readingPrompt
#' @param reader Reader settings (default: the module's).
#' @param outputPerRequest Output tokens assumed per request.
#' @param sample Requests whose tokens are counted.
#'
#' @return A list with `requests`, `input_per_request` (mean of the sample),
#'   `cost` (US dollars) and `model`.
#' @export
apiEstimate <- function(requests, m, reader = m$reader, outputPerRequest = 300, sample = 20) {
  pick <- unique(round(seq(1, nrow(requests), length.out = min(sample, nrow(requests)))))
  counted <- vapply(pick, function(i) {
    b <- apiBody(requests$user[i], m, reader)[c("model", "system", "messages")]
    as.numeric(httr2::resp_body_json(apiCall("messages/count_tokens", b))$input_tokens)
  }, numeric(1))
  cost <- estimateCost(mean(counted) * nrow(requests), outputPerRequest * nrow(requests), reader$model)
  message(sprintf(
    "%d requests to %s: about %.0f input tokens each; estimated cost $%.2f",
    nrow(requests), reader$model, mean(counted), cost
  ))
  list(requests = nrow(requests), input_per_request = mean(counted), cost = cost, model = reader$model)
}

#' Read requests with the Anthropic Message Batches API
#'
#' Estimates the cost first, from the token count of a sample of requests
#' (the free counting endpoint) and an assumed output per request, and stops
#' without sending anything if the estimate exceeds `cap`. Then submits the
#' requests as one batch, waits for it to end, and keeps everything in `dir`:
#' the requests (`requests.jsonl`), the batch ID (`batches.json`), the raw
#' results (`results_<batch>.jsonl`) and a summary with the model, token
#' totals and cost (`run.json`). Called again with the same `dir`, it does not
#' submit again but picks up the batch already sent. `dir` holds source text
#' and is not to be committed.
#'
#' @param requests Requests from [readingRequests()].
#' @inheritParams readingPrompt
#' @param dir The run folder.
#' @param cap The most the run may cost, in US dollars.
#' @param reader Reader settings (default: the module's).
#' @param outputPerRequest Output tokens assumed per request in the estimate.
#' @param sample Requests whose tokens are counted for the estimate.
#' @param poll Seconds between status checks.
#' @param date The date to record.
#'
#' @return As [parseReadings()], plus `cost` (from the reported usage).
#' @export
readWithApi <- function(requests, m, dir, cap, reader = m$reader, outputPerRequest = 300, sample = 20, poll = 60,
                        date = format(Sys.Date())) {
  apiKey()
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  bodies <- lapply(requests$user, apiBody, m = m, reader = reader)
  batchFile <- file.path(dir, "batches.json")
  if (!file.exists(batchFile)) {
    est <- apiEstimate(requests, m, reader, outputPerRequest, sample)$cost
    message(sprintf("estimated cost $%.2f (cap $%.2f)", est, cap))
    if (est > cap) stop(sprintf("estimated cost $%.2f exceeds the cap $%.2f; nothing was sent", est, cap))
    lines <- vapply(seq_along(bodies), function(i) {
      as.character(jsonlite::toJSON(list(custom_id = requests$custom_id[i], params = bodies[[i]]), auto_unbox = TRUE))
    }, character(1))
    writeLines(lines, file.path(dir, "requests.jsonl"), useBytes = TRUE)
    batch <- httr2::resp_body_json(apiCall("messages/batches", list(requests = lapply(seq_along(bodies), function(i) {
      list(custom_id = requests$custom_id[i], params = bodies[[i]])
    }))))
    jsonlite::write_json(list(id = batch$id, submitted = date, estimate_usd = est), batchFile, auto_unbox = TRUE)
  }
  id <- jsonlite::read_json(batchFile)$id
  resultsFile <- file.path(dir, paste0("results_", id, ".jsonl"))
  if (!file.exists(resultsFile)) {
    repeat {
      st <- httr2::resp_body_json(apiCall(paste0("messages/batches/", id)))
      if (identical(st$processing_status, "ended")) break
      Sys.sleep(poll)
    }
    r <- apiCall(NULL, url = st$results_url)
    writeBin(httr2::resp_body_raw(r), resultsFile)
  }
  p <- parseReadings(readLines(resultsFile, encoding = "UTF-8", warn = FALSE), requests, m, run = id, date = date)
  p$cost <- usageCost(p$usage, reader$model)
  jsonlite::write_json(c(
    list(
      batch = id, model = reader$model, requests = nrow(requests), decisions = nrow(p$decisions),
      problems = nrow(p$problems), prompt_hash = promptHash(m), cost_usd = p$cost, date = date
    ),
    p$usage
  ), file.path(dir, "run.json"), auto_unbox = TRUE, pretty = TRUE, digits = NA)
  p
}

#' Requests already sent, unchanged, in an earlier run
#'
#' Compares the full body of each request (model, settings, system prompt,
#' user message and schema) with the bodies an earlier run sent
#' (`requests.jsonl` in its run folder). An identical body was the same
#' request, so its earlier answer stands; only the others need reading.
#'
#' @param requests Requests from [readingRequests()].
#' @inheritParams readingPrompt
#' @param dir The earlier run's folder.
#' @param reader Reader settings (default: the module's).
#'
#' @return The `custom_id`s of the unchanged requests.
#' @export
reusableRequests <- function(requests, m, dir, reader = m$reader) {
  f <- file.path(dir, "requests.jsonl")
  if (!file.exists(f)) {
    return(character(0))
  }
  old <- lapply(readLines(f, encoding = "UTF-8", warn = FALSE), jsonlite::fromJSON, simplifyVector = FALSE)
  json <- function(x) as.character(jsonlite::toJSON(x, auto_unbox = TRUE))
  oldBody <- stats::setNames(vapply(old, function(o) json(o$params), ""), vapply(old, `[[`, "", "custom_id"))
  newBody <- vapply(seq_len(nrow(requests)), function(i) json(apiBody(requests$user[i], m, reader)), "")
  requests$custom_id[!is.na(oldBody[requests$custom_id]) & oldBody[requests$custom_id] == newBody]
}
