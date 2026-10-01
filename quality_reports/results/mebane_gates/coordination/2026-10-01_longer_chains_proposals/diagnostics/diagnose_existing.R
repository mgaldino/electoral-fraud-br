#!/usr/bin/env Rscript
# Read completed runs only. No sampler or model code is sourced or executed.
options(scipen = 999, digits = 16)
local_lib <- "renv/library/macos/R-4.4/aarch64-apple-darwin20"
if (dir.exists(local_lib)) .libPaths(c(local_lib, .libPaths()))
for (p in c("jsonlite", "digest", "posterior")) {
  if (!requireNamespace(p, quietly = TRUE)) stop("Existing package required: ", p)
}
root <- "quality_reports/results/mebane_gates/coordination/2026-10-01_ad_long_stan"
own <- "quality_reports/results/mebane_gates/coordination/2026-10-01_longer_chains_proposals/diagnostics"
args <- commandArgs(trailingOnly = TRUE)
out <- if (length(args)) args[1] else file.path(own, "analysis01")
stopifnot(startsWith(out, paste0(own, "/")), !file.exists(out))
dir.create(out, recursive = TRUE, showWarnings = FALSE)
input_paths <- character()
register <- function(path) {
  stopifnot(file.exists(path), !dir.exists(path))
  input_paths <<- unique(c(input_paths, path))
  path
}
read_csv <- function(path) read.csv(register(path), check.names = FALSE,
                                   stringsAsFactors = FALSE)
read_json <- function(path) jsonlite::read_json(register(path), simplifyVector = TRUE)
sha <- function(path) digest::digest(file = path, algo = "sha256", serialize = FALSE)
write_csv <- function(x, name) {
  path <- file.path(out, name)
  stopifnot(!file.exists(path))
  write.csv(x, path, row.names = FALSE, na = "NA")
}
write_json <- function(x, name) {
  path <- file.path(out, name)
  stopifnot(!file.exists(path))
  jsonlite::write_json(x, path, pretty = TRUE, auto_unbox = TRUE, digits = NA, na = "null")
}
blocks <- c("tau", "nu", "iota.m", "iota.s", "chi.m", "chi.s")
variances <- c("tb", "nb", "imb", "isb", "cmb", "csb")
concepts <- c("legitimate_turnout", "legitimate_winner_share",
              "incremental_manufacturing", "incremental_stealing",
              "extreme_manufacturing", "extreme_stealing")
block_concept <- setNames(concepts, blocks)
variance_block <- setNames(blocks, variances)
run_ids <- c("A_JAGS_20k", "D_JAGS_20k", "D_Stan_2k")
diag_dirs <- setNames(file.path(root, c("jags20k01/A_diagnostics",
                                      "jags20k01/D_diagnostics",
                                      "stan_diagnostics02/common_diagnostics")), run_ids)
raw_dirs <- setNames(file.path(root, c("jags20k01/A", "jags20k01/D",
                                     "stan_diagnostics02/common_view")), run_ids)
iterations <- setNames(c(20000L, 20000L, 2000L), run_ids)
future_iterations <- setNames(c(100000L, 100000L, 5000L), run_ids)
contract <- read_json(file.path(root, "contract.json"))
stopifnot(contract$diagnostics$bulk_ESS_min == 400,
          contract$diagnostics$tail_ESS_min == 400)

