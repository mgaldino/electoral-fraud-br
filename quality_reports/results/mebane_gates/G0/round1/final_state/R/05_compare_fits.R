# R/05_compare_fits.R
#
# Tabela comparativa de parametros entre fits JAGS e Stan,
# intercept-only e zone FE.
#
# Carrega fits disponiveis e produz tabela markdown com posteriors.

source(here::here("R", "00_setup.R"))

suppressPackageStartupMessages({
  library(coda)
})

log_section("Bloco 5F -- Comparacao cross-engine")

# ----------------------------------------------------------------------------
# Funcoes de extracao
# ----------------------------------------------------------------------------

#' Extrai posterior summary de parametros-chave de um fit JAGS
summarize_jags <- function(fit, params) {
  mcmc_list <- as.mcmc.list(fit$mcmc)
  available <- intersect(params, varnames(mcmc_list))
  if (length(available) == 0L) return(NULL)

  # Transform variance params (tb, nb) to SD scale for comparability with Stan
  mcmc_sub <- as.mcmc.list(lapply(mcmc_list, function(ch) {
    mat <- as.matrix(ch)[, available, drop = FALSE]
    for (vp in intersect(jags_variance_params, available)) {
      mat[, vp] <- sqrt(mat[, vp])
    }
    coda::mcmc(mat)
  }))
  stats <- summary(mcmc_sub)
  result <- data.frame(
    parameter = available,
    mean = stats$statistics[, "Mean"],
    sd = stats$statistics[, "SD"],
    q025 = stats$quantiles[, "2.5%"],
    q975 = stats$quantiles[, "97.5%"],
    stringsAsFactors = FALSE
  )
  result
}

#' Extrai posterior summary de parametros-chave de um fit Stan
summarize_stan <- function(fit, params) {
  available <- intersect(params, fit$metadata()$stan_variables)
  if (length(available) == 0L) return(NULL)

  draws <- fit$draws(variables = available, format = "draws_df")
  result <- data.frame(
    parameter = available,
    mean = NA_real_,
    sd = NA_real_,
    q025 = NA_real_,
    q975 = NA_real_,
    stringsAsFactors = FALSE
  )
  for (i in seq_along(available)) {
    v <- draws[[available[i]]]
    result$mean[i] <- mean(v)
    result$sd[i] <- sd(v)
    result$q025[i] <- quantile(v, 0.025)
    result$q975[i] <- quantile(v, 0.975)
  }
  result
}

# ----------------------------------------------------------------------------
# Parametros a comparar
# ----------------------------------------------------------------------------
# JAGS e Stan usam nomes diferentes para os mesmos parametros
# JAGS tb/nb sao variancias; Stan sigma_tau/sigma_nu sao desvios-padrao.
# Para comparacao direta, transformamos tb -> sqrt(tb) na extracao do JAGS.
jags_variance_params <- c("tb", "nb")

param_map <- data.frame(
  display = c("tau_alpha", "nu_alpha", "pi[1]", "pi[2]", "pi[3]",
              "iota_m_alpha", "iota_s_alpha", "chi_m_alpha", "chi_s_alpha",
              "sigma_tau", "sigma_nu", "Ft", "Fw", "stolen"),
  jags = c("tau.alpha", "nu.alpha", "pi[1]", "pi[2]", "pi[3]",
           "iota.m.alpha", "iota.s.alpha", "chi.m.alpha", "chi.s.alpha",
           "tb", "nb", NA, NA, NA),
  stan = c("tau_alpha", "nu_alpha", "pi_1", "pi_2", "pi_3",
           "iota_m_alpha", "iota_s_alpha", "chi_m_alpha", "chi_s_alpha",
           "sigma_tau", "sigma_nu", "Ft", "Fw", "stolen_votes"),
  stringsAsFactors = FALSE
)

# ----------------------------------------------------------------------------
# Carregar fits
# ----------------------------------------------------------------------------
fits <- list()

jags_io_path <- file.path(PATH_RESULTS_LOGS, "05_eforensics_qbl_brasilia_fresh_v2_fit.rds")
if (file.exists(jags_io_path)) {
  fits[["JAGS_IO"]] <- list(type = "jags", fit = readRDS(jags_io_path))
  log_step("JAGS intercept-only carregado")
}

jags_fe_path <- file.path(PATH_RESULTS_LOGS, "05_jags_qbl_zone_fe_fit.rds")
if (file.exists(jags_fe_path)) {
  fits[["JAGS_FE"]] <- list(type = "jags", fit = readRDS(jags_fe_path))
  log_step("JAGS zone FE carregado")
}

