# Bounded contract delta checks; no model enumeration, compilation or MCMC.
args <- commandArgs(trailingOnly = TRUE)
root <- normalizePath(if (length(args)) args[[1]] else ".", mustWork = TRUE)
base <- "quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study"
out <- file.path(root, base, "review_contract")
.libPaths(c(file.path(root, "renv/library/macos/R-4.4/aarch64-apple-darwin20"), .libPaths()))
stopifnot(!file.exists(file.path(out, "delta_checks_v2.json")),
          !file.exists(file.path(out, "delta_checks_v2.log")))
sink(file.path(out, "delta_checks_v2.log"), split = TRUE)
started <- format(Sys.time(), tz = "UTC", usetz = TRUE)
read <- function(p) jsonlite::fromJSON(file.path(root, p), simplifyVector = FALSE)
sha <- function(p) digest::digest(file = file.path(root, p), algo = "sha256")
v1p <- file.path(base, "contract_v1.json")
v2p <- file.path(base, "contract_v2.json")
v1 <- read(v1p); v2 <- read(v2p)
v1hash <- "8f0783b5f3520958a2b1a6d6de5bb217e2ea4ac8656a6ac114024b9d6a95dc17"
v2hash <- "d17b7f508a7ce87eec3ca71ed7df67666b528c755e005ec9e1299e5ff9deb509"
stopifnot(sha(v1p) == v1hash, sha(v2p) == v2hash,
          v2$supersedes$sha256 == v1hash,
          Sys.getenv("CODEX_THREAD_ID") == "01a0f4b8-962b-77a3-a418-6247c6219e8b")
adjudication_path <- file.path(base, "contract_adjudication_v1.json")
adj <- read(adjudication_path)
stopifnot(adj$source$sha256 == v1hash, adj$findings[[1]]$status == "CONFIRMED",
          adj$findings[[1]]$finding_id == "AD-CONTRACT-QA-01",
          sha(adj$review_sources[[1]]$path) == adj$review_sources[[1]]$sha256)
previous <- read(file.path(base, "review_contract/delivery_manifest.json"))
stopifnot(all(vapply(previous$files, function(x) sha(x$path) == x$sha256, logical(1))))
changes <- character()
walk <- function(a, b, path = "") {
  if (identical(a, b)) return(invisible(NULL))
  if (is.list(a) && is.list(b) && !is.null(names(a)) && !is.null(names(b))) {
    for (key in union(names(a), names(b))) {
      p <- paste0(path, "/", key)
      if (!(key %in% names(a)) || !(key %in% names(b))) {
        changes <<- c(changes, p)
      } else walk(a[[key]], b[[key]], p)
    }
  } else changes <<- c(changes, path)
}
walk(v1, v2)
allowed <- c("/contract_id", "/paired_design/initialization/A_auxiliary_counts",
             "/paired_design/execution", "/diagnostics/discrete", "/diagnostics/verdict",
             "/diagnostics/analytic_exemptions_in_empirical_pilot", "/diagnostics/decision_table",
             "/preflight_tests/checks", "/checkpoints", "/supersedes")
stopifnot(setequal(changes, allowed), identical(v1$A, v2$A), identical(v1$D, v2$D),
          identical(v1$case, v2$case), identical(v1$comparison, v2$comparison),
          identical(v1$monitoring, v2$monitoring),
          identical(v1$preflight_tests$checks, head(v2$preflight_tests$checks, -1)),
          identical(v1$checkpoints[-1], v2$checkpoints[-1]))
table <- v2$diagnostics$decision_table
stopifnot(length(table) == 5, length(v2$diagnostics$analytic_exemptions_in_empirical_pilot) == 0)
for (i in 1:4) {
  stopifnot(isTRUE(table[[i]]$mandatory), table[[i]]$thresholds$rhat_lt == 1.01,
            table[[i]]$thresholds$ess_bulk_ge == 400,
            table[[i]]$thresholds$ess_tail_ge == 400,
            grepl("computationally_inconclusive", table[[i]]$on_undefined_or_failure, fixed = TRUE))
}
stopifnot(!table[[5]]$mandatory,
          table[[3]]$thresholds$between_chain_mean_range_le == .05,
          grepl("counts divided by n", table[[3]]$thresholds$range_scale, fixed = TRUE),
          grepl("sample-only constant", table[[3]]$on_undefined_or_failure, fixed = TRUE),
          grepl("cannot rescue", table[[5]]$on_undefined_or_failure, fixed = TRUE))

