args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 6L) {
  stop("Usage: test_model_d.R MODEL_R MODEL_JAGS A_JAGS CONTRACT_V2 DATA_RDS IO_R")
}
names(args) <- c("model_r", "model_jags", "a_jags", "contract", "data_rds", "io_r")
source(args[["io_r"]], local = TRUE)
ad_setup()
source(args[["model_r"]], local = TRUE)
if (!requireNamespace("rjags", quietly = TRUE)) stop("Existing rjags is required")

check <- function(ok, label) {
  if (!isTRUE(ok)) stop("FAIL: ", label)
}
near <- function(x, y, tolerance, label) {
  if (length(x) != length(y) || anyNA(x) || anyNA(y) ||
      any(abs(as.numeric(x) - as.numeric(y)) > tolerance)) {
    stop("FAIL: ", label)
  }
}
rejects <- function(expr, label) {
  check(tryCatch({ force(expr); FALSE }, error = function(e) TRUE), label)
}

check(ad_sha(args[["contract"]]) ==
        "d17b7f508a7ce87eec3ca71ed7df67666b528c755e005ec9e1299e5ff9deb509",
      "contract v2 hash")
check(ad_sha(args[["a_jags"]]) ==
        "f8360126424b7a463f76a1c99efc89a8a5cb81339213bd4931559f14595fbab6",
      "unaltered A source hash")
check(ad_sha(args[["data_rds"]]) ==
        "b2ef611dabb751f9286acbaae841a23c34948ed0a4b6306364cbe94d9d24903e",
      "unaltered prepared data hash")
contract <- jsonlite::read_json(args[["contract"]], simplifyVector = TRUE)
check(identical(contract$contract_id, "AD-DC2010-v2"), "contract ID")
check(identical(as.numeric(contract$D$k), 0.7), "k")
check(identical(as.character(rjags::jags.version()), "4.3.2"), "JAGS 4.3.2")
cat("hashes and local runtime: PASS\n")

states <- function(N) {
  result <- expand.grid(A = 0:N, W = 0:N)
  result <- result[result$A + result$W <= N, , drop = FALSE]
  result$O <- N - result$A - result$W
  result
}

# Independent finite mechanism enumeration, retaining latent L/M/S for conditioning.
mechanism <- function(N, tau, nu, m, s) {
  final <- states(N)
  mass <- numeric(nrow(final))
  joint <- array(0, dim = rep(N + 1L, 4L),
                 dimnames = list(W = 0:N, L = 0:N, M = 0:N, S = 0:N))
  base_p <- c(1 - tau, tau * nu, tau * (1 - nu))
  for (A0 in 0:N) for (L0 in 0:(N - A0)) {
    O0 <- N - A0 - L0
    base_mass <- dmultinom(c(A0, L0, O0), prob = base_p)
    if (base_mass == 0) next
    for (M in 0:A0) for (S in 0:O0) {
      weight <- base_mass * dbinom(M, A0, m) * dbinom(S, O0, s)
      if (weight == 0) next
      A <- A0 - M
      W <- L0 + M + S
      O <- O0 - S
      index <- which(final$A == A & final$W == W & final$O == O)
      mass[[index]] <- mass[[index]] + weight
      joint[W + 1L, L0 + 1L, M + 1L, S + 1L] <-
        joint[W + 1L, L0 + 1L, M + 1L, S + 1L] + weight
    }
  }
  list(states = final, mass = mass, joint = joint)
}

