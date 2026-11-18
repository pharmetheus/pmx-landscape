# The classification protocol (classifications/README.md): every classification has the same
# five steps and the same files, and only its question, values, rubric, scope, patterns and
# rules differ. Steps 1 to 3 (scope, candidates, rule decisions) are deterministic; step 4
# (reading) uses one prompt skeleton for every module (inst/prompts/reading.md) and one output
# schema; step 5 (check) compares two readings.

decisionColumns <- c(
  "source", "item_id", "label", "value", "method", "reader", "prompt", "prompt_hash", "run", "date", "input_hash",
  "note"
)

corpusNames <- c(PAGE = "page", PubMed = "pubmed", "Europe PMC" = "epmc", FDA = "fda")

#' Read a classification module
#'
#' A module is a folder with `module.json` (name, version, question, scope,
#' candidates, text mode, reader and check settings) and the files it names:
#' `values.csv` (`value`, `definition`), `rubric.md`, optionally `rules.csv`
#' (`id`, `label`, `context`, `value`, `note`) and a pattern file for the
#' candidates.
#'
#' @param dir The module folder.
#'
#' @return The module as a list, with `values`, `rubric`, `rules` and
#'   `patterns` (`NULL` when the item is the candidate) read in, and `dir`.
#' @export
readModule <- function(dir) {
  m <- jsonlite::read_json(file.path(dir, "module.json"))
  need <- c("name", "version", "question", "scope", "values", "rubric", "reader")
  if (length(setdiff(need, names(m)))) stop("module.json lacks ", paste(setdiff(need, names(m)), collapse = ", "))
  bad <- setdiff(names(m$scope), names(corpusNames))
  if (length(bad)) stop("unknown source in the scope: ", paste(bad, collapse = ", "))
  m$dir <- dir
  m$valuesFile <- m$values
  m$values <- utils::read.csv(file.path(dir, m$values), colClasses = "character", encoding = "UTF-8")
  dup <- unique(m$values$value[duplicated(m$values$value)])
  if (length(dup)) stop(m$valuesFile, " lists a value twice: ", paste(dup, collapse = ", "))
  m$rubric <- stringi::stri_trim_both(readText(file.path(dir, m$rubric)))
  m$rules <- if (is.null(m$rules)) {
    cols <- c("id", "label", "context", "sentence_exclude", "item_exclude", "max_candidates", "value", "note")
    as.data.frame(stats::setNames(rep(list(character(0)), length(cols)), cols))
  } else {
    utils::read.csv(file.path(dir, m$rules), colClasses = "character", encoding = "UTF-8")
  }
  badRule <- setdiff(m$rules$value, m$values$value)
  if (length(badRule)) stop("a rule gives a value not in ", m$valuesFile, ": ", paste(badRule, collapse = ", "))
  m$patterns <- if (is.null(m$candidates$patterns)) NULL else readPatterns(file.path(dir, m$candidates$patterns))
  bad <- names(m$extra)[vapply(m$extra, function(e) is.null(e$instruction), logical(1))]
  if (length(bad)) stop("an extra answer lacks its instruction: ", paste(bad, collapse = ", "))
  if (is.null(m$text)) m$text <- list(mode = "item")
  m
}

#' The reading prompt of a module
#'
#' The shared skeleton (`inst/prompts/reading.md`) filled with the module's
#' question, values and rubric, and, where `module.json` has `extra`
#' answers (a name and an `instruction` each), a list asking for them. It is
#' the system prompt of every reading request, the same for every item.
#'
#' @param m A module from [readModule()].
#'
#' @return The prompt.
#' @export
readingPrompt <- function(m) {
  skeleton <- readText(system.file("prompts", "reading.md", package = "pmxlandscape", mustWork = TRUE))
  values <- paste0("- `", m$values$value, "`: ", m$values$definition, collapse = "\n")
  p <- stringi::stri_replace_all_fixed(skeleton, "{{question}}", m$question)
  p <- stringi::stri_replace_all_fixed(p, "{{values}}", values)
  p <- stringi::stri_replace_all_fixed(p, "{{rubric}}", m$rubric)
  extra <- if (length(m$extra)) {
    paste0("\n\nAlso give:\n\n", paste0("- `", names(m$extra), "`: ",
      vapply(m$extra, `[[`, "", "instruction"),
      collapse = "\n"
    ))
  } else {
    ""
  }
  stringi::stri_replace_all_fixed(p, "{{extra}}", extra)
}

# The skeleton as the decision record names it; the placeholder for extra answers is left out,
# so modules without them keep the name they had before it was added.
skeletonName <- function() {
  skeleton <- readText(system.file("prompts", "reading.md", package = "pmxlandscape", mustWork = TRUE))
  paste0("reading.md@", substr(corpusHash(stringi::stri_replace_all_fixed(skeleton, "{{extra}}", "")), 1, 8))
}

