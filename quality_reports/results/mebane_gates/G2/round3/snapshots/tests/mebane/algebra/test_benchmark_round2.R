# Documentary-choice and functional tests only: no JAGS, RNG, fits or MCMC.
args <- commandArgs(trailingOnly = TRUE)
root <- normalizePath(".", mustWork = TRUE)
expected <- file.path(root, "quality_reports/results/mebane_gates/G2/round2/results")
if (length(args) != 1L || normalizePath(args[1], mustWork = TRUE) != expected) {
  stop("Provide the existing G2/round2/results directory explicitly; never write round1.")
}
out <- expected
contract_path <- sub("/results$", "/benchmark_contract.json", out)
contract <- jsonlite::fromJSON(contract_path, simplifyVector = FALSE)
source("tests/mebane/algebra/qbl_algebra.R")
checks <- data.frame(id = character(), pass = logical(), detail = character())
check <- function(id, condition, detail = "") {
  checks[nrow(checks) + 1L, ] <<- list(id, isTRUE(condition), detail)
}
close_to <- function(x, y, tol = 1e-12) {
  length(x) == length(y) && all(is.finite(x)) && all(abs(x - y) < tol)
}
fails <- function(expr) inherits(try(force(expr), silent = TRUE), "try-error")

contract_rules <- function(x) {
  c(
    user_authorized_not_approved = x$authorization$status == "authorized_by_user" &&
      !x$gate_approved && !x$inferential_approval && x$round2_independent_review_status == "pending",
    exact_baseline = x$baseline$commit == "3017de537450f97a01872d0157462a68bea348ee" &&
      x$baseline$engine_version_required == "4.3.2" && x$baseline$k == 0.7 &&
      !x$baseline$engine_runtime_probed_in_round2 && !x$baseline$historical_Stan_is_exact_port,
    partial_prior = x$priors$pi$order == "pi1>=max(pi2,pi3)" &&
      !x$priors$pi$pi2_ge_pi3_required && !x$priors$pi$total_order_or_uniform_truncated_simplex_allowed,
    exp_variance = x$priors$variance$rate == 5 && x$priors$variance$jags_precision == "1/v" &&
      !x$priors$variance$exponential_on_sd && x$priors$variance$sd == "sqrt(v)",
    fixed_priors = x$priors$alpha$variance == 1 && x$priors$fixed_intercept$variance == 1e-4 &&
      x$priors$fixed_intercept$precision == 10000 && x$priors$slopes$variance == 1 &&
      x$priors$slopes$precision == 1 && x$priors$fixed_intercept$retain_separately_from_alpha,
    hierarchy_six = x$priors$blocks_per_observation == 6 && length(x$priors$block_names) == 6 &&
      x$first_harness$full_hierarchy_retained && x$first_harness$alpha_plus_b0_retained,
    fixed_harness_not_geography = x$first_harness$design == "intercept_only" &&
      length(x$first_harness$fixed_design_matrices) == 6 && !x$first_harness$national_geography_selected &&
      x$first_harness$geography_production_approval_gate == "G4_before_G6",
    wrapper_response_mapping = x$wrapper_interface$formula1_response == "w" &&
      x$wrapper_interface$formula1_matrix == "Xw" && x$wrapper_interface$formula2_response == "a" &&
      x$wrapper_interface$formula2_matrix == "Xa" && x$wrapper_interface$G3_asymmetric_sentinel_required &&
      !x$wrapper_interface$historical_scripts_modified,
    four_counts = x$latent_counts$number_per_observation == 4 && length(x$latent_counts$nodes) == 4 &&
      x$latent_counts$distribution == "Binomial(N,mu)" && x$latent_counts$denominator == "N_eligible_voters" &&
      x$latent_counts$manufactured_endpoint == 0.999 && !x$latent_counts$truncate_realized_counts_at_k,
    no_repair = !x$likelihood$clamp_allowed && !x$likelihood$denominator_floor_allowed &&
      !x$likelihood$latent_mean_plugin_allowed && !x$likelihood$silent_normalization_or_truncation_allowed &&
      !x$likelihood$F1_F2_repair_allowed && !x$likelihood$N_minus_A_trials_allowed,
    runtime_unknown = x$likelihood$invalid_parent_runtime_semantics == "unknown_to_be_observed_in_G3" &&
      !x$likelihood$certified_physical_generator && !x$G3_go_no_go$generator_go,
    failure_preserved = grepl("do_not_discard_or_redraw", x$likelihood$literal_generation_failure_policy, fixed = TRUE),
    joint_functionals = x$estimands$primary_uncertainty_target == "complete_joint_functional_distribution_per_draw" &&
      length(x$estimands$requires_joint_nodes) == 7 && !x$estimands$additional_binomial_ballot_draw_allowed &&
      !x$estimands$observed_fraud_interpretation_approved,
    draw_aggregation = x$estimands$aggregation == "sum_units_within_each_joint_draw_then_compute_summaries" &&
      grepl("not_a_substitute", x$estimands$conditional_means, fixed = TRUE),
    margin_conditional = x$margin$origin_assumption == "0<=S_R<=S" &&
      x$margin$lower == "Dobs-M-2*S" && x$margin$upper == "Dobs-M-S" && x$margin$requires_feasibility &&
      !x$margin$all_stolen_from_runner_up_assumed && !x$margin$point_counterfactual_winner_identified,
    findings_not_refuted = all(vapply(x$decision_resolution, function(d) {
      d$previous_classification == "CONFIRMED" && !d$scientific_defect_refuted &&
        d$owner_choice_status == "authorized_by_user" && d$independent_revalidation == "pending"
    }, logical(1))),
    held_limitations = length(x$held_limitations) == 9 &&
      all(vapply(x$held_limitations, function(d) d$held, logical(1))),
    replication_separate = x$author_replication$planned_gate == "G10_before_G4" &&
      !x$author_replication$searched_or_executed_here && !x$author_replication$ledger_edited_here,
    g3_not_executed_or_released = length(x$G3_go_no_go$criteria) == 8 &&
      grepl("independent_round2_review", x$G3_go_no_go$entry, fixed = TRUE) &&
      !x$G3_go_no_go$stochastic_inference_or_power_claims_authorized
  )
}
rules <- contract_rules(contract)
for (name in names(rules)) check(paste0("contract_", name), rules[[name]])

