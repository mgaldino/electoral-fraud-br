# Independent finite G2 closure checks; no executor algebra, sampler or production runner.
out <- "quality_reports/results/mebane_gates/G2/round2/review"
stopifnot(dir.exists(out))
r2 <- dirname(out)
g0 <- "quality_reports/results/mebane_gates/G0/round1"
cand <- jsonlite::fromJSON(file.path(r2, "benchmark_contract.json"), simplifyVector = FALSE)
checks <- data.frame(id = character(), passed = logical(), detail = character())
check <- function(id, value, detail = "") {
  checks[nrow(checks) + 1L, ] <<- list(id, isTRUE(value), detail)
}
equal <- function(x, y, tol = 1e-11) {
  length(x) == length(y) && all(is.finite(c(x, y))) && max(abs(x - y)) <= tol
}
assignment <- function(e, name) is.call(e) && is.symbol(e[[1]]) && as.character(e[[1]]) %in% c("<-", "=") &&
  identical(e[[2]], as.name(name))
extract <- function(path, name) {
  hits <- Filter(function(e) assignment(e, name), as.list(parse(path)))
  stopifnot(length(hits) == 1)
  hits[[1]]
}

# Only the pure function returning the literal is evaluated, not the source file.
pure <- new.env(parent = baseenv())
eval(extract(file.path(g0, "ef_models_3017de5.R"), "qbl"), pure)
jags <- readLines(file.path(g0, "qbl_installed_3017de5.jags"), warn = FALSE)
check("literal_matches_primary_qbl", identical(trimws(pure$qbl()), trimws(paste(jags, collapse = "\n"))))
active <- paste(trimws(sub("#.*$", "", jags)), collapse = "\n")
has <- function(x) grepl(x, active, fixed = TRUE)
check("literal_partial_pi", all(vapply(c("pi.aux1 ~ dunif(0,1)", "pi.aux2 ~ dunif(0,pi.aux1)",
                                        "pi.aux3 ~ dunif(0,pi.aux1)"), has, logical(1))))
blocks <- c("tau", "nu", "iota.m", "iota.s", "chi.m", "chi.s")
variances <- c("tb", "nb", "imb", "isb", "cmb", "csb")
effects <- c("th", "nh", "imh", "ish", "cmh", "csh")
for (j in seq_along(blocks)) {
  b <- blocks[j]
  check(paste0("literal_hierarchy_", b),
        has(paste0(variances[j], " ~ dexp(5)")) &&
        has(paste0(b, ".beta <- 1/", variances[j])) &&
        has(paste0(b, ".alpha ~ dnorm(0,1)")) &&
        has(paste0(effects[j], "[j] ~ dnorm(", b, ".alpha,", b, ".beta)")))
}
check("six_fixed_precision_matrices", sum(grepl("10000, 1", sub("#.*$", "", jags), fixed = TRUE)) == 6)
check("six_primary_beta1_predictors", sum(grepl("inprod(", sub("#.*$", "", jags), fixed = TRUE)) == 6 &&
      sum(grepl("inprod.*beta.*1", sub("#.*$", "", jags))) == 6)
check("four_latent_binomials", sum(grepl("N\\.(iota|chi)\\.(m|s)\\[j\\] *~ *dbin", sub("#.*$", "", jags))) == 4)
check("two_observed_N_trials", has("a[j] ~ dbin(p.a[j],N[j])") && has("w[j] ~ dbin(p.w[j],N[j])"))
check("endpoint_999_both_manufactured", sum(grepl("ifelse( N.", sub("#.*$", "", jags), fixed = TRUE) &
                                           grepl(".999", sub("#.*$", "", jags), fixed = TRUE)) == 2)
check("D1_software_scope", cand$target_kind == "literal_software_benchmark_not_certified_data_generator" &&
      cand$baseline$engine_version_required == "4.3.2" && !cand$baseline$historical_Stan_is_exact_port &&
      !cand$baseline$engine_runtime_probed_in_round2 && !cand$inferential_approval)
check("D1_no_runtime_assumption", cand$likelihood$invalid_parent_runtime_semantics ==
        "unknown_to_be_observed_in_G3" && !cand$likelihood$certified_physical_generator &&
        !cand$G3_go_no_go$generator_go)
check("D1_no_silent_repair", !any(unlist(cand$likelihood[c("clamp_allowed", "denominator_floor_allowed",
        "latent_mean_plugin_allowed", "silent_normalization_or_truncation_allowed", "F1_F2_repair_allowed",
        "N_minus_A_trials_allowed")])))
check("D1_all_attempts_preserved", grepl("all_attempts", cand$likelihood$literal_generation_failure_policy) &&
      grepl("do_not_discard_or_redraw", cand$likelihood$literal_generation_failure_policy))
