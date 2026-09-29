args <- commandArgs(trailingOnly = TRUE)
out <- if (length(args)) args[1] else "quality_reports/results/mebane_gates/G2/round1/results"
dir.create(out, recursive = TRUE, showWarnings = FALSE)
source("tests/mebane/algebra/qbl_algebra.R")
t0 <- proc.time()[["elapsed"]]
started <- format(Sys.time(), tz = "UTC", usetz = TRUE)
checks <- list()
metrics <- list()
check <- function(id, condition, detail) {
  checks[[length(checks) + 1L]] <<- data.frame(id = id, pass = isTRUE(condition), detail = detail)
}
metric <- function(id, value) metrics[[id]] <<- as.numeric(value)
close <- function(x, y, tol = 1e-10) all(abs(x - y) <= tol)

src <- new.env(parent = baseenv())
sys.source("quality_reports/results/mebane_gates/G0/round1/ef_models_3017de5.R", src)
installed <- paste(readLines("quality_reports/results/mebane_gates/G0/round1/qbl_installed_3017de5.jags", warn = FALSE), collapse = "\n")
check("source_qbl_exact", identical(trimws(src$qbl()), trimws(installed)), "Installed JAGS literal equals qbl at the fixed commit, ignoring surrounding whitespace only")

# Prior geometry and constants, computed by quadrature rather than simulation.
norm1 <- integrate(function(p) (3 * p - 1) / p^3, 1 / 3, 1 / 2)$value
norm2 <- integrate(function(p) (1 - p) / p^3, 1 / 2, 1)$value
mean1 <- integrate(function(p) (3 * p - 1) / p^2, 1 / 3, 1 / 2)$value +
  integrate(function(p) (1 - p) / p^2, 1 / 2, 1)$value
check("pi_density_normalizes", close(norm1 + norm2, 1), "Integral on largest-component simplex is one")
check("pi_majority_not_required", close(norm2, 0.5), "P(pi1 > 1/2) = 1/2, not one")
check("pi_mean", close(mean1, 3 * log(3) - 4 * log(2)), "Exact E(pi1)")
metric("E_pi1", mean1)
check("pi_partial_order", pi_from_aux(.4, .04, .32)[3] > pi_from_aux(.4, .04, .32)[2], "pi3 can exceed pi2")
check("pi_not_uniform_simplex", !close(pi_density(.6, .2), 6), "Not uniform Dirichlet conditioned on pi1 largest")
check("pi_scale_cancels", close(pi_from_aux(.4, .04, .32), pi_from_aux(1, .1, .8)), "Exact scale cancellation")
x <- .2; y <- .3; h <- 1e-6
ratios <- function(x, y) c(x, y) / (1 - x - y)
J <- cbind((ratios(x + h, y) - ratios(x - h, y)) / (2 * h),
           (ratios(x, y + h) - ratios(x, y - h)) / (2 * h))
check("pi_jacobian", close(det(J), (1 - x - y)^(-3), 1e-8), "Finite difference cross-check of ratio Jacobian")

check("normal_precision", close(normal_precision(.3, .1, 25), dnorm(.3, .1, .2)), "JAGS precision=25 implies variance=.04, sd=.2")
v <- .04; z <- 1.3; a <- -.2
check("noncentered_jacobian", close(dnorm(a + sqrt(v) * z, a, sqrt(v)) * sqrt(v), dnorm(z)), "Normal density times dh/dz is standard normal")
sigma_density <- function(s) 10 * s * exp(-5 * s^2)
check("sigma_density_normalizes", close(integrate(sigma_density, 0, Inf)$value, 1, 1e-8), "Variance Exp(5) induces density 10*s*exp(-5*s^2)")
metric("E_sigma_code", integrate(function(s) s * sigma_density(s), 0, Inf)$value)
metric("E_variance_code", .2)
metric("E_variance_paper_sd_Exp5", .08)
check("scale_prior_divergence", !close(.2, 2 / 25), "Variance-Exp and sd-Exp have different residual variances")
resid_density <- function(x) integrate(function(v) dnorm(x, 0, sqrt(v)) * dexp(v, 5), 0, Inf)$value
check("laplace_induced", close(resid_density(.5), sqrt(5 / 2) * exp(-sqrt(10) * .5), 1e-8), "Normal with exponential variance integrates to Laplace")
check("intercept_not_exactly_removed", !close(1 + 1e-4, 1), "Exact collapsed intercept variance is 1.0001, not 1")
metric("var_intercept_exact", 1.0001)
metric("var_zone_reference", 1.0001)
metric("var_zone_nonreference", 2.0001)
logit_density <- function(p) dnorm(qlogis(p), .2, .7) / (p * (1 - p))
inc_density <- function(p) .7 * dnorm(log(p / (.7 - p)), .2, .7) / (p * (.7 - p))
ext_density <- function(p) .3 * dnorm(log((p - .7) / (1 - p)), .2, .7) / ((p - .7) * (1 - p))
check("logistic_jacobians", close(c(integrate(logit_density, 0, 1)$value,
      integrate(inc_density, 0, .7)$value, integrate(ext_density, .7, 1)$value), rep(1, 3), 1e-7), "All three transformed densities integrate to one")

