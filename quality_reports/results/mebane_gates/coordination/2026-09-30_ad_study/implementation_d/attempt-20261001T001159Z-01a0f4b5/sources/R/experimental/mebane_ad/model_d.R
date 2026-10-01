# Deterministic calculations for the experimental D transfer model.
ad_d_unit <- function(x, name) {
  if (!is.numeric(x) || length(x) != 1L || is.na(x) || !is.finite(x) ||
      x < 0 || x > 1) stop(name, " must be one finite probability")
  as.numeric(x)
}

ad_d_count <- function(x, name) {
  if (!is.numeric(x) || length(x) != 1L || is.na(x) || !is.finite(x) ||
      x < 0 || x != floor(x)) stop(name, " must be one nonnegative integer count")
  as.numeric(x)
}

ad_d_probabilities <- function(tau, nu, m, s) {
  tau <- ad_d_unit(tau, "tau")
  nu <- ad_d_unit(nu, "nu")
  m <- ad_d_unit(m, "m")
  s <- ad_d_unit(s, "s")
  c(A = (1 - tau) * (1 - m),
    W = tau * nu + (1 - tau) * m + tau * (1 - nu) * s,
    O = tau * (1 - nu) * (1 - s))
}

ad_d_magnitudes <- function(eta_iota_m, eta_iota_s, eta_chi_m, eta_chi_s) {
  eta <- c(eta_iota_m, eta_iota_s, eta_chi_m, eta_chi_s)
  if (!is.numeric(eta) || length(eta) != 4L || anyNA(eta) ||
      any(!is.finite(eta))) stop("All four magnitude predictors must be finite")
  k <- 0.7
  list(m = c(0, k * plogis(eta[[1L]]), k + (1 - k) * plogis(eta[[3L]])),
       s = c(0, k * plogis(eta[[2L]]), k + (1 - k) * plogis(eta[[4L]])))
}

ad_d_class_probabilities <- function(tau, nu, m, s) {
  if (!is.numeric(m) || !is.numeric(s) || length(m) != 3L ||
      length(s) != 3L || m[[1L]] != 0 || s[[1L]] != 0) {
    stop("D requires three classes with m[1]=s[1]=0")
  }
  result <- t(vapply(seq_len(3L), function(z) {
    ad_d_probabilities(tau, nu, m[[z]], s[[z]])
  }, numeric(3L)))
  rownames(result) <- paste0("Z", seq_len(3L))
  colnames(result) <- c("A", "W", "O")
  result
}

ad_d_validate_observed <- function(observed, N) {
  N <- ad_d_count(N, "N")
  if (!is.numeric(observed) || length(observed) != 3L ||
      !identical(names(observed), c("A", "W", "O"))) {
    stop("observed must be named c(A,W,O)")
  }
  counts <- vapply(seq_along(observed), function(i) {
    ad_d_count(observed[[i]], names(observed)[[i]])
  }, numeric(1L))
  names(counts) <- names(observed)
  if (sum(counts) != N) stop("A+W+O must equal N")
  counts
}

ad_d_loglik_multinomial <- function(observed, N, probabilities) {
  counts <- ad_d_validate_observed(observed, N)
  if (!is.numeric(probabilities) || length(probabilities) != 3L ||
      !identical(names(probabilities), c("A", "W", "O"))) {
    stop("probabilities must be named c(A,W,O)")
  }
  if (anyNA(probabilities) || any(!is.finite(probabilities)) ||
      any(probabilities < 0 | probabilities > 1) ||
      abs(sum(probabilities) - 1) > 1e-12) {
    stop("probabilities must form a simplex; no renormalization is applied")
  }
  if (any(counts > 0 & probabilities == 0)) return(-Inf)
  lfactorial(N) - sum(lfactorial(counts)) +
    sum(counts[counts > 0] * log(probabilities[counts > 0]))
}

ad_d_mixture_probabilities <- function(pi, tau, nu, m, s) {
  if (!is.numeric(pi) || length(pi) != 3L || anyNA(pi) ||
      any(!is.finite(pi)) || any(pi < 0 | pi > 1) ||
      abs(sum(pi) - 1) > 1e-12) stop("pi must be a three-class simplex")
  as.numeric(pi %*% ad_d_class_probabilities(tau, nu, m, s)) |>
    stats::setNames(c("A", "W", "O"))
}

ad_d_mixture_loglik <- function(observed, N, pi, tau, nu, m, s) {
  ad_d_mixture_probabilities(pi, tau, nu, m, s)
  class_p <- ad_d_class_probabilities(tau, nu, m, s)
  terms <- vapply(seq_len(3L), function(z) {
    if (pi[[z]] == 0) return(-Inf)
    log(pi[[z]]) + ad_d_loglik_multinomial(observed, N, class_p[z, ])
  }, numeric(1L))
  largest <- max(terms)
  if (!is.finite(largest)) return(-Inf)
  largest + log(sum(exp(terms - largest)))
}

ad_d_conditional_lms <- function(W, tau, nu, m, s) {
  W <- ad_d_count(W, "W")
  p <- ad_d_probabilities(tau, nu, m, s)
  components <- c(L = tau * nu, M = (1 - tau) * m,
                  S = tau * (1 - nu) * s)
  if (p[["W"]] == 0) {
    if (W != 0) stop("Conditioning on W>0 when pW=0 is impossible")
    zero <- c(L = 0, M = 0, S = 0)
    return(list(probabilities = zero, mean = zero,
                covariance = matrix(0, 3L, 3L,
                                    dimnames = list(names(zero), names(zero))),
                degenerate = TRUE))
  }
  q <- components / p[["W"]]
  covariance <- W * (diag(q) - outer(q, q))
  dimnames(covariance) <- list(names(q), names(q))
  list(probabilities = q, mean = W * q,
       covariance = covariance, degenerate = FALSE)
}

ad_d_conditional_lms_logpmf <- function(lms, W, tau, nu, m, s) {
  W <- ad_d_count(W, "W")
  if (!is.numeric(lms) || length(lms) != 3L ||
      !identical(names(lms), c("L", "M", "S"))) {
    stop("lms must be named c(L,M,S)")
  }
  counts <- vapply(seq_along(lms), function(i) {
    ad_d_count(lms[[i]], names(lms)[[i]])
  }, numeric(1L))
  names(counts) <- names(lms)
  if (sum(counts) != W) stop("L+M+S must equal W")
  conditional <- ad_d_conditional_lms(W, tau, nu, m, s)
  if (conditional$degenerate) return(0)
  q <- conditional$probabilities
  if (any(counts > 0 & q == 0)) return(-Inf)
  lfactorial(W) - sum(lfactorial(counts)) +
    sum(counts[counts > 0] * log(q[counts > 0]))
}
