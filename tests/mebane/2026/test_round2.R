# Repair regressions; run in a fresh R process for each requested locale.
source("R/lib/mebane_2026_intake.R")
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 1L, !dir.exists(args[[1L]]))
out <- args[[1L]]
dir.create(out, recursive = TRUE)
locale_before <- Sys.getlocale()
f <- function(name) file.path("tests/mebane/2026/fixtures", name)
write_json <- function(x, name) {
  path <- file.path(out, name)
  jsonlite::write_json(x, path, auto_unbox = TRUE, pretty = TRUE, null = "null")
  path
}
write_text <- function(x, name) {
  path <- file.path(out, name)
  writeBin(charToRaw(paste0(paste(x, collapse = "\n"), "\n")), path)
  path
}
records <- list()
check <- function(id, expr, error = NULL) {
  observed <- tryCatch({force(expr); NULL}, error = function(e) conditionMessage(e))
  passed <- if (is.null(error)) is.null(observed) else
    !is.null(observed) && grepl(error, observed, fixed = TRUE)
  records[[length(records) + 1L]] <<- list(id = id, passed = passed,
                                         expected_error = error, observed_error = observed)
}
cfg <- f("config2022.json")
ea11 <- f("ea11_2022.json")
ea16 <- f("ea16_t1_2022.json")
vote <- f("votes_t1_2022.csv")
control <- f("controls_t1_2022.json")
store <- file.path(out, "store")
stage <- function(v = vote, c = cfg, e = ea11, refs = ea16, totals = control, turn = 1L) {
  g7_stage(v, e, refs, totals, c, store, turn)
}
name <- "JOS\u00c9 DA CONCEI\u00c7\u00c3O"
utf8_vote <- write_text(gsub("CANDIDATO", name, readLines(vote), fixed = TRUE), "utf8.csv")
config_utf8 <- g7_json(cfg)
config_utf8$candidate_selection[["1"]]$name <- name
utf8_cfg <- write_json(config_utf8, "config_utf8.json")
check("F03_utf8_read_bytes", {
  v <- g7_read_votes(utf8_vote)
  stopifnot(nrow(v) == 2L, all(vapply(v$candidate_name,
            function(x) identical(charToRaw(x), charToRaw(name)), logical(1))))
})
check("F03_utf8_stage_snapshot_receipt_idempotence", {
  result <- stage(utf8_vote, utf8_cfg)
  path <- file.path(store, "2022", "turn1", result$version)
  stopifnot(identical(charToRaw(result$candidate$name), charToRaw(name)),
            g7_sha(file.path(path, "votes.snapshot")) == g7_sha(utf8_vote),
            identical(charToRaw(g7_json(file.path(path, "receipt.json"))$candidate$name), charToRaw(name)),
            identical(charToRaw(g7_json(file.path(path, "config.snapshot"))$candidate_selection[["1"]]$name),
                      charToRaw(name)),
            identical(stage(utf8_vote, utf8_cfg)$version, result$version),
            !result$data_ready, !result$inference_ready)
})
check("F03_decomposed_utf8_preserved", {
  decomposed <- "JOSE\u0301 DA CONCEIC\u0327A\u0303O"
  c <- config_utf8
  c$candidate_selection[["1"]]$name <- decomposed
  cp <- write_json(c, "config_decomposed.json")
  vp <- write_text(gsub("CANDIDATO", decomposed, readLines(vote), fixed = TRUE), "decomposed.csv")
  stopifnot(identical(charToRaw(stage(vp, cp)$candidate$name), charToRaw(decomposed)))
})
bytes <- readBin(utf8_vote, "raw", n = file.info(utf8_vote)$size)
invalid <- bytes
invalid[match(as.raw(0xc3), invalid)] <- as.raw(0xff)
invalid_file <- file.path(out, "invalid_utf8.csv")
writeBin(invalid, invalid_file)
check("F03_invalid_utf8_read", g7_read_votes(invalid_file), "Invalid UTF-8 CSV bytes")
check("F03_invalid_utf8_stage", stage(invalid_file, utf8_cfg), "Invalid UTF-8 CSV bytes")
nul <- bytes
nul[match(as.raw(0xc3), nul)] <- as.raw(0)
nul_file <- file.path(out, "embedded_nul.csv")
writeBin(nul, nul_file)
check("F03_nul_rejected", g7_read_votes(nul_file), "Invalid UTF-8 CSV: embedded NUL")
check("F01_dates_correct_both_turns", {
  c <- g7_read_config(cfg)
  stopifnot(g7_election(ea11, c, 1L)$date == "02/10/2022",
            g7_election(ea11, c, 2L)$date == "30/10/2022")
})
for (turn in 1:2) {
  doc <- g7_json(ea11)
  doc$pl[[turn]]$dt <- if (turn == 1L) "03/10/2022" else "29/10/2022"
  path <- write_json(doc, paste0("wrong_date_t", turn, ".json"))
  check(paste0("F01_wrong_date_t", turn),
        g7_election(path, g7_read_config(cfg), turn), "EA11 date differs from configured turn date")
}
bad_cfg <- g7_json(cfg)
bad_cfg$election_dates[["2"]] <- "31/11/2022"
check("F01_invalid_config_date", g7_read_config(write_json(bad_cfg, "invalid_date_config.json")),
      "Invalid configured election dates")
bad_cfg$election_dates[["2"]] <- NULL
check("F01_missing_config_date", g7_read_config(write_json(bad_cfg, "missing_date_config.json")),
      "Invalid configured election dates")
