test_that("readModule reads a module and checks its parts", {
  m <- readModule(toyDir())
  expect_equal(m$name, "toy")
  expect_equal(m$values$value, c("used", "mentioned"))
  expect_equal(m$rules$id, "1")
  expect_equal(m$patterns$family, c("Toolx", "Tooly", "Helper"))
  bad <- withr::local_tempdir()
  file.copy(list.files(toyDir(), full.names = TRUE), bad)
  writeLines("value,definition\nused,a\nused,b", file.path(bad, "values.csv"))
  expect_error(readModule(bad), "values.csv.*twice")
})

test_that("readingPrompt fills the shared skeleton and its hash follows every part of the method", {
  m <- readModule(toyDir())
  p <- readingPrompt(m)
  expect_match(p, "For each tool named in the item")
  expect_match(p, "- `used`: The item's own analysis was done with the tool.", fixed = TRUE)
  expect_match(p, "only in the background", fixed = TRUE)
  expect_false(grepl("{{", p, fixed = TRUE))
  h <- promptHash(m)
  expect_equal(promptHash(readModule(toyDir())), h)
  m2 <- m
  m2$rubric <- paste(m$rubric, "Another rule.")
  expect_false(promptHash(m2) == h)
  m3 <- m
  m3$reader$model <- "claude-haiku-5-5"
  expect_false(promptHash(m3) == h)
})

test_that("readingSchema is the same envelope for every module, with the module's values", {
  s <- readingSchema(readModule(toyDir()))
  d <- s$properties$decisions$items
  expect_equal(s$required, list("decisions"))
  expect_equal(d$properties$value$enum, list("used", "mentioned"))
  expect_equal(d$required, list("label", "value", "note"))
  expect_false(d$additionalProperties)
})

test_that("moduleItems gives each item in scope its text, with section headings, and its hash", {
  root <- toyCorpus()
  it <- moduleItems(readModule(toyDir()), root)
  expect_equal(it$item_id, c("1", "2", "3"))
  expect_equal(
    it$text[1], "### title\nA model\n\n### body\nThe model was fitted with Toolx. Tooly was used before [1]."
  )
  expect_equal(it$input_hash, corpusRead(root, "page")$items$hash)
})

test_that("a scope can fall back to other sections for items lacking a required one", {
  root <- withr::local_tempdir()
  s <- corpusSections(
    "Europe PMC", c("A", "A", "A", "B", "B"), c("title", "methods", "body", "title", "body"), "", "xml",
    c("Paper A", strrep("Fitted in Toolx. ", 20), "Intro. Fitted in Toolx.", "Paper B", "Paper B body uses Toolx.")
  )
  it <- corpusItems("Europe PMC", c("A", "B"), 2024L, c("ua", "ub"), "full text", "d", sections = s)
  corpusWrite(list(items = it, sections = s), root, "epmc")
  m <- readModule(toyDir())
  m$scope <- list("Europe PMC" = list(
    sections = list("title", "methods"), fallback = list("title", "body"), required = "methods", min_chars = 100
  ))
  x <- moduleItems(m, root)
  expect_equal(x$item_id, c("A", "B"))
  expect_false(grepl("Intro", x$text[1], fixed = TRUE))
  expect_match(x$text[2], "### body\nPaper B body uses Toolx.", fixed = TRUE)
  m$scope[["Europe PMC"]]$min_chars <- 1000
  expect_match(moduleItems(m, root)$text[1], "Intro", fixed = TRUE)
})

test_that("moduleCandidates gives one candidate per item and label, and ruleDecide settles what a rule can", {
  m <- readModule(toyDir())
  it <- moduleItems(m, toyCorpus())
  cand <- moduleCandidates(m, it)
  expect_equal(paste(cand$item_id, cand$label), c("1 Toolx", "1 Tooly", "2 Tooly"))
  r <- ruleDecide(m, cand, it)
  expect_equal(paste(r$decided$item_id, r$decided$label, r$decided$value), "1 Toolx used")
  expect_equal(r$decided$method, "rule")
  expect_equal(r$decided$reader, "rules.csv:1")
  expect_equal(paste(r$queue$item_id, r$queue$label), c("1 Tooly", "2 Tooly"))
})

