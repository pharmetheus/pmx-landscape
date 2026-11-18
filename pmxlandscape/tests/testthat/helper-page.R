# Invented PAGE abstract pages with the layout of page-meeting.org (September
# 2026): the abstract is a list of <p> elements in article div.content-cleanse,
# in the order authors, affiliations, body, references, citation, session, PDF.
pageHtml <- function(paragraphs, title = "An invented abstract") {
  paste0(
    "<html><body><header><nav>PAGE meetings: NONMEM course, Torsten award</nav></header>",
    "<main><h1>", title, "</h1><article><section><div class=\"container\"><div class=\"content-cleanse\">",
    paste(paragraphs, collapse = ""),
    "</div></div></section></article></main><footer>Stan the webmaster</footer></body></html>"
  )
}

pageTwoAuthors <- pageHtml(c(
  "<p>Anna Author (1,2), Torsten Coauthor (3)</p>",
  "<p>(1) Department of Pharmacy, Example University, Sweden, (2) Example Pharma AB, Sweden, (3) Certara, USA</p>",
  "<p>&nbsp;</p>",
  "<p>Objectives: To describe a population PK model.</p>",
  "<ol><li>Build the model</li><li>Simulate doses</li></ol>",
  "<p>Methods: Models were fitted in Monolix 2023R1 and simulations used mrgsolve.</p>",
  "<p>References: [1] Beal SL. The NONMEM system.</p>",
  "<p>Reference: PAGE 32 (2024) Abstr 99999 [www.page-meeting.org/?abstract=99999]</p>",
  "<p>Poster: Methodology - Model evaluation</p>",
  paste0(
    "<p><a href=\"/wp-content/uploads/pdf_abstracts/abstract_99999.pdf\">",
    "PDF poster / presentation (click to open)</a></p>"
  )
))

pageOneAuthor <- pageHtml(c(
  "<p>A. Single</p>",
  "<p>Medicines Evaluation Board, Utrecht, The Netherlands</p>",
  "<p>Methods: A model was developed for the data.</p>",
  "<p>Reference: PAGE 1 (1992) Abstr 898 [www.page-meeting.org/?abstract=898]</p>",
  "<p>Poster: oral presentation</p>",
  "<p><a href=\"/wp-content/uploads/pdf_abstracts/\">PDF poster / presentation (click to open)</a></p>"
))
