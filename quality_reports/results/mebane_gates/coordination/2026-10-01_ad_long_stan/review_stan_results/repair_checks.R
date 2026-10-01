# Scoped representation checks only; never source or execute a full postprocessor.
stopifnot(Sys.getenv("STAN_REPAIR_QA_RELEASED") == "diagnostic-repair-only")
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 1L)
root <- normalizePath(".", mustWork = TRUE)
new <- file.path(root, "quality_reports/results/mebane_gates/coordination/2026-10-01_ad_long_stan")
scope <- file.path(new, "review_stan_results")
out <- normalizePath(args[1], mustWork = TRUE)
stopifnot(startsWith(out, paste0(scope, "/")))
.libPaths(c(file.path(root, "renv/library/macos/R-4.4/aarch64-apple-darwin20"), .libPaths()))
stopifnot(requireNamespace("jsonlite", quietly = TRUE),
          requireNamespace("digest", quietly = TRUE))
checks <- list()
details <- list()
record <- function(id, ok, evidence = NULL) {
  checks[[length(checks) + 1L]] <<- list(id = id, pass = isTRUE(ok), evidence = evidence)
  if (!isTRUE(ok)) stop("Check failed: ", id)
  invisible(ok)
}
write_new <- function(value, name) {
  path <- file.path(out, name)
  stopifnot(!file.exists(path))
  jsonlite::write_json(value, path, pretty = TRUE, auto_unbox = TRUE,
                       na = "null", digits = NA)
}
definition <- function(path, name) {
  expressions <- parse(path, keep.source = FALSE)
  selected <- Filter(function(x) is.call(x) && identical(x[[1]], as.name("<-")) &&
                       identical(x[[2]], as.name(name)), as.list(expressions))
  stopifnot(length(selected) == 1L)
  selected[[1]]
}
wrapper <- file.path(root, "R/experimental/mebane_ad_long/postprocess_stan_v2.R")
wrapper_function <- eval(definition(wrapper, "ad_postprocess_stan")[[3]])
body_expressions <- as.list(body(wrapper_function))[-1]
assignment <- function(expression, name) is.call(expression) &&
  identical(expression[[1]], as.name("<-")) && identical(expression[[2]], as.name(name))
start <- which(vapply(body_expressions, assignment, logical(1), name = "representation"))
end <- which(vapply(body_expressions, assignment, logical(1), name = "checks"))
stopifnot(length(start) == 1L, length(end) == 1L, end > start)
boundary <- body_expressions[start:(end - 1L)]
stopifnot(length(boundary) == 5L)
normalize_with_candidate <- function(draws, sampler) {
  env <- new.env(parent = baseenv())
  env$draws <- draws
  env$sampler <- sampler
  env$out <- out
  env$ad_json <- function(value, path) {
    stopifnot(identical(path, file.path(out, "input_representation.json")))
    env$emitted <- value
  }
  for (expression in boundary) eval(expression, envir = env)
  list(draws = env$draws, sampler = env$sampler, metadata = env$emitted)
}
numeric_hash <- function(x) digest::digest(x, algo = "sha256")
same_payload <- function(original, plain, label) {
  expected_attributes <- attributes(original)
  expected_attributes$class <- NULL
  record(paste0(label, "_attributes_except_class"),
         identical(attributes(plain), expected_attributes))
  record(paste0(label, "_all_values_and_linear_order"),
         identical(as.numeric(original), as.numeric(plain)))
  record(paste0(label, "_base_array"), is.array(plain) && !inherits(plain, "draws"))
  record(paste0(label, "_iteration_chain_variable_names"),
         identical(dim(original), dim(plain)) && identical(dimnames(original), dimnames(plain)))
}

