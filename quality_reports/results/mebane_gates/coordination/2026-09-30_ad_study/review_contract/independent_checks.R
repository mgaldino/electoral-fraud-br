# Independent contract audit only: no candidate code is sourced and no MCMC runs.
options(scipen = 999, warn = 1)
args <- commandArgs(trailingOnly = TRUE)
root <- normalizePath(if (length(args)) args[[1]] else ".", mustWork = TRUE)
base <- "quality_reports/results/mebane_gates"
review_rel <- file.path(base, "coordination/2026-09-30_ad_study/review_contract")
out <- file.path(root, review_rel)
stopifnot(dir.exists(out))
if (file.exists(file.path(out, "checks.json"))) {
  stop("Existing evidence is preserved. Use a separately reviewed new audit round.")
}
.libPaths(c(file.path(root, "renv/library/macos/R-4.4/aarch64-apple-darwin20"), .libPaths()))
stopifnot(requireNamespace("jsonlite", quietly = TRUE),
          requireNamespace("digest", quietly = TRUE),
          requireNamespace("posterior", quietly = TRUE),
          requireNamespace("rjags", quietly = TRUE))
sink(file.path(out, "checks.log"), split = TRUE)
started <- format(Sys.time(), tz = "UTC", usetz = TRUE)
cat("Started UTC:", started, "\nCommand: env LC_ALL=C LANG=C Rscript --vanilla",
    file.path(review_rel, "independent_checks.R"), shQuote(root), "\n")
reviewer <- Sys.getenv("CODEX_THREAD_ID")
stopifnot(reviewer == "01a0f4b8-962b-77a3-a418-6247c6219e8b")
executor <- "019d795a-acfa-72c2-a210-d55a46c606c2"
sha <- function(path) digest::digest(file = file.path(root, path), algo = "sha256")
ad <- file.path(base, "coordination/2026-09-30_ad_study")
discovery <- file.path(base, "coordination/authors_replication_discovery")
archive <- file.path(discovery, "archive/UMeforensics-eforensics_public-3017de5")
contract_path <- file.path(ad, "contract_v1.json")
contract <- jsonlite::fromJSON(file.path(root, contract_path), simplifyVector = FALSE)
sources <- list(
  contract = list(path = contract_path, expected = "8f0783b5f3520958a2b1a6d6de5bb217e2ea4ac8656a6ac114024b9d6a95dc17"),
  decision = list(path = file.path(ad, "decision.md"), expected = "d2940550c1d693a306de1e112d5e634ae2376b3530ed6762176bd2629dec0635"),
  A = list(path = contract$A$source, expected = contract$A$sha256),
  G2 = list(path = contract$A$specification_contract, expected = contract$A$specification_sha256),
  D_proposal = list(path = file.path(base, "coordination/2026-09-30_model_proposal/proposal_v1.md"), expected = "7fe462ed99561dee68d49fe1c5595845664249060459d018b4d01829fd61153c"),
  dc2010 = list(path = contract$case$source, expected = contract$case$sha256),
  vignette = list(path = file.path(archive, "vignettes/eforensics.Rmd"), expected = "1d5f6894c66cd9a7882adb52f13b31d6fa87d363d2cce30dcf2e54e071c4c7a6"),
  wrapper = list(path = file.path(archive, "R/ef_main.R"), expected = "ee626c0c939f84567c0ee74a100954229567911711193716a46837e1d6e3ce8b"),
  metadata = list(path = file.path(archive, "man/dc2010.Rd"), expected = "36668fe6f8c1bf933d1f749849569887e7c9c190fa718afd838ed7d498ce5873")
)
for (id in names(sources)) {
  sources[[id]]$actual <- sha(sources[[id]]$path)
  sources[[id]]$matches <- identical(sources[[id]]$actual, sources[[id]]$expected)
  stopifnot(sources[[id]]$matches)
}
extra_paths <- c(file.path(discovery, "discovery.md"),
                 file.path(discovery, "replication_contract.json"),
                 file.path(discovery, "source_manifest.json"),
                 file.path(base, "G3/round1/adjudication.md"),
                 "quality_reports/plans/mebane_2022_2026_gates.json", "CLAUDE.md", "README.md")
supplemental <- lapply(extra_paths, function(x) list(path = x, sha256 = sha(x)))
cat("Nine source hashes match the frozen values.\n")