grid <- expand.grid(q = c(0, .01, .2, .8, 1), nu = c(.01, .5, .99),
                    m = c(0, .2, .7, .999), s = c(0, .3, 1))
raw <- with(grid, pw_literal(q, nu, m, s))
reduced <- with(grid, pw_reduced(q, nu, m, s))
check("pw_algebra_identity", close(raw, reduced, 1e-10), "Literal and reduced formulas agree over 180 boundary/interior cases")
check("pw_nonnegative_domain", all(raw >= -1e-10), "No negative pw for valid q,nu,s in [0,1], m in [0,1)")
physical <- with(grid, q <= 1 - m)
check("pw_physical_mean_region", all(raw[physical] + grid$q[physical] <= 1 + 1e-10), "q <= 1-m ensures pa-observed + pw <= 1")
qmean <- pa(.6, .2)
check("paper_identity_at_mean_a", close(pw_literal(qmean, .4, .2, .3), pw_paper(.6, .4, .2, .3)), "Equality holds when observed A/N equals expected abstention")
metric("pw_paper_example", pw_paper(.6, .4, .2, .3))
metric("pw_qbl_example", pw_literal(.1, .4, .2, .3))
check("paper_not_qbl_off_mean", !close(pw_paper(.6, .4, .2, .3), pw_literal(.1, .4, .2, .3)), "Not the same likelihood at general observations")
metric("minimal_invalid_pw", pw_literal(1, .5, .999, 0))
check("minimal_invalid_support", close(pw_literal(1, .5, .999, 0), 499.5, 1e-9), "N=A=count_m=1,count_s=0 produces pw=499.5")
metric("stan_incremental_raw_invalid", pw_literal(.9, .1, .6, .05))
check("stan_clamp_changes_target", pw_literal(.9, .1, .6, .05) > 1 && close(pw_stan(.9, .1, .6, .05), 1 - 1e-9), "Invalid continuous incremental state is retained after clamp")
check("stan_boundary_zero_changed", pw_literal(1, .5, 0, 0) == 0 && pw_stan(1, .5, 0, 0) == 1e-9, "Impossible success gets positive probability")
check("stan_clamp_plateau", pw_stan(.9, .1, .6, .05) == pw_stan(.9, .1, .61, .05), "Saturated region is locally flat for this likelihood term")

for (N in c(1, 2, 5, 20)) {
  mu <- .35
  probs <- dbinom(0:N, N, mu)
  mf <- manufactured_fraction(0:N, N)
  check(paste0("endpoint_mean_N", N), close(sum(probs * mf), mu - .001 * mu^N), "Exact endpoint correction to E(m)")
  check(paste0("endpoint_second_N", N), close(sum(probs * mf^2), mu^2 + mu * (1 - mu) / N - .001999 * mu^N), "Exact second moment after .999 replacement")
}
check("latent_support_overlaps_classes", dbinom(2, 2, .35) > 0 && dbinom(0, 2, .85) > 0, "k restricts binomial probabilities, not realized fractions")
check("endpoint_collision", manufactured_fraction(999, 1000) == manufactured_fraction(1000, 1000), "Two counts map to .999 for N=1000")
check("endpoint_nonmonotone", manufactured_fraction(2000, 2001) > manufactured_fraction(2001, 2001), "Endpoint map decreases for N>1000")

metric("paper_physical_mass_N1", total_mass(1, .5, .5, 0, 0, "paper", TRUE))
metric("qbl_physical_mass_N2", total_mass(2, .5, .5, 0, 0, "reject_invalid", TRUE))
check("paper_rectangular_normalized", close(total_mass(1, .5, .5, 0, 0, "paper"), 1), "Paper product normalized on square")
check("paper_physical_not_normalized", close(total_mass(1, .5, .5, 0, 0, "paper", TRUE), .875), "Paper assigns .125 mass to A+W>N")
check("qbl_physical_not_normalized", close(total_mass(2, .5, .5, 0, 0, "reject_invalid", TRUE), .96875), "No-fraud JAGS still assigns .03125 mass to A+W>N")
check("rejection_C_depends_theta", close(total_mass(1, .5, .5, .999, 0, "reject_invalid"), .9995) &&
      close(total_mass(1, .8, .5, .999, 0, "reject_invalid"), .9998), "Zeroing invalid parents induces parameter-dependent mass")
