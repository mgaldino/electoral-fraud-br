# Deterministic finite checks for a proposal, not a production model or fit.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 1L, !dir.exists(args[1]))
dir.create(args[1], recursive = TRUE)
out <- args[1]
source("R/lib/mebane_model.R")

paper_probs <- function(tau, nu, m, s) {
  c(A = (1 - tau) * (1 - m), L = tau * nu,
    M = (1 - tau) * m, S = tau * (1 - nu) * s,
    O = tau * (1 - nu) * (1 - s))
}

# Enumerate the pre-transfer counts and the two transfers independently of
# the closed-form observed multinomial likelihood.
mechanism <- function(N, tau, nu, m, s) {
  rows <- list()
  k <- 0L
  for (A0 in 0:N) for (L0 in 0:(N - A0)) {
    O0 <- N - A0 - L0
    baseline <- dmultinom(c(A0, L0, O0), prob = c(1 - tau, tau * nu,
                                                tau * (1 - nu)))
    for (M in 0:A0) for (S in 0:O0) {
      k <- k + 1L
      rows[[k]] <- data.frame(A = A0 - M, W = L0 + M + S,
                             O = O0 - S, A0 = A0, O0 = O0,
                             M = M, S = S,
                             mass = baseline * dbinom(M, A0, m) *
                               dbinom(S, O0, s))
    }
  }
  do.call(rbind, rows)
}

grid <- expand.grid(tau = c(0, 0.6, 1), nu = c(0, 0.4, 1),
                    m = c(0, 0.2, 1), s = c(0, 0.3, 1))
grid <- rbind(grid, c(0.5, 0.5, 0.999, 0), c(0.2, 0.8, 0.9, 0.75))
rows <- list()
j <- 0L
for (g in seq_len(nrow(grid))) for (N in 1:4) {
  pars <- as.list(grid[g, ])
  five <- do.call(paper_probs, pars)
  p <- c(A = unname(five["A"]), W = sum(five[c("L", "M", "S")]),
         O = unname(five["O"]))
  raw <- do.call(mechanism, c(list(N = N), pars))
  stopifnot(all(raw$A + raw$W + raw$O == N), all(raw$M <= raw$A0),
            all(raw$S <= raw$O0), all(raw$M + raw$S <= raw$W))
  max_error <- conditional_error <- sequential_error <- 0
  observed_mass <- 0
  rectangle_mass <- triangle_mass <- 0
  for (A in 0:N) for (W in 0:N) {
    independent <- dbinom(A, N, p["A"]) * dbinom(W, N, p["W"])
    rectangle_mass <- rectangle_mass + independent
    if (A + W > N) next
    triangle_mass <- triangle_mass + independent
    exact <- dmultinom(c(A, W, N - A - W), prob = p)
    observed_mass <- observed_mass + exact
    matched <- raw[raw$A == A & raw$W == W, ]
    reconstructed <- sum(matched$mass)
    max_error <- max(max_error, abs(exact - reconstructed))
    # The positive-cell sum avoids cancellation and ratios rounded above 1.
    turnout <- p["W"] + p["O"]
    sequential <- if (turnout == 0) as.numeric(A == N && W == 0) else
      dbinom(A, N, p["A"]) * dbinom(W, N - A, p["W"] / turnout)
    sequential_error <- max(sequential_error, abs(exact - sequential))
    if (exact > 1e-20 && p["W"] > 0) {
      conditional_error <- max(conditional_error,
        abs(sum(matched$M * matched$mass) / reconstructed - W * five["M"] / p["W"]),
        abs(sum(matched$S * matched$mass) / reconstructed - W * five["S"] / p["W"]))
    }
  }
  j <- j + 1L
  rows[[j]] <- data.frame(grid = g, N = N, grid[g, ],
                         multinomial_mass = observed_mass,
                         mechanism_mass = sum(raw$mass),
                         mechanism_error = max_error,
                         sequential_error = sequential_error,
                         conditional_mean_error = conditional_error,
                         paper_rectangle_mass = rectangle_mass,
                         paper_physical_mass = triangle_mass)
}
results <- do.call(rbind, rows)
write.csv(results, file.path(out, "multinomial_checks.csv"), row.names = FALSE)
stopifnot(max(abs(results$multinomial_mass - 1)) < 1e-11,
          max(abs(results$mechanism_mass - 1)) < 1e-11,
          max(abs(results$paper_rectangle_mass - 1)) < 1e-11,
          max(results$mechanism_error) < 1e-11,
          max(results$sequential_error) < 1e-11,
          max(results$conditional_mean_error) < 1e-11)