annotate <- function(d, run) {
  d$run <- run
  d$source_group <- d$group
  base <- sub("\\[.*$", "", d$target)
  d$family <- d$source_group
  d$block <- base
  d$nature <- "continuous"
  idx <- grepl("^pi\\[", d$target)
  d$family[idx] <- "mixture_weight"
  d$block[idx] <- paste0("class_", sub("^pi\\[([1-3])\\]$", "\\1", d$target[idx]))
  idx <- grepl("\\.alpha$", base)
  d$family[idx] <- "global_alpha"
  d$block[idx] <- sub("\\.alpha$", "", base[idx])
  idx <- grepl("^beta\\.", base)
  d$family[idx] <- "global_b0"
  d$block[idx] <- sub("1$", "", sub("^beta\\.", "", base[idx]))
  idx <- base %in% variances
  d$family[idx] <- "global_variance"
  d$block[idx] <- unname(variance_block[base[idx]])
  idx <- grepl("^mu\\.", base)
  d$family[idx] <- "local_magnitude"
  d$block[idx] <- sub("^mu\\.", "", base[idx])
  idx <- grepl("^N\\.", base)
  d$family[idx] <- "A_auxiliary_count"
  d$block[idx] <- sub("^N\\.", "", base[idx])
  d$nature[idx] <- "discrete_auxiliary"
  idx <- base %in% c("M_total", "S_total", "M_fraction_N", "S_fraction_N")
  d$family[idx] <- "joint_transfer_functional"
  d$block[idx] <- substr(base[idx], 1, 1)
  d$nature[idx] <- "mixed_zero_continuous"
  idx <- d$source_group %in% c("class_count", "class_indicator")
  d$nature[idx] <- "discrete_class"
  d$block[idx] <- paste0("class_", sub(".*[,\\[]([1-3])\\]$", "\\1", d$target[idx]))
  idx <- d$source_group == "Stan_internal" & grepl("^z\\[", d$target)
  b <- as.integer(sub("^z\\[[0-9]+,([1-6])\\]$", "\\1", d$target[idx]))
  d$family[idx] <- "NCP_z"
  d$block[idx] <- blocks[b]
  idx <- d$source_group == "Stan_internal" & grepl("^r\\[", d$target)
  d$family[idx] <- "weight_ratio"
  d$block[idx] <- ifelse(d$target[idx] == "r[1]", "pi2_over_pi1", "pi3_over_pi1")
  d$concept <- ifelse(d$block %in% blocks, unname(block_concept[d$block]), d$block)
  d$bulk_undefined <- !is.finite(d$ess_bulk)
  d$tail_undefined <- !is.finite(d$ess_tail)
  d$bulk_below_10 <- is.finite(d$ess_bulk) & d$ess_bulk < 10
  d$bulk_below_50 <- is.finite(d$ess_bulk) & d$ess_bulk < 50
  d$bulk_below_400 <- is.finite(d$ess_bulk) & d$ess_bulk < 400
  d$tail_below_400 <- is.finite(d$ess_tail) & d$ess_tail < 400
  d$rhat_fails <- is.finite(d$rhat) & d$rhat >= 1.01
  d$nominal_draws <- 4L * iterations[[run]]
  d$bulk_fraction_nominal <- d$ess_bulk / d$nominal_draws
  d$bulk_severity <- ifelse(d$bulk_undefined, "undefined",
    ifelse(d$ess_bulk < 10, "below_10", ifelse(d$ess_bulk < 50, "10_to_50",
      ifelse(d$ess_bulk < 400, "50_to_400", "at_least_400"))))
  d
}
common <- lapply(run_ids, function(run) annotate(read_csv(file.path(diag_dirs[[run]], "diagnostics.csv")), run))
names(common) <- run_ids
ncp <- annotate(read_csv(file.path(root, "stan_diagnostics02/NCP_diagnostics.csv")), "D_Stan_2k")
for (name in setdiff(names(common[[1]]), names(ncp))) ncp[[name]] <- NA
all_metrics <- rbind(do.call(rbind, common), ncp[, names(common[[1]])])
stopifnot(!anyDuplicated(paste(all_metrics$run, all_metrics$target)))
globals <- all_metrics[all_metrics$source_group == "global", ]
globals <- do.call(rbind, lapply(run_ids, function(run) {
  x <- globals[globals$run == run, ]
  stopifnot(nrow(x) == 23L, all(is.finite(x$ess_bulk)), all(is.finite(x$ess_tail)))
  x$rank_bulk <- rank(x$ess_bulk, ties.method = "min")
  x$rank_tail <- rank(x$ess_tail, ties.method = "min")
  x[order(x$ess_bulk), ]
}))
write_csv(globals, "global_rankings.csv")
write_csv(all_metrics[order(match(all_metrics$run, run_ids), all_metrics$ess_bulk, na.last = TRUE), ],
          "all_target_rankings.csv")
safe_min <- function(x) if (any(is.finite(x))) min(x[is.finite(x)]) else NA_real_
safe_max <- function(x) if (any(is.finite(x))) max(x[is.finite(x)]) else NA_real_
safe_median <- function(x) if (any(is.finite(x))) median(x[is.finite(x)]) else NA_real_
groups <- split(all_metrics, paste(all_metrics$run, all_metrics$source_group,
                                  all_metrics$family, all_metrics$block, sep = "|"))
