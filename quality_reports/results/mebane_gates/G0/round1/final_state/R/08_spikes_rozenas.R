# R/08_spikes_rozenas.R
#
# Rozenas (2017) spikes test via pacote spikes.
#
# Detecta picos anomalos (spikes) na distribuicao de vote share
# por candidato no nivel secao. Spikes em valores redondos
# (50%, 60%, etc.) sugerem manipulacao.
#
# Referencia: Rozenas, A. (2017) "Detecting election fraud from
# irregularities in vote-share distributions"

source(here::here("R", "00_setup.R"))

suppressPackageStartupMessages({
  library(spikes)
})

log_section("Bloco 3 -- Spikes/Rozenas test")

# ----------------------------------------------------------------------------
# Dados
# ----------------------------------------------------------------------------
log_step("Carregando dados ...")
secao <- data.table::setDT(as.data.frame(arrow::read_parquet(
  file.path(PATH_DATA_PROCESSED, "brasil_2022_secao_clean.parquet")
)))
secao <- secao[flag_exterior == FALSE]

candidatos_t1 <- c(13L, 22L)
candidatos_t2 <- c(13L, 22L)

# ----------------------------------------------------------------------------
# Executar testes
# ----------------------------------------------------------------------------
results <- list()

for (turno in c(1L, 2L)) {
  cands <- if (turno == 1L) candidatos_t1 else candidatos_t2
  sub <- secao[NR_TURNO == turno & NR_VOTAVEL %in% cands]

  for (cand in cands) {
    sub_c <- sub[NR_VOTAVEL == cand]
    label <- sprintf("T%d_cand%d", turno, cand)

    # spikes::spikes() espera data.frame com colunas N, t, v
    # N = total de votos possiveis, t = comparecimento, v = votos do candidato
    spike_df <- data.frame(
      N = sub_c$QT_APTOS,
      t = sub_c$QT_COMPARECIMENTO,
      v = sub_c$QT_VOTOS
    )
    spike_df <- spike_df[complete.cases(spike_df) & spike_df$N > 0L & spike_df$t > 0L, ]
    n <- nrow(spike_df)

    if (n < 100L) {
      log_step("Pulando {label}: n={n} < 100")
      next
    }

    log_step("Testando {label} (n={n}) ...", label = label, n = n)

    sp <- tryCatch(
      spikes::spikes(spike_df),
      error = function(e) {
        msg <- conditionMessage(e)
        cli::cli_inform("Erro em spikes para {label}: {msg}")
        NULL
      }
    )

    if (is.null(sp)) next

    # Extrair resultados — spikes retorna objeto com $fraud (% fraude estimada)
    results[[label]] <- data.frame(
      turno = turno,
      candidato = cand,
      n = n,
      fraud_pct = if (!is.null(sp$fraud)) sp$fraud else NA_real_,
      stringsAsFactors = FALSE
    )
  }
}

# ----------------------------------------------------------------------------
# Salvar resultados
# ----------------------------------------------------------------------------
if (length(results) > 0L) {
  res_dt <- data.table::rbindlist(results, fill = TRUE)
  out_csv <- file.path(PATH_OUTPUT_TABLES, "tab_spikes_rozenas.csv")
  data.table::fwrite(res_dt, out_csv)
  log_step("Resultados salvos em {out_csv}")

  cat("\n=== Spikes/Rozenas Test ===\n")
  for (i in seq_len(nrow(res_dt))) {
    r <- res_dt[i]
    cat(sprintf("T%d cand=%d: fraud_pct=%.4f%%  (n=%d)\n",
                r$turno, r$candidato, r$fraud_pct, r$n))
  }
} else {
  log_step("Nenhum resultado de spikes produzido")
}

log_section("Fim do teste Spikes/Rozenas")
