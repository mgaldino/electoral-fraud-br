# The same draw-shape and decision rules apply to both experimental models.
source("R/experimental/mebane_ad/io.R")
ad_setup()
if (!requireNamespace("posterior", quietly = TRUE)) stop("Existing posterior package required")

ad_node <- function(matrices, name, index = NULL) {
  keys <- if (is.null(index)) c(name, paste0(name, "[1]")) else
    c(paste0(name, "[", index, "]"), if (index == 1L) name)
  columns <- lapply(matrices, function(x) {
    key <- intersect(keys, colnames(x))
    if (length(key) != 1L) stop("Missing or ambiguous node: ", name, " ", index)
    as.numeric(x[, key])
  })
  do.call(cbind, columns)
}

ad_array <- function(matrices, name, n) {
  ans <- array(NA_real_, c(nrow(matrices[[1]]), length(matrices), n))
  for (i in seq_len(n)) ans[, , i] <- ad_node(matrices, name, i)
  ans
}

ad_metric_pass <- function(metrics, chain_range = 0, range_limit = Inf) {
  length(metrics) >= 3L && all(is.finite(metrics[1:3])) &&
    metrics[1] < 1.01 && metrics[2] >= 400 && metrics[3] >= 400 &&
    is.finite(chain_range) && chain_range <= range_limit
}

ad_diagnostic_row <- function(x, target, group, mandatory = TRUE,
                              range_divisor = 1, range_limit = Inf,
                              analytic_constant = FALSE) {
  stopifnot(is.matrix(x), is.numeric(x), ncol(x) == 4L, nrow(x) == 2000L,
            all(is.finite(x)), range_divisor > 0)
  sampled_constant <- length(unique(as.vector(x))) == 1L
  if (analytic_constant && !sampled_constant) stop("False analytic-constant declaration")
  metrics <- if (analytic_constant) rep(NA_real_, 4) else
    suppressWarnings(c(posterior::rhat(x), posterior::ess_bulk(x),
                       posterior::ess_tail(x), posterior::mcse_mean(x)))
  chain_means <- colMeans(x)
  chain_range <- (max(chain_means) - min(chain_means)) / range_divisor
  diagnostic_pass <- if (analytic_constant) TRUE else
    ad_metric_pass(metrics, chain_range, range_limit)
  q <- unname(quantile(x, c(0.025, 0.5, 0.975)))
  data.frame(target = target, group = group, mandatory = mandatory,
             mean = mean(x), sd = sd(as.vector(x)), q025 = q[1], q50 = q[2], q975 = q[3],
             rhat = metrics[1], ess_bulk = metrics[2], ess_tail = metrics[3],
             mcse_mean = metrics[4], chain1 = chain_means[1], chain2 = chain_means[2],
             chain3 = chain_means[3], chain4 = chain_means[4],
             chain_mean_range = chain_range,
             range_limit = if (is.finite(range_limit)) range_limit else NA_real_,
             sampled_constant = sampled_constant, analytic_constant = analytic_constant,
             diagnostic_pass = diagnostic_pass,
             precision_label = if (analytic_constant) "exact_not_MC" else
               if (diagnostic_pass) "diagnostics_met_only" else "inconclusive",
             stringsAsFactors = FALSE)
}

ad_decision <- function(rows, adaptation_adequate, both_runs_complete = TRUE) {
  ok <- isTRUE(adaptation_adequate) && isTRUE(both_runs_complete) &&
    nrow(rows) > 0L && any(rows$mandatory) &&
    all(rows$diagnostic_pass[rows$mandatory])
  if (ok) "exploratory-comparison-only" else "computationally_inconclusive"
}