test_that("rules see the sentence around the tool, the whole item and the number of candidates", {
  m <- readModule(toyDir())
  it <- data.frame(source = "PAGE", item_id = c("1", "2", "3", "4"), year = 2025L, input_hash = "h", text = c(
    "The model was fitted with Toolx 7.4. Data were rich.",
    "The model was fitted with Toolx 7.4 and compared with earlier fits.",
    "The model was fitted with Toolx 7.4. Results were compared with earlier Toolx estimates.",
    "The model was fitted with Toolx 7.4. Tooly was named."
  ))
  cand <- moduleCandidates(m, it)
  m$rules <- data.frame(
    id = "v", label = ".*", context = "{{tool}}\\s*\\d", sentence_exclude = "compar",
    item_exclude = "compar\\w*[^.]{0,40}{{tools}}", max_candidates = "1", value = "used", note = "version"
  )
  r <- ruleDecide(m, cand, it)
  expect_equal(paste(r$decided$item_id, r$decided$label), "1 Toolx")
  expect_equal(r$decided$reader, "rules.csv:v")
  expect_equal(sort(paste(r$queue$item_id, r$queue$label)), c("2 Toolx", "3 Toolx", "4 Toolx", "4 Tooly"))
  m$rules$max_candidates <- ""
  expect_true("4 Toolx" %in% paste(ruleDecide(m, cand, it)$decided$item_id, ruleDecide(m, cand, it)$decided$label))
  # the tool's own pattern keeps its case: a pattern for "nlme" does not match "NLME" in a rule either
  m2 <- m
  nlme <- data.frame(name = "nlme", group = "estimation", regex = "\\bnlme\\b", family = "nlme")
  m2$patterns <- rbind(m$patterns, nlme)
  low <- data.frame(
    source = "PAGE", item_id = "5", year = 2025L, input_hash = "h", text = "Fits used NLME 3.1 and nlme 3.1."
  )
  c5 <- moduleCandidates(m2, low)
  expect_equal(c5$label, "nlme")
  m2$rules$context <- "^Fits used {{tool}}"
  expect_equal(nrow(ruleDecide(m2, c5, low)$decided), 0)
})

test_that("readingRequests makes one request per item with its open candidates", {
  m <- readModule(toyDir())
  it <- moduleItems(m, toyCorpus())
  q <- ruleDecide(m, moduleCandidates(m, it), it)$queue
  req <- readingRequests(m, q, it)
  expect_equal(req$item_id, c("1", "2"))
  expect_true(all(grepl("^[A-Za-z0-9_-]{1,64}$", req$custom_id)))
  expect_false(anyDuplicated(req$custom_id) > 0)
  expect_match(req$user[1], "Item: PAGE 1 (2024)", fixed = TRUE)
  expect_match(req$user[1], "Candidates: \"Tooly\"\n", fixed = TRUE)
  expect_match(req$user[1], "fitted with Toolx", fixed = TRUE)
  whole <- readingRequests(m, NULL, it)
  expect_equal(whole$item_id, c("1", "2", "3"))
  expect_match(whole$user[3], "Candidates: none (classify the item as a whole)", fixed = TRUE)
  m$text <- list(mode = "window", width = 10)
  w <- readingRequests(m, q, it)
  expect_false(grepl("A model", w$user[1], fixed = TRUE))
  expect_match(w$user[1], "Tooly", fixed = TRUE)
})