#' The output schema of a reading
#'
#' The same envelope for every module: a list of decisions, each with a
#' `label`, a `value` from the module's values and a `note`; and, for each of
#' the module's `extra` answers, a list of strings.
#'
#' @inheritParams readingPrompt
#'
#' @return The JSON schema, as a list.
#' @export
readingSchema <- function(m) {
  extra <- stats::setNames(
    rep(list(list(type = "array", items = list(type = "string"))), length(m$extra)), names(m$extra)
  )
  list(
    type = "object",
    properties = c(list(decisions = list(type = "array", items = list(
      type = "object",
      properties = list(
        label = list(type = "string"), value = list(type = "string", enum = as.list(m$values$value)),
        note = list(type = "string")
      ),
      required = list("label", "value", "note"), additionalProperties = FALSE
    ))), extra),
    required = as.list(c("decisions", names(m$extra))), additionalProperties = FALSE
  )
}

#' Hash of everything a reading depends on except the item
#'
#' The prompt, the output schema, the reader settings (model and
#' parameters) and the text mode. Two decisions with the same hash were made
#' the same way.
#'
#' @inheritParams readingPrompt
#'
#' @return A SHA-256 digest.
#' @export
promptHash <- function(m) {
  json <- function(x) as.character(jsonlite::toJSON(x, auto_unbox = TRUE))
  corpusHash(paste(readingPrompt(m), json(readingSchema(m)), json(m$reader), json(m$text), sep = "\n"))
}

#' The items a module classifies, with their text
#'
#' Step 1 of the protocol: the items of the sources in the module's scope,
#' with the text of the sections in scope, each under a `### section` heading
#' (with its part, for example the FDA document and page). A source's scope is
#' either a list of sections, or an object with `sections`, and `fallback`
#' sections for the items that lack every `required` section of at least
#' `min_chars` characters (for example the whole body for papers without a
#' methods section).
#'
#' @inheritParams readingPrompt
#' @param root The corpus folder.
#'
#' @return A data frame with `source`, `item_id`, `year`, `input_hash` (the
#'   corpus item hash) and `text`, for the items with text in scope.
#' @export
moduleItems <- function(m, root) {
  do.call(rbind, lapply(names(m$scope), function(src) {
    sc <- m$scope[[src]]
    if (is.null(names(sc))) sc <- list(sections = sc)
    use <- unlist(sc$sections)
    x <- corpusRead(root, corpusNames[[src]], sections = unique(c(use, unlist(sc$fallback))))
    s <- x$sections
    if (!is.null(sc$fallback)) {
      need <- unlist(sc$required)
      has <- unique(s$item_id[s$section %in% need & s$nchar >= (sc$min_chars %||% 1)])
      s <- s[(s$item_id %in% has & s$section %in% use) | (!s$item_id %in% has & s$section %in% unlist(sc$fallback)), ]
    } else {
      s <- s[s$section %in% use, ]
    }
    head <- ifelse(nzchar(s$part), paste0(s$section, " (", s$part, ")"), s$section)
    s$section <- "all"
    s$text <- paste0("### ", head, "\n", s$text)
    t <- corpusText(s, "all", sep = "\n\n")
    i <- match(t$item_id, x$items$item_id)
    data.frame(source = src, item_id = t$item_id, year = x$items$year[i], input_hash = x$items$hash[i], text = t$text)
  }))
}

#' Candidates of a module
#'
#' Step 2: one row per item and label that the module's patterns find, with
#' the text around every match. A module without patterns has the item as
#' its candidate (label `""`).
#'
#' @inheritParams readingPrompt
#' @param items Items from [moduleItems()].
#'
#' @return A data frame with `source`, `item_id`, `year`, `input_hash`,
#'   `label`, `context` (the snippets, joined by " ... ") and `named` (the
#'   names the text uses for the label's family, joined by "; ", shown to the
#'   reader when they differ from the label).
#' @export
moduleCandidates <- function(m, items) {
  keep <- c("source", "item_id", "year", "input_hash")
  if (is.null(m$patterns)) {
    return(cbind(items[keep], label = "", context = ""))
  }
  groups <- unlist(m$candidates$groups %||% list("estimation", "auxiliary", "pbpk", "nca"))
  f <- findMatches(items$text, m$patterns, groups = groups, width = m$candidates$width %||% 220)
  if (nrow(f) == 0) {
    return(cbind(items[0, keep], label = character(0), context = character(0)))
  }
  key <- paste(f$text, f$family, sep = "\r")
  first <- !duplicated(key)
  ctx <- vapply(split(f$snip, factor(key, levels = unique(key))), paste, character(1), collapse = " ... ")
  # the names the text uses for each family, in order of appearance
  named <- vapply(which(first), function(i) {
    rx <- paste(m$patterns$regex[m$patterns$family == f$family[i]], collapse = "|")
    paste(unique(stringi::stri_extract_all_regex(items$text[f$text[i]], rx)[[1]]), collapse = "; ")
  }, character(1))
  cbind(items[f$text[first], keep], label = f$family[first], context = unname(ctx), named = named, row.names = NULL)
}

`%|NA|%` <- function(a, b) if (is.na(a)) b else a

emptyDecisions <- function() {
  as.data.frame(stats::setNames(rep(list(character(0)), length(decisionColumns)), decisionColumns))
}