pw <- function(N, A, nu, m, s) nu * (1-s) + s + (A/N) * (m-s-nu*(1-s)) / (1-m)
check("D1_invalid_parent_retained", equal(pw(1, 1, .5, .999, 0), 499.5),
      "Algebra only, not JAGS runtime semantics")
check("D1_valid_control", equal(pw(10, 2, .5, .2, .1), .4625))

# Execute only primary-source matrix/response construction, stopping before JAGS checks or calls.
interface <- file.path(r2, "sources/ef_main_3017de5.R")
local <- new.env(parent = globalenv())
eval(extract(interface, "getRegMatrix"), local)
eval(extract(interface, "eforensics_main_par"), local)
body_expr <- as.list(body(local$eforensics_main_par))[-1]
start <- which(vapply(body_expr, assignment, logical(1), name = "func.call")) + 1L
end <- which(vapply(body_expr, assignment, logical(1), name = "dat"))
stopifnot(length(start) == 1, length(end) == 1, start < end)
construction <- body_expr[start:end]
sentinel <- data.frame(N = c(17, 23, 31), a = c(2, 7, 5), w = c(9, 12, 20),
                       cw = c(-2, 0, 3), ca = c(5, -1, 7))
for (b in c("mu.iota.m", "mu.iota.s", "mu.chi.m", "mu.chi.s")) sentinel[[b]] <- 1
make_dat <- function(f1, f2) {
  e <- new.env(parent = local)
  e$data <- sentinel
  e$weights <- NULL
  e$func.call <- as.call(c(list(as.name("eforensics_main_par")),
      list(formula1 = f1, formula2 = f2, formula3 = quote(mu.iota.m ~ 1),
           formula4 = quote(mu.iota.s ~ 1), formula5 = quote(mu.chi.m ~ 1),
           formula6 = quote(mu.chi.s ~ 1), data = quote(data))))
  for (expr in construction) eval(expr, e)
  e$dat
}
dat <- make_dat(quote(w ~ 1), quote(a ~ 1))
mat_names <- c("Xa", "Xw", "X.iota.m", "X.iota.s", "X.chi.m", "X.chi.s")
check("interface_primary_responses", equal(dat$w, sentinel$w) && equal(dat$a, sentinel$a))
check("interface_six_intercept_matrices", all(vapply(dat[mat_names], function(x)
      identical(dim(x), c(3L, 1L)) && all(x == 1), logical(1))))
check("interface_six_dimension_scalars", all(unlist(dat[c("dxa", "dxw", "dx.iota.m", "dx.iota.s", "dx.chi.m", "dx.chi.s")]) == 1))
swapped <- make_dat(quote(a ~ 1), quote(w ~ 1))
check("interface_swapped_negative_control_detected", !equal(swapped$w, sentinel$w) && !equal(swapped$a, sentinel$a))
slopes <- make_dat(quote(w ~ cw), quote(a ~ ca))
check("interface_distinct_covariates", equal(slopes$Xw[, 2], sentinel$cw) && equal(slopes$Xa[, 2], sentinel$ca))
check("interface_contract_matches_source", cand$wrapper_interface$formula1_response == "w" &&
      cand$wrapper_interface$formula2_response == "a" && cand$wrapper_interface$formula1_matrix == "Xw" &&
      cand$wrapper_interface$formula2_matrix == "Xa" && cand$wrapper_interface$G3_asymmetric_sentinel_required)
write.csv(data.frame(N = sentinel$N, expected_a = sentinel$a, expected_w = sentinel$w,
                    outgoing_a = dat$a, outgoing_w = dat$w, swapped_a = swapped$a,
                    swapped_w = swapped$w), file.path(out, "interface_checks.csv"), row.names = FALSE)

# Historical direct-list construction only; no loading, preparation, fitting or production rerun.
for (file in c("05_eforensics_qbl_fresh_diagnostic.R", "05_jags_qbl_zone_fe.R")) {
  e <- new.env(parent = globalenv())
  e$bsb <- sentinel
  e$X1 <- matrix(1, nrow(sentinel), 1)
  e$X_zona <- cbind(1, c(0, 1, 0))
  e$n_dummies <- 2L
  eval(extract(file.path(g0, "final_state/R", file), "dat"), e)
  check(paste0("historical_direct_not_inverted_", file), equal(e$dat$a, sentinel$a) &&
        equal(e$dat$w, sentinel$w) && equal(e$dat$N, sentinel$N))
}
find_calls <- function(expr) {
  found <- list()
  if (is.call(expr) && identical(expr[[1]], as.name("eforensics"))) found <- list(expr)
  if (is.recursive(expr)) {
    children <- as.list(expr)
    for (k in seq_along(children)) {
      if (!identical(children[[k]], quote(expr = ))) found <- c(found, find_calls(children[[k]]))
    }
  }
  found
}
for (file in c("05_eforensics_umeforensics_qbl.R", "07_brasil_full_qbl.R")) {
  calls <- find_calls(parse(file.path(g0, "final_state/R", file)))
  check(paste0("historical_wrapper_inverted_", file), length(calls) ==
        ifelse(grepl("umeforensics", file), 3L, 1L) && all(vapply(calls, function(cl)
        identical(cl$formula1[[2]], as.name("a")) && identical(cl$formula2[[2]], as.name("w")), logical(1))))
}