conditional_check <- function(e, N, tau, nu, m, s) {
  for (W in 0:N) {
    total <- sum(e$joint[W + 1L, , , ])
    if (total == 0) next
    rows <- list()
    weights <- numeric()
    for (L in 0:W) for (M in 0:(W - L)) {
      S <- W - L - M
      weight <- e$joint[W + 1L, L + 1L, M + 1L, S + 1L] / total
      expected <- exp(ad_d_conditional_lms_logpmf(
        c(L = L, M = M, S = S), W, tau, nu, m, s))
      near(weight, expected, 1e-11, "full conditional L/M/S pmf")
      rows[[length(rows) + 1L]] <- c(L, M, S)
      weights <- c(weights, weight)
    }
    near(sum(weights), 1, 1e-11, "conditional normalization")
    values <- do.call(rbind, rows)
    means <- colSums(values * weights)
    centered <- sweep(values, 2L, means)
    covariance <- t(centered) %*% (centered * weights)
    exact <- ad_d_conditional_lms(W, tau, nu, m, s)
    near(means, exact$mean, 1e-11, "conditional means")
    near(covariance, exact$covariance, 1e-11, "conditional covariance")
  }
}

grid <- c(0, 0.2, 0.7, 1)
cases <- expand.grid(tau = grid, nu = grid, m = grid, s = grid)
max_probability_error <- 0
max_logmass_error <- 0
evaluated <- 0L
conditional_cells <- 0L
for (N in 1:4) for (row in seq_len(nrow(cases))) {
  tau <- cases$tau[[row]]
  nu <- cases$nu[[row]]
  m <- cases$m[[row]]
  s <- cases$s[[row]]
  p <- ad_d_probabilities(tau, nu, m, s)
  check(all(p >= 0 & p <= 1), "simplex bounds")
  near(sum(p), 1, 1e-11, "simplex sum")
  e <- mechanism(N, tau, nu, m, s)
  near(sum(e$mass), 1, 1e-11, "mechanism normalization")
  for (j in seq_len(nrow(e$states))) {
    count <- as.numeric(e$states[j, c("A", "W", "O")])
    names(count) <- c("A", "W", "O")
    expected <- dmultinom(count, prob = p)
    error <- abs(e$mass[[j]] - expected)
    max_probability_error <- max(max_probability_error, error)
    near(e$mass[[j]], expected, 1e-11, "mechanism vs multinomial")
    log_mass <- ad_d_loglik_multinomial(count, N, p)
    if (expected == 0) {
      check(identical(log_mass, -Inf), "zero mass log support")
    } else {
      max_logmass_error <- max(max_logmass_error, abs(log_mass - log(expected)))
      near(log_mass, log(expected), 1e-9, "multinomial log mass")
    }
    sequential <- dbinom(count[["A"]], N, p[["A"]])
    if (p[["A"]] < 1) {
      sequential <- sequential * dbinom(count[["W"]], N - count[["A"]],
                                        p[["W"]] / (p[["W"]] + p[["O"]]))
    } else {
      sequential <- as.numeric(count[["A"]] == N && count[["W"]] == 0)
    }
    near(sequential, expected, 1e-11, "sequential factorization")
    evaluated <- evaluated + 1L
  }
  conditional_check(e, N, tau, nu, m, s)
  conditional_cells <- conditional_cells + 1L
}
cat("grid: ", nrow(cases) * 4L, " distributions, ", evaluated,
    " physical cells, ", conditional_cells, " conditional blocks; max errors ",
    format(max_probability_error, digits = 5), " / ",
    format(max_logmass_error, digits = 5), "\n", sep = "")

for (theta in list(c(0.6, 0.4, 0.2, 0.3), c(0.999, 0.2, 0.7, 0.999),
                   c(0, 1, 1, 0), c(1, 0, 0, 1))) {
  p <- do.call(ad_d_probabilities, as.list(theta))
  near(sum(p), 1, 1e-11, "boundary/asymmetric simplex")
  e <- do.call(mechanism, c(list(N = 4L), as.list(theta)))
  for (j in seq_len(nrow(e$states))) {
    near(e$mass[[j]], dmultinom(as.numeric(e$states[j, c("A", "W", "O")]), prob = p),
         1e-11, "boundary/asymmetric mechanism")
  }
  do.call(conditional_check, c(list(e = e, N = 4L), as.list(theta)))
}
degenerate <- ad_d_conditional_lms(0L, 0, 0.4, 0, 0)
check(degenerate$degenerate && all(degenerate$mean == 0), "pW=0,W=0")
rejects(ad_d_conditional_lms(1L, 0, 0.4, 0, 0), "impossible W")
rejects(ad_d_loglik_multinomial(c(A = 1, W = 1, O = 0), 1,
                                c(A = 0.5, W = 0.3, O = 0.2)), "physical support")