#' Decide the candidates a rule settles
#'
#' Step 3. A rule (a row of the module's `rules.csv`) decides a candidate when
#' all its conditions hold:
#'
#' - `label`, a regular expression, matches the whole label;
#' - `context` matches a sentence of the item that names the candidate, and
#'   `sentence_exclude` (if given) does not match that sentence;
#' - `item_exclude` (if given) does not match the item's text;
#' - the item has at most `max_candidates` candidates (if given).
#'
#' In `context` and `sentence_exclude`, `{{tool}}` stands for the candidate's
#' own patterns, and in `item_exclude`, `{{tools}}` for the patterns of all the
#' module's candidate groups; they keep their own case sensitivity, while the
#' rest of a rule ignores case. Sentences end at `.`, `;`, `:`, `!` or `?`
#' followed by white space, and at line breaks. The first rule that decides a
#' candidate gives its value; the rest are left for reading.
#'
#' @inheritParams readingPrompt
#' @param candidates Candidates from [moduleCandidates()].
#' @param items Items from [moduleItems()].
#' @param date The date to record.
#'
#' @return A list with `decided` (decisions, `method` `rule`, `reader`
#'   `rules.csv:<id>`) and `queue` (the candidates left).
#' @export
ruleDecide <- function(m, candidates, items, date = format(Sys.Date())) {
  rules <- m$rules
  for (col in c("sentence_exclude", "item_exclude", "max_candidates")) {
    if (is.null(rules[[col]])) rules[[col]] <- rep("", nrow(rules))
    rules[[col]][is.na(rules[[col]])] <- ""
  }
  keep <- function(rx) paste0("(?-i:", rx, ")")
  toolRx <- function(label) {
    if (is.null(m$patterns)) {
      return("(?!)")
    }
    keep(paste(m$patterns$regex[m$patterns$family == label], collapse = "|"))
  }
  groups <- unlist(m$candidates$groups %||% list("estimation", "auxiliary", "pbpk", "nca"))
  allTools <- if (is.null(m$patterns)) {
    "(?!)"
  } else {
    keep(paste(m$patterns$regex[m$patterns$group %in% groups], collapse = "|"))
  }
  ikey <- paste(items$source, items$item_id)
  ckey <- paste(candidates$source, candidates$item_id)
  nCand <- table(ckey)[ckey]
  sentences <- lapply(items$text, function(t) {
    s <- stringi::stri_split_regex(t, "(?<=[.;:!?])\\s+|\\n+")[[1]]
    s[nzchar(s)]
  })
  detect <- function(x, rx) stringi::stri_detect_regex(x, rx, case_insensitive = TRUE)
  hit <- rep(NA_integer_, nrow(candidates))
  for (i in seq_len(nrow(candidates))) {
    k <- match(ckey[i], ikey)
    tool <- toolRx(candidates$label[i])
    sent <- sentences[[k]]
    sent <- sent[stringi::stri_detect_regex(sent, tool)]
    for (j in seq_len(nrow(rules))) {
      r <- rules[j, ]
      if (!stringi::stri_detect_regex(candidates$label[i], paste0("^(?:", r$label, ")$"))) next
      if (nzchar(r$max_candidates) && nCand[[i]] > as.integer(r$max_candidates)) next
      itemRx <- gsub("{{tools}}", allTools, r$item_exclude, fixed = TRUE)
      if (nzchar(r$item_exclude) && detect(items$text[k], itemRx)) next
      ok <- detect(sent, gsub("{{tool}}", tool, r$context, fixed = TRUE))
      if (nzchar(r$sentence_exclude)) ok <- ok & !detect(sent, gsub("{{tool}}", tool, r$sentence_exclude, fixed = TRUE))
      if (any(ok)) {
        hit[i] <- j
        break
      }
    }
  }
  done <- !is.na(hit)
  d <- candidates[done, ]
  decided <- if (any(done)) {
    data.frame(
      source = d$source, item_id = d$item_id, label = d$label, value = rules$value[hit[done]], method = "rule",
      reader = paste0("rules.csv:", rules$id[hit[done]]), prompt = "", prompt_hash = "", run = "", date = date,
      input_hash = d$input_hash, note = rules$note[hit[done]]
    )
  } else {
    emptyDecisions()
  }
  list(decided = decided, queue = candidates[!done, , drop = FALSE])
}

