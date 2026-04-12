# R/07_brasil_full_qbl.R -- Run Mebane 2023 qbl em Brasil full (T2)
#
# Este script roda o eforensics (UMeforensics/eforensics_public) no
# modelo "qbl" (canonical hierarchical Mebane 2023) sobre o conjunto
# completo de secoes eleitorais do 2o turno da presidencial 2022.
#
# Configuracao:
#   - 4 chains em paralelo (parComp = TRUE)
#   - 2000 burn-in + 5000 post-burn-in + 1000 adaptation = 8000 iter total
#   - autoConv = TRUE (deixa eforensics reiniciar cadeias se convergencia falhar)
#   - Brasil only (exclui exterior)
#   - T2 apenas (Lula + Bolsonaro, leader = Lula)
#   - Intercept-only nos efeitos fixos; random effects ativos via qbl
#
# Tempo esperado: INCERTO.
#   - Calibracao Brasilia qbl (6.7k secoes, 7000 iter, 4 chains): 35.5 min
#   - Calibracao SP qbl compile (26.3k secoes, 200 iter): 22 min -- 2.25x mais
#     per-iter-per-obs que Brasilia. Nao linear em N.
#   - Scaling parece ser ~N^0.6 a N^0.6 extra alem do linear.
#   - Brasil full (472k, ~70x Brasilia): entre 1.7 dias (se super-linearidade
#     for so no compile overhead) e 14 dias (se steady-state tambem for
#     super-linear). Dois cenarios, dois pontos de dado so -- nao da pra
#     distinguir sem uma terceira medida.
#
# ESTRATEGIA: rodar PRIMEIRO um canary (BURN_IN=200, N_ITER=300) pra medir
# steady-state real em Brasil full. Canary deve levar 2-10h wall clock. Com
# o numero do canary, extrapolar com confianca pra 2000 burn + 5000 post.
#
# Canary:
#   BURN_IN=200 N_ITER=300 N_ADAPT=200 Rscript R/07_brasil_full_qbl.R
# Full:
#   Rscript R/07_brasil_full_qbl.R
#
# Este script NAO deve ser rodado no notebook pessoal -- e' para ser transferido
# e executado em desktop dedicado (USP).
#
# Outputs:
#   - data/processed/07_brasil_full_qbl_T2_fit.rds     -- fit completo
#   - quality_reports/results/07_brasil_full_qbl_T2_timings.csv
#   - quality_reports/results/07_brasil_full_qbl_T2_summary.txt
#   - quality_reports/results/07_brasil_full_qbl_T2_sessioninfo.txt
#
# Invocacao:
#   cd electoralFraud
#   Rscript R/07_brasil_full_qbl.R
# ou, para deixar em background com log:
#   nohup Rscript R/07_brasil_full_qbl.R > /tmp/brasil_full_qbl.log 2>&1 &

source(here::here("R", "00_setup.R"))
suppressPackageStartupMessages({
  library(rjags)
  library(eforensics)
})

# Parametros via env var (com defaults de producao)
BURN_IN  <- as.integer(Sys.getenv("BURN_IN",  "2000"))
N_ITER   <- as.integer(Sys.getenv("N_ITER",   "5000"))
N_ADAPT  <- as.integer(Sys.getenv("N_ADAPT",  "1000"))
RUN_TAG  <- Sys.getenv("RUN_TAG", "full")   # "canary" or "full" (etiqueta de arquivo)

log_section("Brasil full qbl T2 -- run de producao")
log_step("R version: {R.version.string}")
log_step("eforensics version: {packageVersion('eforensics')}")
log_step("data.table threads: {data.table::getDTthreads()}")
log_step("MCMC: burn.in={BURN_IN} n.iter={N_ITER} n.adapt={N_ADAPT} [{RUN_TAG}]")

# ==============================================================================
# MONKEY-PATCH: order.formulas (bug do stringr vs formula)
# ==============================================================================
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
    if (!is.na(idx[i]) && idx[i] != 999) formulas.final[[idx[i]]] <- formulas[[i]]
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
log_step("Monkey-patch order.formulas aplicado")

# ==============================================================================
# Dados: Brasil full T2
# ==============================================================================
log_section("Carregando dados")

secao <- setDT(as.data.frame(arrow::read_parquet(
  file.path(PATH_DATA_PROCESSED, "brasil_2022_secao_clean.parquet"))))
log_step("Parquet secao: {format(nrow(secao), big.mark=',')} linhas")

# Filtros: Brasil only, T2, Lula (13) e Bolsonaro (22)
br_t2_long <- secao[flag_exterior == FALSE &
                    NR_TURNO == 2L &
                    NR_VOTAVEL %in% c(13L, 22L)]
log_step("Brasil T2 (Lula + Bolsonaro) long: {format(nrow(br_t2_long), big.mark=',')}")

# Reshape wide: uma linha por secao
br_t2 <- br_t2_long[, .(
  N              = first(QT_APTOS),
  comparecimento = first(QT_COMPARECIMENTO),
  w_lula         = sum(QT_VOTOS[NR_VOTAVEL == 13L]),
  w_bolso        = sum(QT_VOTOS[NR_VOTAVEL == 22L])
), by = .(SG_UF, CD_MUNICIPIO, NR_ZONA, NR_SECAO)]

# Leader = Lula (venceu o 2o turno nacional agregado, 50.9%)
br_t2[, w := w_lula]
br_t2[, a := N - comparecimento]

