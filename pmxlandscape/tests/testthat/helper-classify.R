# A toy classification module (fixtures/module-toy) and a three-item PAGE corpus for it
toyDir <- function() test_path("fixtures", "module-toy")

# A three-item PAGE corpus in a temporary corpus folder
toyCorpus <- function(env = parent.frame()) {
  root <- withr::local_tempdir(.local_envir = env)
  s <- corpusSections("PAGE", c("1", "1", "2", "2", "3"), c("title", "body", "title", "body", "title"), "", "html", c(
    "A model", "The model was fitted with Toolx. Tooly was used before [1].",
    "Another model", "Background: Tooly is common. We used Tooly for the fit.",
    "No tools here"
  ))
  it <- corpusItems("PAGE", c("1", "2", "3"), c(2024L, 2025L, 2025L), paste0("u", 1:3), "abstract page", "2026-09-26",
    sections = s
  )
  corpusWrite(list(items = it, sections = s), root, "page")
  root
}
