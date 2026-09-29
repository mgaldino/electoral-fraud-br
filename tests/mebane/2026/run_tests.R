source("R/lib/mebane_2026_intake.R")
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L || dir.exists(args[[1L]])) stop("Pass one new output directory")
out <- args[[1L]]
dir.create(out, recursive = TRUE)
fixture <- "tests/mebane/2026/fixtures"
f <- function(name) file.path(fixture, name)
cfg <- f("config2022.json")
ea11 <- f("ea11_2022.json")
ea16_1 <- f("ea16_t1_2022.json")
ea16_2 <- f("ea16_t2_2022.json")
control1 <- f("controls_t1_2022.json")
control2 <- f("controls_t2_2022.json")
vote1 <- f("votes_t1_2022.csv")
vote2 <- f("votes_t2_2022.csv")
store <- file.path(out, "store")
g1_config_hash <- g7_sha("config/mebane/2022.json")
g1_fixture_hash <- g7_sha("tests/mebane/data/test_g1.R")
negative <- function(expr, pattern) {
  message <- tryCatch({force(expr); NULL}, error = function(e) conditionMessage(e))
  if (is.null(message) || !grepl(pattern, message, fixed = TRUE))
    stop("Expected error: ", pattern, "; got: ", message)
}
stopifnot(g7_doc_int("000544", "test") == 544L)
for (invalid in list("1.5", "-1", "2147483648", c("1", "2"), NA_character_,
                     1L, NULL))
  negative(g7_doc_int(invalid, "test"), "Invalid documented code")
stage <- function(vote, reference = ea16_1, controls = control1, turn = 1L,
                  config = cfg, election = ea11, provenance = "fixture", source_url = NULL) {
  g7_stage(vote, election, reference, controls, config, store, turn,
           provenance, source_url)
}
first <- stage(vote1)
stopifnot(first$validation$status == "staging_validated", !first$data_ready,
          !first$inference_ready, first$validation$expected_sections == 2L)
same <- stage(vote1)
stopifnot(identical(first$version, same$version))
first_snapshot <- file.path(store, "2022", "turn1", first$version, "votes.snapshot")
first_hash <- g7_sha(first_snapshot)
receipt_path <- file.path(dirname(first_snapshot), "receipt.json")
receipt_backup <- file.path(out, "receipt_original.json")
stopifnot(file.copy(receipt_path, receipt_backup))
receipt_hash <- g7_sha(receipt_path)
for (field in c("validation", "data_ready", "inference_ready", "year", "turn", "version")) {
  forged <- g7_json(receipt_backup)
  if (field == "validation") forged$validation$reference_complete <- FALSE
  if (field == "data_ready") forged$data_ready <- TRUE
  if (field == "inference_ready") forged$inference_ready <- TRUE
  if (field == "year") forged$year <- 2026L
  if (field == "turn") forged$turn <- 2L
  if (field == "version") forged$version <- paste0("forged-", first$version)
  Sys.chmod(receipt_path, "0644")
  jsonlite::write_json(forged, receipt_path, auto_unbox = TRUE, pretty = TRUE)
  negative(stage(vote1), "Staged receipt differs from recomputed validation or policy")
  stopifnot(file.copy(receipt_backup, receipt_path, overwrite = TRUE))
  Sys.chmod(receipt_path, "0444")
  stopifnot(g7_sha(receipt_path) == receipt_hash)
}
old_policy <- g7_policy_version
g7_policy_version <- "g7-intake-v2-policy-change-test"
changed_policy <- stage(vote1)
stopifnot(changed_policy$version != first$version,
          changed_policy$policy_sha256 != first$policy_sha256)
g7_policy_version <- old_policy
stopifnot(stage(vote1)$version == first$version,
          g7_sha(receipt_path) == receipt_hash)
revision <- file.path(out, "revision.csv")
lines <- readLines(vote1)
lines[[2L]] <- sub(",3,10,5,1,1$", ",4,10,5,0,1", lines[[2L]])
writeLines(lines, revision)
revised_controls <- file.path(out, "revised_controls.json")
control <- g7_json(control1)
control$candidate_votes <- 6L
control$blank <- 1L
jsonlite::write_json(control, revised_controls, auto_unbox = TRUE)
second <- stage(revision, controls = revised_controls)
stopifnot(second$version != first$version, file.exists(first_snapshot),
          g7_sha(first_snapshot) == first_hash,
          second$validation$status == "staging_validated")
partial_file <- file.path(out, "partial.csv")
writeLines(readLines(vote1)[1:2], partial_file)
partial <- stage(partial_file)
stopifnot(partial$validation$status == "incomplete_coverage",
          !partial$validation$controls_pass, !partial$data_ready)
other_uf <- file.path(out, "ea16_other_uf.json")
writeLines(sub('"cd":"sp"', '"cd":"am"', readLines(ea16_1), fixed = TRUE), other_uf)
multi_uf_controls <- file.path(out, "multi_uf_controls.json")
control_multi <- g7_json(control1)
control_multi$sections <- 4L
jsonlite::write_json(control_multi, multi_uf_controls, auto_unbox = TRUE)
multi_uf_config <- file.path(out, "multi_uf_config.json")
cfg_multi <- g7_json(cfg)
cfg_multi$territorial_scope$expected_ufs <- list("SP", "AM")
jsonlite::write_json(cfg_multi, multi_uf_config, auto_unbox = TRUE)
multi_uf <- stage(vote1, reference = c(ea16_1, other_uf), controls = multi_uf_controls,
                  config = multi_uf_config)