# The headings a position in an item's text sits under: the numbered headings before it as a
# path ("14.5. A > 14.5.3. B"), each ancestor's number a prefix of the next one's, and the last
# label line (`labels`, such as "Reviewer's Comment") after the last numbered heading and on the
# same or the previous part ("### " line). With `max_parts`, a path whose nearest heading is more
# parts back than that is left out (the window has drifted out of any section the path names).
# Lines with dot leaders are a table of contents, and a number following "Section", "see" and the
# like is a cross-reference; both are left out.
headingTrail <- function(text, at, headings) {
  find <- function(rx) {
    if (is.null(rx)) {
      return(data.frame(start = integer(0), line = character(0)))
    }
    loc <- stringi::stri_locate_all_regex(text, paste0("(?m)", rx), omit_no_match = TRUE)[[1]]
    line <- trimws(stringi::stri_sub(text, loc[, 1], loc[, 2]))
    # a number carried onto its own line from a cross-reference ("see Section\n14.3.1.") is not one
    before <- stringi::stri_sub(text, pmax(loc[, 1] - 30, 1), loc[, 1] - 1)
    crossRef <- grepl("(?i)\\b(?:sections?|see|in|and|to|of)\\s*$", before, perl = TRUE)
    keep <- !grepl("\\.{4,}|(?:\\. ){3,}", line) & !crossRef
    data.frame(start = loc[keep, 1], line = line[keep])
  }
  num <- find(headings$numbered)
  lab <- find(headings$labels)
  parts <- stringi::stri_locate_all_regex(text, "(?m)^### ", omit_no_match = TRUE)[[1]][, 1]
  numPart <- findInterval(num$start, parts)
  number <- sub("^(\\d+(?:\\.\\d+)*).*$", "\\1", num$line)
  vapply(at, function(a) {
    path <- character(0)
    pnum <- character(0)
    here <- findInterval(a, parts)
    for (j in which(num$start < a)) {
      keep <- startsWith(paste0(number[j], "."), paste0(pnum, "."))
      keep <- keep & pnum != number[j]
      path <- c(path[keep], num$line[j])
      pnum <- c(pnum[keep], number[j])
    }
    last <- if (length(path)) max(num$start[num$start < a]) else 0
    nearest <- which(num$start == last)
    if (length(nearest) && here - numPart[nearest] > (headings$max_parts %||% Inf)) path <- character(0)
    from <- if (here > 1) parts[here - 1] else 0
    l <- lab$line[lab$start < a & lab$start > max(last, from)]
    out <- paste(path, collapse = " > ")
    if (length(l)) out <- paste0(out, if (nzchar(out)) "; ", l[length(l)])
    out
  }, character(1))
}

#' Reading requests for the items left
#'
#' Step 4, the part that does not depend on the reader: one request per item
#' with open candidates (or per item, when `queue` is `NULL`), the user
#' message giving the item, its candidates and its text. In `window` text
#' mode the text is the context around each candidate instead of the whole
#' item (`width` characters either side), each window labelled with the
#' section it is in, and at most `max_snippets` windows per candidate, spread
#' evenly over its matches.
#'
#' @inheritParams readingPrompt
#' @param queue Candidates left by [ruleDecide()], or `NULL` to read every
#'   item as a whole.
#' @param items Items from [moduleItems()].
#'
#' @return A data frame with `custom_id` (unique, as the Batch API needs),
#'   `source`, `item_id`, `year`, `input_hash`, `labels` (the candidates,
#'   joined by "; ") and `user`.
#' @export
readingRequests <- function(m, queue, items) {
  if (is.null(queue)) {
    req <- cbind(items[c("source", "item_id", "year", "input_hash")], labels = "", shown = "")
  } else {
    key <- paste(queue$source, queue$item_id)
    labels <- vapply(split(queue$label, factor(key, levels = unique(key))), paste, character(1), collapse = "; ")
    # a family named in the text by another of its names says which, so the reader can find it
    shown <- paste0("\"", queue$label, "\"")
    if (!is.null(queue$named)) {
      asItself <- mapply(function(l, n) {
        tolower(l) %in% tolower(strsplit(n, "; ", fixed = TRUE)[[1]])
      }, queue$label, queue$named)
      other <- nzchar(queue$named) & !asItself
      shown[other] <- paste0(shown[other], " (named in the text: ", queue$named[other], ")")
    }
    cands <- vapply(split(shown, factor(key, levels = unique(key))), paste, character(1), collapse = "; ")
    first <- queue[!duplicated(key), ]
    req <- data.frame(
      source = first$source, item_id = first$item_id, year = first$year, input_hash = first$input_hash,
      labels = unname(labels), shown = unname(cands)
    )
  }
  text <- items$text[match(paste(req$source, req$item_id), paste(items$source, items$item_id))]
  if (identical(m$text$mode, "window") && !is.null(m$patterns)) {
    text <- vapply(seq_len(nrow(req)), function(i) {
      lab <- strsplit(req$labels[i], "; ", fixed = TRUE)[[1]]
      f <- findMatches(text[i], m$patterns[m$patterns$family %in% lab, ],
        groups = unique(m$patterns$group),
        width = m$text$width %||% 400
      )
      # each window says which section (and part) it is from, and optionally the item's own
      # headings it sits under
      heads <- stringi::stri_locate_all_regex(text[i], "(?m)^### [^\n]*")[[1]]
      trail <- if (is.null(m$text$headings)) rep("", nrow(f)) else headingTrail(text[i], f$start, m$text$headings)
      if (!is.na(heads[1, 1])) {
        name <- stringi::stri_sub(text[i], heads[, 1] + 4, heads[, 2])
        at <- findInterval(f$start, heads[, 1])
        name <- ifelse(at > 0, name[pmax(at, 1)], "")
        name <- ifelse(nzchar(trail), paste0(name, " | under: ", trail), name)
        f$snip <- paste0(ifelse(nzchar(name), paste0("[", name, "] "), ""), f$snip)
      }
      # at most max_snippets windows per candidate, spread evenly over its matches
      most <- m$text$max_snippets %||% Inf
      keep <- unlist(lapply(split(seq_len(nrow(f)), factor(f$family, levels = unique(f$family))), function(j) {
        if (length(j) <= most) j else j[unique(round(seq(1, length(j), length.out = most)))]
      }))
      paste(f$snip[sort(keep)], collapse = "\n...\n")
    }, character(1))
  }
  cands <- ifelse(nzchar(req$labels), req$shown, "none (classify the item as a whole)")
  req$user <- paste0(
    "Item: ", req$source, " ", req$item_id, " (", req$year, ")\nCandidates: ", cands, "\n\n",
    if (identical(m$text$mode, "window")) "Text around each candidate:\n\n" else "Text:\n\n", text
  )
  stem <- substr(gsub("[^A-Za-z0-9_-]", "_", m$name), 1, 40)
  req$custom_id <- sprintf("%s-%06d", stem, seq_len(nrow(req)))
  req[c("custom_id", "source", "item_id", "year", "input_hash", "labels", "user")]
}

