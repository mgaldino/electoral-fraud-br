#!/usr/bin/env Rscript
# Locale-C regression probe with byte-validated UTF-8 and an ASCII control.
args <- commandArgs(trailingOnly = TRUE)
prefix <- "quality_reports/results/mebane_gates/G7/round1/review/"
if (length(args) != 1L || !startsWith(args[[1]], prefix) || dir.exists(args[[1]]))
  stop("Pass one new output directory under review")
out <- args[[1]]
dir.create(out, recursive = TRUE)
source("R/lib/mebane_2026_intake.R")
raw_lines <- readLines("tests/mebane/2026/fixtures/votes_t1_2022.csv", warn = FALSE)
ascii_path <- file.path(out, "ascii.csv")
utf8_path <- file.path(out, "utf8.csv")
writeLines(raw_lines, ascii_path, useBytes = TRUE)
utf8_name <- intToUtf8(c(74, 79, 83, 201, 32, 68, 65, 32, 67, 79, 78, 67, 69, 73, 199, 195, 79))
utf8_lines <- gsub("CANDIDATO", utf8_name, raw_lines, fixed = TRUE)
writeLines(utf8_lines, utf8_path, useBytes = TRUE)
read_probe <- function(path) {
  warnings <- character()
  x <- withCallingHandlers(tryCatch(g7_read_votes(path), error = function(e) e),
    warning = function(w) {warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning")})
  list(ok = is.data.frame(x), rows = if (is.data.frame(x)) nrow(x) else NULL,
       names = if (is.data.frame(x)) as.list(x$candidate_name) else NULL,
       error = if (inherits(x, "error")) conditionMessage(x) else NULL,
       warnings = warnings)
}
ascii <- read_probe(ascii_path)
utf8 <- read_probe(utf8_path)
byte_preserving <- read.csv(utf8_path, colClasses = "character", check.names = FALSE,
                            na.strings = character(), fileEncoding = "")
byte_preserving_valid <- nrow(byte_preserving) == 2L &&
  all(!is.na(iconv(byte_preserving$candidate_name, from = "UTF-8", to = "UTF-8",
                   sub = NA_character_))) &&
  all(iconv(byte_preserving$candidate_name, from = "UTF-8", to = "UTF-8") == utf8_name)
bytes <- readBin(utf8_path, "raw", n = file.info(utf8_path)$size)
valid_utf8 <- !is.na(iconv(utf8_name, from = "UTF-8", to = "UTF-8", sub = NA_character_))
outcome <- list(locale = Sys.getlocale("LC_CTYPE"), expected_name = utf8_name,
                utf8_name_bytes = paste(format(charToRaw(utf8_name)), collapse = ""),
                input_sha256 = list(ascii = g7_sha(ascii_path), utf8 = g7_sha(utf8_path)),
                utf8_input_contains_expected_bytes = any(grepl(utf8_name, utf8_lines, fixed = TRUE)),
                utf8_valid = valid_utf8, total_input_bytes = length(bytes),
                byte_preserving_read_rows = nrow(byte_preserving),
                byte_preserving_utf8_valid = byte_preserving_valid,
                ascii = ascii, utf8 = utf8,
                defect_confirmed = identical(Sys.getlocale("LC_CTYPE"), "C") &&
                  valid_utf8 && ascii$ok && identical(ascii$rows, 2L) && !utf8$ok &&
                  identical(utf8$error, "Empty/missing vote values"))
jsonlite::write_json(outcome, file.path(out, "result.json"), auto_unbox = TRUE, pretty = TRUE)
cat(jsonlite::toJSON(outcome[c("locale", "utf8_valid", "ascii", "utf8", "defect_confirmed")],
                     auto_unbox = TRUE), "\n")
if (!outcome$defect_confirmed) quit(status = 1L)
