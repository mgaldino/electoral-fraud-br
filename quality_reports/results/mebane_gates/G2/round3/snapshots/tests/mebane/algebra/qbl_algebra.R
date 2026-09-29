# Audit-only functions. No fit, no production implementation, no MCMC.
normal_precision <- function(x, mu, precision) {
  sqrt(precision / (2 * pi)) * exp(-precision * (x - mu)^2 / 2)
}

pi_from_aux <- function(a, b, c) c(a, b, c) / (a + b + c)
pi_density <- function(p1, p2) {
  p3 <- 1 - p1 - p2
  ifelse(p1 > 0 & p2 >= 0 & p3 >= 0 & p2 <= p1 & p3 <= p1,
         p1^(-3), 0)
}

manufactured_fraction <- function(count, N) {
  ifelse(count == N, 0.999, count / N)
}

pa <- function(tau, m) (1 - tau) * (1 - m)
pw_literal <- function(q, nu, m, s) {
  nu * ((1 - s) / (1 - m)) * (1 - m - q) +
    q * ((m - s) / (1 - m)) + s
}
pw_reduced <- function(q, nu, m, s) {
  c <- nu + (1 - nu) * s
  c + q * (m - c) / (1 - m)
}
pw_paper <- function(tau, nu, m, s) {
  nu * tau + m * (1 - tau) + s * tau * (1 - nu)
}
clamp <- function(p, eps = 1e-9) pmin(1 - eps, pmax(eps, p))
pw_stan <- function(q, nu, m, s) {
  d <- pmax(1e-9, 1 - m)
  clamp(nu * ((1 - s) / d) * (1 - m - q) + q * ((m - s) / d) + s)
}

# Invalid parents are zeroed ONLY as a named mathematical diagnostic kernel.
# This is not a claim about JAGS runtime error/rejection behavior.
observation_kernel <- function(N, A, W, tau, nu, m = 0, s = 0,
                               policy = c("reject_invalid", "stan_clamp", "paper")) {
  policy <- match.arg(policy)
  if (N < 1 || N != as.integer(N) || A < 0 || A > N || W < 0 || W > N ||
      A != as.integer(A) || W != as.integer(W)) return(0)
  p_a <- pa(tau, m)
  p_w <- switch(policy, reject_invalid = pw_literal(A / N, nu, m, s),
                stan_clamp = pw_stan(A / N, nu, m, s),
                paper = pw_paper(tau, nu, m, s))
  if (policy == "stan_clamp") p_a <- clamp(p_a)
  if (!is.finite(p_w) || p_w < 0 || p_w > 1) return(0)
  dbinom(A, N, p_a) * dbinom(W, N, p_w)
}

physical_multinomial <- function(N, A, W, tau, nu, m = 0, s = 0) {
  if (A + W > N) return(0)
  p_a <- pa(tau, m)
  p_w <- pw_paper(tau, nu, m, s)
  dmultinom(c(A, W, N - A - W), prob = c(p_a, p_w, 1 - p_a - p_w))
}

pair_sum <- function(N, A, W, tau, nu, mu_m, mu_s, policy = "reject_invalid") {
  total <- 0
  for (r in 0:N) {
    for (t in 0:N) {
      total <- total + dbinom(r, N, mu_m) * dbinom(t, N, mu_s) *
        observation_kernel(N, A, W, tau, nu, manufactured_fraction(r, N), t / N, policy)
    }
  }
  total
}

factorized_sum <- function(N, A, W, tau, nu, mus, pi, policy = "reject_invalid") {
  parts <- c(observation_kernel(N, A, W, tau, nu, policy = policy),
             pair_sum(N, A, W, tau, nu, mus[1], mus[2], policy),
             pair_sum(N, A, W, tau, nu, mus[3], mus[4], policy))
  sum(pi * parts)
}

brute_sum <- function(N, A, W, tau, nu, mus, pi) {
  result <- 0
  for (r in 0:N) for (t in 0:N) for (v in 0:N) for (u in 0:N) {
    weight <- prod(dbinom(c(r, t, v, u), N, mus))
    parts <- c(observation_kernel(N, A, W, tau, nu),
               observation_kernel(N, A, W, tau, nu, manufactured_fraction(r, N), t / N),
               observation_kernel(N, A, W, tau, nu, manufactured_fraction(v, N), u / N))
    result <- result + weight * sum(pi * parts)
  }
  result
}

total_mass <- function(N, tau, nu, m, s, policy, physical = FALSE) {
  result <- 0
  for (A in 0:N) for (W in 0:N) {
    if (!physical || A + W <= N) {
      result <- result + observation_kernel(N, A, W, tau, nu, m, s, policy)
    }
  }
  result
}

normalizer_pair <- function(N, tau, nu, mu_m, mu_s, physical = FALSE) {
  result <- 0
  for (r in 0:N) for (t in 0:N) for (A in 0:N) {
    m <- manufactured_fraction(r, N)
    p_w <- pw_literal(A / N, nu, m, t / N)
    if (is.finite(p_w) && p_w >= 0 && p_w <= 1) {
      w_mass <- if (physical) pbinom(N - A, N, p_w) else 1
      result <- result + dbinom(r, N, mu_m) * dbinom(t, N, mu_s) *
        dbinom(A, N, pa(tau, m)) * w_mass
    }
  }
  result
}

fraud_amounts <- function(N, tau, nu, m, s) {
  M <- N * m * (1 - tau)
  S <- N * s * tau * (1 - nu)
  c(manufactured = M, stolen = S, total = M + S)
}
