# R/05_stan_eforensics_calibrate.R -- legacy Stan baseline for the simplified JAGS bl()
#
# Objective:
#   1. Build the Brasilia 2022 round-2 section-level dataset used in R/04
#   2. Fit a Stan approximation to the simplified legacy JAGS "bl" model
#   3. Record timings, diagnostics, and substantive summaries
#
# Important:
#   As of 2026-04-11, the canonical JAGS target in UMeforensics is qbl(), not bl().
#   This file is retained only as a legacy baseline for the simplified bl()
#   target used in the old fork / historical comparison, with:
#     - intercept-only formulas
#     - legacy flat Dirichlet prior on pi
#     - k = 0.7
#     - Z_i marginalized
#     - global fraud magnitudes used directly in place of unit-level latent
#       binomial fraud draws from the JAGS implementation

source(here::here("R", "00_setup.R"))

log_step <- function(msg, ...) {
  values <- list(...)
  rendered <- do.call(glue::glue, c(list(msg), values))
  cli::cli_inform("{format(Sys.time(), '%H:%M:%S')}  {rendered}")
}

ensure_extra_library <- function() {
  extra_libs <- unique(c(
    .libPaths(),
    Filter(nzchar, strsplit(Sys.getenv("R_LIBS_USER"), .Platform$path.sep)[[1]]),
    .Library,
    R.home("library"),
    .Library.site
  ))
  .libPaths(extra_libs)
}

ensure_namespace <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    ensure_extra_library()
  }
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cli::cli_abort("Pacote obrigatório não encontrado: {.pkg {pkg}}")
  }
}

ensure_namespace("cmdstanr")
ensure_namespace("posterior")

suppressPackageStartupMessages({
  library(cmdstanr)
  library(posterior)
})

log_section("Bloco 5A -- Stan baseline legado do bl")

PATH_STAN_DIR <- here::here("stan")
PATH_STAN_MODEL <- here::here("stan", "eforensics_bl.stan")
PATH_CMDSTAN_OUTPUT <- here::here("data", "processed", "cmdstanr_outputs")
PATH_STAN_FIT <- here::here("data", "processed", "stan_eforensics_brasilia_fit.rds")
PATH_STAN_TIMINGS <- here::here("quality_reports", "results", "05_stan_brasilia_timings.csv")
PATH_STAN_LOG <- here::here("quality_reports", "results", "05_stan_brasilia_log.md")

fs::dir_create(PATH_STAN_DIR)
fs::dir_create(PATH_CMDSTAN_OUTPUT)

if (!file.exists(PATH_STAN_MODEL)) {
  cli::cli_abort("Arquivo Stan não encontrado: {.file {PATH_STAN_MODEL}}")
}

if (is.null(tryCatch(cmdstanr::cmdstan_path(), error = function(e) NULL))) {
  cli::cli_abort("CmdStan não está disponível neste ambiente.")
}

timeit <- function(label, code) {
  t0 <- Sys.time()
  out <- eval(code, envir = parent.frame())
  t1 <- Sys.time()
  dt <- as.numeric(difftime(t1, t0, units = "secs"))
  cli::cli_inform("  {label}: {sprintf('%.2f', dt)} s wall clock")
  list(result = out, seconds = dt)
}

quantile_025 <- function(x) posterior::quantile2(x, probs = 0.025)
quantile_975 <- function(x) posterior::quantile2(x, probs = 0.975)