check("stan_rectangular_normalized", close(total_mass(3, .5, .1, .6, .05, "stan_clamp"), 1), "Clamp defines a normalized conditional model on square, not physical triangle")
phys_mass <- sum(vapply(0:3, function(A) sum(vapply(0:3, function(W) physical_multinomial(3, A, W, .6, .4, .2, .3), numeric(1))), numeric(1)))
check("alternative_multinomial_normalized", close(phys_mass, 1), "Illustrative alternative only, not approved target")
check("same_mean_different_variance", close(2 * .25, 1 * .5) && !close(2 * .25 * .75, .5 * .5), "N=2,A=1: Bin(2,.25) and Bin(1,.5) have equal means, unequal variances")

mus <- c(.2, .3, .8, .85); mix <- c(.6, .25, .15)
marginal_rows <- list()
for (N in 1:3) for (A in 0:N) for (W in 0:N) {
  reduced <- factorized_sum(N, A, W, .6, .4, mus, mix)
  full <- brute_sum(N, A, W, .6, .4, mus, mix)
  marginal_rows[[length(marginal_rows) + 1L]] <- data.frame(N, A, W, reduced, full, error = abs(reduced - full))
}
marginal <- do.call(rbind, marginal_rows)
check("finite_marginalization_all_small", max(marginal$error) < 1e-12, "29 (A,W,N) cases including impossible physical counts; four-count brute force vs active-pair factorization")
for (physical in c(FALSE, TRUE)) {
  s <- 0
  for (A in 0:3) for (W in 0:3) if (!physical || A + W <= 3) {
    s <- s + pair_sum(3, A, W, .6, .4, .8, .85)
  }
  check(paste0("normalizer_cdf_", physical), close(s, normalizer_pair(3, .6, .4, .8, .85, physical)), "Summing W via binomial CDF matches explicit enumeration")
}
exact <- pair_sum(2, 1, 1, .6, .4, .2, .3)
plug <- observation_kernel(2, 1, 1, .6, .4, .2, .3)
metric("exact_pair_N2_A1_W1", exact)
metric("plugin_pair_N2_A1_W1", plug)
check("plugin_not_marginalization", abs(exact - plug) > 1e-4, "Likelihood of mean fraction differs from mean likelihood")
check("binomial_constants_matter", close(sum(dbinom(0:2, 2, .5)), 1) && close(sum(.5^(0:2) * .5^(2:0)), .75), "Dropping count-dependent choose(N,r) changes marginalization")
metric("N300_pair_evaluations_one_unit", 1 + 2 * 301^2)
metric("N300_pair_evaluations_6748_units", 6748 * (1 + 2 * 301^2))

f <- fraud_amounts(100, .6, .5, .2, .1)
check("estimand_decomposition", close(f, c(8, 3, 11)), "Expected manufactured=8, stolen=3, total=11")
check("margin_bounds", close(c(20 - f[3] - f[2], 20 - f[3]), c(6, 9)), "Without origin information, counterfactual margin lies in [6,9]")
r <- .25; g <- 100
check("rao_blackwell_variance_missing", r * (1 - r) * g^2 == 1875, "Conditional-mean estimand omits class variance 1875 in simple example")
joint <- matrix(c(0, 100, 100, 0), nrow = 2, byrow = TRUE)
check("sum_draws_not_marginal_quantiles", all(rowSums(joint) == 100) && sum(apply(joint, 2, quantile, .975)) != 100,
      "Anti-correlated units: total is always 100, sum of unit quantiles is not")

write.csv(do.call(rbind, checks), file.path(out, "checks.csv"), row.names = FALSE)
write.csv(data.frame(metric = names(metrics), value = unlist(metrics)), file.path(out, "metrics.csv"), row.names = FALSE)
write.csv(marginal, file.path(out, "marginalization.csv"), row.names = FALSE)
writeLines(c(paste("Started:", started), paste("Finished:", format(Sys.time(), tz = "UTC", usetz = TRUE)),
             paste("Elapsed seconds:", proc.time()[["elapsed"]] - t0), "RNG: none; deterministic tests only", capture.output(sessionInfo())),
           file.path(out, "execution.txt"))
all_checks <- do.call(rbind, checks)
print(all_checks, row.names = FALSE)
cat(sprintf("\n%d/%d assertions passed\n", sum(all_checks$pass), nrow(all_checks)))
if (!all(all_checks$pass)) quit(status = 1)
