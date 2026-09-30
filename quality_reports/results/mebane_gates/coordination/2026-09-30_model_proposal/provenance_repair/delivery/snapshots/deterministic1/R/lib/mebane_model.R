# Literal qbl equations. Invalid-parent zero is an audit kernel, not a JAGS claim.
mebane_fraction <- function(r, N, manufactured = FALSE) {
  if (manufactured && r == N) 0.999 else r / N
}

mebane_probabilities <- function(N, A, z, counts, tau, nu) {
  stopifnot(length(counts) == 4L, z %in% 1:3, N >= 1, A >= 0, A <= N)
  m <- c(0, mebane_fraction(counts[1], N, TRUE),
         mebane_fraction(counts[3], N, TRUE))[z]
  s <- c(0, counts[2] / N, counts[4] / N)[z]
  pa <- (1 - tau) * (1 - m)
  q <- A / N
  # Keep both inactive terms in the literal expression for runtime auditing.
  im <- mebane_fraction(counts[1], N, TRUE)
  is <- counts[2] / N
  cm <- mebane_fraction(counts[3], N, TRUE)
  cs <- counts[4] / N
  term <- function(m, s) nu * ((1 - s) / (1 - m)) * (1 - m - q) +
    q * ((m - s) / (1 - m)) + s
  pw <- (z == 1) * nu * (1 - q) + (z == 2) * term(im, is) +
    (z == 3) * term(cm, cs)
  c(pa = pa, pw = pw, m = m, s = s)
}

mebane_kernel <- function(N, A, W, z, counts, tau, nu) {
  if (any(!is.finite(c(N, A, W, tau, nu, counts))) ||
      N < 1 || N != floor(N) || A < 0 || A > N || A != floor(A) ||
      W < 0 || W > N || W != floor(W)) return(0)
  p <- mebane_probabilities(N, A, z, counts, tau, nu)
  if (any(!is.finite(p[1:2])) || any(p[1:2] < 0 | p[1:2] > 1)) return(0)
  dbinom(A, N, p["pa"]) * dbinom(W, N, p["pw"])
}

mebane_enumerate <- function(N, A, W, tau, nu, mus, pi) {
  stopifnot(N %in% 1:3, length(mus) == 4L, length(pi) == 3L)
  out <- 0
  for (z in 1:3) for (r1 in 0:N) for (r2 in 0:N)
    for (r3 in 0:N) for (r4 in 0:N) {
      counts <- c(r1, r2, r3, r4)
      out <- out + pi[z] * prod(dbinom(counts, N, mus)) *
        mebane_kernel(N, A, W, z, counts, tau, nu)
    }
  out
}

mebane_factorized <- function(N, A, W, tau, nu, mus, pi) {
  stopifnot(N %in% 1:3, length(mus) == 4L, length(pi) == 3L)
  base <- mebane_kernel(N, A, W, 1, rep(0, 4), tau, nu)
  pair <- function(z, indices) {
    ans <- 0
    for (r in 0:N) for (s in 0:N) {
      counts <- rep(0, 4)
      counts[indices] <- c(r, s)
      ans <- ans + prod(dbinom(c(r, s), N, mus[indices])) *
        mebane_kernel(N, A, W, z, counts, tau, nu)
    }
    ans
  }
  sum(pi * c(base, pair(2, 1:2), pair(3, 3:4)))
}

mebane_mass <- function(N, tau, nu, mus, pi, physical = FALSE) {
  sum(vapply(0:N, function(A) sum(vapply(0:N, function(W) {
    if (physical && A + W > N) return(0)
    mebane_factorized(N, A, W, tau, nu, mus, pi)
  }, numeric(1))), numeric(1)))
}

mebane_attempts <- function(n_attempts, seed, max_N = 3L) {
  set.seed(seed)
  blocks <- c("tau", "nu", "iota.m", "iota.s", "chi.m", "chi.s")
  out <- vector("list", n_attempts)
  for (i in seq_len(n_attempts)) {
    N <- sample.int(max_N, 1)
    h0 <- runif(1)
    aux <- c(h0, runif(1, 0, h0), runif(1, 0, h0))
    alpha <- rnorm(6)
    variance <- rexp(6, rate = 5)
    beta0 <- rnorm(6, sd = 0.01)
    effect <- rnorm(6, alpha, sqrt(variance))
    eta <- effect + beta0
    names(eta) <- blocks
    mu <- c(plogis(eta[1:2]), 0.7 * plogis(eta[3:4]),
            0.7 + 0.3 * plogis(eta[5:6]))
    counts <- rbinom(4, N, mu[3:6])
    z <- sample.int(3, 1, prob = aux / sum(aux))
    # A is generated before pW, exactly as its observed-parent dependence requires.
    pa <- (1 - mu[1]) * (1 - c(0, mebane_fraction(counts[1], N, TRUE),
                                mebane_fraction(counts[3], N, TRUE))[z])
    A <- rbinom(1, N, pa)
    p <- mebane_probabilities(N, A, z, counts, mu[1], mu[2])
    valid <- all(is.finite(p[1:2])) && all(p[1:2] >= 0 & p[1:2] <= 1)
    W <- if (valid) rbinom(1, N, p["pw"]) else NA_integer_
    out[[i]] <- data.frame(attempt = i, N = N, Z = z, A = A, W = W,
                           r_im = counts[1], r_is = counts[2],
                           r_cm = counts[3], r_cs = counts[4],
                           tau = unname(mu[1]), nu = unname(mu[2]),
                           pa = unname(p["pa"]), pw = unname(p["pw"]),
                           status = if (!valid) "invalid_probability" else if (A + W > N)
                             "invalid_physical" else "valid")
  }
  do.call(rbind, out)
}

mebane_joint_functionals <- function(draws) {
  required <- c("draw", "N", "Z", "tau", "nu", "r_im", "r_is", "r_cm", "r_cs", "Dobs")
  stopifnot(all(required %in% names(draws)))
  by_draw <- split(draws, draws$draw)
  do.call(rbind, lapply(by_draw, function(x) {
    m <- ifelse(x$Z == 1, 0, ifelse(x$Z == 2,
      ifelse(x$r_im == x$N, 0.999, x$r_im / x$N),
      ifelse(x$r_cm == x$N, 0.999, x$r_cm / x$N)))
    s <- ifelse(x$Z == 1, 0, ifelse(x$Z == 2, x$r_is / x$N, x$r_cs / x$N))
    M <- sum(x$N * m * (1 - x$tau))
    S <- sum(x$N * s * x$tau * (1 - x$nu))
    stopifnot(length(unique(x$Dobs)) == 1L)
    data.frame(draw = x$draw[1], M = M, S = S,
               margin_lower = x$Dobs[1] - M - 2 * S,
               margin_upper = x$Dobs[1] - M - S,
               class1 = sum(x$Z == 1), class2 = sum(x$Z == 2),
               class3 = sum(x$Z == 3))
  }))
}