check("F01_2026_calendar_conditional_not_occurrence", {
  c <- g7_read_config("config/mebane/2026/intake.json")
  stopifnot(c$election_dates[["1"]] == "04/10/2026", c$election_dates[["2"]] == "25/10/2026",
            c$calendar_source$turn_2_date_is_conditional,
            is.null(c$candidate_selection[["1"]]), is.null(c$candidate_selection[["2"]]))
  doc <- g7_json(ea11)
  doc$pl <- doc$pl[1L]
  doc$pl[[1L]]$cd <- "3220"
  doc$pl[[1L]]$dt <- "04/10/2026"
  doc$pl[[1L]]$e[[1L]]$cd <- "6257"
  path <- write_json(doc, "documented_2026_T1_config.json")
  stopifnot(g7_election(path, c, 1L)$election == 6257L)
  error <- tryCatch({g7_election(path, c, 2L); "accepted"}, error = conditionMessage)
  stopifnot(grepl("not unique", error, fixed = TRUE))
})
check("F02_declared_fixture_scope_receipt", {
  result <- stage()
  v <- result$validation
  stopifnot(v$reference_complete, is.null(v$complete), !v$national_coverage_attested,
            identical(v$territorial_scope$expected_ufs, list("SP")),
            v$territorial_scope$coverage_basis == "supplied_EA16_principal_sections",
            v$by_uf[[1L]]$reference_sections == 2L, v$by_uf[[1L]]$observed_sections == 2L,
            !result$data_ready, !result$inference_ready)
})
one_ref <- g7_json(ea16)
one_ref$abr[[1L]]$mu[[1L]]$zon[[1L]]$sec <- one_ref$abr[[1L]]$mu[[1L]]$zon[[1L]]$sec[1L]
one_ref_path <- write_json(one_ref, "one_section_ea16.json")
one_vote <- write_text(readLines(vote)[1:2], "one_section.csv")
one_control <- g7_json(control)
one_control$sections <- 1L
one_control$aptos <- 10L
one_control$turnout <- 5L
one_control$candidate_votes <- 3L
one_control$blank <- 1L
one_control$null <- 1L
one_control_path <- write_json(one_control, "one_section_controls.json")
check("F02_one_section_reference_not_national", {
  result <- stage(one_vote, refs = one_ref_path, totals = one_control_path)
  stopifnot(result$validation$reference_complete, !result$validation$national_coverage_attested,
            result$validation$expected_sections == 1L,
            !result$data_ready, !result$inference_ready)
})
multi <- g7_json(cfg)
multi$territorial_scope$expected_ufs <- list("AM", "SP")
multi_path <- write_json(multi, "multi_uf_config.json")
check("F02_missing_reference_uf", stage(c = multi_path), "EA16 missing configured UFs")
other <- g7_json(ea16)
other$abr[[1L]]$cd <- "am"
other_path <- write_json(other, "other_uf_ea16.json")
check("F02_extra_reference_uf", stage(refs = c(ea16, other_path)), "EA16 unexpected UFs")
totals <- g7_json(control)
totals$sections <- 4L
totals_path <- write_json(totals, "multi_uf_controls.json")
check("F02_missing_votes_per_uf", {
  result <- stage(c = multi_path, refs = c(ea16, other_path), totals = totals_path)
  am <- result$validation$by_uf[[1L]]
  stopifnot(!result$validation$reference_complete,
            result$validation$status == "incomplete_coverage", am$uf == "AM",
            am$reference_sections == 2L, am$observed_sections == 0L, am$missing_sections == 2L)
})
extra_vote <- write_text(sub(",SP,", ",AM,", readLines(vote), fixed = TRUE), "extra_uf_votes.csv")
check("F02_extra_vote_uf", stage(extra_vote), "Unexpected section outside independent EA16")
check("F02_receipt_scope_tamper_rejected", {
  result <- stage()
  path <- file.path(store, "2022", "turn1", result$version, "receipt.json")
  original <- readBin(path, "raw", n = file.info(path)$size)
  altered <- g7_json(path)
  altered$validation$national_coverage_attested <- TRUE
  Sys.chmod(path, "0644")
  jsonlite::write_json(altered, path, auto_unbox = TRUE, pretty = TRUE)
  message <- tryCatch({stage(); "accepted"}, error = conditionMessage)
  writeBin(original, path)
  Sys.chmod(path, "0444")
  stopifnot(grepl("Staged receipt differs", message, fixed = TRUE))
})
check("locale_unchanged", stopifnot(identical(Sys.getlocale(), locale_before)))
passed <- all(vapply(records, function(x) x$passed, logical(1)))
write_json(list(status = if (passed) "PASS" else "FAIL", locale_before = locale_before,
                locale_after = Sys.getlocale(), locale_ctype = Sys.getlocale("LC_CTYPE"),
                locale_environment = as.list(Sys.getenv(c("LANG", "LC_ALL", "LC_CTYPE"))),
                candidate_utf8_hex = paste(format(charToRaw(name)), collapse = ""),
                R = R.version.string,
                package_versions = lapply(c("jsonlite", "digest"), function(p) as.character(packageVersion(p))),
                cases = records), "repair_results.json")
if (!passed) stop("Repair regression failures: ", paste(vapply(records[!vapply(records,
             function(x) x$passed, logical(1))], function(x) x$id, character(1)), collapse = ", "))
cat("Round2 repairs PASS:", length(records), "cases; LC_CTYPE=", Sys.getlocale("LC_CTYPE"), "\n")
