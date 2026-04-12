# R/04_eforensics_calibrate.R -- Calibracao do eforensics (Bloco 3 setup)
#
# Objetivo: medir tempo de execucao do pipeline Mebane/Ferrari em Brasilia T2
# (~6.7k secoes, proximo ao tamanho do PA 2024 de Mebane -- 9.2k precincts).
# Extrapolar para Brasil inteiro.
#
# Fases:
#  1. Smoke test com dados sinteticos (confirma que o pacote compila)
#  2. Preparacao do dataset Brasilia T2
#  3. Compilation test (4 chains x 200 iter)
#  4. Full calibration run (4 chains x 5000 post-burn + 2000 burn-in)
#
# A Fase 4 roda em background; este script termina apos disparar.

source(here::here("R", "00_setup.R"))
suppressPackageStartupMessages({
  library(rjags)
  library(eforensics)
})

log_section("Bloco 3 -- Calibracao eforensics")

# ==============================================================================
# MONKEY-PATCH: eforensics:::order.formulas
# ==============================================================================
# O pacote eforensics usa stringr::str_detect(., pattern) onde . e' um objeto
# formula, nao uma string. Versoes recentes de stringr/vctrs rejeitam esse
# input. Substituimos por uma versao que converte formula em string via
# deparse() antes do matching. Pattern match e' por LHS da formula
# (mu.iota.m, mu.iota.s, mu.chi.m, mu.chi.s).

fixed_order_formulas <- function(formula3, formula4, formula5, formula6) {
  if (is.null(formula3)) formula3 <- NA
  if (is.null(formula4)) formula4 <- NA
  if (is.null(formula5)) formula5 <- NA
  if (is.null(formula6)) formula6 <- NA
  formulas <- list(formula3, formula4, formula5, formula6)

  identify_idx <- function(f) {
    if (length(f) == 1L && is.na(f)) return(999)
    s <- paste(deparse(f), collapse = " ")
    if (grepl("mu.iota.m", s, fixed = TRUE)) return(1)
    if (grepl("mu.iota.s", s, fixed = TRUE)) return(2)
    if (grepl("mu.chi.m",  s, fixed = TRUE)) return(3)
    if (grepl("mu.chi.s",  s, fixed = TRUE)) return(4)
    NA_real_
  }
  idx <- vapply(formulas, identify_idx, numeric(1))

  formulas.final <- list(NA, NA, NA, NA)
  for (i in seq_along(idx)) {
    if (!is.na(idx[i]) && idx[i] != 999) {
      formulas.final[[idx[i]]] <- formulas[[i]]
    }
  }
  if (length(formulas.final[[1]]) == 1L && is.na(formulas.final[[1]]))
    formulas.final[[1]] <- mu.iota.m ~ 1
  if (length(formulas.final[[2]]) == 1L && is.na(formulas.final[[2]]))
    formulas.final[[2]] <- mu.iota.s ~ 1
  if (length(formulas.final[[3]]) == 1L && is.na(formulas.final[[3]]))
    formulas.final[[3]] <- mu.chi.m ~ 1
  if (length(formulas.final[[4]]) == 1L && is.na(formulas.final[[4]]))
    formulas.final[[4]] <- mu.chi.s ~ 1

  formulas.final
}

assignInNamespace("order.formulas", fixed_order_formulas, ns = "eforensics")
log_step("Monkey-patch aplicado em eforensics:::order.formulas")

# ==============================================================================
# helper: timer
# ==============================================================================
timeit <- function(label, code) {
  t0 <- Sys.time()
  out <- eval(code, envir = parent.frame())
  t1 <- Sys.time()
  dt <- as.numeric(difftime(t1, t0, units = "secs"))
  cli::cli_inform("  {label}: {sprintf('%.2f', dt)} s wall clock")
  list(result = out, seconds = dt)
}

# ==============================================================================
# PHASE 1 -- synthetic smoke test
# ==============================================================================
log_section("Phase 1 -- synthetic smoke test (nCov=1)")

set.seed(20260410)
sim <- ef_simulateData(n = 300, nCov = 1, nCov.fraud = 1, model = "bl")
log_step("Synthetic data: {nrow(sim$data)} rows, {ncol(sim$data)} cols")
log_step("Cols: {paste(colnames(sim$data), collapse=', ')}")

smoke <- timeit("Phase 1 fit", quote({
  eforensics(
    formula1 = a ~ x1.a,
    formula2 = w ~ x1.w,
    formula3 = mu.iota.m ~ x1.iota.m,
    formula4 = mu.iota.s ~ x1.iota.s,
    formula5 = mu.chi.m  ~ x1.chi.m,
    formula6 = mu.chi.s  ~ x1.chi.s,
    data            = sim$data,
    elegible.voters = "N",
    mcmc            = list(burn.in = 50, n.iter = 150,
                           n.adapt = 100, n.chains = 4),
    model           = "bl",
    parComp         = TRUE,
    autoConv        = FALSE,
    get.dic         = 0
  )
}))
log_step("Phase 1 PASS. Class: {paste(class(smoke$result), collapse='/')}")

# ==============================================================================
# PHASE 2 -- Brasilia T2 dataset
# ==============================================================================
log_section("Phase 2 -- Brasilia T2 dataset")

secao <- setDT(as.data.frame(arrow::read_parquet(
  file.path(PATH_DATA_PROCESSED, "brasil_2022_secao_clean.parquet"))))

# Brasilia (CD_MUNICIPIO=97012), turno 2, so Lula e Bolsonaro
bsb_long <- secao[CD_MUNICIPIO == 97012L & NR_TURNO == 2L &
                    NR_VOTAVEL %in% c(13L, 22L)]
log_step("Brasilia T2 long: {nrow(bsb_long)} linhas")