stan_io_path <- file.path(PATH_DATA_PROCESSED, "stan_eforensics_qbl_brasilia_fit.rds")
if (file.exists(stan_io_path)) {
  fit_tmp <- readRDS(stan_io_path)
  csvs_ok <- tryCatch(all(file.exists(fit_tmp$output_files())), error = function(e) FALSE)
  if (csvs_ok) {
    fits[["Stan_IO"]] <- list(type = "stan", fit = fit_tmp)
    log_step("Stan intercept-only carregado")
  } else {
    log_step("Stan intercept-only: CSV files do CmdStanMCMC nao encontrados. Pulando.")
  }
}

stan_fe_path <- file.path(PATH_DATA_PROCESSED, "stan_eforensics_qbl_brasilia_fit_zone_fe.rds")
if (file.exists(stan_fe_path)) {
  fit_tmp <- readRDS(stan_fe_path)
  csvs_ok <- tryCatch(all(file.exists(fit_tmp$output_files())), error = function(e) FALSE)
  if (csvs_ok) {
    fits[["Stan_FE"]] <- list(type = "stan", fit = fit_tmp)
    log_step("Stan zone FE carregado")
  } else {
    log_step("Stan zone FE: CSV files do CmdStanMCMC nao encontrados. Pulando.")
  }
}

if (length(fits) == 0L) {
  cli::cli_abort("Nenhum fit encontrado. Rode os scripts de estimacao primeiro.")
}

# ----------------------------------------------------------------------------
# Extrair summaries
# ----------------------------------------------------------------------------
summaries <- list()
for (nm in names(fits)) {
  f <- fits[[nm]]
  if (f$type == "jags") {
    params <- na.omit(param_map$jags)
    summaries[[nm]] <- summarize_jags(f$fit, params)
  } else {
    params <- na.omit(param_map$stan)
    summaries[[nm]] <- summarize_stan(f$fit, params)
  }
}

# ----------------------------------------------------------------------------
# Gerar tabela markdown
# ----------------------------------------------------------------------------
out_path <- file.path(PATH_RESULTS_LOGS, "05_compare_fits.md")

sink(out_path)
cat("# Comparacao cross-engine: JAGS vs Stan, intercept-only vs zone FE\n\n")
cat(sprintf("Data: %s\n\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S %z")))

cat("## Fits disponiveis\n\n")
for (nm in names(fits)) {
  cat(sprintf("- **%s**\n", nm))
}

cat("\n## Tabela comparativa (posterior mean [95%% CI])\n\n")

# Header
cols <- names(summaries)
header <- sprintf("| %-18s |", "Parametro")
for (cn in cols) header <- paste0(header, sprintf(" %-30s |", cn))
cat(header, "\n")
sep <- sprintf("|%-20s|", paste(rep("-", 20), collapse = ""))
for (cn in cols) sep <- paste0(sep, sprintf("%-32s|", paste(rep("-", 32), collapse = "")))
cat(sep, "\n")

for (i in seq_len(nrow(param_map))) {
  row <- sprintf("| %-18s |", param_map$display[i])
  for (cn in cols) {
    s <- summaries[[cn]]
    f <- fits[[cn]]

    # Map display name to the correct param name for this engine
    if (f$type == "jags") {
      pname <- param_map$jags[i]
    } else {
      pname <- param_map$stan[i]
    }

    if (is.na(pname) || is.null(s) || !(pname %in% s$parameter)) {
      row <- paste0(row, sprintf(" %-30s |", "--"))
    } else {
      idx <- which(s$parameter == pname)
      val <- sprintf("%.4f [%.4f, %.4f]", s$mean[idx], s$q025[idx], s$q975[idx])
      row <- paste0(row, sprintf(" %-30s |", val))
    }
  }
  cat(row, "\n")
}

cat("\n## Notas\n\n")
cat("- JAGS `tb`/`nb` foram transformados para sqrt(tb)/sqrt(nb) (SD) para comparabilidade com Stan `sigma_tau`/`sigma_nu`.\n")
cat("- JAGS nao computa Ft/Fw diretamente (calculado post-hoc ou via Stan).\n")
cat("- Ft = manufactured votes, Fw = total fraudulent votes, stolen = Fw - Ft.\n")
cat("- Valores de Ft/Fw proximos de zero suportam a hipotese nula (sem fraude).\n")
sink()

log_step("Tabela comparativa salva em {out_path}")
log_section("Fim da comparacao cross-engine")