build_brasilia_data <- function() {
  log_section("Phase 1 -- Brasilia T2 dataset")

  secao <- data.table::setDT(as.data.frame(
    arrow::read_parquet(file.path(PATH_DATA_PROCESSED, "brasil_2022_secao_clean.parquet"))
  ))

  bsb_long <- secao[
    CD_MUNICIPIO == 97012L &
      NR_TURNO == 2L &
      NR_VOTAVEL %in% c(13L, 22L)
  ]

  key_secao <- c("SG_UF", "CD_MUNICIPIO", "NR_ZONA", "NR_SECAO")
  bsb <- bsb_long[, .(
    N = first(QT_APTOS),
    comparecimento = first(QT_COMPARECIMENTO),
    w = sum(QT_VOTOS[NR_VOTAVEL == 13L])
  ), by = key_secao]

  bsb[, a := N - comparecimento]
  bsb[, non_leader := comparecimento - w]

  stopifnot(nrow(bsb) == 6748L)
  stopifnot(all(bsb$N > 0L))
  stopifnot(all(bsb$a >= 0L))
  stopifnot(all(bsb$w >= 0L))
  stopifnot(all(bsb$non_leader >= 0L))
  stopifnot(all(bsb$w <= bsb$N))
  stopifnot(all(bsb$a <= bsb$N))

  n_sec <- nrow(bsb)
  n_total <- sum(bsb$N)
  a_total <- sum(bsb$a)
  w_total <- sum(bsb$w)

  log_step("Brasilia T2 wide: {n_sec} secoes", n_sec = n_sec)
  log_step("Aptos totais: {n_total}", n_total = n_total)
  log_step("Abstenções totais: {a_total}", a_total = a_total)
  log_step("Votos do leader totais: {w_total}", w_total = w_total)

  list(
    dt = bsb,
    stan_data = list(
      n_obs = nrow(bsb),
      N = as.integer(bsb$N),
      a = as.integer(bsb$a),
      w = as.integer(bsb$w),
      k = 0.7
    )
  )
}

build_summary_table <- function(fit, variables) {
  draws <- fit$draws(variables = variables, format = "draws_df")
  posterior::summarise_draws(
    draws,
    mean = mean,
    median = median,
    sd = sd,
    q025 = quantile_025,
    q975 = quantile_975,
    rhat = posterior::rhat,
    ess_bulk = posterior::ess_bulk,
    ess_tail = posterior::ess_tail
  )
}

sampler_divergences <- function(fit) {
  diag_array <- fit$sampler_diagnostics(inc_warmup = FALSE)
  if (length(dim(diag_array)) != 3L) {
    return(NA_integer_)
  }
  if (!("divergent__" %in% dimnames(diag_array)[[3]])) {
    return(NA_integer_)
  }
  as.integer(sum(diag_array[, , "divergent__"]))
}

sampler_treedepth_hits <- function(fit, max_treedepth) {
  diag_array <- fit$sampler_diagnostics(inc_warmup = FALSE)
  if (length(dim(diag_array)) != 3L) {
    return(NA_integer_)
  }
  if (!("treedepth__" %in% dimnames(diag_array)[[3]])) {
    return(NA_integer_)
  }
  as.integer(sum(diag_array[, , "treedepth__"] >= max_treedepth))
}

