# R/05_eforensics_qbl_fresh_diagnostic.R
#
# Objetivo (passo "c" do plano discutido em 2026-04-11):
#
#   Re-rodar JAGS qbl em Brasilia 2022 T2 full (6748 secoes), com a MESMA
#   especificacao intercept-only do `_fit.rds` salvo, mas com:
#     - inicializacao default (sem chute do "modo certo"),
#     - burn-in 5000 (vs 2000 no fit salvo),
#     - 4 chains paralelas via runjags,
#     - monitoracao explicita de tau.alpha, nu.alpha, iota.*.alpha, chi.*.alpha,
#       e dos hiperparametros tb, nb, imb, isb, cmb, csb (que NAO foram
#       monitorados pelo eforensics original).
#
# Pergunta a ser respondida:
#
#   O `05_eforensics_qbl_brasilia_fit.rds` esta preso num modo errado
#   (`beta.tau ~ 0.71` em vez de `~ 1.6`) por insuficiencia de burn-in,
#   ou por defeito estrutural do modelo no `n=6748`?
#
#   Se a resposta for "insuficiencia de burn-in", uma rodada com 5000 burn-in
#   chega no modo certo (`tau.alpha ~ 1.6`, `nu.alpha ~ -0.4`).
#   Se for "defeito estrutural", todas as 4 chains continuam presas no
#   modo errado.
#
# NAO se trata de provar que o modelo eh bom -- isso ja sabemos que ele tem
# multimodalidade legitima nos `*_alpha` (ver PA2024.pdf, Mebane). Trata-se
# de descartar a hipotese de que o `_fit.rds` antigo eh artefato de execucao.
#
# Tempo estimado: ~60-90 min wallclock em paralelo (4 chains, 4 cores).

source(here::here("R", "00_setup.R"))

suppressPackageStartupMessages({
  library(rjags)
  library(coda)
  library(runjags)
  library(eforensics)
})

log_section("Bloco 5C -- JAGS qbl fresco em Brasilia 2022 T2 full (diagnostico de modo)")

# ----------------------------------------------------------------------------
# Modelo qbl
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

X1 <- matrix(1, nrow = nrow(bsb), ncol = 1)
dat <- list(
  w = bsb$w, a = bsb$a, N = bsb$N, n = nrow(bsb),
  Xa = X1, dxa = 1L,
  Xw = X1, dxw = 1L,
  X.iota.m = X1, dx.iota.m = 1L,
  X.iota.s = X1, dx.iota.s = 1L,
  X.chi.m = X1, dx.chi.m = 1L,
  X.chi.s = X1, dx.chi.s = 1L
)

# ----------------------------------------------------------------------------
# runjags com defaults agressivos: burn 5000, sample 5000, adapt 1500
# ----------------------------------------------------------------------------
mons <- c(
  "pi", "beta.tau", "beta.nu",
  "beta.iota.m", "beta.iota.s", "beta.chi.m", "beta.chi.s",
  "tau.alpha", "nu.alpha",
  "iota.m.alpha", "iota.s.alpha", "chi.m.alpha", "chi.s.alpha",
  "tb", "nb", "imb", "isb", "cmb", "csb"
)

log_step("Iniciando run.jags (4 chains, parallel, burn=5000, sample=5000, adapt=1500) ...")
runjags::runjags.options(inits.warning = FALSE, rng.warning = FALSE)
t0 <- Sys.time()
fit <- runjags::run.jags(
  model     = mod_str,
  data      = dat,
  monitor   = mons,
  n.chains  = 4,
  burnin    = 5000,
  sample    = 5000,
  adapt     = 1500,
  method    = "parallel",
  jags.refresh = 60
)
t1 <- Sys.time()
dt <- as.numeric(difftime(t1, t0, units = "secs"))
log_step("run.jags terminou. Wall clock: {sprintf('%.1f', dt)} s = {sprintf('%.2f', dt/60)} min")