test_that("a candidate named in the text by another name of its family says so", {
  m <- readModule(toyDir())
  m$rules <- m$rules[0, ]
  m$patterns$regex[m$patterns$family == "Tooly"] <- "\\bTooly\\b|\\bTY ?\\d\\b"
  it <- data.frame(source = "PAGE", item_id = c("1", "2"), year = 2025L, input_hash = "h", text = c(
    "Fits were done in TY5 and TY 5 again.", "Fits were done in Tooly and in TY5."
  ))
  cand <- moduleCandidates(m, it)
  expect_equal(cand$named, c("TY5; TY 5", "Tooly; TY5"))
  req <- readingRequests(m, cand, it)
  expect_match(req$user[1], "Candidates: \"Tooly\" (named in the text: TY5; TY 5)\n", fixed = TRUE)
  expect_match(req$user[2], "Candidates: \"Tooly\"\n", fixed = TRUE) # named as itself: no note
})

test_that("window mode labels each window with its section and caps the windows per candidate", {
  m <- readModule(toyDir())
  m$rules <- m$rules[0, ]
  pages <- paste0("### review (doc p", sprintf("%04d", 1:30), ")\nPage text with Toolx on it.")
  it <- data.frame(
    source = "FDA", item_id = "1", year = 2025L, input_hash = "h", text = paste(pages, collapse = "\n\n")
  )
  m$text <- list(mode = "window", width = 15, max_snippets = 5)
  req <- readingRequests(m, ruleDecide(m, moduleCandidates(m, it), it)$queue, it)
  w <- strsplit(sub("^.*Text around each candidate:\n\n", "", req$user), "\n...\n", fixed = TRUE)[[1]]
  expect_length(w, 5)
  expect_equal(sub("\\].*$", "]", w), sprintf("[review (doc p%04d)]", c(1, 8, 16, 23, 30)))
})

test_that("window mode can show the numbered headings and labels each window sits under", {
  m <- readModule(toyDir())
  m$rules <- m$rules[0, ]
  pages <- c(
    paste(
      "### review (doc p0001)", "14.5.3. Reviewer's Independent Analysis ........ 299", "14.5. Pharmacometrics Review",
      "14.5.2. Applicant's Analysis", "The model was fitted in Toolx.",
      sep = "\n"
    ),
    paste("### review (doc p0002)", "14.5.3. Reviewer's Independent Analysis", "14.5.3.3. Methods",
      "Simulation was done in Toolx.",
      sep = "\n"
    ),
    paste("### review (doc p0003)", "14.6. Other Matters", "Reviewer's Comment", "Toolx again.", sep = "\n")
  )
  it <- data.frame(
    source = "FDA", item_id = "1", year = 2025L, input_hash = "h", text = paste(pages, collapse = "\n\n")
  )
  m$text <- list(mode = "window", width = 15, headings = list(
    numbered = "^\\d+(?:\\.\\d+)+\\.?\\s+[A-Z][^\\n]*$", labels = "^(?:Reviewer's Comment|Applicant's Position)$"
  ))
  req <- readingRequests(m, ruleDecide(m, moduleCandidates(m, it), it)$queue, it)
  w <- strsplit(sub("^.*Text around each candidate:\n\n", "", req$user), "\n...\n", fixed = TRUE)[[1]]
  expect_equal(sub("\\].*$", "]", w), c(
    "[review (doc p0001) | under: 14.5. Pharmacometrics Review > 14.5.2. Applicant's Analysis]",
    paste(
      "[review (doc p0002) | under: 14.5. Pharmacometrics Review > 14.5.3. Reviewer's Independent Analysis >",
      "14.5.3.3. Methods]"
    ),
    "[review (doc p0003) | under: 14.6. Other Matters; Reviewer's Comment]"
  ))
  # a heading of another chapter is not an ancestor, and a label pages back is stale
  pages <- c(
    paste("### review (doc p0001)", "8.2. Safety", "19.4.1.2. PPK Summary", "Reviewer's Comment", "Text.", sep = "\n"),
    "### review (doc p0002)\nMore text.", "### review (doc p0003)\nMore text.",
    "### review (doc p0004)\nFitted in Toolx."
  )
  it$text <- paste(pages, collapse = "\n\n")
  m$text$headings$numbered <- "^\\d+(?:\\.\\d+)+\\.?\\s+[A-Z][^\\n]*$"
  req <- readingRequests(m, ruleDecide(m, moduleCandidates(m, it), it)$queue, it)
  expect_match(req$user, "[review (doc p0004) | under: 19.4.1.2. PPK Summary] ", fixed = TRUE)
  # a section number wrapped onto its own line from a cross-reference is not a heading
  it$text <- paste("### review (doc p0001)", "19.4. PK Review", "as described in Section",
    "19.4.2. The base model was refined.", "Fitted in Toolx.",
    sep = "\n"
  )
  req <- readingRequests(m, ruleDecide(m, moduleCandidates(m, it), it)$queue, it)
  expect_match(req$user, "[review (doc p0001) | under: 19.4. PK Review] ", fixed = TRUE)
  # with max_parts, a heading more parts back than that is left out
  it$text <- paste(c(
    "### review (doc p0001)\n13.1. Carcinogenesis", sprintf("### review (doc p%04d)\nText.", 2:5),
    "### review (doc p0006)\nFitted in Toolx."
  ), collapse = "\n\n")
  req <- readingRequests(m, ruleDecide(m, moduleCandidates(m, it), it)$queue, it)
  expect_match(req$user, "[review (doc p0006) | under: 13.1. Carcinogenesis] ", fixed = TRUE)
  m$text$headings$max_parts <- 3
  req <- readingRequests(m, ruleDecide(m, moduleCandidates(m, it), it)$queue, it)
  expect_match(req$user, "[review (doc p0006)] ", fixed = TRUE)
  # the limit is on the nearest heading: its ancestors stay, however far back
  it$text <- sub("### review (doc p0005)\nText.", "### review (doc p0005)\n13.1.2. Studies", it$text, fixed = TRUE)
  req <- readingRequests(m, ruleDecide(m, moduleCandidates(m, it), it)$queue, it)
  expect_match(req$user, "[review (doc p0006) | under: 13.1. Carcinogenesis > 13.1.2. Studies] ", fixed = TRUE)
  m$text$headings <- NULL # without the setting the windows are labelled as before
  req <- readingRequests(m, ruleDecide(m, moduleCandidates(m, it), it)$queue, it)
  expect_match(req$user, "[review (doc p0006)] ", fixed = TRUE)
})

