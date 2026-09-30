args <- commandArgs(trailingOnly = TRUE)
out <- args[1]
stopifnot(!dir.exists(out))
dir.create(out, recursive = TRUE)
base <- "quality_reports/results/mebane_gates/G3/round1"
qa <- file.path(base, "review")
rev <- file.path(base, "revision3")
source(file.path(qa, "final_checks/diagnostic_helpers.R"))
payload <- readRDS(file.path(base, "revision2/raw_chains.rds"))
draws <- lapply(payload$draws, qa_targets)
pub <- read.csv(file.path(rev, "postprocess/conditional_comparison.csv"))
ref <- read.csv(file.path(qa, "revision2_diagnostics/independent_comparison.csv"))
old <- read.csv(file.path(base, "revision2/conditional_comparison.csv"))
checks <- list()
add <- function(id, ok, value = NULL) {
  checks[[length(checks) + 1L]] <<- list(id = id, pass = isTRUE(ok), value = value)
}
near <- function(a, b, tol) {
  identical(is.na(a), is.na(b)) && all(abs(a[!is.na(a)] - b[!is.na(b)]) < tol)
}
aliases <- c(r_im = "N.iota.m", r_is = "N.iota.s", r_cm = "N.chi.m", r_cs = "N.chi.s")
ast <- parse(file.path(rev, "code_snapshots/tests/mebane/likelihood/g3_draw_postprocess.R"))
fun <- Filter(function(e) is.call(e) && identical(e[[1L]], as.name("<-")) &&
  identical(e[[2L]], as.name("g3_chain_diagnostics")), as.list(ast))
stopifnot(length(fun) == 1L)
env <- new.env(parent = baseenv())
eval(fun[[1]], envir = env)
corrected <- list()
for (i in seq_len(nrow(pub))) {
  nm <- pub$target[i]
  key <- if (nm %in% names(aliases)) unname(aliases[nm]) else nm
  x <- vapply(draws, function(m) m[, key], numeric(2000))
  rr <- ref[ref$target == key, ]
  constant <- key == "S"
  independent <- if (constant) c(rhat = NA_real_, ess_bulk = NA_real_, ess_tail = NA_real_) else
    c(rhat = posterior::rhat(x), ess_bulk = posterior::ess_bulk(x), ess_tail = posterior::ess_tail(x))
  observed <- unlist(pub[i, c("rhat", "ess_bulk", "ess_tail")], use.names = FALSE)
  add(paste0("diagnostic_", key), near(unname(independent), observed, 1e-8))
  candidate <- env$g3_chain_diagnostics(x, constant = constant)
  add(paste0("function_", key), near(unname(candidate), unname(independent), 1e-12))
  mcse <- qa_batch_mcse(x)$mcse
  add(paste0("mean_MCSE_exact_", key),
      abs(mean(x) - pub$mc_mean[i]) < 1e-12 && abs(mcse - pub$mcse[i]) < 1e-12 &&
      abs(rr$exact - pub$exact[i]) < 1e-12 &&
      abs(max(1e-3, 6*mcse) - pub$tolerance[i]) < 1e-12 &&
      identical(pub$constant[i], constant))
  corrected[[key]] <- data.frame(target = key, rhat = independent[1],
    ess_bulk = independent[2], ess_tail = independent[3], mean = mean(x), mcse = mcse)
}
add("prior_non_diagnostic_fields_unchanged", all(vapply(
  c("exact", "mc_mean", "mcse", "tolerance", "difference"),
  function(nm) near(pub[[nm]], old[[nm]], 1e-12), logical(1))))
add("mean_pass_preserved", all(pub$mean_pass))
add("nine_nonconstant_tail_NA", sum(is.na(pub$ess_tail) & !pub$constant) == 9L)
add("nine_nonconstant_diagnostic_failures", sum(!pub$diagnostic_pass) == 9L)
add("S_exact_constant_preserved", pub$exact[pub$target == "S"] == 0 &&
  pub$mc_mean[pub$target == "S"] == 0 && pub$mcse[pub$target == "S"] == 0)
raw_equal <- function(a, b) identical(readBin(a, "raw", n = file.info(a)$size),
                                    readBin(b, "raw", n = file.info(b)$size))
for (name in list.files(file.path(rev, "postprocess"))) {
  add(paste0("reexecution_byte_identity_", name), raw_equal(
    file.path(rev, "postprocess", name), file.path(qa, "revision3_postprocessor_reexecution", name)))
}
for (name in c("functionals_by_draw.csv", "conditional_exact_states.csv")) {
  add(paste0("revision2_byte_identity_", name), raw_equal(
    file.path(rev, "postprocess", name), file.path(base, "revision2", name)))
}
x <- readRDS(file.path(qa, "attempt_revision3_shape_01/deterministic_matrix.rds"))
add("QA_adversarial_chain_fixture", env$g3_chain_diagnostics(x)[["rhat"]] > 1.1)
wrapped <- posterior::as_draws_array(array(x, c(2000, 4, 1),
  dimnames = list(NULL, NULL, "fixture")))
rejects <- function(y) inherits(tryCatch(env$g3_chain_diagnostics(y), error = identity), "error")
add("reject_array", rejects(wrapped))
add("reject_pooled", rejects(as.matrix(wrapped)))
add("reject_transpose", rejects(t(x)))
fixture <- as.matrix(read.csv(file.path(rev, "shape_regression/fixture.csv")))
plan <- jsonlite::read_json(file.path(rev, "repair_plan.json"), simplifyVector = TRUE)
i <- seq_len(2000)
wave <- .01*sin(2*pi*i/25) + .003*cos(2*pi*i/31)
expected_fixture <- vapply(plan$regression$chain_means,
  function(mu) mu + wave, numeric(2000))
add("candidate_deterministic_fixture", near(as.vector(fixture), as.vector(expected_fixture), 1e-12))
tab <- read.csv(file.path(rev, "shape_regression/diagnostics.csv"))
add("candidate_regression_numbers", near(tab$production,
  unname(env$g3_chain_diagnostics(expected_fixture)), 1e-8))
add("candidate_regression_large_gap", tab$production[tab$diagnostic == "rhat"] > 1.1 &&
  tab$incorrect_pooled[tab$diagnostic == "rhat"] < 1.01)
failed <- sum(!vapply(checks, function(x) x$pass, logical(1)))
write.csv(do.call(rbind, corrected), file.path(out, "recomputed_diagnostics.csv"), row.names = FALSE)
jsonlite::write_json(list(checks = checks, total = length(checks), failed = failed,
  no_MCMC_run = TRUE, repair_resolved = failed == 0,
  nine_tail_NA_retained = TRUE, frozen_criterion_satisfied = FALSE,
  production_validated = FALSE), file.path(out, "checks.json"),
  pretty = TRUE, auto_unbox = TRUE, digits = 17, na = "null")
stopifnot(failed == 0)
cat("QA revision3 checks:", length(checks), "passed; no MCMC\n")
