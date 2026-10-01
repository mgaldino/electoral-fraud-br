# CLI: prepare REPO OUTPUT; sample PREPARATION QA OUTPUT (through supervisor only).
ad_stan_compile_preparation <- function(repo, out, executor_id, compile_methods = FALSE) {
  stopifnot(nzchar(executor_id), dir.exists(file.path(out, "sources")))
  ad_stan_require_scoped_temp(repo)
  snap <- file.path(out, "sources")
  ad_stan_validate_frozen_inputs(snap)
  records <- jsonlite::read_json(file.path(snap, "sources_manifest.json"))$files
  for (record in records) stopifnot(ad_stan_sha(file.path(snap, record$path)) == record$sha256)
  contract_rel <- "quality_reports/results/mebane_gates/coordination/2026-10-01_ad_long_stan/contract.json"
  data_rel <- "quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/data/run-20260930T235038Z-pid61600/dc2010_ad_data.rds"
  settings <- ad_stan_settings(file.path(snap, contract_rel))
  data <- ad_stan_data(file.path(snap, data_rel))
  ad_stan_json(settings, file.path(out, "settings.json"))
  cmdstanr::write_stan_json(data, file.path(out, "data.json"))
  inits <- ad_stan_inits(data)
  for (i in 1:4) cmdstanr::write_stan_json(inits[[i]], file.path(out, paste0("init_chain", i, ".json")))
  write.csv(ad_stan_name_map(data$n), file.path(out, "name_map.csv"), row.names = FALSE)
  build <- ad_stan_new_dir(file.path(out, "build"))
  compile_start <- Sys.time()
  model <- ad_stan_logged(file.path(out, "compile.log"), {
    cat("executor_id:", executor_id, "\n")
    cat("Stan source SHA256:", ad_stan_sha(file.path(snap, "models/experimental/mebane_ad_stan/d_multinomial.stan")), "\n")
    cmdstanr::cmdstan_model(
      file.path(snap, "models/experimental/mebane_ad_stan/d_multinomial.stan"),
      dir = build, cpp_options = list(PRECOMPILED_HEADERS = FALSE), quiet = FALSE,
      compile_model_methods = compile_methods, compile_standalone = compile_methods)
  })
  compile_seconds <- as.numeric(difftime(Sys.time(), compile_start, units = "secs"))
  files <- c(file.path(out, c("settings.json", "data.json", "name_map.csv", "compile.log")),
             file.path(out, paste0("init_chain", 1:4, ".json")), model$exe_file(),
             file.path(snap, "sources_manifest.json"), file.path(snap, vapply(records, `[[`, "", "path")))
  build_files <- list.files(build, recursive = TRUE, full.names = TRUE)
  files <- unique(c(files, build_files[!dir.exists(build_files)]))
  ad_stan_json(list(executor_id = executor_id, status = "prepared_awaiting_independent_QA",
                    created_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
                    repository_root = normalizePath(repo),
                    executable = model$exe_file(), compile_seconds = compile_seconds,
                    runtime = ad_stan_runtime(), deterministic_methods_compiled = compile_methods,
                    contract_sha256 = ad_stan_sha(file.path(snap, contract_rel)),
                    files = ad_stan_file_records(files),
                    empirical_sampling = FALSE), file.path(out, "manifest.json"))
  invisible(list(path = out, model = model))
}

ad_stan_prepare <- function(repo, out, executor_id = Sys.getenv("CODEX_THREAD_ID")) {
  stopifnot(nzchar(executor_id))
  out <- ad_stan_new_dir(out)
  ad_stan_snapshot(repo, file.path(out, "sources"), executor_id)
  frozen <- new.env(parent = globalenv())
  for (f in c("common.R", "run_stan.R")) {
    sys.source(file.path(out, "sources/R/experimental/mebane_ad_stan", f), envir = frozen)
  }
  ad_stan_json(list(executor_id = executor_id, command = commandArgs(), runtime = ad_stan_runtime(),
                    started_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
                    empirical_sampling = FALSE), file.path(out, "run_started.json"))
  tryCatch(frozen$ad_stan_compile_preparation(repo, out, executor_id), error = function(e) {
    ad_stan_json(list(executor_id = executor_id, error = conditionMessage(e),
                      status = "preparation_failed_artifacts_retained"), file.path(out, "failure.json"))
    stop(e)
  })
}

