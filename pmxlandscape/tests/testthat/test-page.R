test_that("pageParseAbstract reads the citation, session and title", {
  a <- pageParseAbstract(pageTwoAuthors)
  expect_equal(a$year, 2024L)
  expect_equal(a$abstract_no, 99999L)
  expect_equal(a$session, "Poster: Methodology - Model evaluation")
  expect_equal(a$title, "An invented abstract")
  expect_equal(pageParseAbstract(pageOneAuthor)$year, 1992L)
})

test_that("the abstract body leaves out authors, affiliations, references and the rest of the page", {
  a <- pageParseAbstract(pageTwoAuthors)
  expect_equal(a$authors, "Anna Author (1,2), Torsten Coauthor (3)")
  expect_match(a$affiliations, "^\\(1\\) Department of Pharmacy")
  expect_match(a$body, "Monolix 2023R1")
  expect_match(a$body, "Simulate doses") # list items are part of the body
  expect_no_match(a$body, "NONMEM|Torsten|Stan|Certara|Reference")
})

test_that("pageParseAbstract gives the PDF address only when there is a file", {
  expect_equal(
    pageParseAbstract(pageTwoAuthors)$pdf_url,
    "https://www.page-meeting.org/wp-content/uploads/pdf_abstracts/abstract_99999.pdf"
  )
  expect_true(is.na(pageParseAbstract(pageOneAuthor)$pdf_url))
})

test_that("a page without the abstract layout gives a row of missing values", {
  a <- pageParseAbstract("<html><body><p>Not an abstract</p></body></html>")
  expect_equal(nrow(a), 1)
  expect_true(is.na(a$year))
  expect_true(is.na(a$body))
})

test_that("mainAffiliation takes the first affiliation of the first author", {
  expect_equal(
    mainAffiliation("Anna Author (1,2), Torsten Coauthor (3)", "(1) Dept A, Uni X, (2) Pharma Y AB, (3) Certara, USA"),
    "Dept A, Uni X"
  )
  expect_equal(mainAffiliation("B. Second (2), A. First (1)", "(1) Place One, (2) Place Two"), "Place Two")
  expect_equal(
    mainAffiliation("A. Single", "Medicines Evaluation Board, Utrecht"),
    "Medicines Evaluation Board, Utrecht"
  )
  expect_equal(mainAffiliation("A. Unmarked, B. Other", "(1) Place One, (2) Place Two"), "Place One")
  expect_true(is.na(mainAffiliation(NA, "Place")))
})

test_that("classifyAffiliation assigns the five types and leaves unknowns unclassified", {
  rules <- readAffiliationRules(repoFile("taxonomy", "affiliation_rules.csv"))
  x <- c(
    "Department of Pharmacy, Uppsala University, Sweden",
    "Pharmacometrics, Novartis Institutes for BioMedical Research, Basel",
    "Example Pharma AB, Sweden",
    "Certara, Princeton, USA",
    "Office of Clinical Pharmacology, U.S. Food and Drug Administration, Silver Spring",
    "Medicines Evaluation Board, Utrecht",
    "Department of Pharmaceutical Sciences, University at Buffalo",
    "Somewhere unknown",
    NA
  )
  expect_equal(
    classifyAffiliation(x, rules),
    c("academia", "industry", "industry", "CRO", "regulator", "regulator", "academia", "unclassified", NA)
  )
})

# Author and affiliation styles seen in the September 2026 pilot, with invented author names.
test_that("mainAffiliation reads markers written as plain digits", {
  expect_equal(
    mainAffiliation(
      "Anna Author1,2, Bo Other1, Cy Third3",
      "1Example Pharma AG, Basel, Switzerland, 2Centre for Research, University of X, UK; 3Third Place"
    ),
    "Example Pharma AG, Basel, Switzerland"
  )
  expect_equal(
    mainAffiliation("Anna Author2, Bo Other1", "1 Place One, France 2 Place Two, Paris, France 3 Place Three"),
    "Place Two, Paris, France"
  )
})

test_that("mainAffiliation is not misled by postcodes, street numbers or separators", {
  expect_equal(
    mainAffiliation(
      "A. Author (1), B. Other (2)", "(1) College of X, Example City 01234, Korea (2) Hospital Y, Example City"
    ),
    "College of X, Example City 01234, Korea"
  )
  expect_equal(
    mainAffiliation("Surname, A.(1), B. Other(2)", "(1)Inst X, Nuremberg, Germany; (2)Univ. of Y"),
    "Inst X, Nuremberg, Germany"
  )
  expect_equal(
    mainAffiliation("P. Author", "Service of Z, 162 Av. Example, 69003 Lyon, France"),
    "Service of Z, 162 Av. Example, 69003 Lyon, France"
  )
})