test_that("apiBody builds a Messages request with a cached system prompt and the schema", {
  m <- readModule(toyDir())
  b <- apiBody("Text of the item", m)
  expect_equal(b$model, "claude-sonnet-5-5")
  expect_equal(b$max_tokens, 1024)
  expect_equal(b$system[[1]]$text, readingPrompt(m))
  expect_equal(b$system[[1]]$cache_control, list(type = "ephemeral", ttl = "1h"))
  expect_equal(b$messages[[1]]$content, "Text of the item")
  expect_equal(b$output_config$format$type, "json_schema")
  expect_equal(b$output_config$format$schema, readingSchema(m))
})

test_that("parseReadings turns batch results into decisions and lists what does not fit", {
  m <- readModule(toyDir())
  it <- moduleItems(m, toyCorpus())
  q <- ruleDecide(m, moduleCandidates(m, it), it)$queue
  req <- readingRequests(m, q, it)
  answer <- function(id, decisions, model = "claude-sonnet-5-5") {
    jsonlite::toJSON(list(custom_id = id, result = list(type = "succeeded", message = list(
      model = model, stop_reason = "end_turn",
      content = list(list(
        type = "text", text = as.character(jsonlite::toJSON(list(decisions = decisions), auto_unbox = TRUE))
      )),
      usage = list(
        input_tokens = 900, output_tokens = 40, cache_read_input_tokens = 0, cache_creation_input_tokens = 500
      )
    ))), auto_unbox = TRUE)
  }
  lines <- c(
    answer(req$custom_id[1], list(list(label = "Tooly", value = "mentioned", note = "Cited as earlier work."))),
    answer(req$custom_id[2], list(
      list(label = "Tooly", value = "used", note = "The fit was done with it."),
      list(label = "Toolz", value = "used", note = "Not a candidate.")
    ))
  )
  p <- parseReadings(lines, req, m, run = "msgbatch_test", date = "2026-10-18")
  d <- p$decisions
  expect_equal(paste(d$item_id, d$label, d$value), c("1 Tooly mentioned", "2 Tooly used"))
  expect_equal(unique(d$method), "ai")
  expect_equal(unique(d$reader), "claude-sonnet-5-5")
  expect_equal(unique(d$prompt_hash), promptHash(m))
  expect_equal(d$input_hash, it$input_hash[1:2])
  expect_equal(unique(d$run), "msgbatch_test")
  expect_equal(p$problems$problem, "label not among the candidates: Toolz")
  expect_equal(p$usage$input_tokens, 1800)
  # a label or value that differs only in case is matched to the candidate and the value
  odd <- answer(req$custom_id[1], list(list(label = "TOOLY", value = "Mentioned", note = "Case differs.")))
  q <- parseReadings(c(odd, lines[2]), req, m, run = "r", date = "d")
  expect_equal(q$decisions$label[1], "Tooly")
  expect_equal(q$decisions$value[1], "mentioned")
  lost <- parseReadings(lines[1], req, m, run = "r", date = "d")
  expect_equal(lost$problems$problem, "no answer")
  err <- jsonlite::toJSON(list(custom_id = req$custom_id[2], result = list(type = "errored")), auto_unbox = TRUE)
  expect_equal(parseReadings(c(lines[1], err), req, m, run = "r", date = "d")$problems$problem, "errored")
})

