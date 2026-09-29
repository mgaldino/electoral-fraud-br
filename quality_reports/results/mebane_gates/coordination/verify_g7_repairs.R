# Coordinator regressions, separate from executor and independent-review suites.
source("R/lib/mebane_2026_intake.R")
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L || file.exists(args[[1L]]))
  stop("Provide a new output JSON path")
fixtures <- "tests/mebane/2026/fixtures"
scratch <- tempfile("g7-coordinator-")
dir.create(scratch)
cfg <- file.path(fixtures, "config2022.json")
vote1 <- file.path(fixtures, "votes_t1_2022.csv")
ea11 <- file.path(fixtures, "ea11_2022.json")
ea16 <- file.path(fixtures, "ea16_t1_2022.json")
control1 <- file.path(fixtures, "controls_t1_2022.json")
records <- list()
record <- function(name, passed, detail = NULL) {
  records[[length(records) + 1L]] <<- list(case = name, passed = isTRUE(passed), detail = detail)
}
negative <- function(name, expected, expr) {
  message <- tryCatch({force(expr); "ACCEPTED"}, error = function(e) conditionMessage(e))
  record(name, identical(message, expected), message)
}
baseline <- g7_stage(vote1, ea11, ea16, control1, cfg, file.path(scratch, "base"), 1L)
record("ascii_control", baseline$validation$status == "staging_validated")
name <- "JOS\u00c9 DA CONCEI\u00c7\u00c3O"
utf8_votes <- file.path(scratch, "utf8.csv")
writeLines(gsub("CANDIDATO", name, readLines(vote1), fixed = TRUE), utf8_votes, useBytes = TRUE)
conf <- g7_json(cfg)
conf$candidate_selection[["1"]]$name <- name
utf8_cfg <- file.path(scratch, "utf8.json")
jsonlite::write_json(conf, utf8_cfg, auto_unbox = TRUE)
utf8 <- g7_stage(utf8_votes, ea11, ea16, control1, utf8_cfg, file.path(scratch, "utf8"), 1L)
again <- g7_stage(utf8_votes, ea11, ea16, control1, utf8_cfg, file.path(scratch, "utf8"), 1L)
record("utf8_exact_end_to_end", identical(charToRaw(enc2utf8(utf8$candidate$name)),
  charToRaw(enc2utf8(name))) && identical(utf8$version, again$version))
invalid <- file.path(scratch, "invalid.csv")
bytes <- readBin(utf8_votes, "raw", n = file.info(utf8_votes)$size)
bytes[which(bytes == as.raw(0xc3))[1L]] <- as.raw(0xff)
writeBin(bytes, invalid)
negative("invalid_utf8_rejected", "Invalid UTF-8 CSV bytes", g7_read_votes(invalid))
for (turn in 1:2) {
  doc <- g7_json(ea11)
  doc$pl[[turn]]$dt <- if (turn == 1L) "03/10/2022" else "29/10/2022"
  path <- file.path(scratch, paste0("wrong_date_", turn, ".json"))
  jsonlite::write_json(doc, path, auto_unbox = TRUE)
  negative(paste0("exact_date_turn", turn), "EA11 date differs from configured turn date",
           g7_election(path, g7_read_config(cfg), turn))
}
conf <- g7_json(cfg)
conf$territorial_scope$expected_ufs <- list("DF", "SP")
path <- file.path(scratch, "missing_uf_config.json")
jsonlite::write_json(conf, path, auto_unbox = TRUE)
negative("missing_configured_uf", "EA16 missing configured UFs",
         g7_stage(vote1, ea11, ea16, control1, path, file.path(scratch, "missing"), 1L))
extra <- g7_json(ea16)
extra$abr[[2L]] <- extra$abr[[1L]]
extra$abr[[2L]]$cd <- "df"
path <- file.path(scratch, "extra_uf.json")
jsonlite::write_json(extra, path, auto_unbox = TRUE)
negative("unexpected_uf", "EA16 unexpected UFs",
         g7_stage(vote1, ea11, path, control1, cfg, file.path(scratch, "extra"), 1L))
validation <- baseline$validation
record("reference_not_national_scope", validation$reference_complete &&
  !validation$national_coverage_attested &&
  identical(unlist(validation$territorial_scope$expected_ufs), "SP") &&
  validation$by_uf[[1L]]$reference_sections == 2L &&
  !baseline$data_ready && !baseline$inference_ready)
result <- list(locale = Sys.getlocale("LC_CTYPE"),
               code_sha256 = g7_sha("R/lib/mebane_2026_intake.R"),
               script_sha256 = g7_sha("quality_reports/results/mebane_gates/coordination/verify_g7_repairs.R"),
               tests = records, all_passed = all(vapply(records, function(x) x$passed, logical(1))))
jsonlite::write_json(result, args[[1L]], pretty = TRUE, auto_unbox = TRUE)
unlink(scratch, recursive = TRUE)
print(result)
stopifnot(result$all_passed)