check("D2_priors_contract", cand$priors$variance$rate == 5 && !cand$priors$variance$exponential_on_sd &&
      cand$priors$fixed_intercept$variance == 1e-4 && cand$priors$slopes$variance == 1 &&
      cand$priors$alpha$variance == 1 && cand$first_harness$alpha_plus_b0_retained &&
      cand$first_harness$full_hierarchy_retained && !cand$priors$pi$pi2_ge_pi3_required)
check("D2_production_not_selected", !cand$first_harness$national_geography_selected &&
      cand$first_harness$geography_production_approval_gate == "G4_before_G6")
check("D2_partial_order_counterexample", {p <- c(.8, .16, .64)/1.6; p[1] >= max(p[2:3]) && p[3] > p[2]})
b0 <- c(.01, -.03, .05, .02, -.02, .04)
alpha <- c(-.4, .2, -.3, .4, -.2, .1)
v <- c(.1, .2, .3, .4, .5, .6)
z <- c(-1, 0, 1)
eta <- sapply(1:6, function(b) drop(dat[[mat_names[b]]] %*% b0[b]) + alpha[b] + sqrt(v[b])*z)
check("D2_alpha_b0_six_blocks", equal(eta[2, ], b0 + alpha) && all(eta[2, ] != alpha))
check("D2_variance_not_sd", equal(1/5, .2) && equal(2/5^2, .08) && equal(1 + 1/10000, 1.0001),
      "Exp(5) on variance versus on SD; intercept sum retains its extra variance")

# A distinct scalar oracle, rather than the executor's functions or assertions.
functional <- function(N, Z, tau, nu, counts) {
  stopifnot(N >= 1, N == floor(N), Z %in% 1:3, all(counts == floor(counts)),
            all(counts >= 0 & counts <= N), tau > 0, tau < 1, nu > 0, nu < 1)
  if (Z == 1) return(c(M = 0, S = 0))
  selected <- counts[if (Z == 2) 1:2 else 3:4]
  manufactured_count_scale <- if (selected[1] == N) .999 * N else selected[1]
  c(M = manufactured_count_scale * (1-tau), S = selected[2] * tau * (1-nu))
}
fixture <- read.csv(file.path(r2, "results/joint_draw_fixture.csv"))
oracle <- t(vapply(seq_len(nrow(fixture)), function(i) {
  x <- fixture[i, ]
  functional(x$N, x$Z, x$tau, x$nu, unlist(x[c("RIM", "RIS", "REM", "RES")], use.names = FALSE))
}, c(M = 0, S = 0)))
recorded <- read.csv(file.path(r2, "results/joint_functionals.csv"))
check("D3_executor_rows_independently_recomputed", equal(oracle[, "M"], recorded$M) && equal(oracle[, "S"], recorded$S))
check("D3_zero_class1", all(oracle[fixture$Z == 1, ] == 0))
check("D3_endpoint_joint_selection", equal(oracle[5:6, "M"], c(49.95, 5.994)) &&
      equal(oracle[5:6, "S"], c(25, 2.8)))
alt <- fixture
alt[fixture$Z == 1, c("RIM", "RIS", "REM", "RES")] <- 0
alt[fixture$Z == 2, c("REM", "RES")] <- 0
alt[fixture$Z == 3, c("RIM", "RIS")] <- 0
inactive <- t(vapply(seq_len(nrow(alt)), function(i) {
  x <- alt[i, ]; functional(x$N, x$Z, x$tau, x$nu,
                            unlist(x[c("RIM", "RIS", "REM", "RES")], use.names = FALSE))
}, c(M = 0, S = 0)))
check("D3_inactive_latents_do_not_affect_functional", equal(as.numeric(inactive), as.numeric(oracle)))
totals <- rowsum(oracle, fixture$draw, reorder = TRUE)
published <- read.csv(file.path(r2, "results/joint_totals.csv"))
check("D3_totals_same_draw", equal(totals[, "M"], published$M) && equal(totals[, "S"], published$S))
check("D3_fractional_not_observed_counts", any(abs(oracle - round(oracle)) > .01))
check("D3_no_extra_noise", !cand$estimands$additional_binomial_ballot_draw_allowed &&
      cand$estimands$primary_uncertainty_target == "complete_joint_functional_distribution_per_draw")