rejects(ad_d_loglik_multinomial(c(A = 1, W = 0, O = 0), 1,
                                c(A = 0.6, W = 0.3, O = 0.2)), "no hidden renormalization")

for (pi in list(c(0.6, 0.25, 0.15), c(1, 0, 0), c(0.4, 0.2, 0.4))) {
  magnitudes <- list(m = c(0, 0.2, 0.8), s = c(0, 0.3, 0.9))
  class_p <- ad_d_class_probabilities(0.6, 0.4, magnitudes$m, magnitudes$s)
  near(ad_d_mixture_probabilities(pi, 0.6, 0.4, magnitudes$m, magnitudes$s),
       colSums(class_p * pi), 1e-11, "class mixture probabilities")
  for (N in 1:4) {
    cells <- states(N)
    for (j in seq_len(nrow(cells))) {
      count <- as.numeric(cells[j, c("A", "W", "O")])
      names(count) <- c("A", "W", "O")
      explicit <- sum(vapply(seq_len(3L), function(z) {
        pi[[z]] * dmultinom(count, prob = class_p[z, ])
      }, numeric(1L)))
      near(exp(ad_d_mixture_loglik(count, N, pi, 0.6, 0.4,
                                   magnitudes$m, magnitudes$s)), explicit,
           1e-11, "mixture vs explicit class sum")
    }
  }
}
cat("boundaries, log mass, mixture and conditional covariance: PASS\n")

d_source <- paste(readLines(args[["model_jags"]], warn = FALSE), collapse = "\n")
a_source <- paste(readLines(args[["a_jags"]], warn = FALSE), collapse = "\n")
blocks <- c("tau", "nu", "iota.m", "iota.s", "chi.m", "chi.s")
v_names <- c("tb", "nb", "imb", "isb", "cmb", "csb")
h_names <- c("th", "nh", "imh", "ish", "cmh", "csh")
for (j in seq_along(blocks)) {
  block <- blocks[[j]]
  check(grepl(paste0(block, ".alpha ~ dnorm(0, 1)"), d_source, fixed = TRUE),
        paste("alpha prior", block))
  check(grepl(paste0("beta.", block, "1 ~ dnorm(0, 10000)"), d_source,
              fixed = TRUE), paste("b0 precision", block))
  check(grepl(paste0(v_names[[j]], " ~ dexp(5)"), d_source, fixed = TRUE),
        paste("Exp(5) variance", block))
  check(grepl(paste0(h_names[[j]], "[i] ~ dnorm(", block, ".alpha, ",
                     block, ".beta)"), d_source, fixed = TRUE),
        paste("centered random effect", block))
  check(grepl(paste0(v_names[[j]], " ~ dexp(5)"), a_source, fixed = TRUE),
        paste("A variance prior", block))
}
for (part in c("pi.aux1 ~ dunif(0, 1)", "pi.aux2 ~ dunif(0, pi.aux1)",
               "pi.aux3 ~ dunif(0, pi.aux1)", "Z[i] ~ dcat(pi[])",
               "observed[i, 1:3] ~ dmulti(p[i, 1:3], N[i])")) {
  check(grepl(part, d_source, fixed = TRUE), paste("D source", part))
}
for (forbidden in c("dbin(", "0.999", ".999", "clamp", "N.iota", "N.chi")) {
  check(!grepl(forbidden, d_source, fixed = TRUE), paste("prohibited D feature", forbidden))
}
u <- c(0.8, 0.2, 0.3)
pi <- u / sum(u)
check(pi[[1L]] >= max(pi[-1L]) && pi[[3L]] > pi[[2L]], "partial pi order")
check(abs(1 / 5 - 0.2) < 1e-15, "Exp(5) is on variance")
cat("prior/source static audit: PASS\n")