# ----------------------------------------------------------------------------
# Salvamento + diagnostico
# ----------------------------------------------------------------------------
out_rds <- file.path(PATH_RESULTS_LOGS, "05_eforensics_qbl_brasilia_fresh_v2_fit.rds")
saveRDS(fit, out_rds)
log_step("Fit salvo em {out_rds}")

mcmc_combined <- as.mcmc.list(fit$mcmc)

key_vars <- c(
  "beta.tau", "tau.alpha",
  "beta.nu", "nu.alpha",
  "pi[1]", "pi[2]", "pi[3]",
  "beta.iota.m", "iota.m.alpha",
  "beta.iota.s", "iota.s.alpha",
  "beta.chi.m", "chi.m.alpha",
  "beta.chi.s", "chi.s.alpha",
  "tb", "nb", "imb", "isb", "cmb", "csb"
)

summary_path <- file.path(PATH_RESULTS_LOGS, "05_eforensics_qbl_brasilia_fresh_v2_summary.txt")
sink(summary_path)
cat("=== JAGS qbl fresh diagnostic ===\n")
cat(sprintf("Brasilia 2022 T2 full (n=%d), 4 chains, burn=5000, sample=5000, adapt=1500\n",
            nrow(bsb)))
cat(sprintf("Wall clock: %.1f s = %.2f min\n", dt, dt/60))
cat(sprintf("Date: %s\n\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S %z")))

cat("=== Per-chain posterior means ===\n")
for (v in key_vars) {
  if (!(v %in% varnames(mcmc_combined))) next
  vals <- sapply(mcmc_combined, function(x) mean(as.matrix(x)[, v]))
  cat(sprintf("%-15s c1=%10.5g c2=%10.5g c3=%10.5g c4=%10.5g  range=%g\n",
              v, vals[1], vals[2], vals[3], vals[4], max(vals) - min(vals)))
}

cat("\n=== Gelman.diag (rhat) ===\n")
key_present <- intersect(key_vars, varnames(mcmc_combined))
mcmc_subset <- as.mcmc.list(lapply(mcmc_combined, function(x) coda::mcmc(as.matrix(x)[, key_present])))
print(gelman.diag(mcmc_subset, autoburnin = FALSE, multivariate = FALSE)$psrf, digits = 4)

cat("\n=== Mebane-style M(pi) (range of chain means) ===\n")
for (v in c("pi[1]", "pi[2]", "pi[3]")) {
  vals <- sapply(mcmc_combined, function(x) mean(as.matrix(x)[, v]))
  cat(sprintf("M(%s) = %g  (chains: %.5f / %.5f / %.5f / %.5f)\n",
              v, max(vals) - min(vals), vals[1], vals[2], vals[3], vals[4]))
}

cat("\n=== Posterior summary (combined) ===\n")
print(summary(mcmc_subset)$statistics, digits = 5)
print(summary(mcmc_subset)$quantiles, digits = 5)
sink()
log_step("Diagnostico salvo em {summary_path}")

cat("\n--- KEY DIAGNOSTIC ---\n")
beta_tau_chains <- sapply(mcmc_combined, function(x) mean(as.matrix(x)[, "beta.tau"]))
cat(sprintf("beta.tau per chain: %s\n",
            paste(sprintf("%.4f", beta_tau_chains), collapse = " ")))
cat(sprintf("Empirical logit turnout: 1.605\n"))
cat(sprintf("Saved (wrong-mode) fit beta.tau: ~0.71\n"))
if (all(abs(beta_tau_chains - 1.6) < 0.1)) {
  cat(">>> FRESH RUN CONVERGED TO CORRECT MODE. The saved fit was an artifact of insufficient burn-in.\n")
} else if (all(abs(beta_tau_chains - 0.71) < 0.1)) {
  cat(">>> FRESH RUN STUCK AT WRONG MODE. The model has structural issues at n=6748.\n")
} else {
  cat(">>> CHAINS DISAGREE. Multimodality at n=6748 -- some chains escaped, some did not.\n")
}

log_section("Fim do diagnostico fresh")