failure <- NULL
tryCatch({
  # Probe before and after explicit namespace loading in this fresh R process.
  draws <- readRDS(file.path(new, "stan2k01/draws_array.rds"))
  sampler <- readRDS(file.path(new, "stan2k01/sampler_diagnostics.rds"))
  details$initial_posterior_namespace_loaded <- "posterior" %in% loadedNamespaces()
  record("fresh_process_posterior_not_loaded", !details$initial_posterior_namespace_loaded)
  record("actual_draws_shape", identical(dim(draws), c(2000L, 4L, 4890L)))
  record("actual_sampler_shape", identical(dim(sampler), c(2000L, 4L, 6L)))
  record("actual_draws_class", identical(class(draws), c("draws_array", "draws", "array")))
  record("actual_sampler_class", identical(class(sampler), c("draws_array", "draws", "array")))
  record("actual_variable_names_unique", !anyDuplicated(dimnames(draws)[[3]]) &&
           !anyDuplicated(dimnames(sampler)[[3]]))
  record("actual_chain_ids", identical(dimnames(draws)[[2]], as.character(1:4)) &&
           identical(dimnames(sampler)[[2]], as.character(1:4)))
  probe <- "z[1,1]"
  record("actual_probe_variable_exists", probe %in% dimnames(draws)[[3]])
  details$before_namespace <- list(draws = dim(as.matrix(draws[, , probe])),
                                   sampler = dim(as.matrix(sampler[, , "energy__"])))
  before_draws_hash <- numeric_hash(draws)
  before_sampler_hash <- numeric_hash(sampler)
  normalized_before <- normalize_with_candidate(draws, sampler)
  loadNamespace("posterior")
  details$after_namespace <- list(draws = dim(as.matrix(draws[, , probe])),
                                  sampler = dim(as.matrix(sampler[, , "energy__"])))
  record("raw_before_namespace_2000_by_4",
         identical(details$before_namespace$draws, c(2000L, 4L)) &&
           identical(details$before_namespace$sampler, c(2000L, 4L)))
  record("raw_after_namespace_8000_by_1",
         identical(details$after_namespace$draws, c(8000L, 1L)) &&
           identical(details$after_namespace$sampler, c(8000L, 1L)))
  normalized_after <- normalize_with_candidate(draws, sampler)
  record("normalization_independent_of_namespace_load_order",
         identical(normalized_before, normalized_after))
  same_payload(draws, normalized_after$draws, "actual_draws")
  same_payload(sampler, normalized_after$sampler, "actual_sampler")
  record("actual_original_draws_not_mutated_in_memory", identical(numeric_hash(draws), before_draws_hash))
  record("actual_original_sampler_not_mutated_in_memory", identical(numeric_hash(sampler), before_sampler_hash))
  record("representation_metadata_matches_original",
         identical(normalized_after$metadata, list(draws_class = class(draws),
           sampler_class = class(sampler), draws_shape = dim(draws), sampler_shape = dim(sampler))))
  selected <- intersect(c("pi[1]", "z[1,1]", "z[143,6]", "r[1]", "r[2]",
                          "M_RB_total", "S_RB_total", "M_total", "S_total"), dimnames(draws)[[3]])
  for (name in selected) {
    actual <- as.matrix(normalized_after$draws[, , name])
    raw_values <- as.numeric(draws[, , name])
    independent <- matrix(raw_values, nrow = 2000L, ncol = 4L)
    record(paste0("actual_fixed_slice_", name), identical(dim(actual), c(2000L, 4L)) &&
             identical(as.numeric(actual), as.numeric(independent)))
  }
  details$actual <- list(draws_shape = dim(draws), sampler_shape = dim(sampler),
                        classes = class(draws), sampler_classes = class(sampler),
                        iteration_names = dimnames(draws)[[1]][c(1, 2000)],
                        chain_names = dimnames(draws)[[2]],
                        all_draws_values_compared = length(draws),
                        all_sampler_values_compared = length(sampler),
                        probe_variables = selected,
                        input_representation = normalized_after$metadata)
  rm(draws, sampler, normalized_before, normalized_after, actual, raw_values, independent)
  invisible(gc())

  # Exact coordinate encodings expose chain swaps, pooling and iteration reversal.
  fixture <- array(0, c(2000L, 4L, 3L), dimnames = list(as.character(1:2000),
                    as.character(1:4), c("z[1,1]", "r[1]", "M_RB_total")))
  for (v in 1:3) for (chain in 1:4) fixture[, chain, v] <- 1e6 * v + 1e4 * chain + 1:2000
  fixture_s3 <- posterior::as_draws_array(fixture)
  fixture_sampler <- posterior::as_draws_array(fixture[, , 1:2, drop = FALSE])
  fixture_copy <- fixture_s3
  fixture_normal <- normalize_with_candidate(fixture_s3, fixture_sampler)
  record("fixture_is_real_posterior_draws_array", inherits(fixture_s3, "draws_array"))
  record("fixture_original_object_unchanged", identical(fixture_s3, fixture_copy))
  same_payload(fixture_s3, fixture_normal$draws, "fixture")
  record("fixture_double_normalization_idempotent",
         identical(normalize_with_candidate(fixture_normal$draws, fixture_normal$sampler)$draws,
                   fixture_normal$draws))

  adapter <- new.env(parent = globalenv())
  diagnostic_path <- file.path(root, "R/experimental/mebane_ad_long/diagnostics_stan.R")
  for (name in c("ad_metric_pass", "ad_diagnostic_row")) eval(definition(diagnostic_path, name), adapter)
  legacy_error <- tryCatch({
    adapter$ad_diagnostic_row(as.matrix(fixture_s3[, , "z[1,1]"]), "fixture", "synthetic")
    NULL
  }, error = function(e) conditionMessage(e))
  record("unrepaired_fixture_rejected_by_unchanged_adapter",
         !is.null(legacy_error) && grepl("ncol(x) == 4L", legacy_error, fixed = TRUE), legacy_error)
  metric_rows <- list()
  for (v in 1:3) {
    name <- dimnames(fixture)[[3]][v]
    matrix <- as.matrix(fixture_normal$draws[, , name])
    row <- adapter$ad_diagnostic_row(matrix, name, "synthetic_sentinel")
    expected_means <- 1e6 * v + 1e4 * (1:4) + 1000.5
    record(paste0("fixture_coordinate_order_", v), identical(as.numeric(matrix), as.numeric(fixture[, , v])))
    record(paste0("fixture_chain_means_", v), identical(unname(unlist(row[paste0("chain", 1:4)])), expected_means))
    independent_metrics <- c(posterior::rhat(fixture[, , v]), posterior::ess_bulk(fixture[, , v]),
                             posterior::ess_tail(fixture[, , v]), posterior::mcse_mean(fixture[, , v]))
    reported_metrics <- unname(unlist(row[c("rhat", "ess_bulk", "ess_tail", "mcse_mean")]))
    record(paste0("fixture_metrics_four_separate_chains_", v),
           isTRUE(all.equal(reported_metrics, independent_metrics, tolerance = 1e-12)))
    metric_rows[[v]] <- row
  }
  write.csv(do.call(rbind, metric_rows), file.path(out, "synthetic_sentinel_metrics.csv"), row.names = FALSE)
  constant_row <- adapter$ad_diagnostic_row(matrix(1, 2000L, 4L), "constant", "synthetic")
  record("undefined_fixture_not_approved", !constant_row$diagnostic_pass &&
           anyNA(constant_row[c("rhat", "ess_bulk", "ess_tail")]))
  record("threshold_boundaries_unchanged", adapter$ad_metric_pass(c(1, 400, 400), .05, .05) &&
           !adapter$ad_metric_pass(c(1.01, 400, 400)) &&
           !adapter$ad_metric_pass(c(1, 399.999, 400)) &&
           !adapter$ad_metric_pass(c(1, 400, 399.999)) &&
           !adapter$ad_metric_pass(c(1, 400, 400), .0500001, .05) &&
           all(vapply(1:3, function(i) {
             values <- c(1, 400, 400); values[i] <- NA_real_
             !adapter$ad_metric_pass(values)
           }, logical(1))))

  # Exercise every internal adapter extraction, but do not run 860 empirical diagnostics.
  internal_names <- c(unlist(lapply(1:6, function(b) paste0("z[", 1:143, ",", b, "]"))), "r[1]", "r[2]")
  route_fixture <- array(rep(as.numeric(fixture[, , 1]), length(internal_names)),
                         c(2000L, 4L, length(internal_names)),
                         dimnames = list(as.character(1:2000), as.character(1:4), internal_names))
  for (v in seq_along(internal_names)) route_fixture[, , v] <- route_fixture[, , v] + v * 1e7
  sampler_fixture <- array(0, c(2000L, 4L, 3L),
                           dimnames = list(NULL, as.character(1:4), c("divergent__", "treedepth__", "energy__")))
  sampler_fixture[, , "energy__"] <- rep(c(1, 2), 4000)
  routed <- normalize_with_candidate(posterior::as_draws_array(route_fixture),
                                    posterior::as_draws_array(sampler_fixture))
  route_env <- new.env(parent = globalenv())
  seen <- character()
  route_env$ad_diagnostic_row <- function(x, target, group) {
    stopifnot(identical(dim(x), c(2000L, 4L)),
              identical(as.numeric(x), as.numeric(route_fixture[, , target])),
              identical(group, "Stan_internal"))
    seen <<- c(seen, target)
    data.frame(target = target, diagnostic_pass = TRUE)
  }
  eval(definition(file.path(root, "R/experimental/mebane_ad_long/stan_bridge.R"),
                  "ad_stan_sampler_checks"), route_env)
  route_result <- route_env$ad_stan_sampler_checks(routed$draws, routed$sampler)
  record("all_860_internal_extractions_preserve_shape_values_and_order", identical(seen, internal_names))
  record("synthetic_sampler_route_four_chains", identical(route_result$chain_diagnostics$chain, 1:4) &&
           all(route_result$chain_diagnostics$divergences == 0) &&
           all(route_result$chain_diagnostics$treedepth_hits == 0) &&
           all(route_result$chain_diagnostics$ebfmi >= .3))
  details$route_test <- list(targets = length(seen), diagnostic_row_replaced_with_shape_spy = TRUE,
                            actual_empirical_NCP_metrics_computed = FALSE)
  details$runtime <- list(R = R.version.string, posterior = as.character(utils::packageVersion("posterior")),
                          jsonlite = as.character(utils::packageVersion("jsonlite")))
  rm(route_fixture, sampler_fixture, routed, fixture, fixture_s3, fixture_copy, fixture_normal)
  invisible(gc())
}, error = function(e) failure <<- conditionMessage(e))
write_new(list(status = if (is.null(failure)) "pass" else "needs_revision", checks = checks,
               details = details, error = failure, full_postprocessor_executed = FALSE,
               empirical_metrics_computed = FALSE, empirical_resampling = FALSE,
               candidate_edits = FALSE), "representation_checks.json")
cat(sprintf("Scoped representation checks: %d passed of %d; %s\n",
            sum(vapply(checks, function(x) x$pass, logical(1))), length(checks),
            if (is.null(failure)) "pass" else failure))
if (!is.null(failure)) quit(status = 1L)
