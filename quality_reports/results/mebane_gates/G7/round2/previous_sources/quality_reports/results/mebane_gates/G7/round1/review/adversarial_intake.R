#!/usr/bin/env Rscript
# Independent G7 probes; writes only beneath this script's review directory.
review <- Sys.getenv("G7_QA_DIR", unset = "quality_reports/results/mebane_gates/G7/round1/review")
prefix <- "quality_reports/results/mebane_gates/G7/round1/review"
if (!(identical(review, prefix) || startsWith(review, paste0(prefix, "/"))))
  stop("G7_QA_DIR must stay within review")
fixtures <- "tests/mebane/2026/fixtures"
source("R/lib/mebane_2026_intake.R")
if (dir.exists(file.path(review, "scratch"))) stop("Existing QA scratch must be preserved; select a new G7_QA_DIR")
dir.create(file.path(review, "scratch"), recursive = TRUE, showWarnings = FALSE)
results <- list()
record <- function(name, expected, value, error = "") {
  results[[length(results) + 1L]] <<- list(case = name, expected = expected,
    observed = value, error = error, pass = identical(expected, value))
}
setup <- function(name) {
  dir <- file.path(review, "scratch", name)
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  orig <- c("votes_t1_2022.csv", "ea11_2022.json", "ea16_t1_2022.json",
            "controls_t1_2022.json", "config2022.json")
  dest <- file.path(dir, c("votes.csv", "ea11.json", "ea16.json", "controls.json", "config.json"))
  stopifnot(all(file.copy(file.path(fixtures, orig), dest, overwrite = TRUE)))
  setNames(dest, c("votes", "ea11", "ea16", "controls", "config"))
}
edit_json <- function(path, fn) {
  x <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  x <- fn(x)
  jsonlite::write_json(x, path, auto_unbox = TRUE)
}
edit_csv <- function(path, fn) {
  x <- readLines(path, warn = FALSE)
  writeLines(fn(x), path, useBytes = TRUE)
}
stage <- function(p, name, store = file.path(review, "scratch", name, "store"),
                  provenance = "fixture", url = NULL, ea16 = p[["ea16"]]) {
  g7_stage(p[["votes"]], p[["ea11"]], ea16, p[["controls"]], p[["config"]],
           store, 1L, provenance, url)
}
probe <- function(name, mutate = function(p) NULL, expected = "error", provenance = "fixture",
                  url = NULL, ea16_fn = function(p) p[["ea16"]]) {
  p <- setup(name)
  mutate(p)
  outcome <- tryCatch({
    r <- stage(p, name, provenance = provenance, url = url, ea16 = ea16_fn(p))
    r$validation$status
  }, error = function(e) paste0("error: ", conditionMessage(e)))
  class <- if (startsWith(outcome, "error:")) "error" else outcome
  record(name, expected, class, if (class == "error") outcome else "")
  invisible(list(paths = p, outcome = outcome))
}

p <- setup("baseline")
r1 <- stage(p, "baseline")
r2 <- stage(p, "baseline")
record("clean_stage", "staging_validated", r1$validation$status)
record("idempotent", "same_version", if (identical(r1$version, r2$version)) "same_version" else "different")
record("simulated_not_ready", "false_false", paste(tolower(as.character(r1$data_ready)),
  tolower(as.character(r1$inference_ready)), sep = "_"))
old_sha <- g7_sha(file.path(review, "scratch/baseline/store/2022/turn1", r1$version, "votes.snapshot"))
edit_csv(p[["votes"]], function(x) sub(",3,10,5,1,1$", ",2,10,5,1,1", x))
edit_json(p[["controls"]], function(x) {x$candidate_votes <- 4L; x})
r3 <- stage(p, "baseline")
record("revision_new_version", "different", if (r3$version != r1$version) "different" else "same")
record("old_snapshot_preserved", "unchanged", if (old_sha == g7_sha(file.path(review,
  "scratch/baseline/store/2022/turn1", r1$version, "votes.snapshot"))) "unchanged" else "changed")
record("review_namespace", "isolated", if (startsWith(normalizePath(file.path(review, "scratch")),
  normalizePath(review))) "isolated" else "outside")

