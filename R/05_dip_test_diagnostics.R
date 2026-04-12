# R/05_dip_test_diagnostics.R
#
# Diagnostico de multimodalidade posterior via Hartigan dip test,
# seguindo Mebane (PA2024).
#
# Aplica dip.test() a pi_1, pi_2, pi_3 de fits JAGS e/ou Stan.
# Tambem computa M(pi_k) = range das medias por chain.
#
# Uso:
#   source("R/05_dip_test_diagnostics.R")
#   -- por default, processa todos os fits .rds disponiveis em PATH_RESULTS_LOGS

source(here::here("R", "00_setup.R"))

suppressPackageStartupMessages({
  library(coda)
  library(diptest)
})

log_section("Bloco 5E -- Dip test diagnostics (Mebane PA2024)")

# ----------------------------------------------------------------------------
# Funcoes
# ----------------------------------------------------------------------------

#' Extrai posteriors de pi de um fit JAGS (runjags object)
extract_pi_jags <- function(fit) {
  mcmc_list <- as.mcmc.list(fit$mcmc)
  pi_names <- c("pi[1]", "pi[2]", "pi[3]")
  available <- intersect(pi_names, varnames(mcmc_list))
  if (length(available) == 0L) {
    cli::cli_abort("Nenhum parametro pi encontrado no fit JAGS")
  }

  # Combined (all chains)
  combined <- do.call(rbind, lapply(mcmc_list, function(ch) {
    as.matrix(ch)[, available, drop = FALSE]
  }))

  # Per-chain means
  chain_means <- do.call(rbind, lapply(mcmc_list, function(ch) {
    colMeans(as.matrix(ch)[, available, drop = FALSE])
  }))

  list(combined = combined, chain_means = chain_means, pi_names = available)
}

#' Extrai posteriors de pi de um fit Stan (CmdStanMCMC object)
extract_pi_stan <- function(fit) {
  pi_names <- c("pi_1", "pi_2", "pi_3")
  draws <- fit$draws(variables = pi_names, format = "draws_df")

  # Combined
  combined <- as.matrix(draws[, pi_names])

  # Per-chain means
  chain_ids <- draws$.chain
  chains <- sort(unique(chain_ids))
  chain_means <- do.call(rbind, lapply(chains, function(ch) {
    idx <- chain_ids == ch
    colMeans(as.matrix(draws[idx, pi_names]))
  }))
  colnames(chain_means) <- pi_names

  list(combined = combined, chain_means = chain_means, pi_names = pi_names)
}

#' Computa dip test e M(pi_k) para um conjunto de posteriors
compute_dip_diagnostics <- function(pi_data) {
  n_pi <- ncol(pi_data$combined)
  results <- data.frame(
    parameter = pi_data$pi_names,
    dip_D = NA_real_,
    dip_pvalue = NA_real_,
    multimodal = NA,
    M_pi = NA_real_,
    stringsAsFactors = FALSE
  )

  for (k in seq_len(n_pi)) {
    # Dip test
    dt <- dip.test(pi_data$combined[, k])
    results$dip_D[k] <- dt$statistic
    results$dip_pvalue[k] <- dt$p.value
    results$multimodal[k] <- dt$p.value < 0.05

    # M(pi_k): range of per-chain means
    chain_vals <- pi_data$chain_means[, k]
    results$M_pi[k] <- max(chain_vals) - min(chain_vals)
  }

  results
}

#' Formata e imprime resultados
print_dip_results <- function(results, label) {
  cat(sprintf("\n=== %s ===\n", label))
  cat(sprintf("%-10s  %10s  %10s  %12s  %10s\n",
              "param", "dip_D", "p-value", "multimodal?", "M(pi_k)"))
  cat(paste(rep("-", 60), collapse = ""), "\n")
  for (i in seq_len(nrow(results))) {
    cat(sprintf("%-10s  %10.6f  %10.4f  %12s  %10.6f\n",
                results$parameter[i],
                results$dip_D[i],
                results$dip_pvalue[i],
                if (results$multimodal[i]) "YES" else "no",
                results$M_pi[i]))
  }
  cat(sprintf("\nPA2024 benchmark: M(pi_2) = 0.110 (Mebane aceita)\n"))
}

# ----------------------------------------------------------------------------
# Processar fits disponiveis
# ----------------------------------------------------------------------------
all_results <- list()
output_lines <- character()

