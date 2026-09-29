# R/06_sp_linearity_check.R -- Verificar linearidade do qbl em N (obs)
#
# Rodamos qbl em Sao Paulo (26.288 secoes, ~3.9x Brasilia) no modo compile
# test (200 iter, 4 chains) e comparamos per-iter-per-obs com Brasilia.
# Se o numero for aproximadamente constante, a extrapolacao linear para
# Brasil full (472k secoes) esta validada.
#
# Nao roda o full (7000 iter) porque seria ~2.4h so para SP -- compile test
# ja e' suficiente para checar linearidade.

source(here::here("R", "00_setup.R"))
suppressPackageStartupMessages({
  library(rjags)
  library(eforensics)
})

log_section("Linearidade qbl -- Sao Paulo compile test")

# Monkey-patch do order.formulas (mesmo do script 05)
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

# Carrega dados
secao <- setDT(as.data.frame(arrow::read_parquet(
  file.path(PATH_DATA_PROCESSED, "brasil_2022_secao_clean.parquet"))))

# Sao Paulo (CD_MUNICIPIO = 71072), T2, Lula e Bolsonaro
sp_long <- secao[CD_MUNICIPIO == 71072L & NR_TURNO == 2L &
                   NR_VOTAVEL %in% c(13L, 22L)]
log_step("SP T2 long rows: {nrow(sp_long)}")

sp <- sp_long[, .(
  N = first(QT_APTOS),
  comparecimento = first(QT_COMPARECIMENTO),
  w_lula  = sum(QT_VOTOS[NR_VOTAVEL == 13L]),
  w_bolso = sum(QT_VOTOS[NR_VOTAVEL == 22L])
), by = .(SG_UF, CD_MUNICIPIO, NR_ZONA, NR_SECAO)]
sp[, w := w_lula]
sp[, a := N - comparecimento]

dat_sp <- as.data.frame(sp[, .(N, a, w)])
log_step("SP T2 secoes unicas: {nrow(dat_sp)} (esperado ~26.288)")

# Compile test: 4 chains x 200 iter
t0 <- Sys.time()
fit_sp <- eforensics(
  formula1 = a ~ 1,
  formula2 = w ~ 1,
  formula3 = mu.iota.m ~ 1,
  formula4 = mu.iota.s ~ 1,
  formula5 = mu.chi.m  ~ 1,
  formula6 = mu.chi.s  ~ 1,
  data            = dat_sp,
  eligible.voters = "N",
  mcmc            = list(burn.in = 50, n.iter = 150,
                         n.adapt = 100, n.chains = 4),
  model           = "qbl",
  parComp         = TRUE,
  autoConv        = FALSE,
  get.dic         = 0
)
t1 <- Sys.time()
dt_sp <- as.numeric(difftime(t1, t0, units = "secs"))

n_obs_sp <- nrow(dat_sp)
per_iter_ms_sp <- 1000 * dt_sp / 200
per_iter_per_obs_us_sp <- 1e6 * dt_sp / (200 * n_obs_sp)

log_step("SP qbl compile 200 iter: {sprintf('%.1f', dt_sp)} s")
log_step("Per iter: {sprintf('%.1f', per_iter_ms_sp)} ms")
log_step("Per iter per obs: {sprintf('%.2f', per_iter_per_obs_us_sp)} us")

# Comparacao direta com Brasilia (da tabela 05_eforensics_qbl_timings.csv)
bsb_timings <- fread(file.path(PATH_RESULTS_LOGS, "05_eforensics_qbl_timings.csv"))
bsb_compile <- bsb_timings[phase == "compile_bsb_qbl"]
per_iter_per_obs_us_bsb <- bsb_compile$per_iter_per_obs_us[1]
scale_obs <- n_obs_sp / bsb_compile$n_obs[1]

log_section("Comparacao Brasilia vs SP (compile test qbl)")
comparison <- data.table(
  cidade             = c("Brasilia", "Sao Paulo"),
  n_obs              = c(bsb_compile$n_obs[1], n_obs_sp),
  wall_seconds       = c(bsb_compile$wall_seconds[1], dt_sp),
  per_iter_ms        = c(bsb_compile$per_iter_ms[1], per_iter_ms_sp),
  per_iter_per_obs_us = c(per_iter_per_obs_us_bsb, per_iter_per_obs_us_sp)
)
print(comparison)

cat(sprintf("\nScale factor em N: %.2fx\n", scale_obs))
cat(sprintf("Ratio wall clock SP/Brasilia: %.2fx\n",
            dt_sp / bsb_compile$wall_seconds[1]))
cat(sprintf("Ratio per_iter_per_obs SP/Brasilia: %.3fx\n",
            per_iter_per_obs_us_sp / per_iter_per_obs_us_bsb))

# Veredito
if (abs(per_iter_per_obs_us_sp / per_iter_per_obs_us_bsb - 1) < 0.20) {
  cat("\nVEREDITO: linearidade OK (per_iter_per_obs ratio < 1.2x)\n")
  cat("Extrapolacao para Brasil full (472.000 secoes) e' confiavel.\n")
} else {
  cat("\nVEREDITO: linearidade QUESTIONAVEL\n")
  cat("Per_iter_per_obs difere materialmente entre Brasilia e SP.\n")
  cat("Extrapolacao linear para Brasil full pode estar errada.\n")
}

# Persistir
fwrite(comparison, file.path(PATH_RESULTS_LOGS, "06_sp_linearity_comparison.csv"))
log_step("Resultado salvo em 06_sp_linearity_comparison.csv")
