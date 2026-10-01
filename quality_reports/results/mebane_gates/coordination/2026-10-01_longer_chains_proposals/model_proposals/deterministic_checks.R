# Deterministic proposal calculations only: no RNG, MCMC, model compilation,
# empirical diagnostic recomputation, or writes outside model_proposals/.
options(scipen = 999, digits = 12)
args <- commandArgs(trailingOnly = FALSE)
file_arg <- sub("^--file=", "", args[grepl("^--file=", args)])
out <- dirname(normalizePath(file_arg))
root <- out
while (!file.exists(file.path(root, "CLAUDE.md"))) root <- dirname(root)

emit <- function(name, lines) {
  path <- file.path(out, name)
  if (file.exists(path)) {
    stopifnot(identical(readLines(path, warn = FALSE), lines))
  } else {
    writeLines(lines, path, useBytes = TRUE)
  }
}
emit_csv <- function(name, x) {
  lines <- capture.output(write.table(x, row.names = FALSE, col.names = TRUE,
                                      sep = ",", quote = TRUE, na = "NA"))
  emit(name, lines)
}

# u2/u1 and u3/u1 are independent U(0,1). Conditioning on r2>=r3
# gives density 2 on the triangle, not density 1/r2.
partial_mean <- c(3 * log(3) - 4 * log(2),
                  (1 - (3 * log(3) - 4 * log(2))) / 2,
                  (1 - (3 * log(3) - 4 * log(2))) / 2)
ordered_mean <- sapply(1:3, function(j) {
  integrate(function(x) vapply(x, function(xx) {
    integrate(function(y) {
      numerator <- switch(j, rep(1, length(y)), rep(xx, length(y)), y)
      2 * numerator / (1 + xx + y)
    }, lower = 0, upper = xx, rel.tol = 1e-10)$value
  }, numeric(1)), lower = 0, upper = 1, rel.tol = 1e-9)$value
})
stopifnot(abs(sum(partial_mean) - 1) < 1e-12,
          abs(sum(ordered_mean) - 1) < 1e-9,
          abs(partial_mean[1] - ordered_mean[1]) < 1e-9,
          ordered_mean[2] > ordered_mean[3])

# eta marginal: alpha ~ N(location, alpha_sd^2), b0 ~ N(0,.01^2),
# local h-alpha | v ~ N(0,v), v ~ Exp(rate). One-dimensional quadrature.
cdf_eta <- function(x, location, alpha_sd, rate) {
  integrate(function(v) pnorm((x - location) / sqrt(alpha_sd^2 + 0.0001 + v)) *
              dexp(v, rate = rate), lower = 0, upper = Inf,
            rel.tol = 1e-10, subdivisions = 200)$value
}
q_eta <- function(p, location, alpha_sd, rate) {
  uniroot(function(x) cdf_eta(x, location, alpha_sd, rate) - p,
          interval = location + c(-20, 20), tol = 1e-9)$root
}
scenarios <- data.frame(
  scenario = c("baseline_incremental", "baseline_extreme",
               "illustrative_C_incremental", "illustrative_C_extreme"),
  location = c(0, 0, qlogis(0.10 / 0.7), 0),
  alpha_sd = c(1, 1, 0.5, 0.5), rate_v = c(5, 5, 20, 20),
  lower = c(0, 0.7, 0, 0.7), width = c(0.7, 0.3, 0.7, 0.3)
)
scales <- do.call(rbind, lapply(seq_len(nrow(scenarios)), function(i) {
  a <- scenarios[i, ]
  q <- a$lower + a$width * plogis(vapply(c(.025, .5, .975), q_eta,
      numeric(1), location = a$location, alpha_sd = a$alpha_sd, rate = a$rate_v))
  data.frame(scenario = a$scenario, location = a$location, alpha_sd = a$alpha_sd,
             variance_rate = a$rate_v, marginal_intensity_q025 = q[1],
             marginal_intensity_median = q[2], marginal_intensity_q975 = q[3],
             E_variance = 1 / a$rate_v,
             local_SD_median = sqrt(qexp(.5, a$rate_v)),
             local_SD_q95 = sqrt(qexp(.95, a$rate_v)),
             prior_mean_count_at_200_opportunities_q025 = 200*q[1],
             prior_mean_count_at_200_opportunities_median = 200*q[2],
             prior_mean_count_at_200_opportunities_q975 = 200*q[3])
}))
stopifnot(abs(scales$marginal_intensity_median - c(.35, .85, .1, .85)) < 1e-8)
emit_csv("prior_scale.csv", scales)