grouped <- do.call(rbind, lapply(groups, function(d) data.frame(
  run = d$run[1], source_group = d$source_group[1], family = d$family[1],
  block = d$block[1], concept = d$concept[1], nature = d$nature[1],
  targets = nrow(d), mandatory = sum(d$mandatory),
  bulk_min = safe_min(d$ess_bulk), bulk_median = safe_median(d$ess_bulk),
  tail_min = safe_min(d$ess_tail), tail_median = safe_median(d$ess_tail),
  bulk_below_10 = sum(d$bulk_below_10), bulk_below_50 = sum(d$bulk_below_50),
  bulk_below_400 = sum(d$bulk_below_400), tail_below_400 = sum(d$tail_below_400),
  bulk_undefined = sum(d$bulk_undefined), tail_undefined = sum(d$tail_undefined),
  tail_undefined_with_finite_bulk = sum(d$tail_undefined & !d$bulk_undefined),
  sampled_constant = sum(d$sampled_constant), rhat_max = safe_max(d$rhat),
  rhat_fails = sum(d$rhat_fails), original_failures = sum(!d$diagnostic_pass),
  worst_bulk_target = if (any(is.finite(d$ess_bulk))) d$target[which.min(d$ess_bulk)] else NA_character_
)))
write_csv(grouped, "grouped_diagnostics.csv")
rare <- do.call(rbind, lapply(run_ids, function(run) do.call(rbind, lapply(1:3, function(k) {
  d <- common[[run]]
  ind <- d[d$source_group == "class_indicator" & d$block == paste0("class_", k), ]
  ct <- d[d$target == paste0("class_count[", k, "]"), ]
  stopifnot(nrow(ind) == 143L, nrow(ct) == 1L)
  data.frame(run = run, class = k, mean_count = ct$mean,
    count_chain1 = ct$chain1, count_chain2 = ct$chain2,
    count_chain3 = ct$chain3, count_chain4 = ct$chain4,
    count_rhat = ct$rhat, count_ess_bulk = ct$ess_bulk, count_ess_tail = ct$ess_tail,
    indicators = 143L, indicators_sampled_constant = sum(ind$sampled_constant),
    indicators_zero_all_chains = sum(ind$sampled_constant & ind$mean == 0),
    indicator_bulk_undefined = sum(ind$bulk_undefined),
    indicator_tail_undefined = sum(ind$tail_undefined),
    indicator_bulk_below_400 = sum(ind$bulk_below_400),
    indicator_tail_below_400 = sum(ind$tail_below_400))
}))))
write_csv(rare, "rare_class_diagnostics.csv")

