# R/05_jags_qbl_zone_fe.R
#
# Objetivo: Rodar JAGS qbl com zone fixed effects (NR_ZONA) nas formulas de
# fraud magnitude (iota.m, iota.s, chi.m, chi.s), mantendo turnout e vote
# choice como intercept-only. Segue o padrao Mebane (PA2024 Table 3).
#
# Design matrices:
#   - Xa, Xw: intercept-only (n x 1)
#   - X.iota.m, X.iota.s, X.chi.m, X.chi.s: zone FE (n x 19 = intercept + 18 dummies)
#
# Monitora Z[j], mu.tau[j], mu.nu[j] para calculo post-hoc de Ft/Fw.
#
# Baseado em: R/05_eforensics_qbl_fresh_diagnostic.R

source(here::here("R", "00_setup.R"))

suppressPackageStartupMessages({
  library(rjags)
  library(coda)
  library(runjags)
  library(eforensics)
})

log_section("Bloco 5D -- JAGS qbl com zone FE em Brasilia 2022 T2")

# ----------------------------------------------------------------------------
# Modelo qbl (string JAGS do pacote eforensics)
# ----------------------------------------------------------------------------
mod_str <- get("qbl", envir = asNamespace("eforensics"))()

# ----------------------------------------------------------------------------
# Dados Brasilia 2022 T2 full (6748 secoes)
# ----------------------------------------------------------------------------
log_step("Lendo Brasilia 2022 T2 ...")
secao <- data.table::setDT(as.data.frame(arrow::read_parquet(
  file.path(PATH_DATA_PROCESSED, "brasil_2022_secao_clean.parquet")
)))
bsb_long <- secao[CD_MUNICIPIO == 97012L &
                    NR_TURNO == 2L &
                    NR_VOTAVEL %in% c(13L, 22L)]
bsb <- bsb_long[, .(
  N = first(QT_APTOS),
  comparec = first(QT_COMPARECIMENTO),
  w = sum(QT_VOTOS[NR_VOTAVEL == 13L])
), by = .(SG_UF, CD_MUNICIPIO, NR_ZONA, NR_SECAO)]
bsb[, a := N - comparec]
stopifnot(nrow(bsb) == 6748L)
stopifnot(all(bsb$N > 0L))
log_step("Brasilia 2022 T2: {nrow(bsb)} secoes, sum(N)={sum(bsb$N)}")

# ----------------------------------------------------------------------------
# Design matrices
# ----------------------------------------------------------------------------
X1 <- matrix(1, nrow = nrow(bsb), ncol = 1)

bsb[, zona_f := factor(NR_ZONA)]
X_zona <- model.matrix(~ zona_f, data = bsb)  # n x 19 (intercept + 18 dummies)
n_zonas <- nlevels(bsb$zona_f)
n_dummies <- ncol(X_zona)

log_step("Zone FE: {n_zonas} zonas, {n_dummies} colunas (intercept + {n_dummies - 1L} dummies)")
log_step("Ref zone: {levels(bsb$zona_f)[1]}")

dat <- list(
  w = bsb$w, a = bsb$a, N = bsb$N, n = nrow(bsb),
  Xa = X1, dxa = 1L,
  Xw = X1, dxw = 1L,
  X.iota.m = X_zona, dx.iota.m = n_dummies,
  X.iota.s = X_zona, dx.iota.s = n_dummies,
  X.chi.m  = X_zona, dx.chi.m  = n_dummies,
  X.chi.s  = X_zona, dx.chi.s  = n_dummies
)

# ----------------------------------------------------------------------------
# Monitors
# ----------------------------------------------------------------------------
# Hyperparameters + per-obs latent class (Z) and probabilities for Ft/Fw
mons <- c(
  "pi", "beta.tau", "beta.nu",
  "beta.iota.m", "beta.iota.s", "beta.chi.m", "beta.chi.s",
  "tau.alpha", "nu.alpha",
  "iota.m.alpha", "iota.s.alpha", "chi.m.alpha", "chi.s.alpha",
  "tb", "nb", "imb", "isb", "cmb", "csb",
  "Z", "mu.tau", "mu.nu"
)

# ----------------------------------------------------------------------------
# MCMC settings
# ----------------------------------------------------------------------------
n_burn   <- as.integer(Sys.getenv("JAGS_QBL_BURN", "5000"))
n_sample <- as.integer(Sys.getenv("JAGS_QBL_SAMPLE", "2000"))
n_adapt  <- as.integer(Sys.getenv("JAGS_QBL_ADAPT", "1500"))
n_chains <- 4L

log_step("MCMC: burn={n_burn}, sample={n_sample}, adapt={n_adapt}, chains={n_chains}")