#' The Messages API request body of one reading
#'
#' @param user The user message (from [readingRequests()]).
#' @inheritParams readingPrompt
#' @param reader The reader settings: `model`, `max_tokens` and optionally
#'   `temperature`.
#'
#' @return The request body, as a list: the reading prompt as a system prompt
#'   cached for an hour, the user message, and the output schema.
#' @export
apiBody <- function(user, m, reader = m$reader) {
  b <- list(
    model = reader$model, max_tokens = reader$max_tokens,
    system = list(list(type = "text", text = readingPrompt(m), cache_control = list(type = "ephemeral", ttl = "1h"))),
    messages = list(list(role = "user", content = user)),
    output_config = list(format = list(type = "json_schema", schema = readingSchema(m)))
  )
  if (!is.null(reader$temperature)) b$temperature <- reader$temperature
  b
}

#' Turn reading results into decisions
#'
#' Parses Message Batches API results (one JSON line per request) and checks
#' each answer against its request: every decision's label must be one of the
#' item's candidates and its value one of the module's values, every
#' candidate needs a decision, and a request without a successful answer is
#' listed.
#'
#' @param lines The result lines.
#' @param requests The requests, from [readingRequests()].
#' @inheritParams readingPrompt
#' @param run The run ID (the batch ID).
#' @param date The date to record.
#' @param reader The reader to record; by default the model the API reports.
#'
#' @return A list with `decisions` (the protocol's decision columns),
#'   `problems` (`source`, `item_id`, `custom_id`, `problem`) and `usage`
#'   (token totals).
#' @export
parseReadings <- function(lines, requests, m, run, date = format(Sys.Date()), reader = NULL) {
  res <- lapply(lines[nzchar(lines)], jsonlite::fromJSON, simplifyVector = FALSE)
  ids <- vapply(res, function(r) r$custom_id, character(1))
  hash <- promptHash(m)
  prompt <- paste0(skeletonName(), " with ", m$name, " v", m$version)
  out <- list()
  extra <- list()
  problems <- list()
  usage <- c(input_tokens = 0, output_tokens = 0, cache_read_input_tokens = 0, cache_creation_input_tokens = 0)
  problem <- function(i, what) {
    problems[[length(problems) + 1]] <<- data.frame(
      source = requests$source[i], item_id = requests$item_id[i], custom_id = requests$custom_id[i], problem = what
    )
  }
  for (i in seq_len(nrow(requests))) {
    k <- match(requests$custom_id[i], ids)
    if (is.na(k)) {
      problem(i, "no answer")
      next
    }
    r <- res[[k]]$result
    if (!identical(r$type, "succeeded")) {
      problem(i, r$type %||% "no result")
      next
    }
    msg <- r$message
    for (u in names(usage)) usage[[u]] <- usage[[u]] + (msg$usage[[u]] %||% 0)
    if (!identical(msg$stop_reason, "end_turn")) {
      problem(i, paste("stopped:", msg$stop_reason))
      next
    }
    text <- paste(vapply(Filter(function(b) identical(b$type, "text"), msg$content), `[[`, "", "text"), collapse = "")
    obj <- tryCatch(jsonlite::fromJSON(text, simplifyVector = FALSE), error = function(e) NULL)
    ans <- obj$decisions
    if (is.null(ans)) {
      problem(i, "answer is not the schema's JSON")
      next
    }
    for (f in names(m$extra)) {
      v <- unlist(obj[[f]])
      if (length(v)) {
        extra[[length(extra) + 1]] <- data.frame(
          source = requests$source[i], item_id = requests$item_id[i], field = f, value = as.character(v),
          reader = reader %||% msg$model, run = run, date = date
        )
      }
    }
    cands <- if (nzchar(requests$labels[i])) strsplit(requests$labels[i], "; ", fixed = TRUE)[[1]] else ""
    for (a in ans) {
      # the API does not guarantee case, so a label or value that differs only in case is matched;
      # a label copied with the hint the request shows ("X (named in the text: Y)") is X
      a$label <- sub(" \\(named in the text: [^)]*\\)$", "", a$label)
      a$label <- cands[match(tolower(a$label), tolower(cands))] %|NA|% a$label
      a$value <- m$values$value[match(tolower(a$value), tolower(m$values$value))] %|NA|% a$value
      if (!a$label %in% cands) {
        problem(i, paste("label not among the candidates:", a$label))
      } else if (!a$value %in% m$values$value) {
        problem(i, paste("value not allowed:", a$value))
      } else {
        out[[length(out) + 1]] <- data.frame(
          source = requests$source[i], item_id = requests$item_id[i], label = a$label, value = a$value, method = "ai",
          reader = reader %||% msg$model, prompt = prompt, prompt_hash = hash, run = run, date = date,
          input_hash = requests$input_hash[i], note = a$note %||% ""
        )
      }
    }
    given <- vapply(ans, function(a) {
      l <- sub(" \\(named in the text: [^)]*\\)$", "", a$label)
      cands[match(tolower(l), tolower(cands))] %|NA|% l
    }, character(1))
    for (cnd in setdiff(cands, given)) problem(i, paste("no decision for candidate:", cnd))
  }
  list(
    decisions = if (length(out)) do.call(rbind, out) else emptyDecisions(),
    problems = if (length(problems)) {
      do.call(rbind, problems)
    } else {
      data.frame(source = character(0), item_id = character(0), custom_id = character(0), problem = character(0))
    },
    usage = as.list(usage),
    extra = if (length(extra)) {
      do.call(rbind, extra)
    } else {
      data.frame(
        source = character(0), item_id = character(0), field = character(0), value = character(0),
        reader = character(0), run = character(0), date = character(0)
      )
    }
  )
}

