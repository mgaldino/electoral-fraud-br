# Synthetic adapter QA only. Run after an explicit test-window release.
stopifnot(Sys.getenv("STAN_REVIEW_TEST_WINDOW") == "OPEN")
root <- normalizePath(".", mustWork = TRUE)
review <- file.path(root, "quality_reports/results/mebane_gates/coordination/2026-10-01_ad_long_stan/review/stan")
.libPaths(c(file.path(root, "renv/library/macos/R-4.4/aarch64-apple-darwin20"), .libPaths()))
for (p in c("digest", "jsonlite", "posterior", "coda")) stopifnot(requireNamespace(p, quietly = TRUE))
source(file.path(review, "oracles.R"))
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 1L, basename(args[1]) == args[1])
out <- file.path(review, args[1])
stopifnot(!file.exists(out), dir.create(out))

run_checks <- function() {
  checks <- list()
  check <- function(name, code) {
    err <- tryCatch({ force(code); NULL }, error = function(e) conditionMessage(e))
    checks[[length(checks) + 1L]] <<- list(name = name, pass = is.null(err), error = err)
    cat(if (is.null(err)) "PASS" else "FAIL", name, if (!is.null(err)) err else "", "\n")
    invisible(is.null(err))
  }
  rejects <- function(code) stopifnot(inherits(tryCatch({force(code); NULL}, error = identity), "error"))
  sha <- function(path) digest::digest(file = path, algo = "sha256", serialize = FALSE)
  json_new <- function(x, path) {
    stopifnot(!file.exists(path))
    jsonlite::write_json(x, path, pretty = TRUE, auto_unbox = TRUE, digits = NA, na = "null")
  }
  records <- list()
  adapter_manifest <- file.path(root, "quality_reports/results/mebane_gates/coordination/2026-10-01_ad_long_stan/stan_diagnostic_candidate/manifest.json")
  expected_adapter_hash <- "3562d593731cec1fe156ee52266a975cd0cbf6d6fe8666c26b15652298bb08b0"
  stopifnot(sha(adapter_manifest) == expected_adapter_hash)
  frozen_adapter <- jsonlite::read_json(adapter_manifest)$files
  for (item in frozen_adapter) {
    stopifnot(sha(file.path(root, item$path)) == item$sha256,
              sha(file.path(root, item$snapshot)) == item$sha256)
  }
  on.exit({
    setwd(root)
    json_new(list(status = if (all(vapply(checks, `[[`, logical(1), "pass"))) "pass" else "needs_revision",
                  adapter_manifest_sha256 = expected_adapter_hash,
                  candidate_freeze_received = TRUE, target_preparation_pending = TRUE, empirical_MCMC = FALSE,
                  reviewer_id = "01a0f4b8-962b-77a3-a418-6247c6219e8b",
                  coordinator_id = "019d795a-acfa-72c2-a210-d55a46c606c2",
                  date_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
                  checks = checks, passed = sum(vapply(checks, `[[`, logical(1), "pass")),
                  failed = sum(!vapply(checks, `[[`, logical(1), "pass")),
                  consumed_sources = records,
                  R = R.version.string, posterior = as.character(utils::packageVersion("posterior"))),
             file.path(out, "checks.json"))
  }, add = TRUE)
  base <- "quality_reports/results/mebane_gates/coordination/2026-10-01_ad_long_stan"
  data_rel <- "quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/data/run-20260930T235038Z-pid61600/dc2010_ad_data.rds"
  sources <- c("R/experimental/mebane_ad/io.R", "R/experimental/mebane_ad/diagnostics.R",
               "R/experimental/mebane_ad_long/stan_bridge.R",
               "R/experimental/mebane_ad_long/postprocess_stan.R",
               "R/experimental/mebane_ad_long/diagnostics_stan.R",
               "R/experimental/mebane_ad_long/prepare_stan_diagnostics.R",
               file.path(base, "contract.json"), file.path(base, "contract_stan_diagnostics.json"), data_rel)
  tree <- file.path(out, "tree")
  dir.create(tree)
  for (rel in sources) {
    original <- file.path(root, rel)
    target <- file.path(tree, rel)
    before <- sha(original)
    dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
    stopifnot(file.copy(original, target, overwrite = FALSE), sha(original) == before, sha(target) == before)
    records[[length(records) + 1L]] <- list(path = rel, snapshot = target, sha256 = before)
  }
  setwd(tree)
  source("R/experimental/mebane_ad_long/postprocess_stan.R", local = globalenv())
  payload <- readRDS(data_rel)
  check("ratios_change_of_variables_18_points", review_prior_identities())
  check("common_processor_exact_two_substitution_delta", {
    original <- readLines("R/experimental/mebane_ad/diagnostics.R")
    expected <- gsub("AD-DC2010-v2", "AD-DC2010-LONG-STAN-v1", original, fixed = TRUE)
    expected <- gsub("R/experimental/mebane_ad/diagnostics.R", "R/experimental/mebane_ad_long/diagnostics_stan.R", expected, fixed = TRUE)
    stopifnot(identical(expected, readLines("R/experimental/mebane_ad_long/diagnostics_stan.R")))
  })
  check("prospective_common_thresholds_unchanged", {
    main <- jsonlite::read_json(file.path(base, "contract.json"))
    adapter <- jsonlite::read_json(file.path(base, "contract_stan_diagnostics.json"))
    stopifnot(identical(main$diagnostics$decision_table, adapter$diagnostics$decision_table),
              length(adapter$diagnostics$analytic_exemptions_in_empirical_pilot) == 0L,
              adapter$source_main_contract$sha256 == sha(file.path(base, "contract.json")))
  })
  blocks <- c("tau", "nu", "iota.m", "iota.s", "chi.m", "chi.s")
  common_names <- c(sprintf("pi[%d]", 1:3), sprintf("alpha[%d]", 1:6),
                    sprintf("b0[%d]", 1:6), sprintf("v[%d]", 1:6),
                    unlist(lapply(1:6, function(j) sprintf("mu[%d,%d]", 1:143, j))),
                    unlist(lapply(c("Z", "pA", "pW", "pO"), function(s) sprintf("%s[%d]", s, 1:143))))
  check("all_1451_columns_by_all_four_chains_exact", {
    sentinel <- array(seq_len(2000L * 4L * length(common_names)), c(2000L, 4L, length(common_names)),
                      dimnames = list(NULL, NULL, common_names))
    review_bridge_mapping(sentinel, ad_stan_common(sentinel))
    rejects(ad_stan_common(sentinel[-1, , , drop = FALSE]))
    rejects(ad_stan_common(sentinel[, , -match("b0[4]", common_names), drop = FALSE]))
    rm(sentinel)
  })
  internal_names <- c(unlist(lapply(1:6, function(j) sprintf("z[%d,%d]", 1:143, j))), "r[1]", "r[2]")
  all_names <- c(common_names, internal_names, "M_total", "S_total", "M_RB_total", "S_RB_total")
  x <- array(0, c(2000L, 4L, length(all_names)), dimnames = list(NULL, NULL, all_names))
  set.seed(1001287)
  random_matrix <- function() matrix(rnorm(8000), 2000L, 4L)
  for (k in 1:2) x[, , sprintf("r[%d]", k)] <- matrix(runif(8000, .1, .9), 2000L, 4L)
  pi1 <- 1 / (1 + x[, , "r[1]"] + x[, , "r[2]"])
  x[, , "pi[1]"] <- pi1
  x[, , "pi[2]"] <- pi1 * x[, , "r[1]"]
  x[, , "pi[3]"] <- pi1 * x[, , "r[2]"]
  for (j in 1:6) {
    x[, , sprintf("alpha[%d]", j)] <- random_matrix() * .1 + (j - 3) / 10
    x[, , sprintf("b0[%d]", j)] <- random_matrix() * .005
    x[, , sprintf("v[%d]", j)] <- matrix(runif(8000, .1, .4), 2000L, 4L)
    for (i in 1:143) {
      z <- random_matrix()
      x[, , sprintf("z[%d,%d]", i, j)] <- z
      eta <- x[, , sprintf("alpha[%d]", j)] + x[, , sprintf("b0[%d]", j)] + sqrt(x[, , sprintf("v[%d]", j)]) * z
      mu <- plogis(eta)
      if (j %in% 3:4) mu <- .7 * mu
      if (j %in% 5:6) mu <- .7 + .3 * mu
      x[, , sprintf("mu[%d,%d]", i, j)] <- mu
    }
  }
  for (i in 1:143) {
    # Deliberately balanced synthetic occupancy, not draws from an empirical posterior.
    Z <- sapply(1:4, function(k) sample(rep(1:3, length.out = 2000L)))
    x[, , sprintf("Z[%d]", i)] <- Z
    mu <- lapply(1:6, function(j) x[, , sprintf("mu[%d,%d]", i, j)])
    m <- (Z == 2) * mu[[3]] + (Z == 3) * mu[[5]]
    s <- (Z == 2) * mu[[4]] + (Z == 3) * mu[[6]]
    x[, , sprintf("pA[%d]", i)] <- (1 - mu[[1]]) * (1 - m)
    x[, , sprintf("pW[%d]", i)] <- mu[[1]] * mu[[2]] + (1 - mu[[1]]) * m + mu[[1]] * (1 - mu[[2]]) * s
    x[, , sprintf("pO[%d]", i)] <- mu[[1]] * (1 - mu[[2]]) * (1 - s)
    x[, , "M_total"] <- x[, , "M_total"] + payload$D$N[i] * (1 - mu[[1]]) * m
    x[, , "S_total"] <- x[, , "S_total"] + payload$D$N[i] * mu[[1]] * (1 - mu[[2]]) * s
  }
  # Secondary sentinels are intentionally distinct; this fixture tests plumbing, not RB mathematics.
  x[, , "M_RB_total"] <- 10 + random_matrix()
  x[, , "S_RB_total"] <- 5 + random_matrix()
  sampler <- array(0, c(2000L, 4L, 3L), dimnames = list(NULL, NULL, c("divergent__", "treedepth__", "energy__")))
  sampler[, , "treedepth__"] <- 5
  sampler[, , "energy__"] <- 20 + random_matrix()
  baseline <- ad_stan_sampler_checks(x, sampler)
  check("860_exact_internal_names_and_mandatory_rows", {
    stopifnot(setequal(baseline$internal_diagnostics$target, internal_names),
              nrow(baseline$internal_diagnostics) == 860L, all(baseline$internal_diagnostics$mandatory), baseline$pass)
  })
  check("HMC_energy_formula_independent", {
    expected <- review_expected_HMC(sampler)
    for (name in names(expected)) review_near(baseline$chain_diagnostics[[name]], expected[[name]], 1e-13)
  })
  check("M_S_same_Z_positive_control", ad_stan_functional_checks(x, payload))
  check("M_S_wrong_total_negative_control", {
    wrong <- x
    wrong[1, 1, "M_total"] <- wrong[1, 1, "M_total"] + 1
    rejects(ad_stan_functional_checks(wrong, payload))
    rm(wrong)
  })
  original_row <- ad_diagnostic_row
  cached <- baseline$internal_diagnostics
  # Unchanged NCP inputs reuse computed rows while new HMC branches execute each time.
  assign("ad_diagnostic_row", function(x, target, ...) cached[match(target, cached$target), , drop = FALSE], envir = globalenv())
  for (kind in c("divergence", "treedepth", "constant_energy", "low_EBFMI")) {
    check(paste0("HMC_rejects_", kind), {
      wrong <- sampler
      if (kind == "divergence") wrong[1, 1, "divergent__"] <- 1
      if (kind == "treedepth") wrong[1, 2, "treedepth__"] <- 12
      if (kind == "constant_energy") wrong[, 3, "energy__"] <- 1
      if (kind == "low_EBFMI") wrong[, 4, "energy__"] <- seq_len(2000)
      stopifnot(!ad_stan_sampler_checks(x, wrong)$pass)
    })
  }
  assign("ad_diagnostic_row", original_row, envir = globalenv())
  for (kind in c("constant", "separated")) {
    check(paste0("NCP_rejects_", kind), {
      value <- if (kind == "constant") matrix(0, 2000L, 4L) else sweep(x[, , "z[1,1]"], 2, c(-3, -1, 1, 3), "+")
      bad_row <- original_row(value, "z[1,1]", "Stan_internal")
      stopifnot(!bad_row$diagnostic_pass)
      modified <- cached
      modified[match("z[1,1]", modified$target), ] <- bad_row
      assign("ad_diagnostic_row", function(x, target, ...) modified[match(target, modified$target), , drop = FALSE], envir = globalenv())
      stopifnot(!ad_stan_sampler_checks(x, sampler)$pass)
      assign("ad_diagnostic_row", original_row, envir = globalenv())
    })
  }
  assign("ad_diagnostic_row", original_row, envir = globalenv())
  run_dir <- "synthetic_stan_run"
  dir.create(run_dir)
  saveRDS(x, file.path(run_dir, "draws_array.rds"))
  saveRDS(sampler, file.path(run_dir, "sampler_diagnostics.rds"))
  json_new(list(generation_wall_seconds = 123, fixture_only = TRUE), file.path(run_dir, "timing.json"))
  json_new(list(exit_code = 0L, timed_out = FALSE, wall_seconds = 140, fixture_only = TRUE), file.path(run_dir, "supervisor_finished.json"))
  artifacts <- file.path(run_dir, c("draws_array.rds", "sampler_diagnostics.rds", "timing.json"))
  json_new(list(status = "sampling_completed_precision_not_assessed", fixture_only = TRUE,
                artifacts = lapply(artifacts, function(p) list(path = p, sha256 = sha(p)))), file.path(run_dir, "manifest.json"))
  result <- ad_postprocess_stan(run_dir, "postprocessed")
  diagnostics <- read.csv("postprocessed/common_diagnostics/diagnostics.csv")
  joint <- read.csv("postprocessed/common_diagnostics/joint_functionals.csv")
  check("full_process_1742_plus_860_required_targets", {
    stopifnot(result$internal_targets == 860L, result$common_result$mandatory_targets == 1742L,
              sum(diagnostics$mandatory) == 1742L, sum(diagnostics$group == "global") == 23L,
              !any(diagnostics$analytic_constant))
  })
  check("full_process_joint_order_and_totals", {
    stopifnot(identical(joint$iteration, rep(1:2000, 4)), identical(joint$chain, rep(1:4, each = 2000)))
    review_near(joint$M, as.vector(x[, , "M_total"]), 1e-7)
    review_near(joint$S, as.vector(x[, , "S_total"]), 1e-7)
  })
  check("full_process_secondary_RB_not_common_targets", {
    rb <- read.csv("postprocessed/RB_diagnostics.csv")
    stopifnot(!any(rb$mandatory), !any(c("M_RB_total", "S_RB_total") %in% diagnostics$target),
              !any(baseline$internal_diagnostics$target %in% diagnostics$target))
  })
  check("full_process_decisions_recomputed_all_rows", {
    expected <- is.finite(diagnostics$rhat) & is.finite(diagnostics$ess_bulk) & is.finite(diagnostics$ess_tail) &
      diagnostics$rhat < 1.01 & diagnostics$ess_bulk >= 400 & diagnostics$ess_tail >= 400 &
      is.finite(diagnostics$chain_mean_range) & (is.na(diagnostics$range_limit) | diagnostics$chain_mean_range <= diagnostics$range_limit)
    stopifnot(identical(expected, diagnostics$diagnostic_pass),
              result$common_result$failed_targets == sum(!expected & diagnostics$mandatory))
  })
  check("full_process_ESS_denominator_exact_and_explicit", {
    review_near(diagnostics$ess_bulk_per_internal_generation_second, diagnostics$ess_bulk / 123, 1e-8)
    review_near(diagnostics$ess_tail_per_internal_generation_second, diagnostics$ess_tail / 123, 1e-8)
    metadata <- jsonlite::read_json("postprocessed/common_view/run_result.json")
    stopifnot(grepl("Stan sample call only", metadata$timing_definition, fixed = TRUE))
  })
  check("all_consumed_live_sources_unchanged_during_check", {
    stopifnot(all(vapply(records, function(x) sha(file.path(root, x$path)) == x$sha256, logical(1))))
  })
  write.csv(baseline$chain_diagnostics, file.path(out, "HMC_independent_baseline.csv"), row.names = FALSE)
  write.csv(baseline$internal_diagnostics, file.path(out, "NCP_baseline.csv"), row.names = FALSE)
  cat("Finished synthetic adapter checks; no sampler or compiled Stan method invoked.\n")
}
run_checks()