ad_stan_sample <- function(preparation, qa_path, out) {
  if (Sys.getenv("AD_STAN_SUPERVISED") != "1") stop("Use the external 3600-second supervisor")
  manifest_path <- file.path(preparation, "manifest.json")
  manifest <- jsonlite::read_json(manifest_path, simplifyVector = FALSE)
  executor_id <- Sys.getenv("CODEX_THREAD_ID")
  stopifnot(nzchar(executor_id), identical(manifest$status, "prepared_awaiting_independent_QA"))
  ad_stan_require_qa(qa_path, manifest_path, manifest$executor_id)
  for (f in manifest$files) if (!identical(ad_stan_sha(f$path), f$sha256)) stop("Prepared file changed: ", f$path)
  cfg <- jsonlite::read_json(file.path(preparation, "settings.json"), simplifyVector = TRUE)
  if (!dir.exists(out)) stop("Supervisor must create the output directory")
  expected <- c("draws_array.rds", "sampler_diagnostics.rds", "fit.rds", "timing.json", "chain_timing.csv")
  if (any(file.exists(file.path(out, expected)))) stop("Refusing existing sampling artifacts")
  csv_dir <- ad_stan_new_dir(file.path(out, "csv"))
  model <- cmdstanr::cmdstan_model(exe_file = manifest$executable, compile = FALSE)
  start <- Sys.time()
  fit <- model$sample(
    data = file.path(preparation, "data.json"),
    init = file.path(preparation, paste0("init_chain", 1:4, ".json")),
    chains = cfg$chains, parallel_chains = cfg$parallel_chains, chain_ids = cfg$chain_ids,
    seed = cfg$seed, iter_warmup = cfg$warmup_iterations, iter_sampling = cfg$post_iterations,
    save_warmup = cfg$save_warmup, thin = cfg$thin, adapt_delta = cfg$adapt_delta,
    max_treedepth = cfg$max_treedepth, output_dir = csv_dir, output_basename = "D_Stan",
    sig_figs = 17, save_cmdstan_config = TRUE, save_metric = TRUE,
    refresh = 200, diagnostics = NULL, show_messages = TRUE)
  generation_seconds <- as.numeric(difftime(Sys.time(), start, units = "secs"))
  for (i in 1:4) writeLines(unlist(fit$output(i), use.names = FALSE),
                            file.path(out, paste0("chain", i, ".log")))
  if (any(fit$return_codes() != 0)) stop("At least one chain failed; CSVs and logs retained")
  # Save the lazy fit handle before reading draws, to avoid a second cached copy.
  saveRDS(fit, file.path(out, "fit.rds"))
  draws <- fit$draws(inc_warmup = FALSE, format = "draws_array")
  stopifnot(identical(as.integer(dim(draws)[1:2]), c(2000L, 4L)))
  saveRDS(draws, file.path(out, "draws_array.rds"))
  sampler <- fit$sampler_diagnostics(inc_warmup = FALSE, format = "draws_array")
  saveRDS(sampler, file.path(out, "sampler_diagnostics.rds"))
  times <- fit$time()
  write.csv(times$chains, file.path(out, "chain_timing.csv"), row.names = FALSE)
  ad_stan_json(list(executor_id = executor_id, generation_wall_seconds = generation_seconds,
                    compilation_seconds_separate = manifest$compile_seconds,
                    cmdstan_times = times, parallel_chains = 1L,
                    chain_ids = cfg$chain_ids, warmup_saved_in_CSV = TRUE,
                    raw_shape = dim(draws), sampler_shape = dim(sampler),
                    ncp_variables = grep("^(z\\[|r\\[)", dimnames(draws)[[3]], value = TRUE)),
               file.path(out, "timing.json"))
  artifacts <- list.files(out, recursive = TRUE, full.names = TRUE)
  artifacts <- artifacts[!dir.exists(artifacts) & basename(artifacts) != "console.log"]
  artifacts <- artifacts[!startsWith(artifacts, paste0(out, "/tmp/"))]
  ad_stan_json(list(executor_id = executor_id, status = "sampling_completed_precision_not_assessed",
                    runtime = ad_stan_runtime(),
                    preparation_manifest_sha256 = ad_stan_sha(manifest_path),
                    qa_sha256 = ad_stan_sha(qa_path),
                    artifacts = lapply(artifacts, function(p) list(path = p, sha256 = ad_stan_sha(p))),
                    diagnostics_computed = FALSE), file.path(out, "manifest.json"))
  invisible(out)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  script <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)))
  source(file.path(dirname(script), "common.R"))
  if (length(args) == 3L && args[1] == "prepare") {
    ad_stan_setup(args[2])
    ad_stan_prepare(normalizePath(args[2]), args[3])
  } else if (length(args) == 4L && args[1] == "sample") {
    ad_stan_setup(getwd())
    ad_stan_sample(normalizePath(args[2]), normalizePath(args[3]), normalizePath(args[4]))
  } else stop("Usage: run_stan.R prepare REPO OUTPUT | sample PREPARATION QA OUTPUT")
}