bad <- contract
bad$likelihood$clamp_allowed <- TRUE
check("reject_mutation_clamp", !all(contract_rules(bad)))
bad <- contract
bad$priors$variance$exponential_on_sd <- TRUE
check("reject_mutation_sd_prior", !all(contract_rules(bad)))
bad <- contract
bad$priors$pi$pi2_ge_pi3_required <- TRUE
check("reject_mutation_total_order", !all(contract_rules(bad)))
bad <- contract
bad$estimands$additional_binomial_ballot_draw_allowed <- TRUE
check("reject_mutation_extra_ballot_binomial", !all(contract_rules(bad)))
bad <- contract
bad$first_harness$alpha_plus_b0_retained <- FALSE
check("reject_mutation_alpha_only", !all(contract_rules(bad)))
bad <- contract
bad$latent_counts$manufactured_endpoint <- 1
check("reject_mutation_endpoint", !all(contract_rules(bad)))
bad <- contract
bad$wrapper_interface$formula1_response <- "a"
check("reject_mutation_wrapper_inversion", !all(contract_rules(bad)))

interface_lines <- readLines(contract$wrapper_interface$primary_source, warn = FALSE)
check("source_interface_mapping_inspected", grepl("formula_number=1", interface_lines[667], fixed = TRUE) &&
        grepl("w       = mat$y", interface_lines[668], fixed = TRUE) &&
        grepl("Xw      = mat$X", interface_lines[669], fixed = TRUE) &&
        grepl("formula_number=2", interface_lines[672], fixed = TRUE) &&
        grepl("a       = mat$y", interface_lines[673], fixed = TRUE) &&
        grepl("Xa      = mat$X", interface_lines[674], fixed = TRUE))
sentinel <- as.data.frame(lapply(contract$wrapper_interface$sentinel_example, unlist))
check("asymmetric_sentinel_physical", all(sentinel$a != sentinel$w) && all(sentinel$a + sentinel$w <= sentinel$N))
# These are contract fixtures via base R, not execution of the historical wrapper.
response1 <- unname(model.response(model.frame(reformulate("1", response = contract$wrapper_interface$formula1_response), sentinel)))
response2 <- unname(model.response(model.frame(reformulate("1", response = contract$wrapper_interface$formula2_response), sentinel)))
check("sentinel_formula_contract", identical(response1, sentinel$w) && identical(response2, sentinel$a))
check("sentinel_swapped_negative_control", !identical(response2, sentinel$w) && !identical(response1, sentinel$a))
write.csv(sentinel, file.path(out, "interface_sentinel.csv"), row.names = FALSE)