# Enumerate the original three reservoirs and both transfers, not final cells.
reservoir_states <- function(N) {
  rows <- list()
  j <- 0L
  for (A0 in 0:N) for (L0 in 0:(N - A0)) {
    O0 <- N - A0 - L0
    for (M in 0:A0) for (S in 0:O0) {
      j <- j + 1L
      rows[[j]] <- c(A0 = A0, L0 = L0, O0 = O0, M = M, S = S,
                     A = A0 - M, W = L0 + M + S, O = O0 - S)
    }
  }
  as.data.frame(do.call(rbind, rows))
}
probabilities <- function(tau, nu, m, s) {
  c((1 - tau) * (1 - m),
    tau * nu + (1 - tau) * m + tau * (1 - nu) * s,
    tau * (1 - nu) * (1 - s))
}
weights <- function(x, N, tau, nu, m, s) {
  initial <- c(1 - tau, tau * nu, tau * (1 - nu))
  vapply(seq_len(nrow(x)), function(j) {
    dmultinom(unlist(x[j, c("A0", "L0", "O0")]), N, initial) *
      dbinom(x$M[j], x$A0[j], m) * dbinom(x$S[j], x$O0[j], s)
  }, numeric(1))
}
grid <- expand.grid(tau = c(0, .2, .7, .999, 1),
                    nu = c(0, .2, .7, .999, 1),
                    m = c(0, .2, .7, .999, 1),
                    s = c(0, .2, .7, .999, 1))
grid <- rbind(grid, data.frame(tau = .6, nu = .4, m = .2, s = .3))
errors <- c(simplex = 0, normalization = 0, mechanism = 0, log_mass = 0,
            sequential = 0, conditional_joint = 0, conditional_moments = 0,
            conditional_covariance = 0, no_transfer_match = 0, mixture = 0)
cases <- 0L
positive_conditionals <- 0L
zero_probability_cells <- 0L
for (N in 1:4) {
  x <- reservoir_states(N)
  keys <- paste(x$A, x$W, x$O, sep = ":")
  groups <- split(seq_len(nrow(x)), keys)
  cells <- vapply(groups, function(g) c(x$A[g[1]], x$W[g[1]], x$O[g[1]]), numeric(3))
  stopifnot(all(x$M <= x$A0), all(x$S <= x$O0),
            all(x$M + x$S <= x$W), all(x$A + x$W + x$O == N))
  for (r in seq_len(nrow(grid))) {
    tau <- grid$tau[r]; nu <- grid$nu[r]; m <- grid$m[r]; s <- grid$s[r]
    p <- probabilities(tau, nu, m, s)
    stopifnot(all(is.finite(p)), all(p >= 0), all(p <= 1))
    errors["simplex"] <- max(errors["simplex"], abs(sum(p) - 1))
    wt <- weights(x, N, tau, nu, m, s)
    marginal <- vapply(groups, function(g) sum(wt[g]), numeric(1))
    expected <- apply(cells, 2, dmultinom, size = N, prob = p)
    errors["normalization"] <- max(errors["normalization"], abs(sum(wt) - 1))
    errors["mechanism"] <- max(errors["mechanism"], abs(marginal - expected))
    positive <- expected > 0
    stopifnot(all(marginal[!positive] == 0))
    zero_probability_cells <- zero_probability_cells + sum(!positive)
    errors["log_mass"] <- max(errors["log_mass"],
                              abs(log(marginal[positive]) - log(expected[positive])))
    sequential <- if (p[2] + p[3] == 0) {
      as.numeric(cells[1, ] == N & cells[2, ] == 0)
    } else {
      dbinom(cells[1, ], N, p[1]) * dbinom(cells[2, ], N - cells[1, ], p[2] / (p[2] + p[3]))
    }
    errors["sequential"] <- max(errors["sequential"], abs(sequential - expected))
    if (p[1] < 1) {
      p0 <- probabilities(1 - p[1], p[2] / (1 - p[1]), 0, 0)
      errors["no_transfer_match"] <- max(errors["no_transfer_match"], abs(p0 - p))
    } else {
      stopifnot(all(p == c(1, 0, 0)))
    }
    for (g in groups[marginal > 0]) {
      positive_conditionals <- positive_conditionals + 1L
      W <- x$W[g[1]]
      actual <- wt[g] / sum(wt[g])
      if (p[2] == 0) {
        stopifnot(W == 0, all(x$M[g] == 0), all(x$S[g] == 0))
        q <- c(1, 0, 0)
      } else {
        q <- c(tau * nu, (1 - tau) * m, tau * (1 - nu) * s) / p[2]
      }
      target <- vapply(g, function(j) dmultinom(c(x$L0[j], x$M[j], x$S[j]), W, q), numeric(1))
      errors["conditional_joint"] <- max(errors["conditional_joint"], abs(actual - target))
      em <- sum(actual * x$M[g]); es <- sum(actual * x$S[g])
      errors["conditional_moments"] <- max(errors["conditional_moments"],
                                           abs(c(em, es) - W * q[2:3]))
      covariance <- sum(actual * (x$M[g] - em) * (x$S[g] - es))
      errors["conditional_covariance"] <- max(errors["conditional_covariance"],
                                              abs(covariance + W * q[2] * q[3]))
    }
    cases <- cases + 1L
  }
  for (tau in c(0, .2, .7, .999, 1)) for (nu in c(0, .2, .7, .999, 1)) {
    pi <- c(.5, .2, .3)
    ms <- rbind(c(0, 0), c(.14, .49), c(.76, .91))
    mixed_reservoir <- Reduce(`+`, lapply(1:3, function(z) {
      wt <- weights(x, N, tau, nu, ms[z, 1], ms[z, 2])
      pi[z] * vapply(groups, function(g) sum(wt[g]), numeric(1))
    }))
    mixed_multinomial <- Reduce(`+`, lapply(1:3, function(z) {
      pi[z] * apply(cells, 2, dmultinom, size = N,
                    prob = probabilities(tau, nu, ms[z, 1], ms[z, 2]))
    }))
    errors["mixture"] <- max(errors["mixture"], abs(mixed_reservoir - mixed_multinomial))
  }
}
stopifnot(errors["log_mass"] < 1e-9, all(errors[names(errors) != "log_mass"] < 1e-11))
cat("Mechanism distributions:", cases, "positive conditionals:", positive_conditionals,
    "zero cells:", zero_probability_cells, "\n")