write_log <- function(dataset, timing_tbl, summary_tbl, full_run, compile_seconds, notes) {
  latest_timing <- timing_tbl[.N]
  rhat_max <- latest_timing$rhat_max[[1]]
  ess_bulk_min <- latest_timing$ess_bulk_min[[1]]
  ess_tail_min <- latest_timing$ess_tail_min[[1]]
  divergent_transitions <- latest_timing$divergent_transitions[[1]]
  treedepth_hits <- latest_timing$max_treedepth_hits[[1]]

  diagnostic_notes <- c(
    if (isTRUE(rhat_max > 1.01)) {
      paste0(
        "Diagnóstico: `rhat_max = ",
        sprintf("%.3f", rhat_max),
        "` indica que esta execução ainda não é adequada para inferência substantiva."
      )
    },
    if (isTRUE(ess_bulk_min < 100)) {
      paste0(
        "Diagnóstico: `ESS_bulk_min = ",
        sprintf("%.1f", ess_bulk_min),
        "` é muito baixo; use apenas como verificação funcional."
      )
    },
    if (isTRUE(ess_tail_min < 100)) {
      paste0(
        "Diagnóstico: `ESS_tail_min = ",
        sprintf("%.1f", ess_tail_min),
        "` é muito baixo; as caudas posteriores não estão estáveis."
      )
    },
    if (isTRUE(divergent_transitions > 0)) {
      paste0("Diagnóstico: houve ", divergent_transitions, " transições divergentes.")
    },
    if (isTRUE(treedepth_hits > 0)) {
      paste0(
        "Diagnóstico: houve ",
        treedepth_hits,
        " transições batendo `max_treedepth`; a geometria posterior segue difícil."
      )
    }
  )

  header <- c(
    "# Bloco 5 -- log da calibração Stan",
    "",
    paste0("Data/hora: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %z")),
    paste0("R: ", getRversion()),
    paste0("CmdStanR: ", as.character(utils::packageVersion("cmdstanr"))),
    paste0("CmdStan: ", cmdstanr::cmdstan_version()),
    "",
    "## Alvo do modelo",
    "",
    "- Modelo: aproximação Stan do `bl()` simplificado legado do `eforensics`.",
    "- Prior de mistura: Dirichlet(1, 1, 1), para espelhar o fork legado usado na comparação com JAGS.",
    "- Constante de threshold: `k = 0.7`.",
    paste0("- Tempo de compilação Stan: `", sprintf("%.2f", compile_seconds), " s`."),
    "- Limitação: esta fase não inclui os random effects hierárquicos do paper de Mebane (2023).",
    "- Limitação adicional: os latentes binomiais por seção (`N.iota.*`, `N.chi.*`) do JAGS foram substituídos por magnitudes globais contínuas.",
    "",
    "## Dataset",
    "",
    paste0("- Seções: ", dataset$stan_data$n_obs),
    paste0("- Aptos totais: ", sum(dataset$dt$N)),
    paste0("- Abstenções totais: ", sum(dataset$dt$a)),
    paste0("- Votos do leader totais: ", sum(dataset$dt$w)),
    ""
  )

  timing_lines <- c(
    "## Timings",
    "",
    paste(capture.output(print(timing_tbl)), collapse = "\n"),
    "",
    "## Resumo posterior (última execução disponível)",
    "",
    paste(capture.output(print(summary_tbl)), collapse = "\n"),
    "",
    "## Notas",
    ""
  )

  run_note <- if (full_run) {
    "- Execução completa realizada (`STAN_EFORENSICS_FULL=1`)."
  } else {
    "- Apenas smoke test executado por default. Rode com `STAN_EFORENSICS_FULL=1` para a calibração completa."
  }

  body <- c(
    run_note,
    paste0("- ", notes),
    paste0("- ", diagnostic_notes)
  )
  writeLines(c(header, timing_lines, body), PATH_STAN_LOG, useBytes = TRUE)
}

dataset <- build_brasilia_data()

log_section("Phase 2 -- compilacao do modelo Stan")
compiled <- timeit("Stan compile", quote({
  cmdstanr::cmdstan_model(
    stan_file = PATH_STAN_MODEL,
    compile = TRUE,
    force_recompile = TRUE,
    quiet = FALSE
  )
}))
mod <- compiled$result

smoke_chains <- 4L
smoke_warmup <- 50L
smoke_sampling <- 100L
full_chains <- 4L
full_warmup <- 2000L
full_sampling <- 5000L

core_variables <- c(
  "pi_1", "pi_2", "pi_3",
  "tau", "nu", "iota_m", "iota_s", "chi_m", "chi_s",
  "Ft", "Fw", "stolen_votes"
)

timing_log <- data.table::data.table(
  phase = character(),
  n_obs = integer(),
  n_chains = integer(),
  warmup = integer(),
  sampling_iter = integer(),
  total_iter = integer(),
  wall_seconds = numeric(),
  per_iter_ms = numeric(),
  per_iter_per_obs_us = numeric(),
  ess_bulk_min = numeric(),
  ess_tail_min = numeric(),
  rhat_max = numeric(),
  divergent_transitions = integer(),
  max_treedepth_hits = integer()
)