# Prices per million tokens at the standard rate, from https://platform.claude.com/docs/en/about-claude/pricing
# (read 2026-10-18); the Batch API halves them. Haiku 5.5: prompts up to 100,000 tokens.
apiPrices <- data.frame(
  model = c("claude-haiku-5-5", "claude-sonnet-5-5", "claude-opus-5-5", "claude-fable-5-1"),
  input = c(0.10, 2, 4, 10), output = c(0.50, 10, 20, 50), date = "2026-10-18"
)

#' Cost of a reading run at the batch rate
#'
#' @param input,output Token counts.
#' @param model Model ID.
#' @param prices Prices per million tokens at the standard rate.
#'
#' @return US dollars; input is priced as uncached, so this is an upper bound
#'   when the system prompt is cached.
#' @export
estimateCost <- function(input, output, model, prices = apiPrices) {
  p <- prices[prices$model == model, ]
  if (nrow(p) == 0) stop("no price recorded for ", model)
  (input * p$input + output * p$output) / 1e6 / 2
}

#' Write reading requests as batches for Claude Code subagents
#'
#' The same prompt, requests and schema as the API route, as files: the
#' system prompt (`system.md`), the schema (`schema.json`) and batches of
#' requests (`batch_001.json`, ... or `batch_001.txt`, ...). A subagent
#' answers each request with one JSON line `{"custom_id": ..., "decisions":
#' [...]}`, and, when the item has a title, `"title_start"`: the title's first
#' five words, which [readAgentAnswers()] checks to catch answers that have
#' slipped onto the wrong item.
#'
#' The text form puts each request under a `======== custom_id: <id> ========`
#' line and wraps lines at `width` characters, since a file reader may cut
#' long lines.
#'
#' @param requests Requests from [readingRequests()].
#' @inheritParams readingPrompt
#' @param dir Where to write.
#' @param size Most requests per batch.
#' @param chars Most characters of request text per batch; a request longer
#'   than this gets a batch of its own.
#' @param format `"json"` or `"text"`.
#' @param width Line width of the text form.
#'
#' @return The batch files.
#' @export
writeAgentBatches <- function(requests, m, dir, size = 25, chars = Inf, format = c("json", "text"), width = 300) {
  format <- match.arg(format)
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  writeLines(readingPrompt(m), file.path(dir, "system.md"), useBytes = TRUE)
  jsonlite::write_json(readingSchema(m), file.path(dir, "schema.json"), auto_unbox = TRUE, pretty = TRUE)
  # a new batch starts when the next request would break the count or the character budget
  group <- integer(nrow(requests))
  g <- 1L
  n <- 0L
  used <- 0
  for (i in seq_len(nrow(requests))) {
    len <- nchar(requests$user[i])
    if (n > 0 && (n >= size || used + len > chars)) {
      g <- g + 1L
      n <- 0L
      used <- 0
    }
    group[i] <- g
    n <- n + 1L
    used <- used + len
  }
  vapply(split(seq_len(nrow(requests)), group), function(rows) {
    k <- group[rows[1]]
    if (format == "json") {
      f <- file.path(dir, sprintf("batch_%03d.json", k))
      x <- lapply(rows, function(i) list(custom_id = requests$custom_id[i], user = requests$user[i]))
      jsonlite::write_json(x, f, auto_unbox = TRUE, pretty = TRUE)
    } else {
      f <- file.path(dir, sprintf("batch_%03d.txt", k))
      x <- unlist(lapply(rows, function(i) {
        lines <- strsplit(requests$user[i], "\n")[[1]]
        wrapped <- unlist(lapply(lines, function(l) {
          if (nchar(l) <= width) {
            return(l)
          }
          # stri_wrap() crashes on lines of a few hundred thousand characters, so a long line is
          # first cut at a space into pieces of at most 50,000
          pieces <- character(0)
          while (nchar(l) > 50000) {
            cut <- stringi::stri_locate_last_regex(substr(l, 1, 50000), "\\s")[1, 1]
            if (is.na(cut)) cut <- 50000
            pieces <- c(pieces, substr(l, 1, cut))
            l <- substr(l, cut + 1, nchar(l))
          }
          unlist(lapply(c(pieces, l), stringi::stri_wrap, width = width, whitespace_only = TRUE))
        }))
        # a word longer than the width is cut
        wrapped <- unlist(lapply(wrapped, function(l) {
          if (nchar(l) <= width) {
            return(l)
          }
          from <- seq(1, nchar(l), width)
          substring(l, from, pmin(from + width - 1, nchar(l)))
        }))
        c(paste0("======== custom_id: ", requests$custom_id[i], " ========"), wrapped, "")
      }))
      writeLines(x, f, useBytes = TRUE)
    }
    f
  }, character(1), USE.NAMES = FALSE)
}

