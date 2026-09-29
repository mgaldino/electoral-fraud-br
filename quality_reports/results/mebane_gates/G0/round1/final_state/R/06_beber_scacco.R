# R/06_beber_scacco.R
#
# Beber & Scacco (2012) last-digit test.
#
# Extrai o ultimo digito da contagem de votos por candidato x secao.
# Testa uniformidade via chi-quadrado contra Uniform({0,...,9}).
# Desvio significativo sugere manipulacao manual dos totais.
#
# Referencia: Beber, B. & Scacco, A. (2012) "What the numbers say:
# A digit-based test for election fraud"

source(here::here("R", "00_setup.R"))

log_section("Bloco 3 -- Beber-Scacco last-digit test")

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

#' Teste de ultimo digito (Beber-Scacco)
#' @param counts vetor de contagens inteiras de votos
#' @return lista com estatistica chi2, p-value, tabela de frequencias
last_digit_test <- function(counts) {
  # Excluir secoes com zero votos: "0 votos" reflete ausencia do candidato
  # na secao, nao um resultado reportado sujeito a manipulacao de digitos.
  counts <- counts[!is.na(counts) & counts > 0L]
  n <- length(counts)
  if (n < 100L) return(NULL)

  last_digit <- counts %% 10L
  observed <- tabulate(last_digit + 1L, nbins = 10)
  names(observed) <- 0:9
  expected <- rep(n / 10, 10)

  chi2 <- chisq.test(observed, p = rep(1/10, 10))

  list(
    n = n,
    chi2_stat = chi2$statistic,
    df = chi2$parameter,
    p_value = chi2$p.value,
    observed = observed,
    expected_per_digit = n / 10,
    max_deviation = max(abs(observed - expected) / expected)
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

    res <- last_digit_test(sub_c$QT_VOTOS)
    if (!is.null(res)) {
      results[[label]] <- data.frame(
        turno = turno,
        candidato = cand,
        n = res$n,
        chi2 = as.numeric(res$chi2_stat),
        df = as.numeric(res$df),
        p_value = res$p_value,
        max_deviation_pct = round(res$max_deviation * 100, 2),
        stringsAsFactors = FALSE
      )
    }
  }
}

# ----------------------------------------------------------------------------
# Salvar resultados
# ----------------------------------------------------------------------------
res_dt <- data.table::rbindlist(results, fill = TRUE)
out_csv <- file.path(PATH_OUTPUT_TABLES, "tab_beber_scacco_last_digit.csv")
data.table::fwrite(res_dt, out_csv)
log_step("Resultados salvos em {out_csv}")

cat("\n=== Beber-Scacco Last-Digit Test ===\n")
cat(sprintf("H0: ultimo digito ~ Uniform(0,...,9)\n"))
for (i in seq_len(nrow(res_dt))) {
  r <- res_dt[i]
  sig <- if (r$p_value < 0.05) " *" else ""
  cat(sprintf("T%d cand=%d: chi2=%.2f, df=%d, p=%.4f, max_dev=%.1f%%%s  (n=%d)\n",
              r$turno, r$candidato, r$chi2, r$df, r$p_value,
              r$max_deviation_pct, sig, r$n))
}

log_section("Fim do teste Beber-Scacco")