print(errors)

# u2/u1 and u3/u1 are independent uniforms: the induced density is pi1^-3.
inner <- function(x) {
  ymax <- pmin(1 - 2 * x, (1 - x) / 2)
  .5 * ((1 - x - ymax)^(-2) - (1 - x)^(-2))
}
prior_integral <- integrate(inner, 0, 1/3, rel.tol = 1e-12)$value +
  integrate(inner, 1/3, .5, rel.tol = 1e-12)$value
u <- rbind(c(.8, .2, .1), c(.8, .1, .2))
pi <- u / rowSums(u)
stopifnot(abs(prior_integral - 1) < 1e-11, all(pi[, 1] >= pi[, 2]),
          all(pi[, 1] >= pi[, 3]), pi[1, 2] > pi[1, 3], pi[2, 2] < pi[2, 3])
prior_moments <- list(variance_mean = 1/5, fixed_intercept_variance = 1/10000,
                     alpha_plus_b0_variance = 1 + 1/10000,
                     marginal_eta_variance = 1 + 1/10000 + 1/5,
                     wrong_sd_Exp5_variance_mean = 2/5^2,
                     pi_density_integral = prior_integral, partial_order_examples = pi)

# Read archived input only to evaluate frozen initial values; do not prepare a second dataset.
env <- new.env(parent = emptyenv())
loaded <- load(file.path(root, contract$case$source), envir = env)
stopifnot(identical(loaded, "dc2010"))
d <- env$dc2010
N <- d$NVoters; A <- d$a; W <- d$Votes
stopifnot(nrow(d) == 143, all(A == N - d$NValid))
ta <- qlogis(sum(N - A) / sum(N)) + c(-.4, -.1, .1, .4)
na <- qlogis(sum(W) / sum(N - A)) + c(.4, .1, -.1, -.4)
ma <- c(-1, 0, 1, -.5)
initialization <- lapply(1:4, function(chain) {
  tau <- plogis(ta[chain]); nu <- plogis(na[chain])
  auxiliary <- cbind(floor(N * .7 * plogis(ma[chain])),
                     floor(N * (.7 + .3 * plogis(ma[chain]))))
  pa <- 1 - tau; pw <- nu * (1 - A / N)
  pd <- probabilities(tau, nu, 0, 0)
  logA <- dbinom(A, N, pa, log = TRUE) + dbinom(W, N, pw, log = TRUE)
  logD <- vapply(seq_along(N), function(i) dmultinom(c(A[i], W[i], N[i] - A[i] - W[i]),
                                                       N[i], pd, log = TRUE), numeric(1))
  stopifnot(all(is.finite(c(ta[chain], na[chain], logA, logD))),
            all(auxiliary >= 0), all(auxiliary <= N), all(pd >= 0), all(pd <= 1))
  list(chain = chain, tau_alpha = ta[chain], nu_alpha = na[chain],
       pA_A = pa, pW_A_range = range(pw), probabilities_D = pd,
       finite_log_mass_A_and_D = TRUE,
       auxiliary_range = range(auxiliary),
       extreme_auxiliary_uses_k_plus_one_minus_k_logistic = TRUE)
})
input_use <- list(rows = nrow(d), N_total = sum(N), A_total = sum(A), W_total = sum(W),
                  O_total = sum(N - A - W), identity_a_NVoters_minus_NValid = TRUE,
                  purpose = "initialization evaluation only; no prepared data exported")