run_sampling <- function(model, data_list, chains, warmup, sampling, phase_label) {
  tag <- paste0(
    phase_label, "_",
    format(Sys.time(), "%Y%m%d_%H%M%S")
  )
  output_dir <- fs::path(PATH_CMDSTAN_OUTPUT, tag)
  fs::dir_create(output_dir)

  fit_timed <- timeit(phase_label, quote({
    model$sample(
      data = data_list,
      seed = 20260410,
      init = 0,
      chains = chains,
      parallel_chains = chains,
      iter_warmup = warmup,
      iter_sampling = sampling,
      adapt_delta = 0.99,
      max_treedepth = 15,
      refresh = 100,
      output_dir = output_dir,
      save_warmup = FALSE
    )
  }))

  fit <- fit_timed$result
  summary_tbl <- build_summary_table(fit, core_variables)
  divs <- sampler_divergences(fit)
  treedepth_hits <- sampler_treedepth_hits(fit, max_treedepth = 15L)
  total_iter <- warmup + sampling

  timing_row <- data.table::data.table(
    phase = phase_label,
    n_obs = dataset$stan_data$n_obs,
    n_chains = chains,
    warmup = warmup,
    sampling_iter = sampling,
    total_iter = total_iter,
    wall_seconds = fit_timed$seconds,
    per_iter_ms = 1000 * fit_timed$seconds / total_iter,
    per_iter_per_obs_us = 1e6 * fit_timed$seconds / (total_iter * dataset$stan_data$n_obs),
    ess_bulk_min = min(summary_tbl$ess_bulk, na.rm = TRUE),
    ess_tail_min = min(summary_tbl$ess_tail, na.rm = TRUE),
    rhat_max = max(summary_tbl$rhat, na.rm = TRUE),
    divergent_transitions = divs,
    max_treedepth_hits = treedepth_hits
  )

  list(fit = fit, summary = summary_tbl, timing = timing_row)
}

log_section("Phase 3 -- smoke test")
smoke <- run_sampling(
  model = mod,
  data_list = dataset$stan_data,
  chains = smoke_chains,
  warmup = smoke_warmup,
  sampling = smoke_sampling,
  phase_label = "smoke_brasilia"
)
timing_log <- data.table::rbindlist(list(timing_log, smoke$timing), use.names = TRUE, fill = TRUE)

full_run <- Sys.getenv("STAN_EFORENSICS_FULL", "0") == "1"
latest_fit <- smoke$fit
latest_summary <- smoke$summary
notes <- "Smoke test concluído com o modelo Stan legado simplificado."

if (full_run) {
  log_section("Phase 4 -- calibracao completa")
  full <- run_sampling(
    model = mod,
    data_list = dataset$stan_data,
    chains = full_chains,
    warmup = full_warmup,
    sampling = full_sampling,
    phase_label = "full_brasilia"
  )

  latest_fit <- full$fit
  latest_summary <- full$summary
  timing_log <- data.table::rbindlist(list(timing_log, full$timing), use.names = TRUE, fill = TRUE)
  saveRDS(latest_fit, PATH_STAN_FIT)
  notes <- paste(
    "Calibração completa concluída.",
    "O objeto `CmdStanMCMC` foi salvo em `data/processed/stan_eforensics_brasilia_fit.rds`."
  )
}

data.table::fwrite(timing_log, PATH_STAN_TIMINGS)
write_log(
  dataset = dataset,
  timing_tbl = timing_log,
  summary_tbl = latest_summary,
  full_run = full_run,
  compile_seconds = compiled$seconds,
  notes = notes
)

path_out <- PATH_STAN_TIMINGS
path_log <- PATH_STAN_LOG
log_step("Timings salvos em {path_out}", path_out = path_out)
log_step("Log salvo em {path_log}", path_log = path_log)
if (full_run) {
  path_fit <- PATH_STAN_FIT
  log_step("Fit completo salvo em {path_fit}", path_fit = path_fit)
}

log_section("Fim do script Stan")
