# R/07_benford_2bl.R
#
# Second-digit Benford (2BL) test on vote counts.
#
# Aplica teste de Benford no segundo digito das contagens de votos
# por candidato x secao. Usa pacote BenfordTests.
#
# Caveat (Deckert-Myagkov-Ordeshook 2011): o teste de Benford sozinho
# nao e evidencia forte de fraude — muitos processos naturais geram
# desvios da lei de Benford. Reportar como UM teste, nao como prova.
#
# Referencia: Deckert, Myagkov, Ordeshook (2011) "Benford's Law and
# the Detection of Election Fraud"

source(here::here("R", "00_setup.R"))

suppressPackageStartupMessages({
  library(BenfordTests)
})

log_section("Bloco 3 -- Benford second-digit (2BL) test")

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
# Funcao de teste
# ----------------------------------------------------------------------------

#' Teste 2BL (segundo digito de Benford)
#' @param counts vetor de contagens inteiras
benford_2bl_test <- function(counts) {
  counts <- counts[!is.na(counts) & counts >= 10L]  # precisa de ao menos 2 digitos
  n <- length(counts)
  if (n < 100L) return(NULL)

  # Segundo digito
  second_digit <- floor((counts / 10^(floor(log10(counts)) - 1)) %% 10)

  # Frequencias observadas
  observed <- tabulate(second_digit + 1L, nbins = 10)

  # Frequencias esperadas (lei de Benford para segundo digito)
  benford_2nd <- sapply(0:9, function(d) {
    sum(log10(1 + 1 / (10 * (1:9) + d)))
  })
  expected <- n * benford_2nd

  # Chi-quadrado
  chi2 <- sum((observed - expected)^2 / expected)
  df <- 9L
  p_value <- pchisq(chi2, df, lower.tail = FALSE)

  # MAD (mean absolute deviation) — metrica de Nigrini
  obs_prop <- observed / n
  mad_stat <- mean(abs(obs_prop - benford_2nd))

  list(
    n = n,
    chi2 = chi2,
    df = df,
    p_value = p_value,
    mad = mad_stat,
    # Nigrini thresholds para MAD do segundo digito:
    # < 0.008 = close conformity
    # 0.008-0.012 = acceptable conformity
    # 0.012-0.015 = marginally acceptable
    # > 0.015 = nonconformity
    mad_interpretation = if (mad_stat < 0.008) "close" else if (mad_stat < 0.012) "acceptable" else if (mad_stat < 0.015) "marginal" else "nonconformity"
  )
}

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

    res <- benford_2bl_test(sub_c$QT_VOTOS)
    if (!is.null(res)) {
      results[[label]] <- data.frame(
        turno = turno,
        candidato = cand,
        n = res$n,
        chi2 = round(res$chi2, 3),
        df = res$df,
        p_value = res$p_value,
        mad = round(res$mad, 5),
        mad_interpretation = res$mad_interpretation,
        stringsAsFactors = FALSE
      )
    }
  }
}

# ----------------------------------------------------------------------------
# Salvar resultados
# ----------------------------------------------------------------------------
res_dt <- data.table::rbindlist(results, fill = TRUE)
out_csv <- file.path(PATH_OUTPUT_TABLES, "tab_benford_2bl.csv")
data.table::fwrite(res_dt, out_csv)
log_step("Resultados salvos em {out_csv}")

cat("\n=== Benford 2BL (Second-Digit) Test ===\n")
cat("Caveat: desvio de Benford nao e evidencia forte de fraude (Deckert et al. 2011)\n")
cat(sprintf("MAD thresholds: <0.008 close, 0.008-0.012 acceptable, >0.015 nonconformity\n\n"))
for (i in seq_len(nrow(res_dt))) {
  r <- res_dt[i]
  sig <- if (r$p_value < 0.05) " *" else ""
  cat(sprintf("T%d cand=%d: chi2=%.2f, p=%.4f, MAD=%.5f (%s)%s  (n=%d)\n",
              r$turno, r$candidato, r$chi2, r$p_value,
              r$mad, r$mad_interpretation, sig, r$n))
}

log_section("Fim do teste Benford 2BL")