# Exact prior-predictive first moments for one D unit, by quadrature.
# This is not a full prior-predictive simulation or a predictive interval.
candidate_mean_inc <- 0.7 * integrate(function(v) vapply(v, function(vv) {
  integrate(function(z) plogis(qlogis(.1/.7) + sqrt(.25 + .0001 + vv)*z) *
              dnorm(z), lower = -Inf, upper = Inf, rel.tol = 1e-9)$value *
    dexp(vv, rate = 20)
}, numeric(1)), lower = 0, upper = Inf, rel.tol = 1e-8)$value
prior_first_moments <- do.call(rbind, lapply(seq_len(3), function(j) {
  weights <- if (j == 2) ordered_mean else partial_mean
  mean_inc <- if (j == 3) candidate_mean_inc else .35
  active_mean <- weights[2]*mean_inc + weights[3]*.85
  p <- c(.5*(1-active_mean), .25+.75*active_mean, .25*(1-active_mean))
  stopifnot(abs(sum(p)-1) < 1e-12, all(p >= 0))
  data.frame(arm = c("1_baseline", "2_ordered_weights", "3_illustrative_intensity")[j],
             E_incremental_intensity = mean_inc,
             E_M_per_N = .5*active_mean, E_S_per_N = .25*active_mean,
             E_A_for_N1000 = 1000*p[1], E_W_for_N1000 = 1000*p[2],
             E_O_for_N1000 = 1000*p[3])
}))
emit_csv("prior_predictive_means.csv", prior_first_moments)

prob <- function(tau, nu, m, s) {
  c(pA = (1-tau)*(1-m), pW = tau*nu + (1-tau)*m + tau*(1-nu)*s,
    pO = tau*(1-nu)*(1-s))
}
same_observed <- rbind(no_fraud = prob(.8, .625, 0, 0),
                       incremental_1 = prob(.75, .5, .2, .2),
                       incremental_2 = prob(2/3, .4, .4, .25))
stopifnot(max(abs(same_observed - matrix(c(.2,.5,.3), 3, 3, byrow=TRUE))) < 1e-14)
example_M <- 1000*(1-.3)*.2
example_S <- 1000*.3*(1-.6)*.4
stopifnot(example_M > example_S)

# Fixed named anchors from existing summaries, never an empirical ranking.
csv <- file.path(root, "quality_reports/results/mebane_gates/coordination/2026-10-01_ad_long_stan/comparison_final01/global_functionals.csv")
dat <- read.csv(csv, check.names = FALSE)
targets <- c("pi[1]", "pi[2]", "pi[3]", "iota.m.alpha", "iota.s.alpha", "M_total", "S_total")
runs <- c("A_JAGS_20k", "D_JAGS_20k", "D_Stan_2k")
keep <- dat$id %in% runs & dat$target %in% targets
anchors <- dat[keep, c("id", "target", "rhat", "ess_bulk", "ess_tail", "mean", "sd", "mcse_mean")]
stopifnot(nrow(anchors) == 21, !anyDuplicated(anchors[c("id","target")]),
          !anyNA(anchors), all(is.finite(as.matrix(anchors[-c(1,2)]))))
emit_csv("selected_anchors.csv", anchors)

result <- capture.output({
  cat("DETERMINISTIC CHECKS ONLY; PROPOSAL NOT APPROVED\n")
  cat("No MCMC, random draws, model edits or empirical diagnostic recalculation.\n\n")
  cat("Prior E(pi), partial order:\n"); print(partial_mean)
  cat("Prior E(pi), full order by conditioning:\n"); print(ordered_mean)
  cat("P(pi2>=pi3) under baseline = 0.5\n")
  cat("Marginal prior scale (quadrature):\n"); print(scales, row.names=FALSE)
  cat("Identical D probabilities for three different parameter settings:\n"); print(same_observed)
  cat("Example m=.2 < s=.4 but M=", example_M, " > S=", example_S, " votes\n", sep="")
  cat("Three fixed-run anchors: 21 rows, no missing/nonfinite values, unique id/target.\n")
  cat("R version: ", R.version.string, "\n", sep="")
  cat("All deterministic assertions passed.\n")
})
emit("deterministic_results.txt", result)
cat(paste(result, collapse="\n"), "\n")
