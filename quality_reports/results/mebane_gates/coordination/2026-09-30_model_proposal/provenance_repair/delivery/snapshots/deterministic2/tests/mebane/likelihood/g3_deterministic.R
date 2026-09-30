source("R/lib/mebane_model.R")
outdir <- "quality_reports/results/mebane_gates/G3/round1/deterministic_attempt2"
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
tau <- nu <- 0.5
mus <- c(0.35, 0.35, 0.85, 0.85)
pi <- c(4, 2, 1) / 7
rows <- list()
for (N in 1:3) for (A in 0:N) for (W in 0:N) {
  full <- mebane_enumerate(N, A, W, tau, nu, mus, pi)
  factored <- mebane_factorized(N, A, W, tau, nu, mus, pi)
  rows[[length(rows) + 1L]] <- data.frame(N, A, W, physical = A + W <= N,
    complete = full, factorized = factored, difference = abs(full - factored))
}
grid <- do.call(rbind, rows)
write.csv(grid, file.path(outdir, "enumeration.csv"), row.names = FALSE)
stopifnot(max(grid$difference) <= 1e-12)
mass <- do.call(rbind, lapply(1:3, function(N) {
  raw <- mebane_mass(N, tau, nu, mus, pi)
  physical <- mebane_mass(N, tau, nu, mus, pi, TRUE)
  data.frame(N, kernel_mass = raw, physical_mass = physical,
             invalid_parent_deficit = 1 - raw,
             unphysical_mass = raw - physical)
}))
write.csv(mass, file.path(outdir, "mass.csv"), row.names = FALSE)
stopifnot(all(mass$kernel_mass > 0), all(mass$kernel_mass <= 1 + 1e-12),
          all(mass$physical_mass <= mass$kernel_mass + 1e-12))
grid$normalized_all <- grid$factorized / mass$kernel_mass[grid$N]
grid$normalized_physical <- ifelse(grid$physical,
  grid$factorized / mass$physical_mass[grid$N], 0)
write.csv(grid, file.path(outdir, "normalization.csv"), row.names = FALSE)
stopifnot(all(abs(tapply(grid$normalized_all, grid$N, sum) - 1) < 1e-12),
          all(abs(tapply(grid$normalized_physical, grid$N, sum) - 1) < 1e-12))
bad <- mebane_probabilities(1, 1, 2, c(1, 0, 0, 0), 0.5, 0.5)
stopifnot(abs(bad["pw"] - 499.5) < 1e-10,
          mebane_kernel(1, 1, 0, 2, c(1, 0, 0, 0), 0.5, 0.5) == 0)
write.csv(data.frame(N = 1, A = 1, W = 0, Z = 2,
                     p_a = bad["pa"], p_w = bad["pw"],
                     diagnostic_kernel = 0),
          file.path(outdir, "counterexample.csv"), row.names = FALSE)
attempts <- mebane_attempts(32, 31101, 3)
write.csv(attempts, file.path(outdir, "generation_attempts.csv"), row.names = FALSE)
stopifnot(nrow(attempts) == 32, identical(attempts$attempt, 1:32),
          all(attempts$N <= 3),
          all(is.na(attempts$W[attempts$status == "invalid_probability"])))
joint <- data.frame(draw = c(1,1,2,2), N = c(2,3,2,3),
  Z = c(2,3,1,2), tau = c(.4,.6,.3,.5), nu = c(.5,.7,.6,.4),
  r_im = c(1,0,0,3), r_is = c(1,0,0,1),
  r_cm = c(0,3,0,0), r_cs = c(0,2,0,0), Dobs = 10)
joint_out <- mebane_joint_functionals(joint)
write.csv(joint, file.path(outdir, "joint_input.csv"), row.names = FALSE)
write.csv(joint_out, file.path(outdir, "joint_functionals.csv"), row.names = FALSE)
stopifnot(nrow(joint_out) == 2, all(joint_out$margin_lower <= joint_out$margin_upper),
          all(joint_out$margin_upper == 10 - joint_out$M - joint_out$S),
          joint_out$M[1] != joint_out$M[2])
cat(sprintf("deterministic PASS: %d grid cases; max diff %.3g; generator statuses %s\n",
  nrow(grid), max(grid$difference), paste(names(table(attempts$status)),
  table(attempts$status), collapse = ", ")))