ad_process_draws <- function(run_dir, data_path, contract_path, out) {
  start <- Sys.time()
  ad_new_dir(out)
  contract <- jsonlite::read_json(contract_path, simplifyVector = TRUE)
  stopifnot(contract$contract_id == "AD-DC2010-v2",
            length(contract$diagnostics$analytic_exemptions_in_empirical_pilot) == 0L)
  input_path <- file.path(run_dir, "raw_chains.rds")
  payload <- readRDS(data_path)
  raw <- readRDS(input_path)
  run <- jsonlite::read_json(file.path(run_dir, "run_result.json"), simplifyVector = TRUE)
  stopifnot(run$raw_sha256 == ad_sha(input_path),
            raw$contract_sha256 == ad_sha(contract_path),
            identical(as.integer(raw$seeds), as.integer(contract$paired_design$chain_seeds)),
            length(raw$draws) == 4L,
            all(vapply(raw$draws, nrow, integer(1)) == 2000L))
  ad_snapshot(c(input_path, file.path(run_dir, "run_result.json"), data_path,
                contract_path, "R/experimental/mebane_ad/diagnostics.R",
                "R/experimental/mebane_ad/io.R"), file.path(out, "consumed_sources"))
  matrices <- lapply(raw$draws, as.matrix)
  stopifnot(all(vapply(matrices, function(x) identical(colnames(x), colnames(matrices[[1]])), logical(1))))
  model <- raw$model
  N <- payload$A$N
  W <- payload$A$w
  n <- length(N)
  Z <- ad_array(matrices, "Z", n)
  tau <- ad_array(matrices, "mu.tau", n)
  nu <- ad_array(matrices, "mu.nu", n)
  stopifnot(all(Z %in% 1:3), all(tau > 0 & tau < 1), all(nu > 0 & nu < 1))
  means <- lapply(c("iota.m", "iota.s", "chi.m", "chi.s"), function(b)
    ad_array(matrices, paste0("mu.", b), n))
  if (model == "A") {
    counts <- lapply(c("iota.m", "iota.s", "chi.m", "chi.s"), function(b)
      ad_array(matrices, paste0("N.", b), n))
    fractions <- lapply(counts, function(x) sweep(x, 3, N, "/"))
    for (b in c(1L, 3L)) fractions[[b]][fractions[[b]] == 1] <- 0.999
  } else {
    fractions <- means
  }
  m <- (Z == 2) * fractions[[1]] + (Z == 3) * fractions[[3]]
  s <- (Z == 2) * fractions[[2]] + (Z == 3) * fractions[[4]]
  M_by_unit <- sweep((1 - tau) * m, 3, N, "*")
  S_by_unit <- sweep(tau * (1 - nu) * s, 3, N, "*")
  M_total <- apply(M_by_unit, c(1, 2), sum)
  S_total <- apply(S_by_unit, c(1, 2), sum)
  rows <- list()
  add <- function(x, target, group, ...) {
    rows[[length(rows) + 1L]] <<- ad_diagnostic_row(x, target, group, ...)
  }
  blocks <- c("tau", "nu", "iota.m", "iota.s", "chi.m", "chi.s")
  for (k in 1:3) add(ad_node(matrices, "pi", k), paste0("pi[", k, "]"), "global")
  for (name in c(paste0(blocks, ".alpha"), paste0("beta.", blocks, "1"),
                 "tb", "nb", "imb", "isb", "cmb", "csb")) {
    add(ad_node(matrices, name), name, "global")
  }
  add(M_total, "M_total", "global")
  add(S_total, "S_total", "global")
  add(M_total / sum(N), "M_fraction_N", "scaled_functional", mandatory = FALSE)
  add(S_total / sum(N), "S_fraction_N", "scaled_functional", mandatory = FALSE)
  for (name in c(paste0("mu.", blocks), "p.a", "p.w", if (model == "D") "p.o")) {
    for (i in seq_len(n)) add(ad_node(matrices, name, i), paste0(name, "[", i, "]"), "local_continuous")
  }
  class_rows <- list()
  for (k in 1:3) {
    indicator <- (Z == k) * 1
    class_count <- apply(indicator, c(1, 2), sum)
    add(class_count, paste0("class_count[", k, "]"), "class_count", range_divisor = n, range_limit = 0.05)
    for (i in seq_len(n)) {
      add(indicator[, , i], paste0("class_indicator[", i, ",", k, "]"),
          "class_indicator", range_limit = 0.05)
      cm <- colMeans(indicator[, , i])
      class_rows[[length(class_rows) + 1L]] <- data.frame(
        precinct = payload$precinct[i], class = k, probability = mean(cm),
        chain1 = cm[1], chain2 = cm[2], chain3 = cm[3], chain4 = cm[4])
    }
  }
  if (model == "A") for (name in paste0("N.", blocks[3:6])) {
    for (i in seq_len(n)) add(ad_node(matrices, name, i), paste0(name, "[", i, "]"), "A_auxiliary")
  }
  joint <- data.frame(iteration = rep(1:2000, 4), chain = rep(1:4, each = 2000),
                      M = as.vector(M_total), S = as.vector(S_total),
                      M_fraction_N = as.vector(M_total / sum(N)),
                      S_fraction_N = as.vector(S_total / sum(N)))
  support <- list(model = model, expected_functionals_are_ballot_counts = FALSE,
                  A_literal_source_preserved = TRUE,
                  expected_M_plus_S_gt_observed_W_fraction =
                    mean(sweep(M_by_unit + S_by_unit, 3, W, ">")),
                  N_total = sum(N), W_total = sum(W))
  if (model == "D") {
    set.seed(contract$paired_design$postprocess_seed)
    M_count <- S_count <- M_cond_mean <- S_cond_mean <- array(0, dim(Z))
    max_probability_error <- 0
    for (i in seq_len(n)) {
      qL <- tau[, , i] * nu[, , i]
      qM <- (1 - tau[, , i]) * m[, , i]
      qS <- tau[, , i] * (1 - nu[, , i]) * s[, , i]
      denominator <- qL + qM + qS
      max_probability_error <- max(max_probability_error,
        abs(denominator - ad_node(matrices, "p.w", i)))
      if (any(denominator == 0) && W[i] != 0) stop("Impossible W at zero pW")
      positive <- denominator > 0
      M_cond_mean[, , i][positive] <- W[i] * qM[positive] / denominator[positive]
      S_cond_mean[, , i][positive] <- W[i] * qS[positive] / denominator[positive]
      for (chain in 1:4) for (iteration in 1:2000) {
        q <- c(qL[iteration, chain], qM[iteration, chain], qS[iteration, chain])
        x <- if (sum(q) == 0) c(0, 0, 0) else
          as.vector(rmultinom(1, size = W[i], prob = q / sum(q)))
        M_count[iteration, chain, i] <- x[2]
        S_count[iteration, chain, i] <- x[3]
      }
    }
    stopifnot(max_probability_error < 1e-11,
              all(M_count >= 0), all(S_count >= 0),
              all(sweep(M_count + S_count, 3, W, "<=")))
    M_ct <- apply(M_count, c(1, 2), sum)
    S_ct <- apply(S_count, c(1, 2), sum)
    add(M_ct, "M_count_total", "D_secondary", mandatory = FALSE)
    add(S_ct, "S_count_total", "D_secondary", mandatory = FALSE)
    joint$M_count <- as.vector(M_ct)
    joint$S_count <- as.vector(S_ct)
    joint$M_count_conditional_mean <- as.vector(apply(M_cond_mean, c(1, 2), sum))
    joint$S_count_conditional_mean <- as.vector(apply(S_cond_mean, c(1, 2), sum))
    saveRDS(list(M = M_count, S = S_count, precinct = payload$precinct,
                 postprocess_seed = contract$paired_design$postprocess_seed),
            file.path(out, "secondary_counts_by_unit.rds"))
    support$conditional_counts_support_pass <- TRUE
    support$conditional_probability_error_max <- max_probability_error
  }
  diagnostics <- do.call(rbind, rows)
  stopifnot(sum(diagnostics$group == "global") == 23L,
            !any(diagnostics$analytic_constant))
  classes <- do.call(rbind, class_rows)
  classes$modal <- ave(classes$probability, classes$precinct,
                       FUN = function(x) x == max(x)) == 1
  write.csv(diagnostics, file.path(out, "diagnostics.csv"), row.names = FALSE)
  write.csv(classes, file.path(out, "class_probabilities.csv"), row.names = FALSE)
  write.csv(joint, file.path(out, "joint_functionals.csv"), row.names = FALSE)
  ad_json(support, file.path(out, "support_checks.json"))
  required <- diagnostics[diagnostics$mandatory, ]
  result <- list(model = model,
                 status = ad_decision(diagnostics, raw$adaptation_adequate),
                 mandatory_targets = nrow(required),
                 failed_targets = sum(!required$diagnostic_pass),
                 undefined_required_targets = sum(!is.finite(required$rhat) |
                   !is.finite(required$ess_bulk) | !is.finite(required$ess_tail)),
                 primary_global_failed = as.character(diagnostics$target[
                   diagnostics$group == "global" & !diagnostics$diagnostic_pass]),
                 elapsed_seconds = as.numeric(difftime(Sys.time(), start, units = "secs")),
                 raw_sha256 = ad_sha(input_path), contract_sha256 = ad_sha(contract_path),
                 shape = c(iterations = 2000L, chains = 4L),
                 production_approved = FALSE, G10_approved = FALSE)
  ad_json(result, file.path(out, "diagnostic_result.json"))
  ad_manifest(out, note = "Raw draw diagnostics, joint functionals and secondary D reconstruction; not electoral inference")
  print(result)
  invisible(result)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 4L) stop("Usage: diagnostics.R RUN_DIR DATA_RDS CONTRACT_JSON NEW_OUT_DIR")
  ad_process_draws(args[1], args[2], args[3], args[4])
}