# Truth-table fixtures for the contract rule, not the future diagnostic implementation.
class_rule <- function(rhat = 1.009, bulk = 400, tail = 400, range = .05,
                       n = 143, counts = FALSE, sample_constant = FALSE,
                       complete = TRUE, adapted = TRUE, secondary_support = TRUE) {
  if (counts) range <- range / n
  values <- c(rhat, bulk, tail, range)
  if (sample_constant || length(values) != 4 || any(!is.finite(values)) ||
      !complete || !adapted || !secondary_support) return("computationally_inconclusive")
  if (rhat < 1.01 && bulk >= 400 && tail >= 400 && range <= .05) "eligible_row_pass" else "computationally_inconclusive"
}
fixtures <- list(
  inclusive_ESS_and_range_boundary = class_rule(),
  rhat_boundary_fails = class_rule(rhat = 1.01),
  bulk_below_boundary = class_rule(bulk = 399),
  tail_below_boundary = class_rule(tail = 399),
  range_above_ceiling = class_rule(range = .050001),
  counts_scaled_below_ceiling = class_rule(range = 7, counts = TRUE),
  counts_scaled_above_ceiling = class_rule(range = 8, counts = TRUE),
  required_NA = class_rule(tail = NA_real_),
  required_missing = class_rule(tail = numeric()),
  nonfinite = class_rule(rhat = Inf),
  sample_constant = class_rule(sample_constant = TRUE),
  incomplete_run = class_rule(complete = FALSE),
  inadequate_adaptation = class_rule(adapted = FALSE),
  secondary_support_defect = class_rule(secondary_support = FALSE))
expected_pass <- c("inclusive_ESS_and_range_boundary", "counts_scaled_below_ceiling")
stopifnot(identical(names(fixtures)[unlist(fixtures) == "eligible_row_pass"], expected_pass))
n <- v2$case$rows
source_paths <- c(v1p, v2p, adjudication_path,
                  file.path(base, "review_contract/review.json"),
                  file.path(base, "review_contract/review.md"),
                  file.path(base, "review_contract/delivery_manifest.json"))
source_hashes <- lapply(source_paths, function(p) list(path = p, sha256 = sha(p)))
result <- list(schema_version = "1.0-independent-delta-checks", started_at_utc = started,
               finished_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
               reviewer_id = Sys.getenv("CODEX_THREAD_ID"),
               executor_id = "019d795a-acfa-72c2-a210-d55a46c606c2",
               contract_sha256 = v2hash, status = "pass_bounded_delta_checks",
               semantic_changes = as.list(changes), undeclared_changes = list(),
               previous_manifest_files_intact = length(previous$files),
               expected_mandatory_targets = list(A = 23 + 8*n + 3*n + 3 + 4*n,
                                                   D = 23 + 9*n + 3*n + 3),
               decision_fixtures = fixtures, source_hashes = source_hashes,
               script_sha256 = sha(file.path(base, "review_contract/check_delta_v2.R")),
               mathematical_enumeration_repeated = FALSE, MCMC = FALSE,
               future_implementation_reviewed = FALSE,
               command = paste("env LC_ALL=C LANG=C Rscript --vanilla",
                               file.path(base, "review_contract/check_delta_v2.R"), root))
jsonlite::write_json(result, file.path(out, "delta_checks_v2.json"), pretty = TRUE, auto_unbox = TRUE)
cat("PASS bounded delta:", length(changes), "declared changed paths;",
    length(fixtures), "decision fixtures;", length(previous$files), "prior delivery files intact.\n")
cat("Expected mandatory scalar targets: A", result$expected_mandatory_targets$A,
    "D", result$expected_mandatory_targets$D, "\n")
print(source_hashes)
print(sessionInfo())
sink()
