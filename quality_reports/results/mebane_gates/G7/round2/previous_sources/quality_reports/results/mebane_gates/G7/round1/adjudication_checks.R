# Independent coordinator counterexamples for election date and coverage scope.
source("R/lib/mebane_2026_intake.R")
fixtures <- "tests/mebane/2026/fixtures"
out <- "quality_reports/results/mebane_gates/G7/round1/adjudication_checks.json"
scratch <- tempfile("g7-adjudication-")
dir.create(scratch)
ea11 <- g7_json(file.path(fixtures, "ea11_2022.json"))
ea11$pl[[1L]]$dt <- "03/10/2022"
wrong_date <- file.path(scratch, "wrong_date.json")
jsonlite::write_json(ea11, wrong_date, auto_unbox = TRUE)
baseline <- function(ea = file.path(fixtures, "ea11_2022.json"),
                     votes = file.path(fixtures, "votes_t1_2022.csv"),
                     sections = file.path(fixtures, "ea16_t1_2022.json"),
                     controls = file.path(fixtures, "controls_t1_2022.json"),
                     name = "baseline") {
  g7_stage(votes, ea, sections, controls, file.path(fixtures, "config2022.json"),
           file.path(scratch, name), 1L)
}
valid <- baseline()
date_result <- baseline(ea = wrong_date, name = "wrong_date")
ea16 <- g7_json(file.path(fixtures, "ea16_t1_2022.json"))
ea16$abr[[1L]]$mu[[1L]]$zon[[1L]]$sec <-
  ea16$abr[[1L]]$mu[[1L]]$zon[[1L]]$sec[1L]
section_path <- file.path(scratch, "one_section.json")
jsonlite::write_json(ea16, section_path, auto_unbox = TRUE)
lines <- readLines(file.path(fixtures, "votes_t1_2022.csv"))
vote_path <- file.path(scratch, "one_vote.csv")
writeLines(lines[1:2], vote_path)
control <- g7_json(file.path(fixtures, "controls_t1_2022.json"))
control$sections <- 1L
control$aptos <- 10L
control$turnout <- 5L
control$candidate_votes <- 3L
control$blank <- 1L
control$null <- 1L
control_path <- file.path(scratch, "one_control.json")
jsonlite::write_json(control, control_path, auto_unbox = TRUE)
small <- baseline(votes = vote_path, sections = section_path,
                  controls = control_path, name = "limited_scope")
record <- list(
  purpose = "Reproduce pre-repair defects, not approve the implementation",
  code_sha256 = g7_sha("R/lib/mebane_2026_intake.R"),
  baseline_status = valid$validation$status,
  wrong_date_status = date_result$validation$status,
  wrong_date_defect_confirmed = date_result$validation$status == "staging_validated",
  reduced_reference_validation = small$validation,
  reduced_reference_receipt_fields = names(small),
  national_approval_claimed = small$data_ready || small$inference_ready,
  reduced_reference_is_complete = small$validation$complete)
stopifnot(record$baseline_status == "staging_validated",
          record$wrong_date_defect_confirmed,
          record$reduced_reference_is_complete,
          !record$national_approval_claimed)
jsonlite::write_json(record, out, pretty = TRUE, auto_unbox = TRUE)
print(record)
unlink(scratch, recursive = TRUE)