# The words of a title, lower case, split at anything but letters and digits
titleWords <- function(x) {
  # markup such as <i>, escaped or not, is dropped first
  x <- gsub("&lt;/?[a-zA-Z]+[^&]*?&gt;|</?[a-zA-Z]+[^>]*>", " ", x, perl = TRUE)
  w <- strsplit(tolower(x), "[^[:alnum:]]+")
  lapply(w, function(v) v[!is.na(v) & nzchar(v)])
}

# The first ten words of the title in each request, or NULL when it has no title section
titleStart <- function(user) {
  has <- grepl("(^|\\n)### title\\n", user)
  t <- sub("(?s)^.*?(?:^|\\n)### title\\n([^\\n]*).*$", "\\1", user, perl = TRUE)
  out <- lapply(titleWords(t), head, 10)
  out[!has] <- list(NULL)
  out
}

# Whether an answer's title start matches: its words begin the title, and there are at least
# three of them (or the whole title)
titleMatches <- function(got, want) {
  g <- titleWords(got)[[1]]
  whole <- length(g) >= min(3, length(want)) && length(g) <= length(want) && identical(g, want[seq_along(g)]) ||
    length(g) > 10 && length(want) == 10 && identical(head(g, 10), want)
  # a title start cut at a character count ends inside a word: the words before it must agree
  # (at least three) and the cut word must begin the title's word
  n <- length(g)
  cut <- n >= 4 && n <= length(want) && identical(g[-n], want[seq_len(n - 1)]) && startsWith(want[n], g[n])
  whole || cut
}

#' Read subagents' answers
#'
#' An answer that carries `title_start` must begin the item's title, with at
#' least three words (case and punctuation aside); one that does not is listed as a
#' problem and gives no decision, since the subagent's answer may belong to
#' another item.
#'
#' @param file A JSON-lines file of answers.
#' @param requests The requests.
#' @inheritParams readingPrompt
#' @param model The model the subagents ran on, with its version ("Claude Sonnet 5.5").
#' @inheritParams parseReadings
#'
#' @return As [parseReadings()], with the reader recorded as a Claude Code
#'   subagent on `model`.
#' @export
readAgentAnswers <- function(file, requests, m, model, run, date = format(Sys.Date())) {
  if (!grepl("[0-9]", model)) {
    stop("give the model with its version, for example \"Claude Sonnet 5.5\", not \"", model, "\"")
  }
  ans <- lapply(readLines(file, encoding = "UTF-8"), jsonlite::fromJSON, simplifyVector = FALSE)
  want <- titleStart(requests$user)
  aligned <- vapply(ans, function(a) {
    k <- match(a$custom_id, requests$custom_id)
    if (is.null(a$title_start) || is.na(k) || is.null(want[[k]])) {
      return(TRUE)
    }
    titleMatches(a$title_start, want[[k]])
  }, logical(1))
  lines <- vapply(ans[aligned], function(a) {
    as.character(jsonlite::toJSON(list(custom_id = a$custom_id, result = list(type = "succeeded", message = list(
      model = model, stop_reason = "end_turn",
      content = list(list(
        type = "text",
        text = as.character(jsonlite::toJSON(c(list(decisions = a$decisions), a[names(m$extra)]), auto_unbox = TRUE))
      ))
    ))), auto_unbox = TRUE))
  }, character(1))
  p <- parseReadings(lines, requests, m, run = run, date = date, reader = paste0("Claude Code subagent (", model, ")"))
  bad <- vapply(ans[!aligned], function(a) a$custom_id, character(1))
  if (length(bad)) {
    # parseReadings lists these as unanswered; say why
    hit <- p$problems$custom_id %in% bad
    p$problems$problem[hit] <- "title start does not match the item (answer may belong to another item)"
  }
  p
}

