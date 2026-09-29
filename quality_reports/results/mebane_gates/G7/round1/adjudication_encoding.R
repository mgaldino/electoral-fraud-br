# Coordinator check: the declared UTF-8 adapter must preserve non-ASCII names.
source("R/lib/mebane_2026_intake.R")
raw <- readLines("tests/mebane/2026/fixtures/votes_t1_2022.csv", warn = FALSE)
name <- "JOS\u00c9 DA CONCEI\u00c7\u00c3O"
path <- tempfile(fileext = ".csv")
writeLines(gsub("CANDIDATO", name, raw, fixed = TRUE), path, useBytes = TRUE)
warnings <- character()
result <- withCallingHandlers(tryCatch(g7_read_votes(path), error = function(e) e),
  warning = function(w) {
    warnings <<- c(warnings, conditionMessage(w))
    invokeRestart("muffleWarning")
  })
passed <- is.data.frame(result) && nrow(result) == length(raw) - 1L &&
  all(enc2utf8(result$candidate_name) == enc2utf8(name))
record <- list(locale = Sys.getlocale("LC_CTYPE"), expected_name = name,
               rows_expected = length(raw) - 1L,
               rows_read = if (is.data.frame(result)) nrow(result) else NULL,
               names_read = if (is.data.frame(result)) result$candidate_name else NULL,
               error = if (inherits(result, "error")) conditionMessage(result) else NULL,
               warnings = warnings, passed = passed)
jsonlite::write_json(record, "quality_reports/results/mebane_gates/G7/round1/adjudication_encoding.json",
                    auto_unbox = TRUE, pretty = TRUE)
print(record)
unlink(path)
cat("Diagnostic only: a FALSE result confirms rejection of valid UTF-8, not a passing regression.\n")
