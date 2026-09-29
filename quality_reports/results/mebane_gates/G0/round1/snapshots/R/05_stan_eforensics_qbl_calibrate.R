# R/05_stan_eforensics_qbl_calibrate.R -- Stan approximation to UMeforensics qbl()
#
# Objective:
#   1. Build the Brasilia 2022 round-2 section-level dataset used in the JAGS qbl run
#   2. Fit a Stan approximation to the canonical qbl() target
#   3. Record timings, diagnostics, and substantive summaries
#
# Important:
#   The JAGS qbl() model contains latent binomial count nodes for iota/chi.
#   This Stan implementation preserves the ordered prior on pi and the full
#   hierarchical random-effect structure, but replaces those latent count nodes
#   with continuous fraud magnitudes on the logistic scale.
#   In the intercept-only case, the redundant pi.aux1 scale and the ultra-tight
#   fixed intercept terms are collapsed to improve HMC geometry.

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

read_env_int <- function(name, default) {
  value <- Sys.getenv(name, "")
  if (!nzchar(value)) {
    return(as.integer(default))
  }
  as.integer(value)
}

read_env_num <- function(name, default) {
  value <- Sys.getenv(name, "")
  if (!nzchar(value)) {
    return(as.numeric(default))
  }
  as.numeric(value)
}

ensure_namespace("cmdstanr")
ensure_namespace("posterior")

suppressPackageStartupMessages({
  library(cmdstanr)
  library(posterior)
})

log_section("Bloco 5B -- Stan qbl hierárquico aproximado")

run_label <- Sys.getenv("STAN_EFORENSICS_QBL_LABEL", "")
run_suffix <- if (nzchar(run_label)) paste0("_", run_label) else ""

PATH_STAN_DIR <- here::here("stan")
PATH_STAN_MODEL <- here::here("stan", "eforensics_qbl.stan")
PATH_CMDSTAN_OUTPUT <- here::here("data", "processed", "cmdstanr_outputs")
PATH_STAN_FIT <- here::here("data", "processed", paste0("stan_eforensics_qbl_brasilia_fit", run_suffix, ".rds"))
PATH_STAN_TIMINGS <- here::here("quality_reports", "results", paste0("05_stan_qbl_brasilia_timings", run_suffix, ".csv"))
PATH_STAN_LOG <- here::here("quality_reports", "results", paste0("05_stan_qbl_brasilia_log", run_suffix, ".md"))

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
  log_section("Phase 1 -- Brasília T2 dataset")

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

  stopifnot(nrow(bsb) == 6748L)
  stopifnot(all(bsb$N > 0L))
  stopifnot(all(bsb$a >= 0L))
  stopifnot(all(bsb$w >= 0L))
  stopifnot(all(bsb$w <= bsb$N))
  stopifnot(all(bsb$a <= bsb$N))

  n_sec <- nrow(bsb)
  n_total <- sum(bsb$N)
  a_total <- sum(bsb$a)
  w_total <- sum(bsb$w)

  log_step("Brasília T2 wide: {n_sec} seções", n_sec = n_sec)
  log_step("Aptos totais: {n_total}", n_total = n_total)
  log_step("Abstenções totais: {a_total}", a_total = a_total)
  log_step("Votos do leader totais: {w_total}", w_total = w_total)

  zone_fe <- Sys.getenv("STAN_EFORENSICS_QBL_ZONE_FE", "0") == "1"

  if (zone_fe) {
    bsb[, zona_f := factor(NR_ZONA)]
    X_zona <- model.matrix(~ zona_f, data = bsb)[, -1, drop = FALSE]
    p_fraud <- ncol(X_zona)
    ref_zona <- levels(bsb$zona_f)[1]
    log_step("Zone FE ativo: {p_fraud} dummies de zona (ref = zona {ref_zona})",
             p_fraud = p_fraud, ref_zona = ref_zona)
  } else {
    X_zona <- matrix(0, nrow = nrow(bsb), ncol = 0)
    p_fraud <- 0L
  }

  X_empty <- matrix(0, nrow = nrow(bsb), ncol = 0)

  list(
    dt = bsb,
    zone_fe = zone_fe,
    p_fraud = p_fraud,
    stan_data = list(
      n_obs = nrow(bsb),
      N = as.integer(bsb$N),
      a = as.integer(bsb$a),
      w = as.integer(bsb$w),
      k = 0.7,
      p_tau = 0L,
      p_nu = 0L,
      p_iota_m = as.integer(p_fraud),
      p_iota_s = as.integer(p_fraud),
      p_chi_m = as.integer(p_fraud),
      p_chi_s = as.integer(p_fraud),
      X_tau = X_empty,
      X_nu = X_empty,
      X_iota_m = X_zona,
      X_iota_s = X_zona,
      X_chi_m = X_zona,
      X_chi_s = X_zona
    )
  )
}

