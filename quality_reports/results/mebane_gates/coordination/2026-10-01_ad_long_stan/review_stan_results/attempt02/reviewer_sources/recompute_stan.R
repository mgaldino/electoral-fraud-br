#!/usr/bin/env Rscript

# Written during sampling. Execute only through run_qa.py after the user's release.
if (Sys.getenv("STAN_RESULTS_QA_RELEASED") != "1") {
  stop("The user has not released the results-QA execution window.")
}
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 2L)
repo <- normalizePath(getwd())
lib <- file.path(repo, "renv/library/macos/R-4.4/aarch64-apple-darwin20")
if (dir.exists(lib)) .libPaths(c(lib, .libPaths()))
stopifnot(requireNamespace("posterior", quietly = TRUE),
          requireNamespace("jsonlite", quietly = TRUE))
binding <- jsonlite::read_json(args[1], simplifyVector = TRUE)
out <- normalizePath(args[2], mustWork = TRUE)
scope <- file.path(repo, "quality_reports/results/mebane_gates/coordination/2026-10-01_ad_long_stan/review_stan_results")
stopifnot(startsWith(out, paste0(scope, "/")),
          identical(binding$execution_window_released, TRUE),
          identical(binding$analysis_mode, "completed"))

new <- file.path(repo, "quality_reports/results/mebane_gates/coordination/2026-10-01_ad_long_stan")
run <- file.path(new, "stan2k01")
diagnostics <- file.path(new, "stan_diagnostics02")
stopifnot(identical(binding$productive_diagnostics,
  "quality_reports/results/mebane_gates/coordination/2026-10-01_ad_long_stan/stan_diagnostics02"))
common <- file.path(diagnostics, "common_diagnostics")
checks <- list()

check <- function(id, ok, evidence = NULL) {
  checks[[length(checks) + 1L]] <<- list(id = id, pass = isTRUE(ok), evidence = evidence)
  if (!isTRUE(ok)) stop(id, call. = FALSE)
}

near <- function(actual, expected, id, atol = 1e-8, rtol = 1e-10) {
  check(paste0(id, ":length"), length(actual) == length(expected))
  check(paste0(id, ":NA-mask"), identical(is.na(as.vector(actual)), is.na(as.vector(expected))))
  keep <- !is.na(actual)
  a <- as.numeric(actual[keep])
  b <- as.numeric(expected[keep])
  check(paste0(id, ":finite"), all(is.finite(a)) && all(is.finite(b)))
  difference <- if (length(a)) max(abs(a - b)) else 0
  check(id, all(abs(a - b) <= atol + rtol * abs(b)), list(max_abs_difference = difference))
  invisible(difference)
}

save_json <- function(value, name) {
  path <- file.path(out, name)
  stopifnot(!file.exists(path))
  jsonlite::write_json(value, path, auto_unbox = TRUE, pretty = TRUE,
                       digits = 16, na = "null")
}

save_csv <- function(value, name) {
  path <- file.path(out, name)
  stopifnot(!file.exists(path))
  write.csv(value, path, row.names = FALSE, na = "NA")
}

read_table <- function(path) read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)

metric_row <- function(x, name, divisor = 1, range_limit = Inf) {
  check(paste0(name, ":matrix"), is.matrix(x) && identical(dim(x), c(2000L, 4L)) &&
          all(is.finite(x)))
  quantiles <- unname(quantile(as.vector(x), c(.025, .5, .975)))
  chain_means <- colMeans(x)
  diagnostic <- suppressWarnings(c(posterior::rhat(x), posterior::ess_bulk(x),
                                    posterior::ess_tail(x), posterior::mcse_mean(x)))
  chain_range <- diff(range(chain_means)) / divisor
  pass <- all(is.finite(diagnostic[1:3])) && diagnostic[1] < 1.01 &&
    diagnostic[2] >= 400 && diagnostic[3] >= 400 &&
    is.finite(chain_range) && chain_range <= range_limit
  data.frame(target = name, mean = mean(x), sd = sd(as.vector(x)),
             q025 = quantiles[1], q50 = quantiles[2], q975 = quantiles[3],
             rhat = diagnostic[1], ess_bulk = diagnostic[2], ess_tail = diagnostic[3],
             mcse_mean = diagnostic[4], chain1 = chain_means[1], chain2 = chain_means[2],
             chain3 = chain_means[3], chain4 = chain_means[4],
             chain_mean_range = chain_range, diagnostic_pass = pass,
             stringsAsFactors = FALSE)
}

