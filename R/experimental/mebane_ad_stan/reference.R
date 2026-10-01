# Independent base-R oracle. No call into the Stan program or previous R helper.
ad_stan_lse <- function(x) {
  peak <- max(x)
  if (is.infinite(peak) && peak < 0) return(-Inf)
  peak + log(sum(exp(x - peak)))
}

ad_stan_reference_log_probs <- function(eta, cls) {
  lt <- plogis(eta[1], log.p = TRUE)
  lnt <- plogis(eta[1], lower.tail = FALSE, log.p = TRUE)
  lu <- plogis(eta[2], log.p = TRUE)
  lnu <- plogis(eta[2], lower.tail = FALSE, log.p = TRUE)
  if (cls == 1L) {
    lm <- ls <- -Inf
    lnm <- lns <- 0
  } else if (cls == 2L) {
    lm <- log(0.7) + plogis(eta[3], log.p = TRUE)
    ls <- log(0.7) + plogis(eta[4], log.p = TRUE)
    lnm <- ad_stan_lse(c(log(0.3), log(0.7) + plogis(eta[3], lower.tail = FALSE, log.p = TRUE)))
    lns <- ad_stan_lse(c(log(0.3), log(0.7) + plogis(eta[4], lower.tail = FALSE, log.p = TRUE)))
  } else if (cls == 3L) {
    lm <- ad_stan_lse(c(log(0.7), log(0.3) + plogis(eta[5], log.p = TRUE)))
    ls <- ad_stan_lse(c(log(0.7), log(0.3) + plogis(eta[6], log.p = TRUE)))
    lnm <- log(0.3) + plogis(eta[5], lower.tail = FALSE, log.p = TRUE)
    lns <- log(0.3) + plogis(eta[6], lower.tail = FALSE, log.p = TRUE)
  } else stop("Invalid class")
  c(A = lnt + lnm, W = ad_stan_lse(c(lt + lu, lnt + lm, lt + lnu + ls)),
    O = lt + lnu + lns)
}

ad_stan_reference_mass <- function(y, logp) {
  lfactorial(sum(y)) - sum(lfactorial(y)) + sum(y[y > 0] * logp[y > 0])
}

ad_stan_reference_likelihood <- function(pars, data) {
  pi <- c(1, pars$r) / (1 + sum(pars$r))
  total <- 0
  for (i in seq_len(data$n)) {
    eta <- pars$alpha + pars$b0 + sqrt(pars$v) * pars$z[i, ]
    terms <- vapply(1:3, function(cls) log(pi[cls]) +
                      ad_stan_reference_mass(data$observed[i, ],
                                             ad_stan_reference_log_probs(eta, cls)), numeric(1))
    total <- total + ad_stan_lse(terms)
  }
  total
}

ad_stan_reference_lp <- function(pars, data, jacobian = FALSE, normalized = FALSE) {
  if (any(pars$v <= 0) || any(pars$r <= 0 | pars$r >= 1)) return(-Inf)
  if (normalized) {
    prior <- sum(dnorm(pars$alpha, log = TRUE)) + sum(dnorm(pars$b0, sd = 0.01, log = TRUE)) +
      sum(dexp(pars$v, rate = 5, log = TRUE)) + sum(dnorm(pars$z, log = TRUE))
  } else {
    prior <- -0.5 * sum(pars$alpha^2) - 0.5 * sum((pars$b0 / 0.01)^2) -
      5 * sum(pars$v) - 0.5 * sum(pars$z^2)
  }
  ans <- prior + ad_stan_reference_likelihood(pars, data)
  if (jacobian) ans <- ans + sum(log(pars$v)) + sum(log(pars$r) + log1p(-pars$r))
  ans
}

ad_stan_pack <- function(pars) c(pars$alpha, pars$b0, log(pars$v), as.vector(pars$z), qlogis(pars$r))

ad_stan_unpack <- function(u, n) {
  stopifnot(length(u) == 20L + 6L * n)
  list(alpha = u[1:6], b0 = u[7:12], v = exp(u[13:18]),
       z = matrix(u[19:(18 + 6 * n)], n, 6), r = plogis(tail(u, 2)))
}

ad_stan_reference_u_lp <- function(u, data, jacobian = FALSE) {
  ans <- ad_stan_reference_lp(ad_stan_unpack(u, data$n), data, jacobian = FALSE)
  if (jacobian) {
    # Work on the unconstrained scale to avoid 1-plogis(u) cancellation.
    ans <- ans + sum(u[13:18]) + sum(plogis(tail(u, 2), log.p = TRUE)) +
      sum(plogis(tail(u, 2), lower.tail = FALSE, log.p = TRUE))
  }
  ans
}

ad_stan_centered_lp <- function(pars, data) {
  h <- sweep(sweep(pars$z, 2, sqrt(pars$v), "*"), 2, pars$alpha, "+")
  prior <- sum(dnorm(pars$alpha, log = TRUE)) + sum(dnorm(pars$b0, sd = 0.01, log = TRUE)) +
    sum(dexp(pars$v, rate = 5, log = TRUE))
  for (j in 1:6) prior <- prior + sum(dnorm(h[, j], pars$alpha[j], sqrt(pars$v[j]), log = TRUE))
  prior + ad_stan_reference_likelihood(pars, data)
}
