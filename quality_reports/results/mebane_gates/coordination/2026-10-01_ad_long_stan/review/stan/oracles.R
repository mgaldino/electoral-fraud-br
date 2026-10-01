# Prepared independent oracles. No automatic execution, model sampling or writes.
review_near <- function(actual, expected, tolerance = 1e-9) {
  stopifnot(length(actual) == length(expected), !anyNA(actual), !anyNA(expected))
  a <- as.numeric(actual)
  b <- as.numeric(expected)
  finite <- is.finite(a) & is.finite(b)
  stopifnot(identical(a[!finite], b[!finite]))
  error <- if (any(finite)) max(abs(a[finite] - b[finite])) else 0
  stopifnot(error <= tolerance)
  error
}

review_lse <- function(x) {
  m <- max(x)
  if (m == -Inf) return(-Inf)
  m + log(sum(exp(x - m)))
}

review_prior_identities <- function() {
  grid <- expand.grid(u1 = c(1e-4, .13, .81), r2 = c(.03, .7), r3 = c(.21, .91))
  errors <- numeric(nrow(grid))
  for (i in seq_len(nrow(grid))) {
    a <- grid$u1[i]
    r <- unlist(grid[i, c("r2", "r3")], use.names = FALSE)
    J <- rbind(c(1, 0, 0), c(r[1], a, 0), c(r[2], 0, a))
    errors[i] <- abs((a^-2) * abs(det(J)) - 1)
    review_near(c(a, a * r) / sum(c(a, a * r)), c(1, r) / (1 + sum(r)), 1e-14)
    p <- c(1, r) / (1 + sum(r))
    stopifnot(p[1] >= max(p[-1]))
  }
  stopifnot(max(errors) < 1e-13, any(grid$r2 > grid$r3), any(grid$r3 > grid$r2))
  list(points = nrow(grid), max_density_error = max(errors))
}

review_forward <- function(pars, data) {
  stopifnot(nrow(pars$z) == data$n, ncol(pars$z) == 6L,
            all(pars$v > 0), all(pars$r > 0 & pars$r < 1))
  eta <- sweep(sweep(pars$z, 2, sqrt(pars$v), "*"), 2, pars$alpha + pars$b0, "+")
  mu <- plogis(eta)
  mu[, 3:4] <- .7 * mu[, 3:4, drop = FALSE]
  mu[, 5:6] <- .7 + .3 * mu[, 5:6, drop = FALSE]
  pi <- c(1, pars$r) / (1 + sum(pars$r))
  rows <- lapply(seq_len(data$n), function(i) {
    t <- mu[i, 1]
    u <- mu[i, 2]
    m <- c(0, mu[i, 3], mu[i, 5])
    s <- c(0, mu[i, 4], mu[i, 6])
    p <- cbind(A = (1 - t) * (1 - m),
               W = t * u + (1 - t) * m + t * (1 - u) * s,
               O = t * (1 - u) * (1 - s))
    terms <- log(pi) + apply(p, 1, function(q)
      dmultinom(data$observed[i, ], prob = q, log = TRUE))
    log_mass <- review_lse(terms)
    q <- exp(terms - log_mass)
    list(p = p, q = q, log_mass = log_mass,
         M = data$N[i] * (1 - t) * m,
         S = data$N[i] * t * (1 - u) * s)
  })
  list(pi = pi, mu = mu, rows = rows)
}

review_log_density <- function(pars, data, jacobian = FALSE) {
  f <- review_forward(pars, data)
  prior <- sum(dnorm(pars$alpha, log = TRUE)) +
    sum(dnorm(pars$b0, sd = .01, log = TRUE)) +
    sum(dexp(pars$v, rate = 5, log = TRUE)) + sum(dnorm(pars$z, log = TRUE))
  answer <- prior + sum(vapply(f$rows, `[[`, numeric(1), "log_mass"))
  if (jacobian) answer <- answer + sum(log(pars$v)) + sum(log(pars$r) + log1p(-pars$r))
  answer
}

review_pack <- function(p) c(p$alpha, p$b0, log(p$v), as.vector(p$z), qlogis(p$r))

review_unpack <- function(u, n) {
  stopifnot(length(u) == 20L + 6L * n)
  list(alpha = u[1:6], b0 = u[7:12], v = exp(u[13:18]),
       z = matrix(u[seq.int(19, 18 + 6 * n)], n, 6), r = plogis(tail(u, 2)))
}

