# R/05_kobak_integer.R
#
# Kobak-Shpilkin-Pshenichnikov (2016) integer percentages test.
#
# Conta a frequencia observada de turnout e vote share em multiplos exatos
# de 5% (e 10%), compara com baseline suave esperado via bootstrap CI.
# Excesso significativo de percentuais redondos e indicador de manipulacao.
#
# Referencia: Kobak, Shpilkin, Pshenichnikov (2016) "Integer percentages
# as electoral anomalies"

source(here::here("R", "00_setup.R"))

log_section("Bloco 3 -- Kobak integer percentages test")

# ----------------------------------------------------------------------------
# Dados
# ----------------------------------------------------------------------------
log_step("Carregando dados ...")
secao <- data.table::setDT(as.data.frame(arrow::read_parquet(
  file.path(PATH_DATA_PROCESSED, "brasil_2022_secao_clean.parquet")
)))

# Filtrar Brasil only (sem exterior)
secao <- secao[flag_exterior == FALSE]

# Candidatos por turno
candidatos_t1 <- c(13L, 22L)  # Lula, Bolsonaro
candidatos_t2 <- c(13L, 22L)

# ----------------------------------------------------------------------------
# Funcao de teste
# ----------------------------------------------------------------------------

#' Testa excesso de percentuais inteiros (multiplos de 5 ou 10)
#' usando comparacao local: contagem no bin do multiplo vs media dos bins
#' vizinhos. Segue o espirito de Kobak et al. (2016).
#'
#' @param values vetor numerico de proporcoes em [0,1]
#' @param multiple multiplo a testar (0.05 = 5%, 0.10 = 10%)
#' @param bin_width largura do bin para histograma fino (default: 0.001)
kobak_test <- function(values, multiple = 0.05, bin_width = 0.001) {
  values <- values[!is.na(values) & values >= 0 & values <= 1]
  n <- length(values)
  if (n == 0L) return(NULL)

  # Histograma fino
  breaks <- seq(0, 1, by = bin_width)
  h <- hist(values, breaks = breaks, plot = FALSE)
  counts <- h$counts
  mids <- h$mids
  n_bins <- length(counts)

  # Identificar bins que correspondem a multiplos exatos
  is_multiple_bin <- sapply(mids, function(m) {
    rem <- m %% multiple
    rem < bin_width / 2 | (multiple - rem) < bin_width / 2
  })

  # Para cada bin de multiplo, comparar com media dos 4 vizinhos
  # (2 abaixo + 2 acima), excluindo outros bins de multiplo
  neighbor_window <- 5L  # vizinhos de cada lado
  ratios <- numeric()

  for (i in which(is_multiple_bin)) {
    lo <- max(1L, i - neighbor_window)
    hi <- min(n_bins, i + neighbor_window)
    neighbors <- seq(lo, hi)
    neighbors <- neighbors[neighbors != i & !is_multiple_bin[neighbors]]
    if (length(neighbors) < 2L) next
    expected <- mean(counts[neighbors])
    if (expected > 0) {
      ratios <- c(ratios, counts[i] / expected)
    }
  }

  if (length(ratios) == 0L) return(NULL)

  # Ratio medio e CI via quantis dos ratios individuais
  list(
    n = n,
    multiple = multiple,
    n_multiples_tested = length(ratios),
    mean_ratio = mean(ratios),
    median_ratio = median(ratios),
    ratio_ci_025 = unname(quantile(ratios, 0.025)),
    ratio_ci_975 = unname(quantile(ratios, 0.975)),
    max_ratio = max(ratios)
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

    # Turnout
    # Vote share (comparecimento) — candidato-especifico
    for (mult in c(0.05, 0.10)) {
      vs_res <- kobak_test(sub_c$vote_share_comparecimento, multiple = mult)
      if (!is.null(vs_res)) {
        results[[paste0(label, "_voteshare_", mult*100, "pct")]] <- c(
          list(turno = turno, candidato = cand, variable = "vote_share",
               multiple_pct = as.integer(mult * 100)),
          vs_res
        )
      }
    }

    # Turnout — mesmo para todos os candidatos, testar so uma vez (cand == primeiro)
    if (cand == cands[1]) {
      # Deduplicar secoes para turnout
      turnout_vals <- sub[!duplicated(paste(NR_ZONA, NR_SECAO))]$turnout
      for (mult in c(0.05, 0.10)) {
        t_res <- kobak_test(turnout_vals, multiple = mult)
        if (!is.null(t_res)) {
          results[[paste0("T", turno, "_turnout_", mult*100, "pct")]] <- c(
            list(turno = turno, candidato = NA_integer_, variable = "turnout",
                 multiple_pct = as.integer(mult * 100)),
            t_res
          )
        }
      }
    }
  }
}

# ----------------------------------------------------------------------------
# Salvar resultados
# ----------------------------------------------------------------------------
res_dt <- data.table::rbindlist(lapply(results, as.data.frame), fill = TRUE)
out_csv <- file.path(PATH_OUTPUT_TABLES, "tab_kobak_integer_pct.csv")
data.table::fwrite(res_dt, out_csv)
log_step("Resultados salvos em {out_csv}")

# Console summary
cat("\n=== Kobak Integer Percentages Test (local-neighbor method) ===\n")
cat("ratio = count_at_multiple / mean(neighbor_counts). ratio > 1 = excess.\n\n")
for (i in seq_len(nrow(res_dt))) {
  r <- res_dt[i]
  cand_str <- if (is.na(r$candidato)) "all" else as.character(r$candidato)
  cat(sprintf("T%d cand=%-4s %s mult=%d%%: mean_ratio=%.3f median=%.3f [%.3f, %.3f] max=%.3f (n=%d, %d multiples)\n",
              r$turno, cand_str, r$variable, r$multiple_pct,
              r$mean_ratio, r$median_ratio,
              r$ratio_ci_025, r$ratio_ci_975, r$max_ratio,
              r$n, r$n_multiples_tested))
}

log_section("Fim do teste Kobak")
