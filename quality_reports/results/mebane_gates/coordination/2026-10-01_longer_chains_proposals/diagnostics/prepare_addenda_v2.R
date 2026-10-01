#!/usr/bin/env Rscript
# Additive annotations and resource arithmetic; no raw draws or sampler are run.
options(scipen = 999, digits = 16)
local_lib <- "renv/library/macos/R-4.4/aarch64-apple-darwin20"
if (dir.exists(local_lib)) .libPaths(c(local_lib, .libPaths()))
stopifnot(requireNamespace("jsonlite", quietly = TRUE),
          requireNamespace("digest", quietly = TRUE))
own <- "quality_reports/results/mebane_gates/coordination/2026-10-01_longer_chains_proposals/diagnostics"
old <- "quality_reports/results/mebane_gates/coordination/2026-10-01_ad_long_stan"
args <- commandArgs(trailingOnly = TRUE)
src <- if (length(args)) args[1] else file.path(own, "analysis01")
out <- if (length(args) > 1L) args[2] else file.path(own, "addenda02")
stopifnot(startsWith(src, paste0(own, "/")),
          startsWith(out, paste0(own, "/")), !file.exists(out))
dir.create(out, recursive = TRUE)
read_csv <- function(name) read.csv(file.path(src, name), check.names = FALSE)
write_csv <- function(x, name) {
  path <- file.path(out, name)
  stopifnot(!file.exists(path))
  write.csv(x, path, row.names = FALSE, na = "NA")
}
sha <- function(path) digest::digest(file = path, algo = "sha256", serialize = FALSE)
d <- read_csv("all_target_rankings.csv")
g <- read_csv("grouped_diagnostics.csv")
before <- d
secondary <- d$source_group == "D_secondary"
stopifnot(sum(secondary) == 4L,
          all(d$target[secondary] %in% c("M_count_total", "S_count_total")))
d$nature[secondary] <- "discrete_secondary_ballot_count"
# Positive infinity fails R-hat; NA remains undefined, not a finite failure.
d$rhat_fails <- !is.na(d$rhat) & d$rhat >= 1.01
d$rhat_undefined <- is.na(d$rhat)
changed <- before$nature != d$nature | before$rhat_fails != d$rhat_fails
write_csv(data.frame(run = d$run[changed], target = d$target[changed],
  old_nature = before$nature[changed], corrected_nature = d$nature[changed],
  old_rhat_fails = before$rhat_fails[changed],
  corrected_rhat_fails = d$rhat_fails[changed]), "annotation_corrections.csv")
write_csv(d, "all_target_rankings_corrected.csv")
g$rhat_undefined <- 0L
for (i in seq_len(nrow(g))) {
  x <- d[d$run == g$run[i] & d$source_group == g$source_group[i] &
           d$family == g$family[i] & d$block == g$block[i], ]
  stopifnot(nrow(x) == g$targets[i], length(unique(x$nature)) == 1L)
  g$nature[i] <- x$nature[1]
  g$rhat_fails[i] <- sum(x$rhat_fails)
  g$rhat_undefined[i] <- sum(x$rhat_undefined)
  g$rhat_max[i] <- if (all(is.na(x$rhat))) NA_real_ else max(x$rhat, na.rm = TRUE)
}
write_csv(g, "grouped_diagnostics_corrected.csv")
globals <- read_csv("global_rankings.csv")
runs <- c("A_JAGS_20k", "D_JAGS_20k", "D_Stan_2k")
global_summary <- do.call(rbind, lapply(runs, function(run) {
  x <- globals[globals$run == run, ]
  data.frame(run = run, globals = nrow(x), original_failures = sum(!x$diagnostic_pass),
    bulk_below_10 = sum(x$ess_bulk < 10), bulk_below_50 = sum(x$ess_bulk < 50),
    bulk_below_400 = sum(x$ess_bulk < 400), tail_below_400 = sum(x$ess_tail < 400),
    undefined_bulk = sum(is.na(x$ess_bulk)), undefined_tail = sum(is.na(x$ess_tail)),
    rhat_max = max(x$rhat), worst_bulk_target = x$target[which.min(x$ess_bulk)])
}))
write_csv(global_summary, "global_summary.csv")
focus <- globals[globals$family %in%
                   c("global_alpha", "global_variance", "mixture_weight", "joint_transfer_functional"),
                 c("run", "target", "rank_bulk", "rank_tail", "ess_bulk", "ess_tail",
                   "rhat", "diagnostic_pass")]