test_that("department names with 'Pharma-' in them do not count as industry", {
  rules <- readAffiliationRules(repoFile("taxonomy", "affiliation_rules.csv"))
  expect_equal(
    classifyAffiliation(
      c("Service De Pharmacologie Clinique, Lyon, France", "Pharmacy Dept, Western Infirmary, Glasgow"), rules
    ),
    c("unclassified", "academia")
  )
})

test_that("service companies are CRO, software companies vendor, and CRO wins where both are named", {
  rules <- readAffiliationRules(repoFile("taxonomy", "affiliation_rules.csv"))
  x <- c(
    "Pharmetheus AB, Uppsala, Sweden",
    "ICON plc, Leeds, UK",
    "qPharmetra LLC, Andover, USA",
    "IQVIA, Durham, USA",
    "Metrum Research Group, Tariffville, USA",
    "Independent consultant, Example Town, UK",
    "Pharsight Corporation, Mountain View, CA, USA",
    "Simcyp Division, Certara UK Limited, Sheffield, UK",
    "Cognigen Corporation, a Simulations Plus company, Buffalo, USA",
    "Simcyp Limited, Sheffield, UK",
    "Lixoft, Antony, France",
    "Simulations Plus, Lancaster, USA",
    "PumasAI Inc, Baltimore, USA",
    "Office of Clinical Pharmacology, FDA, and Certara"
  )
  expect_equal(classifyAffiliation(x, rules), c(
    rep("CRO", 9), rep("vendor", 4), "regulator"
  ))
})

test_that("pageParseAbstract flags the Software Demonstration session", {
  demo <- pageHtml(c(
    "<p>A. Author</p>", "<p>Example University</p>", "<p>A demonstration of a new tool.</p>",
    "<p>Reference: PAGE 15 (2006) Abstr 1037 [www.page-meeting.org/?abstract=1037]</p>",
    "<p>Poster: Software Demonstration</p>"
  ))
  expect_true(pageParseAbstract(demo)$software_demo)
  expect_false(pageParseAbstract(pageTwoAuthors)$software_demo)
  expect_false(pageParseAbstract("<html><body></body></html>")$software_demo)
})

# Cases from the September 2026 check of a sample of PubMed first-author affiliations.
test_that("an email address does not decide the class", {
  rules <- readAffiliationRules(repoFile("taxonomy", "affiliation_rules.csv"))
  expect_equal(classifyAffiliation("Example Hospital, Chiba, Japan. taro.takeda@example.ac.jp", rules), "academia")
})

test_that("a laboratory named after a regulator is not the regulator", {
  rules <- readAffiliationRules(repoFile("taxonomy", "affiliation_rules.csv"))
  x <- c(
    "NMPA Key Laboratory for Clinical Research and Evaluation of Innovative Drugs, West China Hospital, Chengdu",
    "National Medical Products Administration Key Laboratory for Drug Evaluation, Shandong University, Jinan",
    "Center for Drug Evaluation, National Medical Products Administration, Beijing, China"
  )
  expect_equal(classifyAffiliation(x, rules), c("academia", "academia", "regulator"))
})

test_that("more academic, company and regulator wording is recognised", {
  rules <- readAffiliationRules(repoFile("taxonomy", "affiliation_rules.csv"))
  x <- c(
    "Facultad de Ciencias Quimicas, Universidad Catolica de Cordoba, Argentina",
    "Department of Pharmaceutical and Pharmacological Sciences, KU Leuven, Belgium",
    "Memorial Sloan Kettering Cancer Center, New York",
    "Department of Pharmacy, Example NHS Foundation Trust, London",
    "Department of Clinical Pharmacy, Example MC, Hilversum",
    "Fraunhofer-Chalmers Research Centre for Industrial Mathematics, Gothenburg",
    "CSL Behring, King of Prussia, USA",
    "mAbxience Research S.L., Madrid, Spain",
    "Medicines and Medical Devices Agency of Serbia, Belgrade",
    "Example Pharmacometrics, Rotterdam, The Netherlands"
  )
  expect_equal(
    classifyAffiliation(x, rules),
    c(rep("academia", 6), "industry", "industry", "regulator", "CRO")
  )
})