# Normalize classes before any slicing: matrices remain iterations x chains.
normalise_draws <- function(raw, niter) {
  d <- raw$draws
  if (length(dim(d)) == 3L) {
    shape <- dim(d)
    d <- unclass(d)
    stopifnot(identical(dim(d), shape), shape[1] == niter, shape[2] == 4L)
    d <- lapply(1:4, function(k) {
      x <- d[, k, , drop = FALSE]
      dim(x) <- c(niter, shape[3])
      dimnames(x) <- list(NULL, dimnames(raw$draws)[[3]])
      x
    })
  } else {
    d <- lapply(d, function(x) {
      shape <- dim(x)
      y <- unclass(x)
      stopifnot(length(shape) == 2L, identical(dim(y), shape))
      y
    })
  }
  stopifnot(length(d) == 4L, all(vapply(d, nrow, integer(1)) == niter),
    all(vapply(d, function(x) identical(colnames(x), colnames(d[[1]])), logical(1))))
  d
}
focus <- list()
shapes <- list()
within <- list()
metric_checks <- list()
payload <- list()
for (run in run_ids) {
  message("Reading focused existing draws: ", run)
  raw_path <- register(file.path(raw_dirs[[run]], "raw_chains.rds"))
  result <- read_json(file.path(raw_dirs[[run]], "run_result.json"))
  stopifnot(sha(raw_path) == result$raw_sha256)
  raw <- readRDS(raw_path)
  niter <- iterations[[run]]
  chains <- normalise_draws(raw, niter)
  globals_run <- common[[run]][common[[run]]$source_group == "global", ]
  names_focus <- c(globals_run$target, paste0("class_count[", 1:3, "]"))
  x <- array(NA_real_, c(niter, 4L, length(names_focus)),
    dimnames = list(iteration = as.character(seq_len(niter)), chain = as.character(1:4),
                   variable = names_focus))
  joint <- read_csv(file.path(diag_dirs[[run]], "joint_functionals.csv"))
  stopifnot(nrow(joint) == niter * 4L, !anyDuplicated(paste(joint$iteration, joint$chain)))
  for (k in 1:4) {
    zcols <- paste0("Z[", 1:143, "]")
    stopifnot(all(zcols %in% colnames(chains[[k]])))
    for (name in setdiff(globals_run$target, c("M_total", "S_total"))) {
      key <- intersect(c(name, paste0(name, "[1]")), colnames(chains[[k]]))
      stopifnot(length(key) == 1L)
      x[, k, name] <- chains[[k]][, key]
    }
    j <- joint[joint$chain == k, ]
    j <- j[order(j$iteration), ]
    stopifnot(identical(j$iteration, seq_len(niter)))
    x[, k, "M_total"] <- j$M
    x[, k, "S_total"] <- j$S
    for (cl in 1:3) x[, k, paste0("class_count[", cl, "]")] <-
      rowSums(chains[[k]][, zcols, drop = FALSE] == cl)
  }
  shapes[[run]] <- list(iterations = niter, chains = 4L,
    source_variables = ncol(chains[[1]]), focused_variables = length(names_focus),
    source_class = class(raw$draws), per_chain_class = class(raw$draws[[1]]),
    normalization = "unclass before slicing; explicit base iteration-by-chain matrix; no thinning")
  payload[[run]] <- data.frame(run = run, input_file_bytes = file.info(raw_path)$size,
    raw_object_bytes = as.numeric(object.size(raw)), source_variables = ncol(chains[[1]]),
    current_iterations = niter, proposed_iterations = future_iterations[[run]],
    projected_plain_draw_bytes_four_chains = 8 * 4 * future_iterations[[run]] * ncol(chains[[1]]),
    projected_archive_bytes_linear = file.info(raw_path)$size * future_iterations[[run]] / niter)
  rm(raw, chains, joint)
  gc(verbose = FALSE)
  stopifnot(all(is.finite(x)))
  focus[[run]] <- x
  for (name in names_focus) {
    mat <- matrix(x[, , name], nrow = niter, ncol = 4L)
    got <- suppressWarnings(c(rhat = posterior::rhat(mat), bulk = posterior::ess_bulk(mat),
                              tail = posterior::ess_tail(mat)))
    orig <- common[[run]][common[[run]]$target == name, ]
    want <- c(rhat = orig$rhat, bulk = orig$ess_bulk, tail = orig$ess_tail)
    ok <- (is.na(got) & is.na(want)) | (is.finite(got) & is.finite(want) &
                                      abs(got - want) <= 0.000001 * pmax(1, abs(want)))
    stopifnot(all(ok))
    metric_checks[[length(metric_checks) + 1L]] <- data.frame(run = run, target = name,
      rhat_recomputed = got[1], bulk_recomputed = got[2], tail_recomputed = got[3],
      max_abs_difference = if (any(is.finite(got))) max(abs(got[is.finite(got)] - want[is.finite(got)])) else NA_real_,
      metrics_match = all(ok), iterations = niter, chains = 4L, thinning = 1L)
    for (k in 1:4) {
      segments <- c(list(full = seq_len(niter)), setNames(split(seq_len(niter),
        ceiling(seq_len(niter) / (niter / 4))), paste0("quarter", 1:4)))
      for (seg in names(segments)) {
        v <- mat[segments[[seg]], k]
        constant <- length(unique(v)) == 1L
        m <- matrix(v, ncol = 1L)
        q <- quantile(v, c(0.05, 0.5, 0.95), names = FALSE)
        within[[length(within) + 1L]] <- data.frame(run = run, target = name, chain = k,
          segment = seg, start = min(segments[[seg]]), end = max(segments[[seg]]),
          n = length(v), mean = mean(v), sd = sd(v), q05 = q[1], median = q[2], q95 = q[3],
          zero_fraction = mean(v == 0), sampled_constant = constant,
          ess_bulk = if (constant) NA_real_ else suppressWarnings(posterior::ess_bulk(m)),
          ess_tail = if (constant) NA_real_ else suppressWarnings(posterior::ess_tail(m)),
          autocorrelation_lag1 = if (constant) NA_real_ else cor(v[-length(v)], v[-1]))
      }
    }
  }
  message("Focused metrics matched: ", run)
}
write_csv(do.call(rbind, within), "within_chain_summaries.csv")
write_csv(do.call(rbind, metric_checks), "focused_metric_checks.csv")
write_csv(do.call(rbind, payload), "payload_sizes.csv")
write_json(shapes, "draw_shapes.json")
saveRDS(focus, file.path(out, "focused_draws.rds"))

