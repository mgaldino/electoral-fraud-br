# R/05_eforensics_umeforensics_qbl.R -- Calibracao UMeforensics/eforensics_public
# modelo "qbl" (quasi-bl, hierarquico, canonical Mebane 2023).
#
# Contexto: o fork DiogoFerrari/eforensics (antigo, modelo "bl") foi rodado em
# R/04_eforensics_calibrate.R como baseline. Descobriu-se depois que:
#   - UMeforensics/eforensics_public tem "qbl" como modelo default
#   - "qbl" e' o modelo HIERARQUICO COMPLETO Mebane 2023 (random effects + prior
#     ordenado + k=0.7)
#   - o "bl" dos dois forks e' uma simplificacao sem random effects
#
# Este script calibra qbl na mesma Brasilia T2 usada pelo script 04 pra
# comparacao direta de tempo:
#   - Phase 1: smoke test sintetico (300 obs) -- so pra garantir que o qbl compila
#   - Phase 2: Brasilia compilation test (4 chains x 200 iter)
#   - Phase 3: Brasilia full run (4 chains x 7000 iter = 2000 burn + 5000 post)
#
# Comparacao final com script 04:
#   - bl (DiogoFerrari):        12.2 min wall (Brasilia, 7000 iter, 4 chains)
#   - qbl (UMeforensics):       ?? min -- este script
#
# Ajuda a decidir se qbl cabe em overnight pra Brasil full, ou se e' inviavel.

source(here::here("R", "00_setup.R"))
suppressPackageStartupMessages({
  library(rjags)
  library(eforensics)
})

log_section("Calibracao UMeforensics qbl -- Brasilia T2")
log_step("eforensics versao: {packageVersion('eforensics')}")

# ==============================================================================
# MONKEY-PATCH: eforensics:::order.formulas
# ==============================================================================
# Mesmo bug do fork antigo -- str_detect nao aceita formula. Patch via deparse.

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
# Helper: timer
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
# Note: ef_simulateData nao suporta 'qbl' -- usamos 'bl' para gerar dados
# sinteticos, mas rodamos qbl na estimacao. A estrutura dos dados (w, a, N) e'
# a mesma.

log_section("Phase 1 -- synthetic smoke test (nCov=1, model=qbl)")

set.seed(20260410)
sim <- ef_simulateData(n = 300, nCov = 1, nCov.fraud = 1, model = "bl")
log_step("Synthetic data (gerado via bl): {nrow(sim$data)} rows, {ncol(sim$data)} cols")

smoke <- timeit("Phase 1 qbl fit (sintetico)", quote({
  eforensics(
    formula1 = a ~ x1.a,
    formula2 = w ~ x1.w,
    formula3 = mu.iota.m ~ x1.iota.m,
    formula4 = mu.iota.s ~ x1.iota.s,
    formula5 = mu.chi.m  ~ x1.chi.m,
    formula6 = mu.chi.s  ~ x1.chi.s,
    data            = sim$data,
    eligible.voters = "N",
    mcmc            = list(burn.in = 50, n.iter = 150,
                           n.adapt = 100, n.chains = 4),
    model           = "qbl",
    parComp         = TRUE,
    autoConv        = FALSE,
    get.dic         = 0
  )
}))
log_step("Phase 1 qbl PASS")

# ==============================================================================
# PHASE 2 -- Brasilia data
# ==============================================================================
log_section("Phase 2 -- Brasilia T2 dataset")

secao <- setDT(as.data.frame(arrow::read_parquet(
  file.path(PATH_DATA_PROCESSED, "brasil_2022_secao_clean.parquet"))))

bsb_long <- secao[CD_MUNICIPIO == 97012L & NR_TURNO == 2L &
                    NR_VOTAVEL %in% c(13L, 22L)]

bsb <- bsb_long[, .(
  N             = first(QT_APTOS),
  comparecimento = first(QT_COMPARECIMENTO),
  w_lula         = sum(QT_VOTOS[NR_VOTAVEL == 13L]),
  w_bolso        = sum(QT_VOTOS[NR_VOTAVEL == 22L])
), by = .(SG_UF, CD_MUNICIPIO, NR_ZONA, NR_SECAO)]