test_that("company names match as whole words only", {
  rules <- readAffiliationRules(repoFile("taxonomy", "affiliation_rules.csv"))
  x <- c(
    "Example Hospital, 12, Hatakeda, Example City, Japan",
    "Department of Pharmacology, University of Rochester, USA",
    "School of Pharmacy, University of Bristol, UK",
    "Bristol-Myers Squibb, Princeton, USA",
    "F. Hoffmann-La Roche Ltd, Basel",
    "Princess Example Center for Pediatric Oncology, Utrecht"
  )
  expect_equal(classifyAffiliation(x, rules), c("academia", "academia", "academia", "industry", "industry", "academia"))
})

# Cases from the second, out-of-sample check (September 2026).
test_that("out-of-sample corrections: regulator wording, city names, departments, hospitals", {
  rules <- readAffiliationRules(repoFile("taxonomy", "affiliation_rules.csv"))
  x <- c(
    "Office of Clinical Pharmacology, Center for Drug Evaluation and Research, Food & Drug Administration, USA",
    "Department of Pharmacy, Wuxi People's Hospital, Wuxi, China",
    "WuXi AppTec, Shanghai, China",
    "Quantitative Pharmacology and Pharmacometrics, Rahway, NJ, USA",
    "Example Pharmacometrics, Rotterdam, The Netherlands",
    "Department of Pharmacy, Mayo Clinic, Rochester, USA",
    "Clinica Las Condes, Santiago, Chile",
    "Pharmacy Department, Example NHSFT, London",
    "Department of Pharmacy, Radboudumc, Nijmegen",
    "Example Kinderspital, Vienna, Austria",
    "Monash Health, Melbourne, Australia",
    "Ministry of Health, Example Country",
    "Genmab, Copenhagen, Denmark"
  )
  expect_equal(classifyAffiliation(x, rules), c(
    "regulator", "academia", "CRO", "unclassified", "CRO", "academia", "academia", "academia", "academia",
    "academia", "academia", "unclassified", "industry"
  ))
})

# From the code review (September 2026)
test_that("mainAffiliation reads more marker styles and cuts the fallback before the second affiliation", {
  expect_equal(
    mainAffiliation("A. Author1, B. Other2", "1) Example University, Canada, (2) Example CRO Inc"),
    "Example University, Canada"
  )
  expect_equal(
    mainAffiliation("A. Author1, B. Other2", "1, Dept A, Example University; 2, Company Y"),
    "Dept A, Example University"
  )
  expect_equal(
    mainAffiliation("A. Author(12), B. Other(3)", "(1) Uni X (2) Uni Y (3) Pharma Z"),
    "Uni X"
  ) # (12) read as 1 and 2
  expect_equal(
    mainAffiliation("A. Author, B. Other (2)", "Institute X, Seattle, (2) Example Pharma"),
    "Institute X, Seattle"
  )
  expect_equal(
    mainAffiliation("A. Author1, B. Other2", "1Dept A, SE-75122 Uppsala, Sweden, 2Company Y"),
    "Dept A, SE-75122 Uppsala, Sweden"
  )
})

test_that("public laboratories are academia and a CRO unit inside an institute is not a CRO", {
  rules <- readAffiliationRules(repoFile("taxonomy", "affiliation_rules.csv"))
  x <- c(
    "Example National Laboratory, New Mexico, USA", "Beijing Key Laboratory of Example Research, Beijing",
    "Ecole Polytechnique Federale de Lausanne, Switzerland",
    "Clinical Trials Unit-CRO, Example National Cancer Institute, Italy",
    "Example Laboratories Ltd, Cambridge, UK"
  )
  expect_equal(classifyAffiliation(x, rules), c("academia", "academia", "academia", "academia", "industry"))
})

# Styles from the check of 163 PAGE abstracts (September 2026), with invented names.
test_that("mainAffiliation reads square-bracket markers", {
  expect_equal(
    mainAffiliation(
      "A. First [2,3]*, B. Other [1]*", "[1] Example Vendor, France, [2] Example University, USA, [3] Other Place"
    ),
    "Example University, USA"
  )
})

test_that("classifyFirstAuthor falls back step by step when the first piece does not decide", {
  rules <- readAffiliationRules(repoFile("taxonomy", "affiliation_rules.csv"))
  au <- c(
    "A. First (1,2), B. Other (3)", # first piece undecided, the author's second decides
    "A. First (1), B. Other (2)", # shared prefix names the company
    "A. First (1), B. Other (2)", # institution after the last marker, shared by all
    "A. First (1), B. Other (2)"
  )
  af <- c(
    "(1) Laboratory of Example Cells, Lyon, (2) Example University, Lyon, (3) Example Pharma Inc",
    "Clinical Pharmacology, Novartis: (1) Basel, Switzerland; (2) East Hanover, USA",
    paste(
      "(1) Pediatric Pharmacology and Pharmacometrics, (2) Pediatric Cardiology,",
      "Example University Children's Hospital, Basel"
    ),
    "(1) Example University, Oslo, (2) Example Pharma Inc"
  )
  r <- classifyFirstAuthor(au, af, rules)
  expect_equal(r$affiliation_type, c("academia", "industry", "academia", "academia"))
  expect_equal(r$step, c("other affiliation", "shared prefix", "whole line", "first affiliation"))
})