# ----------------------------------------------------------------------------
# Run
# ----------------------------------------------------------------------------
log_step("Iniciando run.jags (zone FE, parallel) ...")
runjags::runjags.options(inits.warning = FALSE, rng.warning = FALSE)
t0 <- Sys.time()
fit <- runjags::run.jags(
  model     = mod_str,
  data      = dat,
  monitor   = mons,
  n.chains  = n_chains,
  burnin    = n_burn,
  sample    = n_sample,
  adapt     = n_adapt,
  method    = "parallel",
  jags.refresh = 60
)
t1 <- Sys.time()
dt <- as.numeric(difftime(t1, t0, units = "secs"))
log_step("run.jags terminou. Wall clock: {sprintf('%.1f', dt)} s = {sprintf('%.2f', dt/60)} min")

# ----------------------------------------------------------------------------
# Save fit
# ----------------------------------------------------------------------------
out_rds <- file.path(PATH_RESULTS_LOGS, "05_jags_qbl_zone_fe_fit.rds")
saveRDS(fit, out_rds)
log_step("Fit salvo em {out_rds}")

# ----------------------------------------------------------------------------
# Diagnostics
# ----------------------------------------------------------------------------
mcmc_combined <- as.mcmc.list(fit$mcmc)

# Key hyperparameters (exclude per-obs vectors from gelman.diag)
key_vars <- c(
  "beta.tau", "tau.alpha",
  "beta.nu", "nu.alpha",
  "pi[1]", "pi[2]", "pi[3]",
  "iota.m.alpha", "iota.s.alpha",
  "chi.m.alpha", "chi.s.alpha",
  "tb", "nb", "imb", "isb", "cmb", "csb"
)
# Add zone FE betas (first few for diagnostics)
for (nm in c("beta.iota.m", "beta.iota.s", "beta.chi.m", "beta.chi.s")) {
  key_vars <- c(key_vars, paste0(nm, "[1]"), paste0(nm, "[2]"))
}

summary_path <- file.path(PATH_RESULTS_LOGS, "05_jags_qbl_zone_fe_summary.txt")
sink(summary_path)
cat("=== JAGS qbl zone FE diagnostic ===\n")
cat(sprintf("Brasilia 2022 T2 full (n=%d), %d chains, burn=%d, sample=%d, adapt=%d\n",
            nrow(bsb), n_chains, n_burn, n_sample, n_adapt))
cat(sprintf("Zone FE: %d zonas, %d colunas de design matrix\n", n_zonas, n_dummies))
cat(sprintf("Wall clock: %.1f s = %.2f min\n", dt, dt/60))
cat(sprintf("Date: %s\n\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S %z")))

cat("=== Per-chain posterior means (key hyperparams) ===\n")
for (v in key_vars) {
  if (!(v %in% varnames(mcmc_combined))) next
  vals <- sapply(mcmc_combined, function(x) mean(as.matrix(x)[, v]))
  cat(sprintf("%-20s c1=%10.5g c2=%10.5g c3=%10.5g c4=%10.5g  range=%g\n",
              v, vals[1], vals[2], vals[3], vals[4], max(vals) - min(vals)))
}

cat("\n=== Gelman.diag (rhat) for key hyperparams ===\n")
key_present <- intersect(key_vars, varnames(mcmc_combined))
if (length(key_present) > 0L) {
  mcmc_subset <- as.mcmc.list(lapply(mcmc_combined, function(x) {
    coda::mcmc(as.matrix(x)[, key_present, drop = FALSE])
  }))
  print(gelman.diag(mcmc_subset, autoburnin = FALSE, multivariate = FALSE)$psrf, digits = 4)
}

cat("\n=== Mebane-style M(pi) (range of chain means) ===\n")
for (v in c("pi[1]", "pi[2]", "pi[3]")) {
  if (!(v %in% varnames(mcmc_combined))) next
  vals <- sapply(mcmc_combined, function(x) mean(as.matrix(x)[, v]))
  cat(sprintf("M(%s) = %g  (chains: %.5f / %.5f / %.5f / %.5f)\n",
              v, max(vals) - min(vals), vals[1], vals[2], vals[3], vals[4]))
}

cat("\n=== Posterior summary (combined, key hyperparams) ===\n")
if (length(key_present) > 0L) {
  print(summary(mcmc_subset)$statistics, digits = 5)
  print(summary(mcmc_subset)$quantiles, digits = 5)
}
sink()
log_step("Diagnostico salvo em {summary_path}")

# ----------------------------------------------------------------------------
# Quick console output
# ----------------------------------------------------------------------------
cat("\n--- KEY DIAGNOSTIC (zone FE) ---\n")
beta_tau_chains <- sapply(mcmc_combined, function(x) mean(as.matrix(x)[, "beta.tau"]))
cat(sprintf("beta.tau per chain: %s\n",
            paste(sprintf("%.4f", beta_tau_chains), collapse = " ")))
cat(sprintf("Empirical logit turnout: 1.605\n"))

for (v in c("tau.alpha", "nu.alpha", "pi[1]", "pi[2]", "iota.m.alpha")) {
  if (!(v %in% varnames(mcmc_combined))) next
  vals <- sapply(mcmc_combined, function(x) mean(as.matrix(x)[, v]))
  cat(sprintf("%-20s mean=%.4f  range=%.4f\n", v, mean(vals), max(vals) - min(vals)))
}

log_section("Fim do script JAGS qbl zone FE")