timing <- read_csv(file.path(root, "comparison_final01/timings_diagnostics.csv"))
timing <- timing[match(run_ids, timing$id), ]
runtime <- do.call(rbind, lapply(seq_along(run_ids), function(i) {
  t <- timing[i, ]
  ratio <- future_iterations[[run_ids[i]]] / iterations[[run_ids[i]]]
  adapt <- if (is.finite(t$adaptation_seconds)) t$adaptation_seconds else 0
  warm_ratio <- if (t$engine == "JAGS") 2000 / 5000 else 1000 / 2000
  phase_serial <- adapt + t$warmup_seconds * warm_ratio + t$sampling_seconds * ratio
  nonphase <- t$generation_process_seconds - t$warmup_seconds - t$sampling_seconds - adapt
  nonphase <- max(0, nonphase - if (t$compilation_is_inside_generation) t$compilation_seconds else 0)
  overhead_scenario <- nonphase * ratio
  diag_scenario <- t$diagnostic_process_seconds * ratio
  data.frame(run = t$id, proposed_post_per_chain = future_iterations[[t$id]],
    proposed_adapt_per_chain = if (t$engine == "JAGS") 1000L else NA_integer_,
    proposed_burn_or_warmup_per_chain = if (t$engine == "JAGS") 2000L else 1000L,
    phase_serial_seconds = phase_serial, phase_ideal_four_parallel_seconds = phase_serial / 4,
    diagnostic_linear_scenario_seconds = diag_scenario,
    nonphase_linear_scenario_seconds = overhead_scenario,
    total_ideal_parallel_scenario_minutes = (phase_serial / 4 + diag_scenario + overhead_scenario) / 60,
    total_serial_scenario_minutes = (phase_serial + diag_scenario + overhead_scenario) / 60,
    interpretation = "Illustrative phase scaling, not forecast or measured bound; excludes new compilation and hardware contention")
}))
write_csv(runtime, "runtime_scenarios.csv")
write_csv(read_csv(file.path(root, "stan_diagnostics02/HMC_by_chain.csv")), "HMC_existing.csv")
write_csv(read_csv(file.path(root, "stan_diagnostics02/RB_diagnostics.csv")), "RB_existing.csv")
register(file.path(root, "handoff.md"))
register(file.path(root, "stan_diagnostics02/result.json"))
register(file.path(root, "stan_diagnostics02/input_representation.json"))
register("models/experimental/mebane_ad_stan/d_multinomial.stan")
register("R/experimental/mebane_ad_long/stan_bridge.R")
inputs <- lapply(input_paths, function(p) list(path = p, bytes = unname(file.info(p)$size), sha256 = sha(p)))
write_json(list(created_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
  inputs = inputs, packages = as.list(sapply(c("posterior", "jsonlite", "digest"),
                                            function(p) as.character(packageVersion(p)))),
  script_sha256 = sha(file.path(own, "diagnose_existing.R")),
  note = "Descriptive thresholds below 10/50 do not modify frozen criteria. All diagnostic metrics use unthinned draws. No sampler executed."),
  "input_manifest.json")
capture.output(sessionInfo(), file = file.path(out, "sessionInfo.txt"))
print(globals[, c("run", "target", "rank_bulk", "ess_bulk", "ess_tail", "rhat")], row.names = FALSE)
message("Diagnostic artifacts saved in ", out)