#' Draw the items for a blind second reading
#'
#' @param ids Data frame of items (`source`, `item_id`).
#' @param fraction Share to draw.
#' @param seed Random seed, recorded with the check.
#'
#' @return The drawn rows, in their original order. The caller's random
#'   state is left unchanged.
#' @export
blindSample <- function(ids, fraction, seed) {
  if (exists(".Random.seed", envir = globalenv())) {
    old <- get(".Random.seed", envir = globalenv())
    on.exit(assign(".Random.seed", old, envir = globalenv()), add = TRUE)
  } else {
    on.exit(rm(".Random.seed", envir = globalenv()), add = TRUE)
  }
  set.seed(seed, kind = "Mersenne-Twister", normal.kind = "Inversion", sample.kind = "Rejection")
  ids[sort(sample.int(nrow(ids), round(fraction * nrow(ids)))), , drop = FALSE]
}

#' Agreement of two readings
#'
#' @param first,second Decisions with `source`, `item_id`, `label` and
#'   `value`; only the labels both read are compared.
#'
#' @return A data frame with `compared`, `agree`, `share`, Cohen's `kappa` and
#'   Krippendorff's `alpha` for nominal values (two readers, no missing values:
#'   `1 - (n - 1) * D / E`, with `n` twice the number compared, `D` the
#'   disagreeing pairs counted both ways and `E` the sum of `n_c * n_k` over
#'   pairs of different values).
#' @export
agreement <- function(first, second) {
  k <- function(d) paste(d$source, d$item_id, d$label, sep = "\r")
  both <- intersect(k(first), k(second))
  a <- first$value[match(both, k(first))]
  b <- second$value[match(both, k(second))]
  lv <- union(a, b)
  po <- mean(a == b)
  pe <- sum(vapply(lv, function(v) mean(a == v) * mean(b == v), numeric(1)))
  nc <- vapply(lv, function(v) sum(a == v) + sum(b == v), numeric(1))
  n <- 2 * length(both)
  e <- n^2 - sum(nc^2)
  data.frame(
    compared = length(both), agree = sum(a == b), share = po,
    kappa = if (pe < 1) (po - pe) / (1 - pe) else NA_real_,
    alpha = if (e > 0) 1 - (n - 1) * 2 * sum(a != b) / e else NA_real_
  )
}

#' The tags of a module from its decisions
#'
#' One decision per item and label: a human decision if there is one, else an
#' adjudication of a disagreement, else the latest reading or rule decision.
#'
#' @param decisions Decisions with `source`, `item_id`, `label`, `method`
#'   and `date`.
#'
#' @return The decisions kept, in order of first appearance of each label.
#' @export
moduleTags <- function(decisions) {
  rank <- match(decisions$method, c("human", "adjudication", "ai", "rule"))
  rank[decisions$method %in% c("ai", "rule")] <- 3L
  key <- paste(decisions$source, decisions$item_id, decisions$label, sep = "\r")
  o <- order(match(key, unique(key)), rank, -xtfrm(decisions$date), -seq_along(key))
  d <- decisions[o, ]
  d <- d[!duplicated(key[o]), ]
  rownames(d) <- NULL
  d
}

#' Withhold notes that repeat the item's text
#'
#' Readers are told not to quote, but a note can still repeat a phrase. Notes
#' are published and the text of most sources is not, so a note that shares a
#' run of `n` or more words with its own item's text (case, punctuation and
#' spacing ignored) is replaced before the decisions are written.
#'
#' @param decisions Decisions with `source`, `item_id` and `note`.
#' @param items Items with `source`, `item_id` and `text` (from
#'   [moduleItems()]).
#' @param n The shortest run of words that counts as repeating.
#'
#' @return `decisions` with such notes replaced by
#'   `"(withheld: repeats the item's text)"`.
#' @export
withholdQuotes <- function(decisions, items, n = 8) {
  words <- function(s) {
    w <- strsplit(tolower(stringi::stri_replace_all_regex(s, "[^\\p{L}\\p{N}]+", " ")), " ", fixed = TRUE)[[1]]
    w[nzchar(w)]
  }
  key <- paste(items$source, items$item_id)
  for (i in seq_len(nrow(decisions))) {
    w <- words(decisions$note[i])
    if (length(w) < n) next
    own <- items$text[match(paste(decisions$source[i], decisions$item_id[i]), key)]
    text <- paste0(" ", paste(words(own), collapse = " "), " ")
    runs <- vapply(seq_len(length(w) - n + 1), function(k) {
      paste0(" ", paste(w[k:(k + n - 1)], collapse = " "), " ")
    }, character(1))
    if (any(stringi::stri_detect_fixed(text, runs))) decisions$note[i] <- "(withheld: repeats the item's text)"
  }
  decisions
}