test_that("estimateCost prices tokens at the batch rate", {
  e <- estimateCost(input = 2e6, output = 1e5, model = "claude-sonnet-5-5")
  expect_equal(e, 2 * 1 + 0.1 * 5)
  expect_equal(estimateCost(input = 1e6, output = 0, model = "claude-haiku-5-5"), 0.05)
  expect_error(estimateCost(1, 1, "claude-unknown"), "no price")
})

test_that("agent batches round-trip through the same parser", {
  m <- readModule(toyDir())
  it <- moduleItems(m, toyCorpus())
  req <- readingRequests(m, ruleDecide(m, moduleCandidates(m, it), it)$queue, it)
  dir <- withr::local_tempdir()
  files <- writeAgentBatches(req, m, dir, size = 1)
  expect_length(files, 2)
  expect_true(file.exists(file.path(dir, "system.md")))
  b <- jsonlite::read_json(files[1])
  expect_equal(b[[1]]$custom_id, req$custom_id[1])
  writeLines(c(
    jsonlite::toJSON(list(
      custom_id = req$custom_id[1], decisions = list(list(label = "Tooly", value = "mentioned", note = "x"))
    ), auto_unbox = TRUE),
    jsonlite::toJSON(list(
      custom_id = req$custom_id[2], decisions = list(list(label = "Tooly", value = "used", note = "y"))
    ), auto_unbox = TRUE)
  ), file.path(dir, "answers.jsonl"))
  p <- readAgentAnswers(file.path(dir, "answers.jsonl"), req, m,
    model = "claude-sonnet-5-5", run = "agents-1", date = "d"
  )
  expect_equal(p$decisions$value, c("mentioned", "used"))
  expect_equal(unique(p$decisions$reader), "Claude Code subagent (claude-sonnet-5-5)")
  # a reader is always named with its model version
  expect_error(readAgentAnswers(file.path(dir, "answers.jsonl"), req, m, model = "sonnet", run = "agents-1"), "version")
})

test_that("agent batches in text form wrap long lines and keep to a character budget", {
  m <- readModule(toyDir())
  it <- moduleItems(m, toyCorpus())
  req <- readingRequests(m, ruleDecide(m, moduleCandidates(m, it), it)$queue, it)
  req$user[2] <- paste(req$user[2], strrep("word ", 200))
  dir <- withr::local_tempdir()
  one <- writeAgentBatches(req, m, file.path(dir, "a"), format = "text", width = 60)
  expect_length(one, 1)
  expect_match(one, "batch_001\\.txt$")
  x <- readLines(one)
  expect_true(all(nchar(x) <= 60))
  expect_equal(sum(grepl("^======== custom_id: ", x)), 2)
  expect_true(any(grepl(req$custom_id[2], x, fixed = TRUE)))
  # a budget smaller than either request gives each its own batch, never an empty one
  expect_length(writeAgentBatches(req, m, file.path(dir, "b"), format = "text", chars = 10), 2)
  expect_length(writeAgentBatches(req, m, file.path(dir, "c"), format = "text", chars = sum(nchar(req$user))), 1)
})

