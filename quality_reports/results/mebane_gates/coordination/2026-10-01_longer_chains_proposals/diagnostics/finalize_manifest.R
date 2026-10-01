#!/usr/bin/env Rscript
# Inventory this proposal only; no sampler, compilation, or model edits.
options(scipen = 999)
local_lib <- "renv/library/macos/R-4.4/aarch64-apple-darwin20"
if (dir.exists(local_lib)) .libPaths(c(local_lib, .libPaths()))
stopifnot(requireNamespace("jsonlite", quietly = TRUE),
          requireNamespace("digest", quietly = TRUE))
own <- "quality_reports/results/mebane_gates/coordination/2026-10-01_longer_chains_proposals/diagnostics"
manifest_path <- file.path(own, "candidate_manifest.json")
hashes_path <- file.path(own, "artifact_hashes.csv")
stopifnot(!file.exists(manifest_path), !file.exists(hashes_path))
sha <- function(p) digest::digest(file = p, algo = "sha256", serialize = FALSE)
read_csv <- function(p) read.csv(file.path(own, p), check.names = FALSE)
global <- read_csv("analysis01/global_rankings.csv")
checks <- read_csv("analysis01/focused_metric_checks.csv")
all_old <- read_csv("analysis01/all_target_rankings.csv")
all_new <- read_csv("addenda02/all_target_rankings_corrected.csv")
metric_cols <- c("target", "run", "rhat", "ess_bulk", "ess_tail", "mean", "sd",
                 "q025", "q50", "q975", "mandatory", "diagnostic_pass")
stopifnot(identical(all_old[, metric_cols], all_new[, metric_cols]),
          nrow(global) == 69L, nrow(checks) == 78L, all(checks$metrics_match),
          all(checks$thinning == 1L), all(checks$chains == 4L))
shapes <- jsonlite::read_json(file.path(own, "analysis01/draw_shapes.json"))
stopifnot(all(vapply(shapes, function(x) x$chains == 4L, logical(1))))
payload <- read_csv("addenda02/resource_payload_addendum.csv")
stopifnot(identical(payload$numeric_payload_bytes,
                   c(6016000000, 4643200000, 232160000, 782400000)),
          !any(payload$is_peak_RSS_or_total_RAM))
files <- list.files(own, recursive = TRUE, full.names = TRUE, all.files = TRUE,
                    no.. = TRUE)
files <- sort(files[!file.info(files)$isdir])
stopifnot(all(startsWith(files, paste0(own, "/"))))
inventory <- data.frame(path = substring(files, nchar(own) + 2L),
  bytes = unname(file.info(files)$size),
  sha256 = vapply(files, sha, character(1)), stringsAsFactors = FALSE)
write.csv(inventory, hashes_path, row.names = FALSE)
canonical <- c("diagnostic_proposal.md", "handoff.md", "analysis01/global_rankings.csv",
  "addenda02/all_target_rankings_corrected.csv", "addenda02/grouped_diagnostics_corrected.csv",
  "analysis01/rare_class_diagnostics.csv", "analysis01/within_chain_summaries.csv",
  "analysis01/focused_metric_checks.csv", "analysis01/focused_traces.pdf",
  "addenda02/proposed_protocol.csv", "addenda02/resource_payload_addendum.csv")
stopifnot(all(canonical %in% inventory$path),
          length(list.files(file.path(own, "trace_preview"), pattern = "[.]png$")) == 6L)
manifest <- list(created_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
  status = "diagnostic_and_protocol_candidate_requires_user_confirmation",
  scope = normalizePath(own), new_sampling = FALSE, prior_change = FALSE,
  compilation = FALSE, installation = FALSE, deletion = FALSE,
  independent_QA_by_executor = FALSE,
  coordinator_reported_check = "69 globals / 897 cells agree with reviewed tables; user message",
  executor_checks = list(global_rows = nrow(global), focused_metric_matches = nrow(checks),
    original_metrics_and_decisions_unchanged = TRUE, thinning = 1L,
    class_aware_iteration_chain_shape = TRUE,
    trace_PDF_pages_rendered_and_visually_inspected = 6L,
    resource_payload_arithmetic_checked = TRUE),
  verification_limits = c("Local/NCP metrics reused from valid existing diagnostics",
    "No peak-RAM or parallel-speedup measurement", "No independent review of this proposal claimed"),
  canonical_files = canonical,
  input_manifests = c("analysis01/input_manifest.json", "addenda02/input_rechecks.csv"),
  superseded_annotations = c("analysis01/all_target_rankings.csv",
                            "analysis01/grouped_diagnostics.csv"),
  preserved_failed_attempt = list(directory = "addenda01", script = "prepare_addenda.R",
    cause = "Integer overflow caught by payload assertion before writing resource payload",
    replacement = "prepare_addenda_v2.R and addenda02"),
  inventory = list(path = "artifact_hashes.csv", sha256 = sha(hashes_path),
    files = nrow(inventory), note = "Contains all existing files in this scope except manifest and inventory itself"),
  key_hashes = inventory[inventory$path %in% canonical, ])
jsonlite::write_json(manifest, manifest_path, pretty = TRUE, auto_unbox = TRUE,
                     digits = NA, na = "null")
stopifnot(all(vapply(files, sha, character(1)) == inventory$sha256))
cat("Manifest SHA256: ", sha(manifest_path), "\n", sep = "")
print(inventory[inventory$path %in% canonical, c("path", "sha256")], row.names = FALSE)