stopifnot(multi_uf$validation$status == "incomplete_coverage",
          multi_uf$validation$expected_sections == 4L)
copied_uf <- file.path(out, "ea16_duplicate.json")
file.copy(ea16_1, copied_uf)
negative(stage(vote1, reference = c(ea16_1, copied_uf)),
         "Duplicate section across EA16 references")
wrong_schema <- file.path(out, "schema_changed.csv")
writeLines(sub("candidate_code", "number", readLines(vote1), fixed = TRUE), wrong_schema)
negative(stage(wrong_schema), "Unknown normalized CSV schema")
bad_ea11 <- file.path(out, "ea11_bad_fraction.json")
writeLines(sub('"cd":"1"', '"cd":"1.5"', readLines(ea11), fixed = TRUE), bad_ea11)
negative(stage(vote1, election = bad_ea11), "Invalid documented code EA11 cp.cd")
bad_ea16 <- file.path(out, "ea16_bad_vector.json")
writeLines(sub('"cdp":"544"', '"cdp":["544","545"]', readLines(ea16_1), fixed = TRUE),
           bad_ea16)
negative(stage(vote1, reference = bad_ea16), "Invalid documented code EA16 cdp")
bad_section <- file.path(out, "ea16_bad_section.json")
writeLines(sub('"ns":"0001"', '"ns":"1"', readLines(ea16_1), fixed = TRUE), bad_section)
negative(stage(vote1, reference = bad_section), "Invalid EA16 section")
bad_controls <- file.path(out, "bad_controls.json")
bad <- g7_json(control1)
bad$candidate_votes <- 99L
jsonlite::write_json(bad, bad_controls, auto_unbox = TRUE)
failed_control <- stage(vote1, controls = bad_controls)
stopifnot(failed_control$validation$status == "control_mismatch", !failed_control$data_ready)
conflict <- file.path(out, "candidate_conflict.csv")
writeLines(sub(",22,CANDIDATO,", ",13,CANDIDATO,", readLines(vote1), fixed = TRUE), conflict)
negative(stage(conflict), "Candidate code/name conflict")
wrong_turn <- file.path(out, "wrong_turn.csv")
writeLines(sub("2022,1,", "2022,2,", readLines(vote1), fixed = TRUE), wrong_turn)
negative(stage(wrong_turn), "Election scope mismatch turn")
negative(stage(vote1, provenance = "official", source_url = "https://resultados.tse.jus.br/test"),
         "Official provenance requires official phase")
official_label_ea11 <- file.path(out, "ea11_official_label.json")
official_label_ea16 <- file.path(out, "ea16_official_label.json")
writeLines(sub('"f":"s"', '"f":"o"', readLines(ea11), fixed = TRUE), official_label_ea11)
writeLines(sub('"f":"s"', '"f":"o"', readLines(ea16_1), fixed = TRUE), official_label_ea16)
label_only <- stage(vote1, reference = official_label_ea16, election = official_label_ea11,
                    provenance = "official", source_url = "https://resultados.tse.jus.br/fixture")
stopifnot(!label_only$data_ready, !label_only$inference_ready)
second_turn <- stage(vote2, reference = ea16_2, controls = control2, turn = 2L)
stopifnot(second_turn$validation$status == "staging_validated",
          file.exists(file.path(store, "2022", "turn2", second_turn$version, "votes.snapshot")))
negative(stage(vote1, config = "config/mebane/2026/intake.json"), "EA11 identity/date invalid")
for (state in c("waiting_external", "inconclusive")) {
  route <- g7_gate_route("pass", "pass", "pass", state)
  stopifnot(route$g9 == state, route$example_only, !route$records_verified)
}
negative(g7_gate_route("queued", "pass", "pass", "waiting_external"), "Invalid gate route")
negative(g7_gate_route("pass", "queued", "pass", "inconclusive"), "Invalid gate route")
negative(g7_gate_route("queued", "pass", "pass", "pass"), "Invalid gate route")
negative(g7_gate_route("pass", "pass", "pass", "not_applicable"),
         "independent official non-occurrence")
stopifnot(g7_gate_route("pass", "pass", "pass", "not_applicable", "not_held", TRUE)$t2_applicability ==
            "officially_not_held")
stopifnot(!g7_gate_route("pass", "pass", "pass", "waiting_external")$records_verified)
stopifnot(g7_sha("config/mebane/2022.json") == g1_config_hash,
          g7_sha("tests/mebane/data/test_g1.R") == g1_fixture_hash)
summary <- list(status = "PASS", fixture = "2022-derived synthetic only",
                assertions = c("idempotence", "immutable_revision", "partial_coverage",
                               "receipt_tamper_all_state_fields", "policy_change_new_version",
                               "multi_uf_EA16", "duplicate_EA16", "documented_string_codes",
                               "invalid_documented_codes", "zero_padded_section_keys", "unknown_schema",
                               "control_mismatch", "candidate_conflict", "scope",
                               "simulated_not_official", "official_label_not_authorization",
                               "year_turn_isolation",
                               "t2_nonoccurrence_attestation", "G6_inference_gate"),
                original_version = first$version, revised_version = second$version,
                turn2_version = second_turn$version,
                preserved_2022 = list(config_sha256 = g1_config_hash,
                                      fixture_sha256 = g1_fixture_hash))
jsonlite::write_json(summary, file.path(out, "test_summary.json"), auto_unbox = TRUE, pretty = TRUE)
cat("G7 rehearsal PASS\n")