probe("partial_votes", function(p) edit_csv(p[["votes"]], function(x) x[-3L]), "incomplete_coverage")
probe("control_mismatch", function(p) edit_json(p[["controls"]], function(x) {x$turnout <- 8L; x}), "control_mismatch")
probe("unknown_schema", function(p) edit_csv(p[["votes"]], function(x) sub("candidate_name", "candidate_label", x)))
probe("wrong_year", function(p) edit_csv(p[["votes"]], function(x) sub("^2022", "2026", x)))
probe("wrong_turn", function(p) edit_csv(p[["votes"]], function(x) sub("^2022,1,", "2022,2,", x)))
probe("candidate_conflict", function(p) edit_csv(p[["votes"]], function(x) sub(",22,CANDIDATO,", ",13,CANDIDATO,", x)))
probe("missing_value", function(p) edit_csv(p[["votes"]], function(x) sub(",22,CANDIDATO,3,", ",22,,3,", x)))
probe("negative_votes", function(p) edit_csv(p[["votes"]], function(x) sub(",3,10,5,1,1$", ",-3,10,5,1,1", x)))
probe("fractional_votes", function(p) edit_csv(p[["votes"]], function(x) sub(",3,10,5,1,1$", ",3.5,10,5,1,1", x)))
probe("turnout_over_aptos", function(p) edit_csv(p[["votes"]], function(x) sub(",3,10,5,1,1$", ",3,10,11,1,1", x)))
probe("duplicate_row", function(p) edit_csv(p[["votes"]], function(x) c(x, x[2L])))
probe("lost_leading_zero", function(p) edit_csv(p[["votes"]], function(x) sub(",00001,0001,0001,", ",1,0001,0001,", x)))
probe("wrong_ea11_date_year", function(p) edit_json(p[["ea11"]], function(x) {x$pl[[1L]]$dt <- "02/10/2026"; x}))
probe("impossible_ea11_date", function(p) edit_json(p[["ea11"]], function(x) {x$pl[[1L]]$dt <- "31/02/2022"; x}))
probe("changed_ea11_date_same_year", function(p) edit_json(p[["ea11"]], function(x) {x$pl[[1L]]$dt <- "03/10/2022"; x}), "staging_validated")
probe("wrong_documented_pleito", function(p) edit_json(p[["ea11"]], function(x) {x$pl[[1L]]$cd <- "543"; x}))
probe("numeric_document_code", function(p) edit_json(p[["ea11"]], function(x) {x$pl[[1L]]$cd <- 544L; x}))
probe("fractional_document_code", function(p) edit_json(p[["ea11"]], function(x) {x$pl[[1L]]$cd <- "544.5"; x}))
probe("vector_document_code", function(p) edit_json(p[["ea11"]], function(x) {x$pl[[1L]]$cd <- list("544", "545"); x}))
probe("phase_mismatch", function(p) edit_json(p[["ea16"]], function(x) {x$f <- "o"; x}))
probe("bad_ea16_section", function(p) edit_json(p[["ea16"]], function(x) {x$abr[[1]]$mu[[1]]$zon[[1]]$sec[[1]]$ns <- "1"; x}))
probe("duplicate_ea16_files", expected = "error", ea16_fn = function(p) rep(p[["ea16"]], 2L))
probe("simulated_official_label", expected = "error", provenance = "official",
  url = "https://resultados.tse.jus.br/example")
probe("official_phase_forged", function(p) {
  edit_json(p[["ea11"]], function(x) {x$f <- "o"; x})
  edit_json(p[["ea16"]], function(x) {x$f <- "o"; x})
}, "staging_validated", "official", "https://resultados.tse.jus.br/example")
official <- jsonlite::fromJSON(file.path(review, "scratch/official_phase_forged/store/2022/turn1",
  list.files(file.path(review, "scratch/official_phase_forged/store/2022/turn1"))[1], "receipt.json"))
record("forged_official_not_ready", "false_false", paste(tolower(as.character(official$data_ready)),
  tolower(as.character(official$inference_ready)), sep = "_"))
probe("partial_ea16_scope", function(p) {
  edit_json(p[["ea16"]], function(x) {x$abr[[1]]$mu[[1]]$zon[[1]]$sec <- x$abr[[1]]$mu[[1]]$zon[[1]]$sec[1]; x})
  edit_csv(p[["votes"]], function(x) x[-3L])
  edit_json(p[["controls"]], function(x) {x$sections <- 1L; x$aptos <- 10L; x$turnout <- 5L;
    x$candidate_votes <- 3L; x$blank <- 1L; x$null <- 1L; x})
}, "staging_validated")
probe("unresolved_2026_selection", function(p) {
  stopifnot(file.copy("config/mebane/2026/intake.json", p[["config"]], overwrite = TRUE))
  edit_json(p[["ea11"]], function(x) {x$pl[[1]]$cd <- "3220"; x$pl[[1]]$dt <- "04/10/2026";
    x$pl[[1]]$e[[1]]$cd <- "6257"; x})
  edit_json(p[["ea16"]], function(x) {x$cdp <- "3220"; x})
  edit_csv(p[["votes"]], function(x) sub("^2022,1,544,544,", "2026,1,3220,6257,", x))
  edit_json(p[["controls"]], function(x) {x$year <- 2026L; x$pleito <- 3220L; x$election <- 6257L; x})
})