test_that("agent batches in text form wrap a line of a million characters, keeping every word", {
  m <- readModule(toyDir())
  it <- moduleItems(m, toyCorpus())
  req <- readingRequests(m, ruleDecide(m, moduleCandidates(m, it), it)$queue, it)[1, ]
  words <- sprintf("w%06d", seq_len(125000))
  req$user <- paste(req$user, paste(words, collapse = " "), sep = "\n")
  dir <- withr::local_tempdir()
  x <- readLines(writeAgentBatches(req, m, dir, format = "text", width = 300))
  expect_true(all(nchar(x) <= 300))
  got <- unlist(strsplit(x, " "))
  expect_equal(got[grepl("^w\\d{6}$", got)], words)
})

test_that("agent answers whose title start does not match the item are refused", {
  m <- readModule(toyDir())
  it <- moduleItems(m, toyCorpus())
  req <- readingRequests(m, ruleDecide(m, moduleCandidates(m, it), it)$queue, it)
  dir <- withr::local_tempdir()
  writeLines(c(
    jsonlite::toJSON(list(
      custom_id = req$custom_id[1], title_start = "a  Model",
      decisions = list(list(label = "Tooly", value = "mentioned", note = "x"))
    ), auto_unbox = TRUE),
    jsonlite::toJSON(list(
      custom_id = req$custom_id[2], title_start = "A model",
      decisions = list(list(label = "Tooly", value = "used", note = "y"))
    ), auto_unbox = TRUE)
  ), file.path(dir, "answers.jsonl"))
  p <- readAgentAnswers(file.path(dir, "answers.jsonl"), req, m,
    model = "Claude Sonnet 5.5", run = "agents-1", date = "d"
  )
  expect_equal(p$decisions$item_id, "1") # case and spacing do not matter
  expect_equal(p$problems$item_id, "2")
  expect_match(p$problems$problem, "title start")
  # words joined by a slash count as one word or two
  req$user[1] <- sub("A model", "Population pharmacokinetics of lopinavir/ritonavir in children", req$user[1])
  writeLines(jsonlite::toJSON(list(
    custom_id = req$custom_id[1], title_start = "Population pharmacokinetics of lopinavir/ritonavir in",
    decisions = list(list(label = "Tooly", value = "mentioned", note = "x"))
  ), auto_unbox = TRUE), file.path(dir, "answers.jsonl"))
  p <- readAgentAnswers(file.path(dir, "answers.jsonl"), req[1, ], m,
    model = "Claude Sonnet 5.5", run = "agents-1", date = "d"
  )
  expect_equal(p$decisions$item_id, "1")
  # markup in the title, escaped or not, is not part of its words
  req$user[1] <- sub("Population pharmacokinetics", "&lt;i&gt;In vivo&lt;/i&gt; <b>pharmacokinetics</b>", req$user[1])
  writeLines(jsonlite::toJSON(list(
    custom_id = req$custom_id[1], title_start = "In vivo pharmacokinetics of lopinavir",
    decisions = list(list(label = "Tooly", value = "mentioned", note = "x"))
  ), auto_unbox = TRUE), file.path(dir, "answers.jsonl"))
  p <- readAgentAnswers(file.path(dir, "answers.jsonl"), req[1, ], m,
    model = "Claude Sonnet 5.5", run = "agents-1", date = "d"
  )
  expect_equal(p$decisions$item_id, "1")
})

