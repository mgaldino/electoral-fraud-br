#!/usr/bin/env Rscript

# Independent reconstruction from persisted chains; never calls either model or runner.
stopifnot(requireNamespace("posterior", quietly = TRUE),
          requireNamespace("jsonlite", quietly = TRUE))

root <- "quality_reports/results/mebane_gates/coordination"
new <- file.path(root, "2026-10-01_ad_long_stan")
out <- file.path(new, "review_jags_results")
data_path <- file.path(root, "2026-09-30_ad_study/data/run-20260930T235038Z-pid61600/dc2010_ad_data.rds")
payload <- readRDS(data_path)
N <- payload$A$N
n <- length(N)
stopifnot(n == 143L, identical(N, payload$D$N),
          identical(unname(payload$A$a), unname(payload$D$observed[, 1])),
          identical(unname(payload$A$w), unname(payload$D$observed[, 2])),
          identical(rownames(payload$D$observed), payload$precinct),
          all(rowSums(payload$D$observed) == N), sum(N) == 452992)
contract <- jsonlite::read_json(file.path(new, "contract.json"), simplifyVector = TRUE)
stopifnot(contract$contract_id == "AD-DC2010-LONG-v1",
          length(contract$diagnostics$analytic_exemptions_in_empirical_pilot) == 0L)

blocks <- c("tau", "nu", "iota.m", "iota.s", "chi.m", "chi.s")
globals <- c(paste0("pi[", 1:3, "]"), paste0(blocks, ".alpha"),
             paste0("beta.", blocks, "1"), c("tb", "nb", "imb", "isb", "cmb", "csb"),
             "M_total", "S_total")
stopifnot(length(globals) == 23L)

read_metric <- function(tab, target) {
  row <- tab[tab$target == target, , drop = FALSE]
  stopifnot(nrow(row) == 1L)
  row
}

extract <- function(chains, name) {
  stopifnot(all(vapply(chains, function(x) name %in% colnames(x), logical(1))))
  x <- vapply(chains, function(chain) as.numeric(chain[, name]), numeric(20000))
  stopifnot(identical(dim(x), c(20000L, 4L)), all(is.finite(x)))
  x
}

check_close <- function(actual, recorded, name, tolerance = 1e-8) {
  if (any(is.na(actual) != is.na(recorded))) stop("NA mismatch: ", name)
  ok <- !is.na(actual)
  delta <- if (any(ok)) max(abs(actual[ok] - recorded[ok])) else 0
  if (!is.finite(delta) || delta > tolerance) stop("Value mismatch: ", name, " delta=", delta)
  delta
}

metrics <- function(x) {
  q <- unname(quantile(as.vector(x), c(.025, .5, .975)))
  suppressWarnings(c(mean = mean(x), sd = sd(as.vector(x)), q025 = q[1],
                     q50 = q[2], q975 = q[3], rhat = posterior::rhat(x),
                     ess_bulk = posterior::ess_bulk(x), ess_tail = posterior::ess_tail(x),
                     mcse_mean = posterior::mcse_mean(x),
                     setNames(colMeans(x), paste0("chain", 1:4))))
}

expected_targets <- function(model) {
  local <- as.vector(outer(c(paste0("mu.", blocks), "p.a", "p.w",
                              if (model == "D") "p.o"), seq_len(n),
                           function(prefix, i) paste0(prefix, "[", i, "]")))
  indicators <- as.vector(outer(seq_len(n), 1:3,
                                function(i, k) paste0("class_indicator[", i, ",", k, "]")))
  c(globals, local, paste0("class_count[", 1:3, "]"), indicators,
    if (model == "A") as.vector(outer(paste0("N.", blocks[3:6]), seq_len(n),
                                      function(prefix, i) paste0(prefix, "[", i, "]"))))
}