# Reshape long -> wide: uma linha por secao com votos dos 2 candidatos
key_secao <- c("SG_UF", "CD_MUNICIPIO", "NR_ZONA", "NR_SECAO")
bsb <- bsb_long[, .(
  N             = first(QT_APTOS),
  comparecimento = first(QT_COMPARECIMENTO),
  w_lula         = sum(QT_VOTOS[NR_VOTAVEL == 13L]),
  w_bolso        = sum(QT_VOTOS[NR_VOTAVEL == 22L]),
  brancos        = first(QT_VOTOS_BRANCOS),
  nulos          = first(QT_VOTOS_NULOS)
), by = key_secao]

# Leader (Mebane def): quem teve mais votos na eleicao agregada da unidade
# Em Brasilia T2, Lula ganhou (~51.7%). Globalmente tambem. Leader = Lula.
bsb[, w := w_lula]
bsb[, a := N - comparecimento]  # abstencoes

log_step("Brasilia T2 wide: {nrow(bsb)} secoes")
log_step("Summary N, a, w:")
print(summary(bsb[, .(N, a, w)]))
log_step("Leader (Lula) total votes: {sum(bsb$w)}")
log_step("Non-leader (Bolso+brancos+nulos) total: {sum(bsb$comparecimento - bsb$w)}")
log_step("Aptos total: {sum(bsb$N)}")

# eforensics precisa de um data.frame simples com as colunas-chave
dat_bsb <- as.data.frame(bsb[, .(N, a, w)])
stopifnot(nrow(dat_bsb) == 6748)  # sanity

# ==============================================================================
# PHASE 3 -- compilation test (4 chains x 200 iter)
# ==============================================================================
log_section("Phase 3 -- Brasilia compilation test (4 chains, 50+150 iter)")

log_step("Disparando eforensics com formulas intercept-only...")
phase3 <- timeit("Phase 3 fit", quote({
  eforensics(
    formula1 = a ~ 1,
    formula2 = w ~ 1,
    formula3 = mu.iota.m ~ 1,
    formula4 = mu.iota.s ~ 1,
    formula5 = mu.chi.m  ~ 1,
    formula6 = mu.chi.s  ~ 1,
    data            = dat_bsb,
    elegible.voters = "N",
    mcmc            = list(burn.in = 50, n.iter = 150,
                           n.adapt = 100, n.chains = 4),
    model           = "bl",
    parComp         = TRUE,
    autoConv        = FALSE,
    get.dic         = 0
  )
}))

log_step("Phase 3 PASS. Class: {paste(class(phase3$result), collapse='/')}")
log_step("Phase 3 wall clock: {sprintf('%.2f', phase3$seconds)} s")

# Por-iteracao (200 iter total)
per_iter_ms <- 1000 * phase3$seconds / 200
log_step("Per iter (wall, 4 chains paralelas): {sprintf('%.2f', per_iter_ms)} ms")

# ==============================================================================
# PHASE 4 -- kickoff calibration run (4 chains x 5000 post-burn)
# ==============================================================================
# NOTA: Este passo roda completo aqui se invocado com FULL=TRUE via Sys.getenv.
# Caso contrario, o script so reporta o que o Phase 3 descobriu e sai -- o
# usuario pode disparar o Phase 4 separadamente em background.

run_full <- Sys.getenv("EFORENSICS_FULL", "0") == "1"

if (run_full) {
  log_section("Phase 4 -- full calibration (4 chains, 2000 burn + 5000 post)")
  log_step("Rodando... isso pode levar de varios minutos a horas.")

  phase4 <- timeit("Phase 4 fit", quote({
    eforensics(
      formula1 = a ~ 1,
      formula2 = w ~ 1,
      formula3 = mu.iota.m ~ 1,
      formula4 = mu.iota.s ~ 1,
      formula5 = mu.chi.m  ~ 1,
      formula6 = mu.chi.s  ~ 1,
      data            = dat_bsb,
      elegible.voters = "N",
      mcmc            = list(burn.in = 2000, n.iter = 5000,
                             n.adapt = 1000, n.chains = 4),
      model           = "bl",
      parComp         = TRUE,
      autoConv        = FALSE,
      get.dic         = 0
    )
  }))

  log_step("Phase 4 PASS. Wall clock: {sprintf('%.2f', phase4$seconds)} s")

  # Summary e diagnosticos
  log_step("Extraindo summary do fit...")
  tryCatch({
    print(summary(phase4$result))
  }, error = function(e) {
    log_step("summary() falhou: {conditionMessage(e)}")
  })

  # Salvar o fit para analise posterior
  saveRDS(phase4$result,
          file.path(PATH_RESULTS_LOGS, "04_eforensics_brasilia_fit.rds"))
  log_step("Fit salvo em quality_reports/results/04_eforensics_brasilia_fit.rds")

  # Gravar summary numeric key metrics
  timing_log <- data.table(
    phase        = c("smoke_synth", "compile_bsb", "full_bsb"),
    n_obs        = c(300L, 6748L, 6748L),
    n_chains     = c(4L, 4L, 4L),
    total_iter   = c(200L, 200L, 7000L),  # burn + post
    wall_seconds = c(smoke$seconds, phase3$seconds, phase4$seconds)
  )
  timing_log[, per_iter_ms := 1000 * wall_seconds / total_iter]
  timing_log[, per_iter_per_obs_us := 1e6 * wall_seconds / (total_iter * n_obs)]

  fwrite(timing_log,
         file.path(PATH_RESULTS_LOGS, "04_eforensics_timings.csv"))
  log_step("Timings salvos em 04_eforensics_timings.csv")
  print(timing_log)
}

log_section("Fim do script de calibracao")