t2 <- setup("turn2")
stopifnot(file.copy(file.path(fixtures, c("votes_t2_2022.csv", "ea16_t2_2022.json",
  "controls_t2_2022.json")), t2[c("votes", "ea16", "controls")], overwrite = TRUE))
t2_receipt <- g7_stage(t2[["votes"]], t2[["ea11"]], t2[["ea16"]],
  t2[["controls"]], t2[["config"]], file.path(review, "scratch/turn2/store"), 2L)
record("turn2_separate_namespace", "2022/turn2", paste(t2_receipt$year,
  paste0("turn", t2_receipt$turn), sep = "/"))
record("turn2_not_ready", "false_false", paste(tolower(as.character(t2_receipt$data_ready)),
  tolower(as.character(t2_receipt$inference_ready)), sep = "_"))

# Recompute against altered stored metadata while the five input hashes remain intact.
for (field in c("validation", "data_ready", "inference_ready", "year", "version")) {
  q <- setup(paste0("receipt_", field))
  receipt <- stage(q, paste0("receipt_", field))
  path <- file.path(review, "scratch", paste0("receipt_", field), "store/2022/turn1",
                    receipt$version, "receipt.json")
  Sys.chmod(path, "0644")
  edit_json(path, function(x) {
    if (field == "validation") x$validation$observed_sections <- 99L
    if (field == "data_ready") x$data_ready <- TRUE
    if (field == "inference_ready") x$inference_ready <- TRUE
    if (field == "year") x$year <- 2026L
    if (field == "version") x$version <- "fake"
    x
  })
  observed <- tryCatch({stage(q, paste0("receipt_", field)); "accepted"},
    error = function(e) "error")
  record(paste0("tampered_receipt_", field), "error", observed)
}
q <- setup("snapshot_tamper")
receipt <- stage(q, "snapshot_tamper")
path <- file.path(review, "scratch/snapshot_tamper/store/2022/turn1", receipt$version, "votes.snapshot")
Sys.chmod(path, "0644")
writeLines("tampered", path)
record("tampered_snapshot", "error", tryCatch({stage(q, "snapshot_tamper"); "accepted"}, error = function(e) "error"))
q <- setup("policy_change")
a <- stage(q, "policy_change")
g7_policy_version <- paste0(g7_policy_version, "-qa-change")
b <- stage(q, "policy_change")
record("policy_changes_version", "different", if (a$version != b$version) "different" else "same")
g7_policy_version <- "g7-intake-v2"

route <- function(name, ..., expected = "error") {
  value <- tryCatch(g7_gate_route(...), error = function(e) NULL)
  observed <- if (is.null(value)) "error" else if (identical(value$example_only, TRUE) &&
    identical(value$records_verified, FALSE)) "example_only" else "authorized"
  record(name, expected, observed)
}
route("G8pass_G9waiting", "pass", "pass", "pass", "waiting_external", expected = "example_only")
route("G8pass_G9inconclusive", "pass", "pass", "pass", "inconclusive", expected = "example_only")
route("G6pending_route", "queued", "pass", "pass", "waiting_external")
route("G9NA_without_attestation", "pass", "pass", "pass", "not_applicable")
route("G9NA_attested_scenario", "pass", "pass", "pass", "not_applicable",
      t2_occurrence = "not_held", nonoccurrence_attested = TRUE, expected = "example_only")

concurrency <- list()
if (.Platform$OS.type == "unix") for (i in 1:8) {
  name <- paste0("concurrent_", i)
  pair <- setup(name)
  responses <- parallel::mclapply(1:2, function(j) tryCatch({
    stage(pair, name)
    "ok"
  }, error = function(e) paste0("error: ", conditionMessage(e))), mc.cores = 2L)
  replay <- tryCatch({stage(pair, name); "ok"}, error = function(e) paste0("error: ", conditionMessage(e)))
  concurrency[[i]] <- list(attempt = i, writers = unlist(responses), serial_replay = replay)
}
jsonlite::write_json(list(note = "Stress probe only; no cross-process lock or atomic directory transaction is implemented.",
  attempts = concurrency), file.path(review, "concurrency_probe.json"), auto_unbox = TRUE, pretty = TRUE)

jsonlite::write_json(list(cases = results, total = length(results),
  passed = sum(vapply(results, function(x) x$pass, logical(1)))),
  file.path(review, "adversarial_results.json"), auto_unbox = TRUE, pretty = TRUE)
cat("QA cases:", length(results), "matched:", sum(vapply(results, function(x) x$pass, logical(1))), "\n")
for (x in results) if (!x$pass) cat("FAIL", x$case, "expected", x$expected, "observed", x$observed, x$error, "\n")
if (!all(vapply(results, function(x) x$pass, logical(1)))) quit(status = 1L)