# Tiny fixed matrices are test fixtures, not a production harness implementation.
designs <- lapply(contract$first_harness$fixed_design_matrices, function(name) matrix(1, 3, 1))
check("six_one_column_fixed_designs", length(designs) == 6 &&
        all(vapply(designs, function(x) identical(dim(x), c(3L, 1L)) && all(x == 1), logical(1))))
b0 <- 0.02
alpha <- -0.3
v <- 0.2
z <- c(-1, 0, 1)
eta <- drop(designs[[1]] %*% b0) + alpha + sqrt(v) * z
check("harness_retains_alpha_plus_b0", close_to(eta, -0.28 + sqrt(v) * z) &&
        !close_to(eta, alpha + sqrt(v) * z))
prior_covariance <- diag(c(contract$priors$alpha$variance,
                          contract$priors$fixed_intercept$variance,
                          contract$priors$slopes$variance))
dummy_design <- rbind(reference = c(1, 1, 0), other = c(1, 1, 1))
dummy_covariance <- dummy_design %*% prior_covariance %*% t(dummy_design)
check("dummy_prior_fidelity_only", close_to(diag(dummy_covariance), c(1.0001, 2.0001)) &&
        close_to(dummy_covariance[1, 2], 1.0001) && !contract$first_harness$national_geography_selected)

# Each row is a complete synthetic joint draw for one unit; not simulated data or posterior samples.
fixture <- data.frame(
  draw = rep(1:4, each = 2), unit = rep(1:2, 4), N = rep(c(100, 10), 4),
  Wobs = rep(c(40, 4), 4), Robs = rep(c(30, 2), 4),
  Z = c(2, 1, 1, 2, 3, 3, 2, 2),
  tau = c(0.6, 0.5, 0.6, 0.5, 0.5, 0.4, 0.6, 0.6),
  nu = c(0.5, 0.4, 0.5, 0.4, 0.5, 0.3, 0.5, 0.5),
  RIM = c(20, 2, 20, 2, 1, 1, 5, 1), RIS = c(10, 5, 10, 5, 1, 1, 15, 2),
  REM = c(100, 10, 100, 10, 100, 10, 100, 10), RES = c(100, 10, 100, 10, 100, 10, 100, 10)
)
joint_functionals <- function(x) {
  stopifnot(all(x$N >= 1), all(x$N == floor(x$N)), all(x$Z %in% 1:3),
            all(x$tau > 0 & x$tau < 1), all(x$nu > 0 & x$nu < 1),
            !anyDuplicated(x[c("draw", "unit")]))
  for (name in c("RIM", "RIS", "REM", "RES")) {
    stopifnot(all(x[[name]] >= 0 & x[[name]] <= x$N), all(x[[name]] == floor(x[[name]])))
  }
  rm <- ifelse(x$Z == 2, x$RIM, ifelse(x$Z == 3, x$REM, 0))
  rs <- ifelse(x$Z == 2, x$RIS, ifelse(x$Z == 3, x$RES, 0))
  x$m <- ifelse(x$Z == 1, 0, manufactured_fraction(rm, x$N))
  x$s <- rs / x$N
  x$M <- x$N * x$m * (1 - x$tau)
  x$S <- x$N * x$s * x$tau * (1 - x$nu)
  x$Ft <- x$M
  x$Fw <- x$M + x$S
  x$Dobs <- x$Wobs - x$Robs
  x$lower <- x$Dobs - x$M - 2 * x$S
  x$upper <- x$Dobs - x$M - x$S
  x$necessary_vote_feasibility <- x$Fw <= x$Wobs
  x$source_capacity_verified <- NA
  x$bounds_are_conditional_only <- TRUE
  x
}
result <- joint_functionals(fixture)
check("zero_class1_functionals", all(result$M[result$Z == 1] == 0) && all(result$S[result$Z == 1] == 0))
check("numeric_M8_S3", close_to(c(result$M[1], result$S[1]), c(8, 3)))
check("countN_endpoint_not_one", close_to(result$m[result$Z == 3], rep(0.999, 2)))
check("fractional_functionals_not_realized_counts", close_to(result$S[7], 4.5) &&
        result$S[7] != floor(result$S[7]))