test_that("more institutes, companies and consultancies are recognised", {
  rules <- readAffiliationRules(repoFile("taxonomy", "affiliation_rules.csv"))
  x <- c(
    "Inria, Villeurbanne, France", "Consiglio Nazionale delle Ricerche (CNR), Rome", "EMBL-EBI, Hinxton, UK",
    "LACDR, Leiden, The Netherlands", "Antoni van Leeuwenhoek, Amsterdam", "UCSF, San Francisco, USA",
    "PharmaMar, Madrid, Spain", "Pumas AI, Baltimore, USA", "esqLABS GmbH, Saterland, Germany",
    "Pediatric Pharmacology and Pharmacometrics, Basel"
  )
  expect_equal(
    classifyAffiliation(x, rules),
    c(rep("academia", 6), "industry", "vendor", "CRO", "unclassified")
  )
})

pageWith <- function(bodyParas) {
  paste0(
    "<html><body><h1>A title</h1><article><div class='content-cleanse'>",
    "<p>Anna Author (1)</p><p>(1) Some University</p>",
    paste0("<p>", bodyParas, "</p>", collapse = ""),
    "<p>Reference: PAGE 33 (2025) Abstr 99998 [www.page-meeting.org/?abstract=99998]</p>",
    "<p>Poster: Methodology - Other topics</p></div></article></body></html>"
  )
}

test_that("a reference list without a References: heading is left out of the body (PAGE 2025 layout)", {
  a <- pageParseAbstract(pageWith(c(
    "Methods: models were fitted in Monolix 2024R1 and compared with SAMBA [1].",
    "[1] H Yun, R Svensson. Evaluation of FREM. CPT: Pharmacometrics & Systems Pharmacology. 2022"
  )))
  expect_match(a$body, "Monolix 2024R1")
  expect_match(a$body, "SAMBA \\[1\\]") # an inline citation stays
  expect_no_match(a$body, "Systems Pharmacology|Yun")
  b <- pageParseAbstract(pageWith(c(
    "Results: the final model had two compartments.",
    "1. Ogami, C., Tsuji, Y. (2019). Pharmacokinetics of linezolid. 2. Tsai, H. Machine learning for thrombocytopenia."
  )))
  expect_no_match(b$body, "Ogami|Machine learning")
})

test_that("a reference list appended to the last paragraph is cut off there", {
  a <- pageParseAbstract(pageWith(
    paste(
      "Conclusion: the workflow found the model.",
      "1. Bruno R, Chanu P. Tumor dynamics. CPT Pharmacometrics Syst Pharmacol. 2020"
    )
  ))
  expect_match(a$body, "found the model\\.$")
})

test_that("numbered lists in the methods are not taken for references", {
  a <- pageParseAbstract(pageWith(c(
    "Methods: 1. Structural model: two compartments. 2. Covariate model: weight on CL.",
    "[1] alone at the start of a sentence is not a reference when no author follows"
  )))
  expect_match(a$body, "Structural model")
  expect_match(a$body, "Covariate model")
})

test_that("item lists numbered [1], [2] in the body stay; reference lists in the forms PAGE 2025 uses are cut", {
  keep <- c(
    "[1] BAYES MCMC method with WinBUGS [2] plus the model library",
    "[1] The IgG domain binds to the FcRn receptor",
    "1. Standard PK parameters were estimated with Pmetrics (NPAG)[1]. 2. Weights per subject",
    "[1] Version VI using FOCE with interaction.",
    "[1] Under H0, the pd follow a uniform distribution."
  )
  for (k in keep) expect_equal(cutReferenceList(paste("Methods:", k)), paste("Methods:", k), label = k)
  refs <- c(
    "[1] Le Tourneau C, Lee JJ, Siu LL. Dose Escalation Methods. J Natl Cancer Inst. 2009",
    "[1] S. Südfeld et al., Post-induction hypotension. 2017",
    "1. Sidharta PN, Treiber A, Dingemanse J. Clinical Pharmacokinetics. 2015",
    "[1] Macheras P. On an unphysical hypothesis of Bateman equation. 2019"
  )
  for (r in refs) expect_equal(cutReferenceList(paste("Conclusion: done.", r)), "Conclusion: done.", label = r)
})