# Sanity: eforensics assume N > 0 em todas as obs
stopifnot(all(br_t2$N > 0))
stopifnot(all(br_t2$w >= 0))
stopifnot(all(br_t2$a >= 0))
stopifnot(all(br_t2$w <= br_t2$N - br_t2$a))  # w <= comparecimento

dat <- as.data.frame(br_t2[, .(N, a, w)])
log_step("Brasil T2 wide: {format(nrow(dat), big.mark=',')} secoes")
log_step("Summary N, a, w:")
print(summary(dat))

# ==============================================================================
# Fit eforensics qbl
# ==============================================================================
log_section("Fit qbl (isso vai demorar -- ~1.7 dias esperados)")

t0 <- Sys.time()
log_step("Inicio: {format(t0, '%Y-%m-%d %H:%M:%S %Z')}")

fit <- eforensics(
  formula1 = a ~ 1,
  formula2 = w ~ 1,
  formula3 = mu.iota.m ~ 1,
  formula4 = mu.iota.s ~ 1,
  formula5 = mu.chi.m  ~ 1,
  formula6 = mu.chi.s  ~ 1,
  data                   = dat,
  eligible.voters        = "N",
  mcmc                   = list(burn.in  = BURN_IN,
                                 n.iter   = N_ITER,
                                 n.adapt  = N_ADAPT,
                                 n.chains = 4),
  model                  = "qbl",
  parComp                = TRUE,
  autoConv               = if (RUN_TAG == "canary") FALSE else TRUE,
  max.auto               = 3,         # max 3 restarts (limite de tempo)
  get.dic                = 0,         # sem DIC (economiza tempo)
  mcmc.conv.diagnostic   = "MCMCSE",
  mcmc.conv.parameters   = "pi",
  mcmcse.conv.precision  = 0.05
)

t1 <- Sys.time()
dt <- as.numeric(difftime(t1, t0, units = "secs"))
log_step("Fim: {format(t1, '%Y-%m-%d %H:%M:%S %Z')}")
log_step("Wall clock: {sprintf('%.1f', dt)} s = {sprintf('%.2f', dt/3600)} h = {sprintf('%.2f', dt/86400)} dias")

# ==============================================================================
# Persistir
# ==============================================================================
log_section("Persistindo artefatos")

# Fit (pode ser grande -- varios GB)
fit_path <- file.path(PATH_DATA_PROCESSED,
                      sprintf("07_brasil_full_qbl_T2_%s_fit.rds", RUN_TAG))
saveRDS(fit, fit_path)
log_step("Fit salvo: {fit_path}")

# Timing
total_iter <- BURN_IN + N_ITER + N_ADAPT
timing_path <- file.path(PATH_RESULTS_LOGS,
                         sprintf("07_brasil_full_qbl_T2_%s_timings.csv", RUN_TAG))
fwrite(data.table(
  model         = "qbl",
  scope         = "brasil_full_T2",
  run_tag       = RUN_TAG,
  n_obs         = nrow(dat),
  n_chains      = 4L,
  burn_in       = BURN_IN,
  post_burn     = N_ITER,
  adapt         = N_ADAPT,
  total_iter    = total_iter,
  wall_seconds  = dt,
  wall_hours    = dt / 3600,
  wall_days     = dt / 86400,
  per_iter_ms   = 1000 * dt / total_iter,
  per_iter_per_obs_us = 1e6 * dt / (total_iter * nrow(dat)),
  start_time    = format(t0, "%Y-%m-%d %H:%M:%S %Z"),
  end_time      = format(t1, "%Y-%m-%d %H:%M:%S %Z")
), timing_path)
log_step("Timing salvo: {timing_path}")

# Summary do fit
summary_path <- file.path(PATH_RESULTS_LOGS,
                          sprintf("07_brasil_full_qbl_T2_%s_summary.txt", RUN_TAG))
sink(summary_path)
cat("# Brasil full qbl T2 -- summary\n")
cat(sprintf("# Data: %s\n", format(t1, "%Y-%m-%d")))
cat(sprintf("# Wall clock: %.1f s (%.2f h)\n\n", dt, dt / 3600))
tryCatch(print(summary(fit)),
         error = function(e) cat("summary() falhou:", conditionMessage(e), "\n"))
sink()
log_step("Summary salvo: {summary_path}")

# Session info (reprodutibilidade)
sess_path <- file.path(PATH_RESULTS_LOGS,
                       sprintf("07_brasil_full_qbl_T2_%s_sessioninfo.txt", RUN_TAG))
sink(sess_path)
cat("# Session info do run Brasil full qbl T2\n")
cat(sprintf("# Host: %s\n", Sys.info()[["nodename"]]))
cat(sprintf("# User: %s\n", Sys.info()[["user"]]))
cat(sprintf("# Date: %s\n\n", format(t1, "%Y-%m-%d %H:%M:%S %Z")))
print(sessionInfo())
cat("\n\n## renv status (sumario)\n")
lock <- jsonlite::fromJSON("renv.lock")
cat("R:", lock$R$Version, "\n")
cat("N pacotes lockfile:", length(lock$Packages), "\n")
cat("eforensics pacote:", lock$Packages$eforensics$Package,
    "v", lock$Packages$eforensics$Version,
    "from", lock$Packages$eforensics$RemoteRepo, "\n")
sink()
log_step("Session info salvo: {sess_path}")

log_section("Run concluido")
log_step("Transferir de volta os 4 arquivos em quality_reports/results/07_*.txt/csv")
log_step("E o fit em data/processed/07_brasil_full_qbl_T2_fit.rds")