test_that("blindSample draws a reproducible share of the items", {
  ids <- data.frame(source = "PAGE", item_id = as.character(1:200))
  a <- blindSample(ids, 0.15, seed = 7)
  expect_equal(nrow(a), 30)
  expect_equal(a, blindSample(ids, 0.15, seed = 7))
  expect_false(identical(a, blindSample(ids, 0.15, seed = 8)))
})

test_that("agreement compares two readings of the same labels, with Cohen's kappa", {
  key <- data.frame(source = "PAGE", item_id = as.character(1:10), label = "T")
  first <- cbind(key, value = c(rep("used", 6), rep("mentioned", 4)))
  second <- cbind(key, value = c(rep("used", 5), "mentioned", rep("mentioned", 3), "used"))
  a <- agreement(first, second)
  expect_equal(a$compared, 10)
  expect_equal(a$agree, 8)
  # p_o = 0.8, p_e = 0.6 * 0.6 + 0.4 * 0.4 = 0.52
  expect_equal(a$kappa, (0.8 - 0.52) / (1 - 0.52))
  expect_equal(agreement(first, second[1:5, ])$compared, 5)
})

test_that("agreement gives Krippendorff's alpha for nominal values", {
  # Krippendorff's binary example for two observers and ten units: alpha = 0.095
  key <- data.frame(source = "PAGE", item_id = as.character(1:10), label = "T")
  first <- cbind(key, value = as.character(c(0, 1, 0, 0, 0, 0, 0, 0, 1, 0)))
  second <- cbind(key, value = as.character(c(1, 1, 1, 0, 0, 1, 0, 0, 0, 0)))
  expect_equal(agreement(first, second)$alpha, 1 - 19 * 8 / 168)
  expect_equal(round(agreement(first, second)$alpha, 3), 0.095)
  same <- agreement(first, first)
  expect_equal(same$alpha, 1)
})

test_that("moduleTags keeps one decision per label: a human's, else an adjudication, else the latest", {
  d <- data.frame(
    source = "PAGE", item_id = c("1", "1", "1", "2", "2", "3", "4", "4"), label = "T",
    value = c("used", "mentioned", "used", "used", "mentioned", "used", "used", "mentioned"),
    method = c("ai", "adjudication", "ai", "ai", "human", "rule", "human", "adjudication"),
    date = c(
      "2026-10-01", "2026-10-02", "2026-10-03", "2026-10-01", "2026-09-01", "2026-10-01", "2026-09-01", "2026-10-05"
    )
  )
  t <- moduleTags(d)
  expect_equal(
    paste(t$item_id, t$value, t$method),
    c("1 mentioned adjudication", "2 mentioned human", "3 used rule", "4 used human")
  )
})

test_that("withholdQuotes withholds notes that repeat eight or more words of the item's text", {
  it <- data.frame(source = "PAGE", item_id = c("1", "2"), text = c(
    "Methods: All models were developed in NONMEM 7.3 with FOCE-I.", "Monolix was compared."
  ))
  d <- data.frame(source = "PAGE", item_id = c("1", "1", "2"), note = c(
    "All models were developed in NONMEM 7.3, so it was used.",
    "The fit was done in NONMEM.",
    "Monolix was compared, all models were developed in NONMEM 7.3."
  ))
  w <- withholdQuotes(d, it)
  expect_equal(w$note, c(
    "(withheld: repeats the item's text)", "The fit was done in NONMEM.",
    "Monolix was compared, all models were developed in NONMEM 7.3."
  ))
  expect_equal(withholdQuotes(d, it, n = 2)$note[2], "(withheld: repeats the item's text)")
})

toyExtra <- function() {
  m <- readModule(toyDir())
  m$extra <- list(other_tools = list(instruction = "every other estimation tool the text names, as written"))
  m
}

test_that("a module without extra answers keeps its prompt and schema", {
  m <- readModule(toyDir())
  p <- readingPrompt(m)
  expect_false(grepl("{{extra}}", p, fixed = TRUE))
  expect_false(grepl("Also give", p, fixed = TRUE))
  expect_match(p, "Do not quote the text.\n?$")
  expect_equal(names(readingSchema(m)$properties), "decisions")
})

