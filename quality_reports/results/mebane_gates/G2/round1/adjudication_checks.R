# Coordinator checks: finite arithmetic, not a JAGS runtime or inference test.
q <- 1
m <- 0.999
s <- 0
nu <- 0.5
pw <- nu * ((1 - s) / (1 - m)) * (1 - m - q) +
  q * ((m - s) / (1 - m)) + s
paper_physical <- sum(vapply(0:1, function(a) {
  dbinom(a, 1, 0.5) * pbinom(1 - a, 1, 0.25)
}, numeric(1)))
qbl_physical <- sum(vapply(0:2, function(a) {
  dbinom(a, 2, 0.5) * pbinom(2 - a, 2, 0.5 * (1 - a / 2))
}, numeric(1)))
r <- 0:2
p <- 0.4 + 0.6 * r / 2
exact <- sum(dbinom(r, 2, 0.3) * dbinom(1, 2, p))
plug_in <- dbinom(1, 2, 0.4 + 0.6 * 0.3)
class_probability <- c(0.2, 0.8)
conditional_mean <- 10 * class_probability
between_variance <- mean((conditional_mean - mean(conditional_mean))^2)
within_variance <- mean(100 * class_probability * (1 - class_probability))
results <- data.frame(
  check = c("qbl_invalid_probability", "paper_physical_mass_N1",
            "qbl_physical_mass_N2", "exact_discrete_likelihood",
            "plugin_likelihood", "J_mean_residual_variance",
            "paper_mean_residual_variance", "full_functional_variance",
            "conditional_expectation_variance"),
  value = c(pw, paper_physical, qbl_physical, exact, plug_in,
            1 / 5, 2 / 5^2, between_variance + within_variance,
            between_variance),
  expected = c(499.5, 0.875, 0.96875, 0.4116, 0.4872, 0.2, 0.08, 25, 9)
)
results$pass <- abs(results$value - results$expected) < 1e-9
stopifnot(all(results$pass))
write.csv(results, "quality_reports/results/mebane_gates/G2/round1/adjudication_checks.csv",
          row.names = FALSE)
print(results)