# Component normalization preserves pi as the pre-data class weights.
# Global normalization instead changes them to pi_z*C_z/sum(pi*C).
normalization <- list()
k <- 0L
pi <- c(0.6, 0.25, 0.15)
for (N in 1:3) {
  dat <- expand.grid(A = 0:N, W = 0:N)
  physical <- dat$A + dat$W <= N
  L <- sapply(1:3, function(z) vapply(seq_len(nrow(dat)), function(i) {
    mebane_factorized(N, dat$A[i], dat$W[i], 0.6, 0.4,
                     c(0.2, 0.3, 0.8, 0.9), as.numeric(1:3 == z))
  }, numeric(1)))
  L[!physical, ] <- 0
  C <- colSums(L)
  stopifnot(all(C > 0), all(C <= 1 + 1e-11))
  normalized <- sweep(L, 2, C, "/")
  stopifnot(max(abs(colSums(normalized) - 1)) < 1e-11,
            abs(sum(normalized %*% pi) - 1) < 1e-11,
            abs(sum(L %*% pi) / sum(pi * C) - 1) < 1e-11)
  k <- k + 1L
  normalization[[k]] <- data.frame(N = N, z = 1:3, C = C,
    pi_component = pi, pi_global = pi * C / sum(pi * C))
}

example <- paper_probs(0.6, 0.4, 0.2, 0.3)
pA <- example["A"]
pW <- sum(example[c("L", "M", "S")])
tau0 <- 1 - pA
nu0 <- pW / tau0
same <- paper_probs(tau0, nu0, 0, 0)
stopifnot(abs(same["A"] - pA) < 1e-12,
          abs(same["L"] - pW) < 1e-12,
          abs(same["O"] - example["O"]) < 1e-12)
f1 <- mebane_probabilities(1, 1, 2, c(1, 0, 0, 0), 0.5, 0.5)["pw"]
f2 <- mebane_kernel(2, 1, 2, 1, rep(0, 4), 0.5, 0.5)
stopifnot(abs(f1 - 499.5) < 1e-9, abs(f2 - 1 / 32) < 1e-14)

write.csv(do.call(rbind, normalization), file.path(out, "normalization_choices.csv"), row.names = FALSE)
summary <- list(status = "deterministic_checks_pass", estimation_performed = FALSE,
  parameter_cases = nrow(grid), distributions = nrow(results), tolerance = 1e-11,
  max_mechanism_error = max(results$mechanism_error),
  max_sequential_error = max(results$sequential_error),
  max_conditional_mean_error = max(results$conditional_mean_error),
  F1 = unname(f1), F2 = unname(f2),
  example = list(N = 1000, probabilities = as.list(example),
    expected_A_W_O = c(1000 * pA, 1000 * pW, 1000 * example["O"]),
    no_transfer_tau = unname(tau0), no_transfer_nu = unname(nu0),
    expected_M_S = 1000 * unname(example[c("M", "S")]),
    conditional_M_S_given_W400 = 400 * unname(example[c("M", "S")]) / pW),
  limitation = "Algebraic checks only; no identification, MCMC, production approval or author replication.")
jsonlite::write_json(summary, file.path(out, "result.json"), pretty = TRUE,
                     auto_unbox = TRUE, digits = 16)
writeLines(capture.output(sessionInfo()), file.path(out, "sessionInfo.txt"))
print(summary)