# Deterministic diagnostic fixtures, never simulated or fitted posterior samples.
n <- 2000L
fixture <- sapply(0:3, function(c) qnorm((((seq_len(n) * 613L + c * 277L) %% n) + .5) / n))
separated <- sweep(fixture, 2, c(-2, -1, 1, 2), `+`)
arr <- array(separated, dim = c(n, 4, 1),
             dimnames = list(NULL, NULL, "fixture"))
proper <- posterior::rhat(arr[, , 1])
pooled <- posterior::rhat(matrix(as.vector(separated), ncol = 1))
constant_tail <- posterior::ess_tail(matrix(1, nrow = n, ncol = 4))
stopifnot(proper > 1.01, pooled < 1.01, is.na(constant_tail))
diagnostic_fixture <- list(shape = dim(arr), separated_rhat = proper,
                          wrongly_pooled_rhat = pooled, constant_tail_ESS = constant_tail,
                          label = "deterministic fixture; not fitted or MCMC-generated draws")
example <- list(N = 1000, W_observed = 400,
                expected_M_S = c(80, 108),
                conditional_mean_M_S = 400 * c(.08, .108) / .428,
                conditional_cov_M_S = -400 * .08 * .108 / .428^2)
runtime <- list(R = R.version.string, JAGS = as.character(rjags::jags.version()),
                packages = lapply(c("jsonlite", "digest", "posterior", "rjags"),
                                  function(p) list(name = p, version = as.character(packageVersion(p)))),
                probe = "namespace/version only; no model compilation, adaptation or MCMC")
stopifnot(runtime$JAGS == contract$paired_design$JAGS_version_required)
for (s in sources) stopifnot(identical(sha(s$path), s$actual))
result <- list(schema_version = "1.0-independent-contract-checks", reviewer_id = reviewer,
               executor_id = executor, started_at_utc = started,
               finished_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
               contract_sha256 = sources$contract$actual, computational_checks_status = "pass",
               review_status_inferred_from_checks = FALSE, MCMC_run = FALSE,
               distributions = cases, positive_conditionals = positive_conditionals,
               zero_mass_cells = zero_probability_cells, mixture_distributions = 100,
               max_absolute_errors = as.list(errors), priors = prior_moments,
               data_use = input_use, initialization = initialization,
               diagnostics_fixture = diagnostic_fixture, example = example,
               runtime = runtime, source_hashes = sources, supplementary_sources = supplemental,
               script_sha256 = sha(file.path(review_rel, "independent_checks.R")),
               not_tested = c("future D JAGS source or runtime", "future actual outgoing runner interface",
                              "empirical posterior mixing or run budget feasibility", "candidate implementation",
                              "data-preparation outputs", "external numeric replication"))
jsonlite::write_json(result, file.path(out, "checks.json"), pretty = TRUE,
                     auto_unbox = TRUE, digits = 16, na = "null")
cat("Initialization summaries:\n"); print(initialization)
cat("Diagnostic fixture:\n"); print(diagnostic_fixture)
cat("PASS scoped deterministic checks; no contract verdict is inferred automatically.\n")
print(sessionInfo())
sink()