subset_dataset <- function(dataset, n_keep) {
  if (n_keep >= dataset$stan_data$n_obs) {
    return(dataset)
  }

  idx <- seq_len(n_keep)
  sd <- dataset$stan_data
  list(
    dt = dataset$dt[idx],
    zone_fe = dataset$zone_fe,
    p_fraud = dataset$p_fraud,
    stan_data = list(
      n_obs = n_keep,
      N = sd$N[idx],
      a = sd$a[idx],
      w = sd$w[idx],
      k = sd$k,
      p_tau = sd$p_tau,
      p_nu = sd$p_nu,
      p_iota_m = sd$p_iota_m,
      p_iota_s = sd$p_iota_s,
      p_chi_m = sd$p_chi_m,
      p_chi_s = sd$p_chi_s,
      X_tau = sd$X_tau[idx, , drop = FALSE],
      X_nu = sd$X_nu[idx, , drop = FALSE],
      X_iota_m = sd$X_iota_m[idx, , drop = FALSE],
      X_iota_s = sd$X_iota_s[idx, , drop = FALSE],
      X_chi_m = sd$X_chi_m[idx, , drop = FALSE],
      X_chi_s = sd$X_chi_s[idx, , drop = FALSE]
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

finite_min_or_na <- function(x) {
  finite_x <- x[is.finite(x)]
  if (length(finite_x) == 0L) {
    return(NA_real_)
  }
  min(finite_x)
}

finite_max_or_na <- function(x) {
  finite_x <- x[is.finite(x)]
  if (length(finite_x) == 0L) {
    return(NA_real_)
  }
  max(finite_x)
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

write_log <- function(dataset_used, timing_tbl, summary_tbl, full_run, compile_seconds, notes) {
  latest_timing <- timing_tbl[.N]

  header <- c(
    "# Bloco 5B -- log da calibração Stan qbl",
    "",
    paste0("Data/hora: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %z")),
    paste0("R: ", getRversion()),
    paste0("CmdStanR: ", as.character(utils::packageVersion("cmdstanr"))),
    paste0("CmdStan: ", cmdstanr::cmdstan_version()),
    "",
    "## Alvo do modelo",
    "",
    "- Modelo: aproximação Stan do `qbl()` canônico do `UMeforensics`.",
    "- Mantido: prior ordenado de `pi`, seis blocos hierárquicos e `k = 0.7`.",
    "- Relaxação: as contagens binomiais latentes `N.iota.*` e `N.chi.*` do JAGS foram substituídas por magnitudes contínuas na escala logística.",
    "- Reparametrização: no caso intercept-only, `pi.aux1` foi marginalizado e os interceptos fixos ultra-concentrados foram colapsados nas localizações `alpha`.",
    paste0("- Tempo de compilação Stan: `", sprintf("%.2f", compile_seconds), " s`."),
    "",
    "## Dataset usado na última execução",
    "",
    paste0("- Seções: ", dataset_used$stan_data$n_obs),
    paste0("- Aptos totais: ", sum(dataset_used$dt$N)),
    paste0("- Abstenções totais: ", sum(dataset_used$dt$a)),
    paste0("- Votos do leader totais: ", sum(dataset_used$dt$w)),
    paste0("- Zone FE: ", if (isTRUE(dataset_used$zone_fe)) paste0("ativo (", dataset_used$p_fraud, " dummies)") else "desativado"),
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
    "- Execução completa realizada (`STAN_EFORENSICS_QBL_FULL=1`)."
  } else {
    "- Apenas smoke test executado por default. Rode com `STAN_EFORENSICS_QBL_FULL=1` para a calibração completa."
  }

  diag_notes <- c(
    if (isTRUE(latest_timing$rhat_max[[1]] > 1.01)) {
      paste0("Diagnóstico: `rhat_max = ", sprintf("%.3f", latest_timing$rhat_max[[1]]), "` ainda está alto.")
    },
    if (isTRUE(latest_timing$ess_bulk_min[[1]] < 100)) {
      paste0("Diagnóstico: `ESS_bulk_min = ", sprintf("%.1f", latest_timing$ess_bulk_min[[1]]), "` ainda é baixo.")
    },
    if (isTRUE(latest_timing$divergent_transitions[[1]] > 0)) {
      paste0("Diagnóstico: houve ", latest_timing$divergent_transitions[[1]], " transições divergentes.")
    },
    if (isTRUE(latest_timing$max_treedepth_hits[[1]] > 0)) {
      paste0("Diagnóstico: houve ", latest_timing$max_treedepth_hits[[1]], " hits de `max_treedepth`.")
    }
  )

  body <- c(run_note, paste0("- ", notes), paste0("- ", diag_notes))
  writeLines(c(header, timing_lines, body), PATH_STAN_LOG, useBytes = TRUE)
}

dataset_full <- build_brasilia_data()
smoke_n <- read_env_int("STAN_EFORENSICS_QBL_SMOKE_N", dataset_full$stan_data$n_obs)
dataset_smoke <- subset_dataset(dataset_full, smoke_n)

log_section("Phase 2 -- compilação do modelo Stan")
compiled <- timeit("Stan compile", quote({
  cmdstanr::cmdstan_model(
    stan_file = PATH_STAN_MODEL,
    compile = TRUE,
    force_recompile = FALSE,
    quiet = FALSE
  )
}))
mod <- compiled$result

smoke_chains <- read_env_int("STAN_EFORENSICS_QBL_SMOKE_CHAINS", 2L)
smoke_warmup <- read_env_int("STAN_EFORENSICS_QBL_SMOKE_WARMUP", 25L)
smoke_sampling <- read_env_int("STAN_EFORENSICS_QBL_SMOKE_SAMPLING", 25L)
full_chains <- 4L
full_warmup <- 2000L
full_sampling <- 5000L
adapt_delta <- read_env_num("STAN_EFORENSICS_QBL_ADAPT_DELTA", 0.99)
max_treedepth <- read_env_int("STAN_EFORENSICS_QBL_MAX_TREEDEPTH", 12L)

core_variables <- c(
  "pi_1", "pi_2", "pi_3",
  "tau_alpha", "nu_alpha", "iota_m_alpha", "iota_s_alpha", "chi_m_alpha", "chi_s_alpha",
  "sigma_tau", "sigma_nu", "sigma_iota_m", "sigma_iota_s", "sigma_chi_m", "sigma_chi_s",
  "Ft", "Fw", "stolen_votes"
)
if (dataset_full$p_fraud > 0L) {
  p <- dataset_full$p_fraud
  beta_vars <- unlist(lapply(
    c("beta_iota_m", "beta_iota_s", "beta_chi_m", "beta_chi_s"),
    function(nm) paste0(nm, "[", seq_len(p), "]")
  ))
  core_variables <- c(core_variables, beta_vars)
}

timing_log <- data.table::data.table(
  phase = character(),
  model = character(),
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

run_sampling <- function(model, dataset_obj, chains, warmup, sampling, phase_label) {
  tag <- paste0(phase_label, "_", format(Sys.time(), "%Y%m%d_%H%M%S"))
  output_dir <- fs::path(PATH_CMDSTAN_OUTPUT, tag)
  fs::dir_create(output_dir)

  sd <- dataset_obj$stan_data
  init_fun <- function(chain_id) {
    offset <- (chain_id - 1) * 0.02
    inits <- list(
      pi_aux2_raw = 0.10 + offset,
      pi_aux3_raw = 0.05 + offset,
      tau_alpha = 1.0 + offset,
      nu_alpha = 0.0 - offset,
      iota_m_alpha = -2.0 + offset,
      iota_s_alpha = -1.5 + offset,
      chi_m_alpha = -0.25 + offset,
      chi_s_alpha = -0.25 - offset,
      tb = 0.10,
      nb = 0.10,
      imb = 0.05,
      isb = 0.05,
      cmb = 0.05,
      csb = 0.05,
      z_th = rep(0, sd$n_obs),
      z_nh = rep(0, sd$n_obs),
      z_imh = rep(0, sd$n_obs),
      z_ish = rep(0, sd$n_obs),
      z_cmh = rep(0, sd$n_obs),
      z_csh = rep(0, sd$n_obs),
      beta_tau = rep(0, sd$p_tau),
      beta_nu = rep(0, sd$p_nu),
      beta_iota_m = rep(0, sd$p_iota_m),
      beta_iota_s = rep(0, sd$p_iota_s),
      beta_chi_m = rep(0, sd$p_chi_m),
      beta_chi_s = rep(0, sd$p_chi_s)
    )
    inits
  }

  fit_timed <- timeit(phase_label, quote({
    model$sample(
      data = dataset_obj$stan_data,
      seed = 20260411,
      init = init_fun,
      chains = chains,
      parallel_chains = chains,
      iter_warmup = warmup,
      iter_sampling = sampling,
      adapt_delta = adapt_delta,
      max_treedepth = max_treedepth,
      refresh = max(1, floor((warmup + sampling) / 5)),
      output_dir = output_dir,
      save_warmup = FALSE
    )
  }))

  fit <- fit_timed$result
  summary_tbl <- build_summary_table(fit, core_variables)
  divs <- sampler_divergences(fit)
  treedepth_hits <- sampler_treedepth_hits(fit, max_treedepth = max_treedepth)
  total_iter <- warmup + sampling

  timing_row <- data.table::data.table(
    phase = phase_label,
    model = "qbl_stan_relaxed_reparam",
    n_obs = dataset_obj$stan_data$n_obs,
    n_chains = chains,
    warmup = warmup,
    sampling_iter = sampling,
    total_iter = total_iter,
    wall_seconds = fit_timed$seconds,
    per_iter_ms = 1000 * fit_timed$seconds / total_iter,
    per_iter_per_obs_us = 1e6 * fit_timed$seconds / (total_iter * dataset_obj$stan_data$n_obs),
    ess_bulk_min = finite_min_or_na(summary_tbl$ess_bulk),
    ess_tail_min = finite_min_or_na(summary_tbl$ess_tail),
    rhat_max = finite_max_or_na(summary_tbl$rhat),
    divergent_transitions = divs,
    max_treedepth_hits = treedepth_hits
  )

  list(fit = fit, summary = summary_tbl, timing = timing_row)
}

log_section("Phase 3 -- smoke test")
smoke_n_obs <- dataset_smoke$stan_data$n_obs
log_step("Smoke test em {smoke_n_obs} seções", smoke_n_obs = smoke_n_obs)
smoke <- run_sampling(
  model = mod,
  dataset_obj = dataset_smoke,
  chains = smoke_chains,
  warmup = smoke_warmup,
  sampling = smoke_sampling,
  phase_label = "smoke_brasilia_qbl"
)
timing_log <- data.table::rbindlist(list(timing_log, smoke$timing), use.names = TRUE, fill = TRUE)

full_run <- Sys.getenv("STAN_EFORENSICS_QBL_FULL", "0") == "1"
latest_fit <- smoke$fit
latest_summary <- smoke$summary
latest_dataset <- dataset_smoke
notes <- paste(
  "Smoke test concluído com a aproximação hierárquica Stan do qbl.",
  "As contagens latentes binomiais do JAGS foram relaxadas para magnitudes contínuas.",
  "A parametrização intercept-only também colapsa dimensões redundantes de mistura e intercepto para melhorar a geometria do HMC."
)

if (full_run) {
  log_section("Phase 4 -- calibração completa")
  full <- run_sampling(
    model = mod,
    dataset_obj = dataset_full,
    chains = full_chains,
    warmup = full_warmup,
    sampling = full_sampling,
    phase_label = "full_brasilia_qbl"
  )

  latest_fit <- full$fit
  latest_summary <- full$summary
  latest_dataset <- dataset_full
  timing_log <- data.table::rbindlist(list(timing_log, full$timing), use.names = TRUE, fill = TRUE)
  saveRDS(latest_fit, PATH_STAN_FIT)
  notes <- paste(
    "Calibração completa concluída com a aproximação hierárquica Stan do qbl.",
    "A parametrização intercept-only colapsa dimensões redundantes de mistura e intercepto para melhorar a geometria do HMC.",
    "O objeto `CmdStanMCMC` foi salvo em `data/processed/stan_eforensics_qbl_brasilia_fit.rds`."
  )
}

data.table::fwrite(timing_log, PATH_STAN_TIMINGS)
write_log(
  dataset_used = latest_dataset,
  timing_tbl = timing_log,
  summary_tbl = latest_summary,
  full_run = full_run,
  compile_seconds = compiled$seconds,
  notes = notes
)

path_timings <- PATH_STAN_TIMINGS
path_log <- PATH_STAN_LOG
log_step("Timings salvos em {path_timings}", path_timings = path_timings)
log_step("Log salvo em {path_log}", path_log = path_log)
if (full_run) {
  path_fit <- PATH_STAN_FIT
  log_step("Fit completo salvo em {path_fit}", path_fit = path_fit)
}

log_section("Fim do script Stan qbl")