check("decomposition_Ft_Fw", close_to(result$Ft, result$M) && close_to(result$Fw, result$M + result$S))
check("scalar_formula_matches_rows", close_to(as.numeric(fraud_amounts(100, 0.6, 0.5, 0.2, 0.1)), c(8, 3, 11)))
changed <- fixture
changed$RIM[changed$Z == 3] <- 0
changed$RIS[changed$Z == 3] <- 0
changed$REM[changed$Z != 3] <- 0
changed$RES[changed$Z != 3] <- 0
check("inactive_counts_not_used_in_functional", close_to(joint_functionals(changed)$Fw, result$Fw))
changed <- fixture
changed$RIM[1] <- 101
check("invalid_latent_no_clipping", fails(joint_functionals(changed)))
changed <- fixture
changed$RIS[1] <- 0.5
check("noninteger_latent_rejected", fails(joint_functionals(changed)))
changed <- rbind(fixture, fixture[1, ])
check("duplicate_joint_key_rejected", fails(joint_functionals(changed)))

totals <- aggregate(cbind(M, S, Ft, Fw, Dobs, Wobs) ~ draw, data = result, FUN = sum)
totals$lower <- totals$Dobs - totals$M - 2 * totals$S
totals$upper <- totals$Dobs - totals$M - totals$S
totals$necessary_vote_feasibility <- totals$Fw <= totals$Wobs
check("joint_total_draw1", close_to(as.numeric(totals[1, c("M", "S", "Fw", "lower", "upper")]), c(8, 3, 11, -2, 1)))
check("same_draw_totals", close_to(totals$M, c(8, 1, 55.944, 2.4)) &&
        close_to(totals$S, c(3, 1.5, 27.8, 5.1)))
check("infeasible_rows_flagged_not_dropped", nrow(result) == 8 && sum(!result$necessary_vote_feasibility) == 2)
check("infeasible_draw_flagged_not_dropped", nrow(totals) == 4 && !totals$necessary_vote_feasibility[3])
check("capacity_not_fabricated", all(is.na(result$source_capacity_verified)))
check("margin_bounds_order", all(result$lower <= result$upper) && all(totals$lower <= totals$upper))
for (rho in c(0, 0.3, 1)) {
  d0 <- totals$Dobs - totals$M - totals$S - rho * totals$S
  check(paste0("margin_origin_rho_", rho), all(d0 >= totals$lower - 1e-12 & d0 <= totals$upper + 1e-12),
        "Algebraic conditional bound only; infeasible rows do not become valid reconstructions.")
}

# Finite weighted examples show uncertainty lost by conditional averaging, with no RNG.
complete <- c(0, 0, 0, 8)
conditional_mean <- rep(mean(complete), 4)
popvar <- function(x) mean((x - mean(x))^2)
check("mean_agrees_distribution_does_not", mean(complete) == mean(conditional_mean) &&
        popvar(complete) == 12 && popvar(conditional_mean) == 0)
check("conditional_quantile_not_full_quantile", unname(quantile(complete, 0.95)) !=
        unname(quantile(conditional_mean, 0.95)))
u1 <- c(0, 10, 0, 10)
u2 <- c(10, 0, 10, 0)
check("sum_quantiles_not_total_quantile", unname(quantile(u1 + u2, 0.75)) == 10 &&
        unname(quantile(u1, 0.75) + quantile(u2, 0.75)) == 20)
check("no_rng_state_created", !exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))

write.csv(fixture, file.path(out, "joint_draw_fixture.csv"), row.names = FALSE)
write.csv(result, file.path(out, "joint_functionals.csv"), row.names = FALSE)
write.csv(totals, file.path(out, "joint_totals.csv"), row.names = FALSE)
write.csv(data.frame(example = c("full_functional", "conditional_mean"),
                     mean = c(mean(complete), mean(conditional_mean)),
                     variance = c(popvar(complete), popvar(conditional_mean))),
          file.path(out, "uncertainty_example.csv"), row.names = FALSE)
write.csv(checks, file.path(out, "round2_checks.csv"), row.names = FALSE)
capture.output(sessionInfo(), file = file.path(out, "R_session.txt"))
cat(sprintf("Round2: %d/%d deterministic checks passed; no RNG, JAGS or MCMC.\n",
            sum(checks$pass), nrow(checks)))
if (!all(checks$pass)) {
  print(checks[!checks$pass, ])
  stop("Round2 contract/functional test failed")
}