stored_row <- function(table, name) {
  found <- table[table$target == name, , drop = FALSE]
  check(paste0(name, ":one-stored-row"), nrow(found) == 1L)
  found
}

compare_row <- function(recomputed, table, prefix) {
  old <- stored_row(table, recomputed$target)
  fields <- setdiff(names(recomputed), c("target", "diagnostic_pass"))
  near(unlist(recomputed[fields], use.names = FALSE), unlist(old[fields], use.names = FALSE),
       paste0(prefix, ":", recomputed$target), atol = 1e-7)
  check(paste0(prefix, ":", recomputed$target, ":pass"),
        identical(recomputed$diagnostic_pass, old$diagnostic_pass))
}

leading_comments <- function(path) {
  connection <- file(path, "rt")
  on.exit(close(connection))
  lines <- character()
  repeat {
    line <- readLines(connection, n = 1L, warn = FALSE)
    if (!length(line)) stop("CSV header absent: ", path)
    if (!nzchar(trimws(line))) next
    if (!startsWith(line, "#")) break
    lines <- c(lines, line)
  }
  lines
}

csv_setting <- function(header, name) {
  pattern <- paste0("^#\\s*", name, "\\s*=\\s*")
  selected <- grep(pattern, header, value = TRUE)
  check(paste0("CSV:", name, ":metadata"), length(selected) == 1L)
  value <- sub(" .*", "", sub(pattern, "", selected))
  if (value %in% c("true", "false")) return(as.numeric(value == "true"))
  as.numeric(value)
}

stan_csv_name <- function(name) {
  pieces <- strsplit(name, ".", fixed = TRUE)[[1]]
  if (length(pieces) == 1L) name else
    paste0(pieces[1], "[", paste(pieces[-1], collapse = ","), "]")
}

