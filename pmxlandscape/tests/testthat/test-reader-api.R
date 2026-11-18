# The API route against mocked responses: no key, no network, no cost.
toyRequests <- function(env = parent.frame()) {
  m <- readModule(test_path("fixtures", "module-toy"))
  root <- toyCorpus(env)
  it <- moduleItems(m, root)
  list(m = m, req = readingRequests(m, ruleDecide(m, moduleCandidates(m, it), it)$queue, it))
}

mockApi <- function(calls, answers) {
  function(req) {
    calls$log <- c(calls$log, paste(req$method %||% "GET", sub("https://api.anthropic.com/v1/", "", req$url)))
    json <- function(x) {
      httr2::response(200, headers = list("content-type" = "application/json"), body = charToRaw(
        as.character(jsonlite::toJSON(x, auto_unbox = TRUE))
      ))
    }
    if (grepl("count_tokens$", req$url)) {
      return(json(list(input_tokens = 2000)))
    }
    if (grepl("batches$", req$url)) {
      return(json(list(id = "msgbatch_test", processing_status = "in_progress")))
    }
    if (grepl("batches/msgbatch_test$", req$url)) {
      return(json(list(
        id = "msgbatch_test", processing_status = "ended",
        results_url = "https://api.anthropic.com/v1/messages/batches/msgbatch_test/results"
      )))
    }
    if (grepl("results$", req$url)) {
      return(httr2::response(200, body = charToRaw(paste(answers, collapse = "\n"))))
    }
    httr2::response(404)
  }
}

answerLine <- function(id, label, value) {
  as.character(jsonlite::toJSON(list(custom_id = id, result = list(type = "succeeded", message = list(
    model = "claude-sonnet-5-5", stop_reason = "end_turn",
    content = list(list(type = "text", text = as.character(jsonlite::toJSON(
      list(decisions = list(list(label = label, value = value, note = "n"))),
      auto_unbox = TRUE
    )))),
    usage = list(
      input_tokens = 100, output_tokens = 30, cache_read_input_tokens = 1900, cache_creation_input_tokens = 0
    )
  ))), auto_unbox = TRUE))
}

test_that("readWithApi stops before sending anything when the estimate exceeds the cap", {
  withr::local_envvar(ANTHROPIC_API_KEY = "test-key")
  x <- toyRequests()
  calls <- new.env()
  httr2::local_mocked_responses(mockApi(calls, character(0)))
  dir <- withr::local_tempdir()
  # 2 requests x 2000 input tokens + 2 x 300 output tokens at the Claude Sonnet 5.5 batch rate is $0.0055
  expect_error(suppressMessages(readWithApi(x$req, x$m, dir, cap = 0.001, poll = 0)), "exceeds the cap")
  expect_false(any(grepl("^POST messages/batches$", calls$log)))
  expect_false(file.exists(file.path(dir, "batches.json")))
})

test_that("readWithApi submits, waits, keeps the raw results and returns the decisions", {
  withr::local_envvar(ANTHROPIC_API_KEY = "test-key")
  x <- toyRequests()
  calls <- new.env()
  answers <- c(answerLine(x$req$custom_id[1], "Tooly", "mentioned"), answerLine(x$req$custom_id[2], "Tooly", "used"))
  httr2::local_mocked_responses(mockApi(calls, answers))
  dir <- withr::local_tempdir()
  r <- suppressMessages(readWithApi(x$req, x$m, dir, cap = 1, poll = 0, date = "2026-10-18"))
  expect_equal(r$decisions$value, c("mentioned", "used"))
  expect_equal(unique(r$decisions$run), "msgbatch_test")
  expect_equal(readLines(file.path(dir, "results_msgbatch_test.jsonl"), warn = FALSE), answers)
  expect_true(file.exists(file.path(dir, "requests.jsonl")))
  run <- jsonlite::read_json(file.path(dir, "run.json"))
  expect_equal(run$model, "claude-sonnet-5-5")
  expect_equal(run$requests, 2)
  # 200 uncached + 3800 cached input tokens and 60 output tokens, at batch rates
  expect_equal(run$cost_usd, (200 * 2 + 3800 * 0.2 + 60 * 10) / 1e6 / 2)
  # a second call finds the batch already submitted and does not submit again
  calls$log <- character(0)
  suppressMessages(readWithApi(x$req, x$m, dir, cap = 1, poll = 0, date = "2026-10-18"))
  expect_false(any(grepl("^POST messages/batches$", calls$log)))
})

test_that("the API key is required and never part of what is saved", {
  withr::local_envvar(ANTHROPIC_API_KEY = "")
  x <- toyRequests()
  expect_error(readWithApi(x$req, x$m, withr::local_tempdir(), cap = 1), "ANTHROPIC_API_KEY")
  withr::local_envvar(ANTHROPIC_API_KEY = "secret-test-key")
  calls <- new.env()
  httr2::local_mocked_responses(mockApi(calls, c(
    answerLine(x$req$custom_id[1], "Tooly", "mentioned"), answerLine(x$req$custom_id[2], "Tooly", "used")
  )))
  dir <- withr::local_tempdir()
  suppressMessages(readWithApi(x$req, x$m, dir, cap = 1, poll = 0))
  saved <- unlist(lapply(list.files(dir, full.names = TRUE), readLines, warn = FALSE))
  expect_false(any(grepl("secret-test-key", saved, fixed = TRUE)))
})

test_that("reusableRequests finds the requests whose whole body was already sent in an earlier run", {
  x <- toyRequests()
  dir <- withr::local_tempdir()
  lines <- vapply(seq_len(nrow(x$req)), function(i) {
    body <- list(custom_id = x$req$custom_id[i], params = apiBody(x$req$user[i], x$m))
    as.character(jsonlite::toJSON(body, auto_unbox = TRUE))
  }, "")
  writeLines(lines, file.path(dir, "requests.jsonl"))
  expect_equal(reusableRequests(x$req, x$m, dir), x$req$custom_id)
  changed <- x$req
  changed$user[2] <- paste(changed$user[2], "more")
  expect_equal(reusableRequests(changed, x$m, dir), x$req$custom_id[1])
  m2 <- x$m
  m2$rubric <- "Another rubric."
  expect_length(reusableRequests(x$req, m2, dir), 0)
})