bsb[, w := w_lula]
bsb[, a := N - comparecimento]

dat_bsb <- as.data.frame(bsb[, .(N, a, w)])
log_step("Brasilia T2: {nrow(dat_bsb)} secoes")
stopifnot(nrow(dat_bsb) == 6748)

# ==============================================================================
# PHASE 3 -- Brasilia compile test (4 chains x 200 iter)
# ==============================================================================
log_section("Phase 3 -- Brasilia qbl compilation test")

phase3 <- timeit("Phase 3 qbl compile Brasilia", quote({
  eforensics(
    formula1 = a ~ 1,
    formula2 = w ~ 1,
    formula3 = mu.iota.m ~ 1,
    formula4 = mu.iota.s ~ 1,
    formula5 = mu.chi.m  ~ 1,
    formula6 = mu.chi.s  ~ 1,
    data            = dat_bsb,
    eligible.voters = "N",
    mcmc            = list(burn.in = 50, n.iter = 150,
                           n.adapt = 100, n.chains = 4),
    model           = "qbl",
    parComp         = TRUE,
    autoConv        = FALSE,
    get.dic         = 0
  )
}))

log_step("Phase 3 qbl PASS")
log_step("Phase 3 wall clock: {sprintf('%.2f', phase3$seconds)} s")
per_iter_ms_3 <- 1000 * phase3$seconds / 200
log_step("Per iter (qbl compile): {sprintf('%.2f', per_iter_ms_3)} ms")

# ==============================================================================
# PHASE 4 -- Brasilia FULL run (4 chains x 7000 iter)
# ==============================================================================
# Roda so se EFORENSICS_FULL=1
run_full <- Sys.getenv("EFORENSICS_FULL", "0") == "1"

if (run_full) {
  log_section("Phase 4 -- Brasilia qbl FULL (4 chains, 2000 burn + 5000 post)")
  log_step("Rodando... isso pode levar de 30 min a 3 horas.")

  phase4 <- timeit("Phase 4 qbl full Brasilia", quote({
    eforensics(
      formula1 = a ~ 1,
      formula2 = w ~ 1,
      formula3 = mu.iota.m ~ 1,
      formula4 = mu.iota.s ~ 1,
      formula5 = mu.chi.m  ~ 1,
      formula6 = mu.chi.s  ~ 1,
      data            = dat_bsb,
      eligible.voters = "N",
      mcmc            = list(burn.in = 2000, n.iter = 5000,
                             n.adapt = 1000, n.chains = 4),
      model           = "qbl",
      parComp         = TRUE,
      autoConv        = FALSE,
      get.dic         = 0
    )
  }))

  log_step("Phase 4 qbl PASS. Wall clock: {sprintf('%.2f', phase4$seconds)} s")

  tryCatch({
    print(summary(phase4$result))
  }, error = function(e) {
    log_step("summary() falhou: {conditionMessage(e)}")
  })

  saveRDS(phase4$result,
          file.path(PATH_RESULTS_LOGS, "05_eforensics_qbl_brasilia_fit.rds"))
  log_step("Fit salvo em quality_reports/results/05_eforensics_qbl_brasilia_fit.rds")

  timing_log <- data.table(
    phase        = c("smoke_synth_qbl", "compile_bsb_qbl", "full_bsb_qbl"),
    model        = c("qbl", "qbl", "qbl"),
    n_obs        = c(300L, 6748L, 6748L),
    n_chains     = c(4L, 4L, 4L),
    total_iter   = c(200L, 200L, 7000L),
    wall_seconds = c(smoke$seconds, phase3$seconds, phase4$seconds)
  )
  timing_log[, per_iter_ms := 1000 * wall_seconds / total_iter]
  timing_log[, per_iter_per_obs_us := 1e6 * wall_seconds / (total_iter * n_obs)]

  fwrite(timing_log,
         file.path(PATH_RESULTS_LOGS, "05_eforensics_qbl_timings.csv"))
  log_step("Timings salvos em 05_eforensics_qbl_timings.csv")
  print(timing_log)
}

log_section("Fim do script de calibracao qbl")