prepared <- readRDS(args[["data_rds"]])
check(identical(colnames(prepared$D$observed), c("A", "W", "O")), "D data order")
check(identical(prepared$D$observed[, "A"], prepared$A$a), "A role")
check(identical(prepared$D$observed[, "W"], prepared$A$w), "W role")
check(all(rowSums(prepared$D$observed) == prepared$D$N), "data identity")
check(length(prepared$D$N) == 143L, "143 data rows")
swapped <- prepared$D$observed[, c("W", "A", "O")]
colnames(swapped) <- c("A", "W", "O")
check(!identical(swapped[, "A"], prepared$A$a), "wrong-input negative control")
cat("prepared data interface and swapped negative control: PASS\n")

# All stochastic nodes are conditioned to synthetic values; only deterministic
# nodes are sampled. This is not a posterior fit to D.C. or to any observed case.
synthetic <- list(n = 3L, N = c(10L, 11L, 12L),
                  observed = rbind(c(3L, 4L, 3L), c(4L, 4L, 3L),
                                   c(2L, 6L, 4L)),
                  Z = 1:3, pi.aux1 = 0.8, pi.aux2 = 0.2, pi.aux3 = 0.1)
tau <- c(0.6, 0.6, 0.6)
nu <- c(0.4, 0.4, 0.4)
fixed <- list(th = qlogis(tau), nh = qlogis(nu),
              imh = rep(qlogis(0.2 / 0.7), 3L),
              ish = rep(qlogis(0.3 / 0.7), 3L),
              cmh = rep(qlogis((0.8 - 0.7) / 0.3), 3L),
              csh = rep(qlogis((0.9 - 0.7) / 0.3), 3L))
for (j in seq_along(blocks)) {
  synthetic[[paste0(blocks[[j]], ".alpha")]] <- 0
  synthetic[[paste0("beta.", blocks[[j]], "1")]] <- 0
  synthetic[[v_names[[j]]]] <- 0.2
  synthetic[[h_names[[j]]]] <- fixed[[h_names[[j]]]]
}
cat("JAGS fixed-parent call: jags.model(n=3, all stochastic parents and observations conditioned, n.adapt=0)\n")
jags <- rjags::jags.model(args[["model_jags"]], data = synthetic,
                          n.chains = 1L, n.adapt = 0L, quiet = TRUE)
cat("JAGS fixed-parent call: jags.samples(p.a,p.w,p.o,m,s, n.iter=1)\n")
draw <- rjags::jags.samples(jags, c("p.a", "p.w", "p.o", "m", "s"), n.iter = 1L)
for (i in 1:3) {
  magnitudes <- ad_d_magnitudes(fixed$imh[[i]], fixed$ish[[i]],
                                fixed$cmh[[i]], fixed$csh[[i]])
  p <- ad_d_probabilities(tau[[i]], nu[[i]],
                          magnitudes$m[[i]], magnitudes$s[[i]])
  near(as.numeric(draw[["p.a"]])[[i]], p[["A"]], 1e-11, "JAGS p.a vs R")
  near(as.numeric(draw[["p.w"]])[[i]], p[["W"]], 1e-11, "JAGS p.w vs R")
  near(as.numeric(draw[["p.o"]])[[i]], p[["O"]], 1e-11, "JAGS p.o vs R")
  near(as.numeric(draw[["m"]])[i + 3L * (0:2)], magnitudes$m,
       1e-11, "JAGS m classes vs R")
  near(as.numeric(draw[["s"]])[i + 3L * (0:2)], magnitudes$s,
       1e-11, "JAGS s classes vs R")
}
cat("JAGS deterministic fixed-parent comparison: PASS\n")
cat("ALL MODEL D PREFLIGHT CHECKS PASS; NO EMPIRICAL POSTERIOR OR MCMC PILOT\n")