# fit must be an existing frozen synthetic fit with deterministic methods ready.
# The checker never calls sample(), generate_quantities() or a model runner.
review_compiled_density <- function(fit, states, data) {
  result <- list()
  for (jac in c(FALSE, TRUE)) {
    oracle <- compiled <- numeric(length(states))
    for (k in seq_along(states)) {
      p <- states[[k]]
      u <- review_pack(p)
      review_near(fit$unconstrain_variables(p), u, 1e-10)
      compiled[k] <- fit$log_prob(u, jacobian = jac)
      oracle[k] <- review_log_density(p, data, jacobian = jac)
    }
    # Compare changes so Stan's dropped normalizing constants cannot cause a false failure.
    error <- review_near(compiled - compiled[1], oracle - oracle[1], 1e-8)
    result[[paste0("density_jacobian_", jac)]] <- list(max_error = error, cases = length(states))
  }
  for (k in seq_along(states)) {
    p <- states[[k]]
    u <- review_pack(p)
    expected <- sum(log(p$v)) + sum(log(p$r) + log1p(-p$r))
    review_near(fit$log_prob(u, jacobian = TRUE) - fit$log_prob(u, jacobian = FALSE), expected, 1e-9)
    h <- sweep(sweep(p$z, 2, sqrt(p$v), "*"), 2, p$alpha, "+")
    centered <- sum(vapply(1:6, function(j) sum(dnorm(h[, j], p$alpha[j], sqrt(p$v[j]), log = TRUE)), numeric(1)))
    review_near(centered + data$n / 2 * sum(log(p$v)), sum(dnorm(p$z, log = TRUE)), 1e-9)
  }
  u <- review_pack(states[[1]])
  for (jac in c(FALSE, TRUE)) {
    numeric_gradient <- vapply(seq_along(u), function(j) {
      step <- 1e-5 * max(1, abs(u[j]))
      upper <- lower <- u
      upper[j] <- upper[j] + step
      lower[j] <- lower[j] - step
      (review_log_density(review_unpack(upper, data$n), data, jac) -
         review_log_density(review_unpack(lower, data$n), data, jac)) / (2 * step)
    }, numeric(1))
    gradient <- as.numeric(fit$grad_log_prob(u, jacobian = jac))
    stopifnot(length(gradient) == length(numeric_gradient), all(is.finite(gradient)))
    relative_error <- max(abs(gradient - numeric_gradient) / pmax(1, abs(numeric_gradient)))
    stopifnot(relative_error < 5e-5)
    result[[paste0("gradient_jacobian_", jac)]] <- list(max_scaled_error = relative_error)
  }
  result
}

review_fixed_GQ <- function(draws, pars, data) {
  stopifnot(is.matrix(draws), nrow(draws) > 0L)
  f <- review_forward(pars, data)
  get <- function(x) as.numeric(draws[, x])
  M <- S <- MRB <- SRB <- numeric(nrow(draws))
  for (i in seq_len(data$n)) {
    row <- f$rows[[i]]
    Z <- get(sprintf("Z[%d]", i))
    stopifnot(all(Z %in% 1:3))
    review_near(Z, get(sprintf("Z_rng[%d]", i)), 0)
    for (j in 1:6) review_near(get(sprintf("mu[%d,%d]", i, j)), rep(f$mu[i, j], nrow(draws)))
    for (j in 1:3) {
      review_near(get(sprintf("responsibility[%d,%d]", i, j)), rep(row$q[j], nrow(draws)))
      review_near(get(sprintf("%s[%d]", c("pA", "pW", "pO")[j], i)), row$p[Z, j])
      review_near(get(sprintf("p_RB[%d,%d]", i, j)), rep(sum(row$q * row$p[, j]), nrow(draws)))
    }
    review_near(get(sprintf("M_active[%d]", i)), row$M[Z])
    review_near(get(sprintf("S_active[%d]", i)), row$S[Z])
    review_near(get(sprintf("log_lik[%d]", i)), rep(row$log_mass, nrow(draws)))
    M <- M + row$M[Z]
    S <- S + row$S[Z]
    MRB <- MRB + sum(row$q * row$M)
    SRB <- SRB + sum(row$q * row$S)
  }
  errors <- c(M = review_near(get("M_total"), M), S = review_near(get("S_total"), S),
              M_RB = review_near(get("M_RB_total"), MRB), S_RB = review_near(get("S_RB_total"), SRB))
  list(rows = nrow(draws), units = data$n, max_total_errors = errors)
}

review_bridge_mapping <- function(draws, mapped) {
  stopifnot(identical(as.integer(dim(draws)[1:2]), c(2000L, 4L)), length(mapped) == 4L)
  blocks <- c("tau", "nu", "iota.m", "iota.s", "chi.m", "chi.s")
  pairs <- setNames(paste0("pi[", 1:3, "]"), paste0("pi[", 1:3, "]"))
  pairs <- c(pairs, setNames(paste0("alpha[", 1:6, "]"), paste0(blocks, ".alpha")),
             setNames(paste0("b0[", 1:6, "]"), paste0("beta.", blocks, "1")),
             setNames(paste0("v[", 1:6, "]"), c("tb", "nb", "imb", "isb", "cmb", "csb")))
  for (j in 1:6) pairs <- c(pairs, setNames(sprintf("mu[%d,%d]", 1:143, j), sprintf("mu.%s[%d]", blocks[j], 1:143)))
  for (j in 1:4) pairs <- c(pairs, setNames(sprintf("%s[%d]", c("Z", "pA", "pW", "pO")[j], 1:143),
                                           sprintf("%s[%d]", c("Z", "p.a", "p.w", "p.o")[j], 1:143)))
  stopifnot(length(pairs) == 1451L, !anyDuplicated(names(pairs)))
  for (chain in 1:4) {
    stopifnot(nrow(mapped[[chain]]) == 2000L, setequal(colnames(mapped[[chain]]), names(pairs)))
    review_near(attr(mapped[[chain]], "mcpar"), c(2001, 4000, 1), 0)
    for (j in seq_along(pairs)) review_near(mapped[[chain]][, names(pairs)[j]], draws[, chain, pairs[j]], 0)
  }
  list(variables = length(pairs), chains = 4L, iterations = 2000L)
}

review_expected_HMC <- function(sampler) {
  stopifnot(identical(as.integer(dim(sampler)[1:2]), c(2000L, 4L)))
  do.call(rbind, lapply(1:4, function(chain) {
    E <- sampler[, chain, "energy__"]
    denominator <- sum((E - mean(E))^2)
    ebfmi <- if (is.finite(denominator) && denominator > 0) sum(diff(E)^2) / denominator else NA_real_
    data.frame(chain = chain, divergences = sum(sampler[, chain, "divergent__"]),
               treedepth_hits = sum(sampler[, chain, "treedepth__"] >= 12), ebfmi = ebfmi)
  }))
}