check("D3_no_prior_redraw", grepl("never independent fresh prior draws", cand$estimands$latent_source, fixed = TRUE))
check("D3_conditional_means_not_quantiles", grepl("not_a_substitute", cand$estimands$conditional_means) &&
      !cand$estimands$observed_fraud_interpretation_approved)
q <- function(x) unname(quantile(x, .75, type = 1))
u <- c(0, 10, 0, 10); w <- 10-u
check("D3_total_quantile_not_sum_quantiles", q(u+w) == 10 && q(u)+q(w) == 20)
distribution <- c(0, 0, 0, 8)
conditional_mean <- rep(2, 4)
check("D3_RB_same_mean_different_distribution", mean(distribution) == mean(conditional_mean) &&
      mean((distribution-2)^2) == 12 && mean((conditional_mean-2)^2) == 0 &&
      unname(quantile(distribution, .95, type = 1)) == 8 &&
      unname(quantile(conditional_mean, .95, type = 1)) == 2)

lower <- published$Dobs - totals[, "M"] - 2*totals[, "S"]
upper <- published$Dobs - totals[, "M"] - totals[, "S"]
check("D3_margin_independent_oracle", equal(lower, published$lower) && equal(upper, published$upper))
for (rho in c(0, .2, .8, 1)) {
  counterfactual <- (published$Wobs-totals[, "M"]-totals[, "S"]) -
    ((published$Wobs-published$Dobs)+rho*totals[, "S"])
  check(paste0("D3_margin_origin_", rho), all(counterfactual >= lower-1e-11 & counterfactual <= upper+1e-11))
}
check("D3_no_point_winner", any(lower < 0 & upper > 0) && !cand$margin$point_counterfactual_winner_identified)
check("D3_infeasible_not_dropped", nrow(recorded) == nrow(fixture) && nrow(published) == 4 &&
      identical(recorded$necessary_vote_feasibility, rowSums(oracle) <= recorded$Wobs) &&
      !published$necessary_vote_feasibility[3] && all(is.na(recorded$source_capacity_verified)))
check("D3_no_capacity_assumption", cand$margin$requires_feasibility &&
      !cand$margin$all_stolen_from_runner_up_assumed && grepl("without_clipping", cand$margin$feasibility_policy))
check("nine_root_limitations_retained", setequal(vapply(cand$held_limitations, `[[`, "", "id"),
      c("F1", "F2", "PAPER_JAGS_STAN", "NORMALIZATION", "IDENTIFICATION", "TOTALS_AND_ORIGIN",
        "GEOGRAPHY", "HISTORICAL_FITS", "MARGINALIZATION_COST")) &&
      all(vapply(cand$held_limitations, `[[`, logical(1), "held")))
# Evaluate only the executor's directory guard, never its runner or output expressions.
runner_expr <- as.list(parse("tests/mebane/algebra/test_benchmark_round2.R"))
guard <- Filter(function(e) is.call(e) && identical(e[[1]], as.name("if")), runner_expr)[[1]]
guard_env <- new.env(parent = globalenv())
guard_env$args <- normalizePath(out)
guard_env$expected <- normalizePath(file.path(r2, "results"))
guard_result <- tryCatch({eval(guard, guard_env); "accepted"}, error = conditionMessage)
check("runner_rejects_alternative_directory", identical(guard_result,
      "Provide the existing G2/round2/results directory explicitly; never write round1."), guard_result)
guard_env$args <- guard_env$expected
check("runner_accepts_frozen_directory_guard_only", identical(tryCatch({eval(guard, guard_env); "accepted"},
      error = conditionMessage), "accepted"), "Only the guard evaluated; no runner writes performed")
instructions <- readLines(file.path(r2, "implementation.md"), warn = FALSE, encoding = "UTF-8")
check("runner_documented_isolated_reproduction", grepl("isolada", instructions[50], fixed = TRUE) &&
      grepl("regrava", instructions[50], fixed = TRUE), "implementation.md:50 already documents the safe route")
check("no_rng_state", !exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
check("no_sampler_loaded", !any(c("rjags", "runjags", "rstan", "cmdstanr") %in% loadedNamespaces()))
write.csv(checks, file.path(out, "independent_checks.csv"), row.names = FALSE)
write.csv(cbind(fixture[c("draw", "unit")], oracle), file.path(out, "independent_functionals.csv"), row.names = FALSE)
capture.output(sessionInfo(), file = file.path(out, "R_session.txt"))
cat(sprintf("Independent closure: %d/%d passed. No MCMC or RNG.\n", sum(checks$passed), nrow(checks)))
if (!all(checks$passed)) {
  print(checks[!checks$passed, ])
  stop("Independent G2 closure checks failed")
}