test_that("extra answers are asked for in the prompt and the schema", {
  m <- toyExtra()
  expect_match(readingPrompt(m), "Also give:\n\n- `other_tools`: every other estimation tool", fixed = TRUE)
  s <- readingSchema(m)
  expect_equal(names(s$properties), c("decisions", "other_tools"))
  expect_equal(s$properties$other_tools, list(type = "array", items = list(type = "string")))
  expect_equal(unlist(s$required), c("decisions", "other_tools"))
  expect_false(promptHash(m) == promptHash(readModule(toyDir())))
})

test_that("extra answers come back from the API and from subagents", {
  m <- toyExtra()
  it <- moduleItems(m, toyCorpus())
  req <- readingRequests(m, ruleDecide(m, moduleCandidates(m, it), it)$queue, it)
  body <- list(
    decisions = list(list(label = "Tooly", value = "mentioned", note = "x")), other_tools = list("Toolq", "Toolr")
  )
  line <- jsonlite::toJSON(list(custom_id = req$custom_id[1], result = list(type = "succeeded", message = list(
    model = "claude-sonnet-5-5", stop_reason = "end_turn",
    content = list(list(type = "text", text = as.character(jsonlite::toJSON(body, auto_unbox = TRUE))))
  ))), auto_unbox = TRUE)
  p <- parseReadings(line, req[1, ], m, run = "r", date = "d")
  expect_equal(p$extra$field, c("other_tools", "other_tools"))
  expect_equal(p$extra$value, c("Toolq", "Toolr"))
  expect_equal(p$extra$item_id, rep(req$item_id[1], 2))
  expect_equal(unique(p$extra$reader), "claude-sonnet-5-5")
  dir <- withr::local_tempdir()
  answer <- jsonlite::toJSON(c(list(custom_id = req$custom_id[1]), body), auto_unbox = TRUE)
  writeLines(answer, file.path(dir, "a.jsonl"))
  a <- readAgentAnswers(file.path(dir, "a.jsonl"), req[1, ], m, model = "Claude Sonnet 5.5", run = "agents", date = "d")
  expect_equal(a$extra$value, c("Toolq", "Toolr"))
  expect_equal(unique(a$extra$reader), "Claude Code subagent (Claude Sonnet 5.5)")
  none <- parseReadings(line, req[1, ], readModule(toyDir()), run = "r", date = "d")
  expect_equal(nrow(none$extra), 0)
})

test_that("a label copied with its 'named in the text' hint is matched to its candidate", {
  m <- readModule(toyDir())
  it <- moduleItems(m, toyCorpus())
  req <- readingRequests(m, ruleDecide(m, moduleCandidates(m, it), it)$queue, it)
  body <- list(decisions = list(list(label = "Tooly (named in the text: Tooly 2)", value = "mentioned", note = "x")))
  line <- jsonlite::toJSON(list(custom_id = req$custom_id[1], result = list(type = "succeeded", message = list(
    model = "m", stop_reason = "end_turn",
    content = list(list(type = "text", text = as.character(jsonlite::toJSON(body, auto_unbox = TRUE))))
  ))), auto_unbox = TRUE)
  p <- parseReadings(line, req[1, ], m, run = "r", date = "d")
  expect_equal(p$decisions$label, "Tooly")
  expect_equal(nrow(p$problems), 0)
})

test_that("titleMatches accepts a title start cut in the middle of its last word", {
  want <- titleWords("A Bayesian analysis of halofantrine pharmacokinetics in malaria patients")[[1]]
  expect_true(titleMatches("A Bayesian analysis of halofantrine pharmacokinetics in malaria patien", want))
  # a cut word must still begin the title's word, and three whole words must agree before it
  expect_false(titleMatches("A Bayesian analysis of halofantrine pharmacokinetics in malaria pxtien", want))
  expect_false(titleMatches("A Bayes", want))
  expect_false(titleMatches("A Bayesian analysis of carboplatin pharmacokinetics", want))
})