inspect_model <- function(model) {
  cat("Reading ", model, " raw chains\n", sep = "")
  base <- file.path(new, "jags20k01")
  run_dir <- file.path(base, model)
  report_dir <- file.path(base, paste0(model, "_diagnostics"))
  raw <- readRDS(file.path(run_dir, "raw_chains.rds"))
  tab <- read.csv(file.path(report_dir, "diagnostics.csv"), check.names = FALSE)
  joint <- read.csv(file.path(report_dir, "joint_functionals.csv"))
  init <- readRDS(file.path(run_dir, "actual_initial_values.rds"))
  actual_data <- readRDS(file.path(run_dir, "actual_jags_data.rds"))
  sampling <- jsonlite::read_json(file.path(run_dir, "sampling_metadata.json"), simplifyVector = TRUE)
  run <- jsonlite::read_json(file.path(run_dir, "run_result.json"), simplifyVector = TRUE)
  diag <- jsonlite::read_json(file.path(report_dir, "diagnostic_result.json"), simplifyVector = TRUE)
  stopifnot(identical(raw$model, model), identical(sampling$model, model),
            identical(run$model, model), identical(diag$model, model),
            identical(raw$contract_sha256, sampling$contract_sha256),
            identical(raw$contract_sha256, diag$contract_sha256),
            identical(as.integer(raw$seeds), as.integer(contract$paired_design$chain_seeds)),
            identical(as.integer(sampling$sampling$chain_seeds), as.integer(raw$seeds)),
            isTRUE(raw$adaptation_adequate), isTRUE(run$adaptation_adequate),
            length(run$warnings) == 0L, length(raw$draws) == 4L,
            length(init) == 4L)
  for (i in 1:4) {
    stopifnot(init[[i]]$.RNG.seed == raw$seeds[i],
              identical(init[[i]]$.RNG.name, "base::Wichmann-Hill"),
              identical(as.integer(init[[i]]$Z), rep(1L, n)),
              isTRUE(all.equal(unname(unlist(init[[i]][c("pi.aux1", "pi.aux2", "pi.aux3")])),
                               c(.8, .2, .1))))
  }
  if (model == "A") {
    stopifnot(isTRUE(all.equal(actual_data, payload$A)))
  } else {
    stopifnot(isTRUE(all.equal(actual_data, payload$D)))
  }
  chains <- lapply(raw$draws, as.matrix)
  names0 <- colnames(chains[[1]])
  stopifnot(all(vapply(chains, function(x) identical(dim(x), dim(chains[[1]])) &&
                      identical(colnames(x), names0), logical(1))),
            all(vapply(raw$draws, function(x) identical(as.integer(attr(x, "mcpar")),
                     c(6001L, 26000L, 1L)), logical(1))),
            all(vapply(chains, nrow, integer(1)) == 20000L))

  M <- matrix(0, 20000, 4)
  S <- matrix(0, 20000, 4)
  class_range_delta <- 0
  class_probability_delta <- 0
  class_table <- read.csv(file.path(report_dir, "class_probabilities.csv"))
  for (u in seq_len(n)) {
    z <- extract(chains, paste0("Z[", u, "]"))
    stopifnot(all(z %in% 1:3))
    tau <- extract(chains, paste0("mu.tau[", u, "]"))
    nu <- extract(chains, paste0("mu.nu[", u, "]"))
    if (model == "A") {
      m2 <- extract(chains, paste0("N.iota.m[", u, "]")) / N[u]
      s2 <- extract(chains, paste0("N.iota.s[", u, "]")) / N[u]
      m3 <- extract(chains, paste0("N.chi.m[", u, "]")) / N[u]
      s3 <- extract(chains, paste0("N.chi.s[", u, "]")) / N[u]
      m2[m2 == 1] <- .999
      s2[s2 == 1] <- .999
    } else {
      m2 <- extract(chains, paste0("mu.iota.m[", u, "]"))
      s2 <- extract(chains, paste0("mu.iota.s[", u, "]"))
      m3 <- extract(chains, paste0("mu.chi.m[", u, "]"))
      s3 <- extract(chains, paste0("mu.chi.s[", u, "]"))
    }
    m <- (z == 2) * m2 + (z == 3) * m3
    s <- (z == 2) * s2 + (z == 3) * s3
    M <- M + N[u] * (1 - tau) * m
    S <- S + N[u] * tau * (1 - nu) * s
    for (k in 1:3) {
      indicator <- (z == k) * 1
      key <- paste0("class_indicator[", u, ",", k, "]")
      range <- diff(range(colMeans(indicator)))
      class_range_delta <- max(class_range_delta,
                               check_close(range, read_metric(tab, key)$chain_mean_range,
                                           paste(model, key, "range")))
      cr <- class_table[class_table$precinct == payload$precinct[u] & class_table$class == k, ]
      stopifnot(nrow(cr) == 1L)
      class_probability_delta <- max(class_probability_delta,
        check_close(mean(indicator), cr$probability, paste(model, key, "probability")))
    }
  }
  for (k in 1:3) {
    count <- matrix(0, 20000, 4)
    for (u in seq_len(n)) count <- count + (extract(chains, paste0("Z[", u, "]")) == k)
    key <- paste0("class_count[", k, "]")
    check_close(diff(range(colMeans(count))) / n,
                read_metric(tab, key)$chain_mean_range, paste(model, key, "range"))
  }
  stopifnot(nrow(joint) == 80000L,
            identical(joint$iteration, rep(1:20000, 4)),
            identical(joint$chain, rep(1:4, each = 20000)))
  joint_delta <- max(check_close(as.vector(M), joint$M, paste(model, "joint M"), 1e-7),
                     check_close(as.vector(S), joint$S, paste(model, "joint S"), 1e-7),
                     check_close(as.vector(M / sum(N)), joint$M_fraction_N,
                                 paste(model, "M/N")),
                     check_close(as.vector(S / sum(N)), joint$S_fraction_N,
                                 paste(model, "S/N")))

  max_global_delta <- 0
  global_failures <- character()
  for (target in globals) {
    x <- if (target == "M_total") M else if (target == "S_total") S else extract(chains, target)
    v <- metrics(x)
    row <- read_metric(tab, target)
    delta <- check_close(v, unlist(row[names(v)], use.names = FALSE),
                         paste(model, target, "metrics"), 1e-6)
    max_global_delta <- max(max_global_delta, delta)
    if (!row$diagnostic_pass) global_failures <- c(global_failures, target)
  }

  expected <- expected_targets(model)
  required <- tab[tab$mandatory, ]
  stopifnot(length(expected) == if (model == "A") 2171L else 1742L,
            nrow(required) == length(expected),
            !anyDuplicated(required$target), setequal(required$target, expected),
            all(tab$analytic_constant == FALSE),
            all(tab$range_limit[tab$group %in% c("class_indicator", "class_count")] == .05),
            all(is.na(tab$range_limit[!tab$group %in% c("class_indicator", "class_count")])))
  finite <- is.finite(required$rhat) & is.finite(required$ess_bulk) &
            is.finite(required$ess_tail) & is.finite(required$chain_mean_range)
  check_range <- required$group %in% c("class_indicator", "class_count")
  independent_pass <- finite & required$rhat < 1.01 & required$ess_bulk >= 400 &
                      required$ess_tail >= 400 &
                      (!check_range | required$chain_mean_range <= .05)
  independent_pass[is.na(independent_pass)] <- FALSE
  stopifnot(identical(independent_pass, required$diagnostic_pass),
            sum(!independent_pass) == diag$failed_targets,
            sum(!finite) == diag$undefined_required_targets,
            all(!independent_pass[!finite]),
            setequal(global_failures, diag$primary_global_failed))
  spot <- c("mu.tau[1]", "p.w[1]", "class_indicator[1,1]", "class_count[1]",
            if (model == "A") "N.iota.m[1]" else "p.o[1]")
  for (target in spot) {
    x <- if (target == "class_count[1]") {
      Reduce(`+`, lapply(seq_len(n), function(u) (extract(chains, paste0("Z[", u, "]")) == 1) * 1))
    } else if (target == "class_indicator[1,1]") {
      (extract(chains, "Z[1]") == 1) * 1
    } else extract(chains, target)
    check_close(metrics(x), unlist(read_metric(tab, target)[names(metrics(x))], use.names = FALSE),
                paste(model, target, "spot metrics"), 1e-6)
  }
  result <- list(model = model, raw_variables = length(names0), chains = 4L,
                 iterations_per_chain = 20000L, mcpar = c(6001L, 26000L, 1L),
                 seeds = raw$seeds, adaptation_adequate = raw$adaptation_adequate,
                 N_total = sum(N), mandatory = nrow(required),
                 failed = sum(!independent_pass), undefined_subset_failed = sum(!finite),
                 global_failed = global_failures, global_failed_count = length(global_failures),
                 max_global_metric_abs_delta = max_global_delta,
                 max_joint_draw_abs_delta = joint_delta,
                 max_class_range_abs_delta = class_range_delta,
                 max_class_probability_abs_delta = class_probability_delta,
                 M_mean = mean(M), S_mean = mean(S),
                 max_global_rhat = max(tab$rhat[tab$group == "global"], na.rm = TRUE),
                 min_global_bulk_ess = min(tab$ess_bulk[tab$group == "global"], na.rm = TRUE),
                 min_global_tail_ess = min(tab$ess_tail[tab$group == "global"], na.rm = TRUE),
                 status = "computationally_inconclusive")
  rm(raw, chains, M, S, tab, joint, init, actual_data)
  invisible(gc())
  cat("Completed ", model, ": ", result$failed, "/", result$mandatory,
      " failed; globals ", result$global_failed_count, "/23\n", sep = "")
  result
}

results <- list(A = inspect_model("A"), D = inspect_model("D"))
jsonlite::write_json(results, file.path(out, "recomputed_results.json"),
                     auto_unbox = TRUE, pretty = TRUE, digits = 16, na = "null")