# JAGS intercept-only (fresh v2)
jags_io_path <- file.path(PATH_RESULTS_LOGS, "05_eforensics_qbl_brasilia_fresh_v2_fit.rds")
if (file.exists(jags_io_path)) {
  log_step("Processando JAGS intercept-only ...")
  fit_jags_io <- readRDS(jags_io_path)
  pi_jags_io <- extract_pi_jags(fit_jags_io)
  res_jags_io <- compute_dip_diagnostics(pi_jags_io)
  all_results[["JAGS intercept-only"]] <- res_jags_io
  print_dip_results(res_jags_io, "JAGS intercept-only (fresh v2)")
} else {
  log_step("JAGS intercept-only fit nao encontrado: {jags_io_path}")
}

# JAGS zone FE
jags_fe_path <- file.path(PATH_RESULTS_LOGS, "05_jags_qbl_zone_fe_fit.rds")
if (file.exists(jags_fe_path)) {
  log_step("Processando JAGS zone FE ...")
  fit_jags_fe <- readRDS(jags_fe_path)
  pi_jags_fe <- extract_pi_jags(fit_jags_fe)
  res_jags_fe <- compute_dip_diagnostics(pi_jags_fe)
  all_results[["JAGS zone FE"]] <- res_jags_fe
  print_dip_results(res_jags_fe, "JAGS zone FE")
} else {
  log_step("JAGS zone FE fit nao encontrado (ainda nao rodou)")
}

# Stan intercept-only
stan_io_path <- file.path(PATH_DATA_PROCESSED, "stan_eforensics_qbl_brasilia_fit.rds")
if (file.exists(stan_io_path)) {
  log_step("Processando Stan intercept-only ...")
  fit_stan_io <- readRDS(stan_io_path)
  stan_csvs_ok <- tryCatch(all(file.exists(fit_stan_io$output_files())), error = function(e) FALSE)
  if (stan_csvs_ok) {
    pi_stan_io <- extract_pi_stan(fit_stan_io)
    res_stan_io <- compute_dip_diagnostics(pi_stan_io)
    all_results[["Stan intercept-only"]] <- res_stan_io
    print_dip_results(res_stan_io, "Stan intercept-only")
  } else {
    log_step("Stan intercept-only: CSV files do CmdStanMCMC nao encontrados. Pulando.")
  }
} else {
  log_step("Stan intercept-only fit nao encontrado")
}

# Stan zone FE
stan_fe_path <- file.path(PATH_DATA_PROCESSED, "stan_eforensics_qbl_brasilia_fit_zone_fe.rds")
if (file.exists(stan_fe_path)) {
  log_step("Processando Stan zone FE ...")
  fit_stan_fe <- readRDS(stan_fe_path)
  stan_csvs_ok <- tryCatch(all(file.exists(fit_stan_fe$output_files())), error = function(e) FALSE)
  if (stan_csvs_ok) {
    pi_stan_fe <- extract_pi_stan(fit_stan_fe)
    res_stan_fe <- compute_dip_diagnostics(pi_stan_fe)
    all_results[["Stan zone FE"]] <- res_stan_fe
    print_dip_results(res_stan_fe, "Stan zone FE")
  } else {
    log_step("Stan zone FE: CSV files do CmdStanMCMC nao encontrados. Pulando.")
  }
} else {
  log_step("Stan zone FE fit nao encontrado (ainda nao rodou)")
}

# ----------------------------------------------------------------------------
# Salvar relatorio
# ----------------------------------------------------------------------------
out_path <- file.path(PATH_RESULTS_LOGS, "05_dip_test_diagnostics.txt")
sink(out_path)
cat("=== Dip Test Diagnostics (Hartigan) ===\n")
cat(sprintf("Date: %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S %z")))
cat(sprintf("Reference: Mebane (PA2024) — D(pi_k) for unimodality, M(pi_k) for chain agreement\n\n"))

for (nm in names(all_results)) {
  print_dip_results(all_results[[nm]], nm)
}

cat("\n=== Interpretacao ===\n")
cat("- dip_D: estatistica de Hartigan. Valores maiores = mais evidencia de multimodalidade.\n")
cat("- p-value < 0.05: rejeita H0 de unimodalidade.\n")
cat("- M(pi_k): diferenca entre maior e menor media por chain. Mebane aceita M(pi_2) = 0.110 em PA2024.\n")
cat("- Multimodalidade em pi_2 e esperada quando pi_2 ~ 0 (componente de fraude rara).\n")
sink()
log_step("Relatorio salvo em {out_path}")

log_section("Fim do dip test diagnostics")