write_csv(focus, "focus_global_comparison.csv")
sizes <- read_csv("payload_sizes.csv")
repr_path <- file.path(old, "stan_diagnostics02/input_representation.json")
repr <- jsonlite::read_json(repr_path, simplifyVector = TRUE)
stopifnot(identical(as.integer(repr$draws_shape), c(2000L, 4L, 4890L)))
payload <- data.frame(
  run = c(runs, "D_Stan_2k"),
  representation = c("A_JAGS_retained_nodes", "D_JAGS_retained_nodes",
                     "D_Stan_common_bridge_only", "D_Stan_full_draws_array"),
  post_per_chain = c(100000L, 100000L, 5000L, 5000L),
  chains = 4L, variables = c(sizes$source_variables, repr$draws_shape[3]),
  bytes_per_numeric = 8L)
payload$numeric_payload_bytes <- with(payload, as.double(post_per_chain) * chains * variables * bytes_per_numeric)
payload$decimal_GB <- payload$numeric_payload_bytes / 1e9
payload$binary_GiB <- payload$numeric_payload_bytes / 1024^3
payload$is_peak_RSS_or_total_RAM <- FALSE
payload$excluded <- "CSV; warmup; sampler/model state; worker memory; object overhead; temporary copies; bridge and diagnostic arrays"
stopifnot(identical(payload$numeric_payload_bytes,
                   c(6016000000, 4643200000, 232160000, 782400000)))
write_csv(payload, "resource_payload_addendum.csv")
protocol <- data.frame(
  model_engine = c("A_JAGS", "D_JAGS", "D_Stan"),
  chains = 4L, parallel_chain_processes = 4L, threads_per_chain = 1L,
  adapt_per_chain = c(1000L, 1000L, NA_integer_),
  burn_or_warmup_per_chain = c(2000L, 2000L, 1000L),
  post_per_chain = c(100000L, 100000L, 5000L), thin = 1L,
  retained_total = c(400000L, 400000L, 20000L),
  adapt_delta = c(NA_real_, NA_real_, 0.99),
  max_treedepth = c(NA_integer_, NA_integer_, 12L),
  fit_attempts = 1L, heavy_fits_at_once = 1L,
  new_sampling_authorized = FALSE, prior_change_authorized = FALSE)
write_csv(protocol, "proposed_protocol.csv")
snapshot_paths <- c("CLAUDE.md", file.path(dirname(own), "resource_snapshot.json"),
  file.path(dirname(own), "decision.md"), file.path(old, "handoff.md"),
  file.path(old, "completion.json"), file.path(old, "results_adjudication.json"),
  repr_path)
stopifnot(all(file.exists(snapshot_paths)))
dir.create(file.path(out, "context_snapshots"))
snapshots <- lapply(snapshot_paths, function(p) {
  target <- file.path(out, "context_snapshots", basename(p))
  stopifnot(!file.exists(target), file.copy(p, target, overwrite = FALSE), sha(p) == sha(target))
  list(source = p, copy = target, sha256 = sha(target))
})
frozen <- jsonlite::read_json(file.path(src, "input_manifest.json"))$inputs
verification <- do.call(rbind, lapply(frozen, function(x) {
  current <- sha(x$path)
  data.frame(path = x$path, at_analysis_sha256 = x$sha256,
    at_addendum_sha256 = current, matches = identical(current, x$sha256),
    live_document = identical(x$path, file.path(old, "handoff.md")))
}))
stopifnot(all(verification$matches | verification$live_document))
write_csv(verification, "input_rechecks.csv")
checks <- read_csv("focused_metric_checks.csv")
stopifnot(nrow(globals) == 69L, nrow(checks) == 78L, all(checks$metrics_match),
  all(checks$chains == 4L), all(checks$thinning == 1L),
  all(global_summary$original_failures == c(14L, 13L, 10L)),
  !anyDuplicated(paste(d$run, d$target)))
jsonlite::write_json(list(created_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
  scope = "Executor consistency checks, not independent QA or release",
  global_rows = nrow(globals), all_target_rows = nrow(d),
  focused_unthinned_matches = nrow(checks), annotation_corrections = sum(changed),
  annotations_do_not_change_metrics_or_original_decisions = TRUE,
  original_outputs_preserved = TRUE, new_sampling = FALSE,
  snapshots = snapshots,
  script_sha256 = sha(file.path(own, "prepare_addenda_v2.R"))),
  file.path(out, "addendum_checks.json"), pretty = TRUE, auto_unbox = TRUE)
print(global_summary, row.names = FALSE)
print(payload[, 1:9], row.names = FALSE)
message("Additive outputs saved in ", out)
