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
#' @param values vetor numerico de proporcoes em [0,1]
#' @param multiple multiplo a testar (0.05 = 5%, 0.10 = 10%)
#' @param n_boot numero de bootstraps para CI
#' @param tolerance tolerancia para considerar "inteiro" (default: 0.001)
kobak_test <- function(values, multiple = 0.05, n_boot = 1000, tolerance = 0.001) {
  values <- values[!is.na(values) & values >= 0 & values <= 1]
  n <- length(values)
  if (n == 0L) return(NULL)

  # Contagem observada de valores em multiplos exatos
  remainder <- values %% multiple
  is_integer <- remainder < tolerance | (multiple - remainder) < tolerance
  observed_count <- sum(is_integer)
  observed_frac <- observed_count / n

  # Esperado sob distribuicao suave: proporcao de bins que sao multiplos
  # Para multiple=0.05, bins de tamanho tolerance*2 = 0.002 cobrem
  # 2*tolerance/multiple = 0.04 da area por multiplo, vezes ceil(1/multiple)+1 multiplos
  n_multiples <- floor(1 / multiple) + 1L
  expected_frac <- n_multiples * (2 * tolerance)

  # Bootstrap CI: reamostrar e recontar
  set.seed(20260413)
  boot_fracs <- replicate(n_boot, {
    boot_vals <- sample(values, n, replace = TRUE)
    boot_rem <- boot_vals %% multiple
    boot_int <- boot_rem < tolerance | (multiple - boot_rem) < tolerance
    sum(boot_int) / n
  })

  ratio <- observed_frac / expected_frac
  boot_ratios <- boot_fracs / expected_frac

  list(
    n = n,
    multiple = multiple,
    observed_count = observed_count,
    observed_frac = observed_frac,
    expected_frac = expected_frac,
    ratio = ratio,
    ratio_ci_025 = quantile(boot_ratios, 0.025),
    ratio_ci_975 = quantile(boot_ratios, 0.975),
    p_excess = mean(boot_fracs >= observed_frac)
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
    t_res <- kobak_test(sub_c$turnout, multiple = 0.05)
    if (!is.null(t_res)) {
      results[[paste0(label, "_turnout_5pct")]] <- c(
        list(turno = turno, candidato = cand, variable = "turnout", multiple_pct = 5),
        t_res
      )
    }

    # Vote share (comparecimento)
    vs_res <- kobak_test(sub_c$vote_share_comparecimento, multiple = 0.05)
    if (!is.null(vs_res)) {
      results[[paste0(label, "_voteshare_5pct")]] <- c(
        list(turno = turno, candidato = cand, variable = "vote_share", multiple_pct = 5),
        vs_res
      )
    }

    # 10% multiples
    t10_res <- kobak_test(sub_c$turnout, multiple = 0.10)
    if (!is.null(t10_res)) {
      results[[paste0(label, "_turnout_10pct")]] <- c(
        list(turno = turno, candidato = cand, variable = "turnout", multiple_pct = 10),
        t10_res
      )
    }

    vs10_res <- kobak_test(sub_c$vote_share_comparecimento, multiple = 0.10)
    if (!is.null(vs10_res)) {
      results[[paste0(label, "_voteshare_10pct")]] <- c(
        list(turno = turno, candidato = cand, variable = "vote_share", multiple_pct = 10),
        vs10_res
      )
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
cat("\n=== Kobak Integer Percentages Test ===\n")
for (i in seq_len(nrow(res_dt))) {
  r <- res_dt[i]
  cat(sprintf("T%d cand=%d %s mult=%d%%: ratio=%.3f [%.3f, %.3f] n=%d\n",
              r$turno, r$candidato, r$variable, r$multiple_pct,
              r$ratio, r$ratio_ci_025, r$ratio_ci_975, r$n))
}

log_section("Fim do teste Kobak")
