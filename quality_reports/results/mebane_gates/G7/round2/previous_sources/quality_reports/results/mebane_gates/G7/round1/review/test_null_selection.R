#!/usr/bin/env Rscript
# Exact 2026 null-selection guard probe. The output directory must be new.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L || dir.exists(args[[1L]])) stop("Pass one new review output directory")
out <- args[[1L]]
review <- "quality_reports/results/mebane_gates/G7/round1/review/"
if (!startsWith(out, review)) stop("Output must stay in review")
dir.create(out, recursive = TRUE)
source("R/lib/mebane_2026_intake.R")
fixture <- "tests/mebane/2026/fixtures/"
paths <- setNames(file.path(out, c("votes.csv", "ea11.json", "ea16.json", "controls.json", "config.json")),
                  c("votes", "ea11", "ea16", "controls", "config"))
orig <- c(paste0(fixture, "votes_t1_2022.csv"), paste0(fixture, "ea11_2022.json"),
          paste0(fixture, "ea16_t1_2022.json"), paste0(fixture, "controls_t1_2022.json"),
          "config/mebane/2026/intake.json")
stopifnot(all(file.copy(orig, paths)))
ea11 <- g7_json(paths[["ea11"]])
ea11$pl <- ea11$pl[1]
ea11$pl[[1]]$cd <- "3220"
ea11$pl[[1]]$dt <- "04/10/2026"
ea11$pl[[1]]$e[[1]]$cd <- "6257"
jsonlite::write_json(ea11, paths[["ea11"]], auto_unbox = TRUE)
ea16 <- g7_json(paths[["ea16"]])
ea16$cdp <- "3220"
jsonlite::write_json(ea16, paths[["ea16"]], auto_unbox = TRUE)
votes <- readLines(paths[["votes"]], warn = FALSE)
votes <- sub("^2022,1,544,544,1,", "2026,1,3220,6257,1,", votes)
writeLines(votes, paths[["votes"]], useBytes = TRUE)
controls <- g7_json(paths[["controls"]])
controls$year <- 2026L
controls$pleito <- 3220L
controls$election <- 6257L
jsonlite::write_json(controls, paths[["controls"]], auto_unbox = TRUE)
cfg <- g7_read_config(paths[["config"]])
identity <- g7_election(paths[["ea11"]], cfg, 1L)
sections <- g7_sections(paths[["ea16"]], identity$pleito, identity$phase)
v <- g7_read_votes(paths[["votes"]])
stopifnot(cfg$year == 2026L, cfg$cargo == 1L, is.null(cfg$candidate_selection[["1"]]),
          identity$pleito == 3220L, identity$election == 6257L,
          identity$date == "04/10/2026", identity$phase == "s", length(sections) == 2L,
          all(v$year == 2026), all(v$turn == 1), all(v$pleito == 3220),
          all(v$election == 6257), all(v$cargo == 1))
expected <- "Candidate selection unresolved for turn"
at_validate <- tryCatch({g7_validate(v, cfg, identity, sections, 1L); "accepted"},
                        error = function(e) conditionMessage(e))
at_stage <- tryCatch({g7_stage(paths[["votes"]], paths[["ea11"]], paths[["ea16"]],
                      paths[["controls"]], paths[["config"]], file.path(out, "store"), 1L);
                      "accepted"}, error = function(e) conditionMessage(e))
log <- list(case = "2026_null_candidate_selection", year = 2026L, date = identity$date,
            pleito = identity$pleito, election = identity$election, cargo = cfg$cargo,
            sections = length(sections), input_hashes = as.list(vapply(paths, g7_sha, character(1))),
            expected_error = expected, at_validate = at_validate, at_stage = at_stage,
            pass = identical(at_validate, expected) && identical(at_stage, expected))
jsonlite::write_json(log, file.path(out, "result.json"), auto_unbox = TRUE, pretty = TRUE)
cat(jsonlite::toJSON(log[c("case", "expected_error", "at_validate", "at_stage", "pass")],
                     auto_unbox = TRUE), "\n")
if (!log$pass) quit(status = 1L)