main <- function() {
  payload <- readRDS(file.path(repo, paste0(
    "quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/",
    "data/run-20260930T235038Z-pid61600/dc2010_ad_data.rds")))
  N <- payload$D$N
  check("data:143-units", length(N) == 143L && sum(N) == 452992 &&
          identical(payload$precinct, rownames(payload$D$observed)))
  draws <- unclass(readRDS(file.path(run, "draws_array.rds")))
  sampler <- unclass(readRDS(file.path(run, "sampler_diagnostics.rds")))
  check("raw:shape", length(dim(draws)) == 3L &&
          identical(as.integer(dim(draws)[1:2]), c(2000L, 4L)))
  check("sampler:shape", length(dim(sampler)) == 3L &&
          identical(as.integer(dim(sampler)[1:2]), c(2000L, 4L)))
  raw_names <- dimnames(draws)[[3]]
  check("raw:unique-names", !anyDuplicated(raw_names))
  check("raw:143-Z-names", setequal(grep("^Z\\[[0-9]+\\]$", raw_names, value = TRUE), paste0("Z[", 1:143, "]")))
  check("raw:chain-order", identical(as.integer(dimnames(draws)[[2]]), 1:4))
  check("sampler:chain-order", identical(dimnames(draws)[[2]], dimnames(sampler)[[2]]))
  node <- function(name) {
    check(paste0("node:", name), name %in% raw_names)
    matrix(draws[, , name], nrow = 2000L, ncol = 4L)
  }

  # Read each CSV separately; retained draws must be its final 2000 rows.
  csv_files <- list.files(file.path(run, "csv"), pattern = "\\.csv$", full.names = TRUE)
  check("CSV:four-files", length(csv_files) == 4L)
  seen <- integer()
  for (path in csv_files) {
    header <- leading_comments(path)
    chain <- as.integer(csv_setting(header, "id"))
    check("CSV:chain-id", chain %in% 1:4 && !(chain %in% seen))
    seen <- c(seen, chain)
    for (setting in c("num_samples", "num_warmup")) {
      check(paste0("CSV:", chain, ":", setting), csv_setting(header, setting) == 2000)
    }
    check(paste0("CSV:", chain, ":seed"), csv_setting(header, "seed") == 1001261)
    check(paste0("CSV:", chain, ":thin"), csv_setting(header, "thin") == 1)
    check(paste0("CSV:", chain, ":warmup-saved"), csv_setting(header, "save_warmup") == 1)
    values <- read.csv(path, comment.char = "#", check.names = FALSE, colClasses = "numeric")
    names(values) <- vapply(names(values), stan_csv_name, character(1))
    check(paste0("CSV:", chain, ":4000-rows"), nrow(values) == 4000L && !anyDuplicated(names(values)))
    retained <- values[2001:4000, , drop = FALSE]
    check(paste0("CSV:", chain, ":names"), all(raw_names %in% names(retained)))
    near(as.matrix(retained[raw_names]), draws[, chain, ], paste0("CSV:", chain, ":raw-values"))
    sampler_names <- dimnames(sampler)[[3]]
    check(paste0("CSV:", chain, ":sampler-names"), all(sampler_names %in% names(retained)))
    near(as.matrix(retained[sampler_names]), sampler[, chain, ],
         paste0("CSV:", chain, ":sampler-values"))
    rm(values, retained)
    invisible(gc())
  }

  table <- read_table(file.path(common, "diagnostics.csv"))
  blocks <- c("tau", "nu", "iota.m", "iota.s", "chi.m", "chi.s")
  common_globals <- c(paste0("pi[", 1:3, "]"), paste0(blocks, ".alpha"),
                      paste0("beta.", blocks, "1"), "tb", "nb", "imb", "isb", "cmb", "csb",
                      "M_total", "S_total")
  original_globals <- c(paste0("pi[", 1:3, "]"), paste0("alpha[", 1:6, "]"),
                        paste0("b0[", 1:6, "]"), paste0("v[", 1:6, "]"), "M_total", "S_total")
  global_map <- setNames(original_globals, common_globals)
  M <- S <- M_RB <- S_RB <- matrix(0, 2000, 4)
  counts <- lapply(1:3, function(k) matrix(0, 2000, 4))
  class_ranges <- list()
  for (i in seq_len(143L)) {
    Z <- node(paste0("Z[", i, "]"))
    check(paste0("Z:", i, ":support"), all(Z %in% 1:3))
    mu <- lapply(1:6, function(b) {
      variance <- node(paste0("v[", b, "]"))
      check(paste0("variance:", b, ":nonnegative"), all(variance >= 0))
      eta <- node(paste0("alpha[", b, "]")) + node(paste0("b0[", b, "]")) +
        sqrt(variance) * node(paste0("z[", i, ",", b, "]"))
      value <- plogis(eta)
      if (b %in% 3:4) value <- .7 * value
      if (b %in% 5:6) value <- .7 + .3 * value
      near(value, node(paste0("mu[", i, ",", b, "]")), paste0("mu:", i, ":", b))
      value
    })
    m <- (Z == 2) * mu[[3]] + (Z == 3) * mu[[5]]
    s <- (Z == 2) * mu[[4]] + (Z == 3) * mu[[6]]
    M <- M + N[i] * (1 - mu[[1]]) * m
    S <- S + N[i] * mu[[1]] * (1 - mu[[2]]) * s
    near((1 - mu[[1]]) * (1 - m), node(paste0("pA[", i, "]")), paste0("pA:", i))
    near(mu[[1]] * mu[[2]] + (1 - mu[[1]]) * m + mu[[1]] * (1 - mu[[2]]) * s,
         node(paste0("pW[", i, "]")), paste0("pW:", i))
    near(mu[[1]] * (1 - mu[[2]]) * (1 - s), node(paste0("pO[", i, "]")), paste0("pO:", i))
    weights <- lapply(1:3, function(k) node(paste0("responsibility[", i, ",", k, "]")))
    check(paste0("responsibility:", i, ":support"), all(unlist(weights) >= 0) && all(unlist(weights) <= 1))
    near(Reduce(`+`, weights), matrix(1, 2000, 4), paste0("responsibility:", i, ":sum"))
    M_RB <- M_RB + N[i] * (1 - mu[[1]]) * (weights[[2]] * mu[[3]] + weights[[3]] * mu[[5]])
    S_RB <- S_RB + N[i] * mu[[1]] * (1 - mu[[2]]) * (weights[[2]] * mu[[4]] + weights[[3]] * mu[[6]])
    for (k in 1:3) {
      indicator <- 1 * (Z == k)
      counts[[k]] <- counts[[k]] + indicator
      key <- paste0("class_indicator[", i, ",", k, "]")
      means <- colMeans(indicator)
      row <- stored_row(table, key)
      near(c(mean(indicator), means, diff(range(means))),
           unlist(row[c("mean", paste0("chain", 1:4), "chain_mean_range")], use.names = FALSE), key)
      class_ranges[[length(class_ranges) + 1L]] <- data.frame(target = key, chain_range = diff(range(means)))
    }
  }
  near(M, node("M_total"), "joint:M-original", atol = 1e-7)
  near(S, node("S_total"), "joint:S-original", atol = 1e-7)
  near(M_RB, node("M_RB_total"), "RB:M-original", atol = 1e-7)
  near(S_RB, node("S_RB_total"), "RB:S-original", atol = 1e-7)
  joint <- read_table(file.path(common, "joint_functionals.csv"))
  check("joint:order", nrow(joint) == 8000L && identical(joint$iteration, rep(1:2000, 4)) &&
          identical(joint$chain, rep(1:4, each = 2000)))
  near(as.vector(M), joint$M, "joint:M-csv", atol = 1e-7)
  near(as.vector(S), joint$S, "joint:S-csv", atol = 1e-7)
  near(as.vector(M / sum(N)), joint$M_fraction_N, "joint:M-fraction")
  near(as.vector(S / sum(N)), joint$S_fraction_N, "joint:S-fraction")
  globals <- do.call(rbind, lapply(common_globals, function(name) {
    x <- if (name == "M_total") M else if (name == "S_total") S else node(global_map[[name]])
    row <- metric_row(x, name)
    compare_row(row, table, "global")
    row
  }))
  save_csv(globals, "globals_recomputed.csv")
  for (k in 1:3) compare_row(metric_row(counts[[k]], paste0("class_count[", k, "]"),
                                      divisor = 143, range_limit = .05), table, "class-count")
  save_csv(do.call(rbind, class_ranges), "class_ranges_recomputed.csv")

  local_targets <- unlist(lapply(c(paste0("mu.", blocks), "p.a", "p.w", "p.o"),
                                 function(prefix) paste0(prefix, "[", 1:143, "]")))
  indicator_targets <- unlist(lapply(1:3, function(k) paste0("class_indicator[", 1:143, ",", k, "]")))
  expected <- c(common_globals, local_targets, paste0("class_count[", 1:3, "]"), indicator_targets)
  required <- table[table$mandatory, , drop = FALSE]
  check("common:mandatory-universe", nrow(required) == 1742L && !anyDuplicated(required$target) &&
          setequal(required$target, expected) && !anyNA(table$mandatory) && all(!table$analytic_constant))
  check("common:group-labels", setequal(table$target[table$group == "global"], common_globals) &&
          setequal(table$target[table$group == "local_continuous"], local_targets) &&
          setequal(table$target[table$group == "class_indicator"], indicator_targets) &&
          setequal(table$target[table$group == "class_count"], paste0("class_count[", 1:3, "]")) &&
          !any(grepl("RB", table$target)))
  class_row <- required$target %in% c(paste0("class_count[", 1:3, "]"), indicator_targets)
  check("common:range-contract", all(required$range_limit[class_row] == .05) &&
          all(is.na(required$range_limit[!class_row])) && all(is.finite(required$chain_mean_range)))
  undefined <- !is.finite(required$rhat) | !is.finite(required$ess_bulk) | !is.finite(required$ess_tail)
  pass <- !undefined & required$rhat < 1.01 & required$ess_bulk >= 400 & required$ess_tail >= 400 &
    (!class_row | required$chain_mean_range <= .05)
  pass[is.na(pass)] <- FALSE
  check("common:all-1742-decisions", identical(pass, required$diagnostic_pass))
  check("common:undefined-is-subset-failed", all(!pass[undefined]))
  save_csv(data.frame(target = required$target, group = required$group,
                      undefined = undefined, recomputed_pass = pass), "common_decisions.csv")

  internal_names <- c(unlist(lapply(1:6, function(b) paste0("z[", 1:143, ",", b, "]"))), "r[1]", "r[2]")
  internal_stored <- read_table(file.path(diagnostics, "NCP_diagnostics.csv"))
  raw_internal <- grep("^(z\\[|r\\[)", raw_names, value = TRUE)
  check("NCP:860-exact-names", length(raw_internal) == 860L && setequal(raw_internal, internal_names) &&
          nrow(internal_stored) == 860L && !anyDuplicated(internal_stored$target) &&
          setequal(internal_stored$target, internal_names) && all(internal_stored$mandatory) &&
          all(!internal_stored$analytic_constant))
  ncp <- do.call(rbind, lapply(internal_names, function(name) {
    row <- metric_row(node(name), name)
    compare_row(row, internal_stored, "NCP")
    row
  }))
  save_csv(ncp, "NCP_recomputed.csv")

  check("HMC:required-columns", all(c("energy__", "divergent__", "treedepth__") %in% dimnames(sampler)[[3]]))
  hmc <- do.call(rbind, lapply(1:4, function(k) {
    energy <- sampler[, k, "energy__"]
    denominator <- sum((energy - mean(energy))^2)
    # The two (iterations - 1) denominators cancel in mean(diff(E)^2) / var(E).
    ebfmi <- if (is.finite(denominator) && denominator > 0) sum(diff(energy)^2) / denominator else NA_real_
    data.frame(chain = k, divergences = sum(sampler[, k, "divergent__"]),
               treedepth_hits = sum(sampler[, k, "treedepth__"] >= 12), ebfmi = ebfmi)
  }))
  hmc_old <- read_table(file.path(diagnostics, "HMC_by_chain.csv"))
  check("HMC:four-ordered-chains", identical(hmc_old$chain, 1:4))
  near(as.matrix(hmc), as.matrix(hmc_old[names(hmc)]), "HMC:all-metrics")
  hmc_pass <- isTRUE(all(is.finite(hmc$ebfmi) & hmc$ebfmi >= .3 &
                    hmc$divergences == 0 & hmc$treedepth_hits == 0))
  save_csv(hmc, "HMC_recomputed.csv")

  rb_old <- read_table(file.path(diagnostics, "RB_diagnostics.csv"))
  check("RB:secondary-only", nrow(rb_old) == 2L && all(!rb_old$mandatory) &&
          all(rb_old$group == "Rao_Blackwell_secondary") &&
          !any(c("M_RB_total", "S_RB_total") %in% required$target))
  rb <- rbind(metric_row(M_RB, "M_RB_total"), metric_row(S_RB, "S_RB_total"))
  for (i in 1:2) compare_row(rb[i, ], rb_old, "RB")
  save_csv(rb, "RB_recomputed.csv")

  common_result <- jsonlite::read_json(file.path(common, "diagnostic_result.json"), simplifyVector = TRUE)
  result <- jsonlite::read_json(file.path(diagnostics, "result.json"), simplifyVector = TRUE)
  check("result:nested-common", isTRUE(all.equal(result$common_result, common_result)))
  expected_status <- if (all(pass) && all(ncp$diagnostic_pass) && hmc_pass)
    "diagnostics_met_for_this_model" else "computationally_inconclusive"
  check("result:counts", common_result$mandatory_targets == 1742L &&
          common_result$failed_targets == sum(!pass) &&
          common_result$undefined_required_targets == sum(undefined) &&
          result$internal_targets == 860L && result$NCP_failed == sum(!ncp$diagnostic_pass))
  check("result:status", identical(common_result$status, expected_status) &&
          identical(result$status, expected_status) && identical(result$HMC_checks_pass, hmc_pass))
  check("result:no-production", identical(result$production_approved, FALSE) && identical(result$G10_approved, FALSE))
  save_json(list(execution_status = "checks_completed", reviewer_id = binding$reviewer_id,
                 common_targets = 1742L, common_failed = sum(!pass),
                 common_undefined_subset_failed = sum(undefined), globals_recomputed = 23L,
                 global_failed = globals$target[!globals$diagnostic_pass],
                 global_failed_count = sum(!globals$diagnostic_pass),
                 internal_targets = 860L, internal_failed = sum(!ncp$diagnostic_pass),
                 HMC_pass = hmc_pass, RB_is_secondary = TRUE, status_confirmed = expected_status,
                 posterior_version = as.character(utils::packageVersion("posterior")),
                 csvs_checked_against_original_RDS = 4L,
                 local_metric_scope = "All common decisions; raw class ranges and counts. Local Rhat/ESS not recomputed exhaustively.",
                 final_review_pending = TRUE), "recomputed_summary.json")
  rm(draws, sampler, M, S, M_RB, S_RB)
  invisible(gc())
}

outcome <- tryCatch({ main(); list(status = "checks_completed") }, error = function(error) {
  list(status = "checker_stopped_requires_adjudication", error = conditionMessage(error))
})
save_json(list(outcome = outcome, checks = checks), "recompute_checks.json")
if (outcome$status != "checks_completed") stop(outcome$error, call. = FALSE)
