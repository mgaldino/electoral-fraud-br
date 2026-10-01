# Deterministic review of frozen native libraries. No compilation or sampling.
root <- normalizePath(".")
.libPaths(c(file.path(root, "renv/library/macos/R-4.4/aarch64-apple-darwin20"), .libPaths()))
for (p in c("Rcpp", "jsonlite", "digest")) stopifnot(requireNamespace(p, quietly = TRUE))
base <- file.path(root, "quality_reports/results/mebane_gates/coordination/2026-10-01_ad_long_stan")
review <- file.path(base, "review/stan")
prep <- file.path(base, "stan_impl/run-20261001T105406Z-attempt03-01a0f4b5/preparation")
source(file.path(review, "oracles.R"))
out <- file.path(review, "compiled_checks01")
stopifnot(!file.exists(out), dir.create(out))
sha <- function(p) digest::digest(file = p, algo = "sha256", serialize = FALSE)
write_new <- function(x, p) {
  stopifnot(!file.exists(p))
  jsonlite::write_json(x, p, auto_unbox = TRUE, pretty = TRUE, digits = NA, na = "null")
}
run <- function() {
  results <- list()
  check <- function(name, code) {
    error <- tryCatch({force(code); NULL}, error = function(e) conditionMessage(e))
    results[[length(results) + 1L]] <<- list(name = name, pass = is.null(error), error = error)
    cat(if (is.null(error)) "PASS" else "FAIL", name, if (!is.null(error)) error else "", "\n")
    is.null(error)
  }
  on.exit(write_new(list(
    status = if (all(vapply(results, `[[`, logical(1), "pass"))) "pass" else "needs_revision",
    reviewer_id = "01a0f4b8-962b-77a3-a418-6247c6219e8b",
    preparation_manifest_sha256 = "2ad3246c3b1a5b5e0c676a85434824644b440cc75c386bc45feeabc34b789bfb",
    adapter_manifest_sha256 = "3562d593731cec1fe156ee52266a975cd0cbf6d6fe8666c26b15652298bb08b0",
    checks = results, empirical_MCMC = FALSE, compilation = FALSE,
    generated_new_Stan_draws = FALSE, completed_utc = format(Sys.time(), tz = "UTC", usetz = TRUE)),
    file.path(out, "checks.json")), add = TRUE)
  manifest_path <- file.path(prep, "manifest.json")
  preflight_path <- file.path(prep, "preflight_manifest.json")
  adapter_path <- file.path(base, "stan_diagnostic_candidate/manifest.json")
  stopifnot(sha(manifest_path) == "2ad3246c3b1a5b5e0c676a85434824644b440cc75c386bc45feeabc34b789bfb",
            sha(preflight_path) == "7169d8b0e2536739ad2b2a9a9b9f6bfb471b9e6da3424aaad7cf86bd801d0c23",
            sha(adapter_path) == "3562d593731cec1fe156ee52266a975cd0cbf6d6fe8666c26b15652298bb08b0")
  manifests <- lapply(c(manifest_path, preflight_path, adapter_path), jsonlite::read_json)
  records <- c(manifests[[1]]$files, manifests[[2]]$files)
  check("preparation_and_preflight_all_file_hashes", {
    for (f in records) stopifnot(sha(f$path) == f$sha256)
  })
  check("adapter_all_14_sources_and_snapshots", {
    for (f in manifests[[3]]$files) stopifnot(sha(file.path(root, f$path)) == f$sha256,
                                            sha(file.path(root, f$snapshot)) == f$sha256)
  })
  write_new(list(preparation_files = length(manifests[[1]]$files),
                 preflight_files = length(manifests[[2]]$files), adapter_files = length(manifests[[3]]$files),
                 executable = manifests[[1]]$executable, executable_sha256 = sha(manifests[[1]]$executable),
                 model_sha256 = sha(file.path(prep, "sources/models/experimental/mebane_ad_stan/d_multinomial.stan")),
                 compile_seconds = manifests[[1]]$compile_seconds, compile_scope = manifests[[1]]$compile_scope),
            file.path(out, "binding.json"))

  # Load the exact Rcpp interfaces archived by the implementer; no sourceCpp rebuild.
  products <- file.path(prep, "compiler_products/sourceCpp-aarch64-apple-darwin20-1.1.1")
  dll <- dyn.load(file.path(products, "sourcecpp_115aa10ddd9e4/sourceCpp_2.so"))
  fn_dll <- dyn.load(file.path(products, "sourcecpp_115aa51870d84/sourceCpp_4.so"))
  native <- function(name, ...) .Call(getNativeSymbolInfo(paste0("sourceCpp_1_", name), dll)$address, ...)
  standalone <- function(name, ...) .Call(getNativeSymbolInfo(paste0("sourceCpp_3_", name), fn_dll)$address, ...)
  data_file <- file.path(prep, "tests/synthetic_data.json")
  data <- jsonlite::read_json(data_file, simplifyVector = TRUE)
  ptr <- native("model_ptr", data_file, 1001291L)$model_ptr
  fit <- list(log_prob = function(u, jacobian = TRUE) native("log_prob", ptr, as.numeric(u), jacobian),
              grad_log_prob = function(u, jacobian = TRUE) native("grad_log_prob", ptr, as.numeric(u), jacobian),
              unconstrain_variables = function(p) native("unconstrain_variables", ptr,
                c(p$alpha, p$b0, p$v, as.vector(p$z), p$r)))
  p <- list(alpha = c(.23, -.37, .62, -.48, .17, -.83),
            b0 = c(.002, -.007, .009, .004, -.003, .006),
            v = c(.13, .27, .08, .52, .31, .19),
            z = matrix(seq(-.67, .94, length.out = 6 * data$n), data$n, 6), r = c(.72, .19))
  states <- list(p, within(p, r <- rev(r)), within(p, v <- c(1e-6, .04, .4, .9, .21, .18)),
                 within(p, {alpha <- alpha + c(.12, -.2, .3, -.1, .4, -.3); b0 <- -b0}))
  check("native_log_densities_Jacobians_NCP_and_gradients", {
    answer <- review_compiled_density(fit, states, data)
    write_new(answer, file.path(out, "density_gradient_errors.json"))
  })
  check("mixture_not_multinomial_at_average_probability", {
    f <- review_forward(p, data)
    wrong <- sum(vapply(seq_len(data$n), function(i)
      dmultinom(data$observed[i, ], prob = as.numeric(f$pi %*% f$rows[[i]]$p), log = TRUE), numeric(1)))
    correct <- sum(vapply(f$rows, `[[`, numeric(1), "log_mass"))
    stopifnot(abs(wrong - correct) > 1e-3)
  })
  check("native_standalone_probability_and_mass_functions", {
    for (state in states) {
      f <- review_forward(state, data)
      for (i in seq_len(data$n)) for (cls in 1:3) {
        eta <- state$alpha + state$b0 + sqrt(state$v) * state$z[i, ]
        lp <- as.numeric(standalone("ad_log_probabilities", eta, as.integer(cls)))
        review_near(exp(lp), f$rows[[i]]$p[cls, ], 1e-13)
        actual <- standalone("ad_count_log_lpmf", as.integer(data$observed[i, ]), lp)
        review_near(actual, dmultinom(data$observed[i, ], prob = f$rows[[i]]$p[cls, ], log = TRUE), 1e-10)
      }
    }
    review_near(standalone("ad_count_log_lpmf", c(0L, 3L, 0L), c(-Inf, 0, -Inf)), 0, 0)
    stopifnot(standalone("ad_count_log_lpmf", c(1L, 2L, 0L), c(-Inf, 0, -Inf)) == -Inf)
  })
  check("existing_fixed_parameter_GQ_independent_reconstruction", {
    csv <- list.files(file.path(prep, "tests/fixed_parameter"), pattern = "\\.csv$", full.names = TRUE)
    stopifnot(length(csv) == 1L)
    draws <- as.matrix(read.csv(csv, comment.char = "#", check.names = FALSE))
    colnames(draws) <- vapply(colnames(draws), function(name) {
      if (!grepl("\\.", name)) return(name)
      parts <- strsplit(name, ".", fixed = TRUE)[[1]]
      paste0(parts[1], "[", paste(parts[-1], collapse = ","), "]")
    }, character(1))
    parameters <- jsonlite::read_json(file.path(prep, "tests/fixed_parameters.json"), simplifyVector = TRUE)
    stopifnot(nrow(draws) == 256L)
    answer <- review_fixed_GQ(draws, parameters, data)
    write_new(answer, file.path(out, "GQ_errors.json"))
  })
  check("143_rows_data_and_four_initial_states_unchanged", {
    actual <- jsonlite::read_json(file.path(prep, "data.json"), simplifyVector = TRUE)
    payload <- readRDS(file.path(base, "../2026-09-30_ad_study/data/run-20260930T235038Z-pid61600/dc2010_ad_data.rds"))
    stopifnot(actual$n == 143L, identical(as.integer(actual$N), as.integer(payload$D$N)),
              identical(unname(actual$observed), unname(payload$D$observed)))
    t <- sum(actual$N - actual$observed[, 1]) / sum(actual$N)
    u <- sum(actual$observed[, 2]) / sum(actual$N - actual$observed[, 1])
    for (k in 1:4) {
      init <- jsonlite::read_json(file.path(prep, paste0("init_chain", k, ".json")), simplifyVector = TRUE)
      review_near(init$alpha, c(qlogis(t) + c(-.4, -.1, .1, .4)[k], qlogis(u) + c(.4, .1, -.1, -.4)[k], rep(c(-1, 0, 1, -.5)[k], 4)), 1e-12)
      stopifnot(all(init$b0 == 0), all(init$z == 0), all(init$v == c(.1, .2, .3, .4)[k]))
      review_near(init$r, c(.25, .125), 0)
    }
  })
  check("adapter_ESS_NA_masks_and_denominators_recheck", {
    folder <- file.path(review, "adapter_checks02/tree/postprocessed")
    d <- read.csv(file.path(folder, "common_diagnostics/diagnostics.csv"))
    for (kind in c("bulk", "tail")) {
      expected <- d[[paste0("ess_", kind)]] / 123
      actual <- d[[paste0("ess_", kind, "_per_internal_generation_second")]]
      stopifnot(identical(is.na(actual), is.na(expected)))
      good <- is.finite(expected)
      review_near(actual[good], expected[good], 1e-8)
    }
    result <- jsonlite::read_json(file.path(folder, "result.json"), simplifyVector = TRUE)
    stopifnot(sum(d$mandatory & !is.finite(d$ess_tail)) == 429L,
              result$status == "computationally_inconclusive", result$HMC_checks_pass,
              result$NCP_failed == 0L, all(d$diagnostic_pass[d$group == "global"]))
    write_new(list(status = "pass", own_checker_error = "review_near disallowed expected NA; finite values and NA locations now checked separately",
                   candidate_changed = FALSE, prior_attempt_preserved = TRUE,
                   mandatory_NA_targets = 429L, output_status = result$status,
                   Rhat_ESS_thresholds_unchanged = TRUE, full_pipeline_not_repeated = TRUE),
              file.path(out, "adapter_ESS_resolution.json"))
  })
  check("frozen_artifacts_unchanged_after_native_reads", {
    for (f in records) stopifnot(sha(f$path) == f$sha256)
    stopifnot(sha(manifest_path) == "2ad3246c3b1a5b5e0c676a85434824644b440cc75c386bc45feeabc34b789bfb",
              sha(preflight_path) == "7169d8b0e2536739ad2b2a9a9b9f6bfb471b9e6da3424aaad7cf86bd801d0c23")
  })
  dir.create(file.path(out, "supervisor_tests"))
  cat("Completed deterministic native checks; no compilation, GQ generation or MCMC invoked.\n")
}
run()
