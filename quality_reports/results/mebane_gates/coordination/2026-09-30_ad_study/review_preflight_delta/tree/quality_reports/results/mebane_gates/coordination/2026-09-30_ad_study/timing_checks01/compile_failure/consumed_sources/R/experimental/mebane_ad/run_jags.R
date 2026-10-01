# One bounded model run. The paired supervisor must enforce the reviewed release.
source("R/experimental/mebane_ad/io.R")
ad_setup()
source("R/experimental/mebane_ad/prepare_dc2010.R")

ad_blocks <- c("tau", "nu", "iota.m", "iota.s", "chi.m", "chi.s")
ad_h_names <- c("th", "nh", "imh", "ish", "cmh", "csh")
ad_v_names <- c("tb", "nb", "imb", "isb", "cmb", "csb")

ad_check_payload <- function(payload, contract) {
  stopifnot(ad_sha(contract$case$source) == contract$case$sha256,
            ad_sha(contract$A$source) == contract$A$sha256,
            ad_sha(contract$A$specification_contract) == contract$A$specification_sha256)
  raw <- load_dc2010(contract$case$source)
  expected <- build_dc2010_data(validate_dc2010(raw, contract$case$rows))
  if (!identical(payload, expected)) stop("Outgoing data differ from the frozen author input")
  invisible(TRUE)
}

ad_model_data <- function(model, payload) {
  stopifnot(model %in% c("A", "D"))
  payload[[model]]
}

ad_initial_values <- function(model, payload, contract) {
  N <- payload$A$N
  turnout <- sum(N - payload$A$a) / sum(N)
  share <- sum(payload$A$w) / sum(N - payload$A$a)
  stopifnot(turnout > 0, turnout < 1, share > 0, share < 1)
  offsets <- c(-0.4, -0.1, 0.1, 0.4)
  magnitudes <- c(-1, 0, 1, -0.5)
  variances <- c(0.1, 0.2, 0.3, 0.4)
  lapply(seq_len(contract$paired_design$chains), function(chain) {
    alpha <- c(qlogis(turnout) + offsets[chain],
               qlogis(share) - offsets[chain], rep(magnitudes[chain], 4))
    init <- list("pi.aux1" = 0.8, "pi.aux2" = 0.2, "pi.aux3" = 0.1,
                 Z = rep(1L, length(N)),
                 .RNG.name = contract$paired_design$RNG_name,
                 .RNG.seed = as.integer(contract$paired_design$chain_seeds[chain]))
    for (b in seq_along(ad_blocks)) {
      init[[paste0(ad_blocks[b], ".alpha")]] <- alpha[b]
      init[[paste0("beta.", ad_blocks[b], "1")]] <- if (model == "A") c(0) else 0
      init[[ad_h_names[b]]] <- rep(alpha[b], length(N))
      init[[ad_v_names[b]]] <- variances[chain]
    }
    if (model == "A") {
      mu <- c(rep(0.7 * plogis(magnitudes[chain]), 2),
              rep(0.7 + 0.3 * plogis(magnitudes[chain]), 2))
      for (b in 1:4) init[[paste0("N.", ad_blocks[b + 2])]] <- floor(N * mu[b])
    }
    init
  })
}

ad_monitors <- function(model) {
  c("pi", paste0(ad_blocks, ".alpha"), paste0("beta.", ad_blocks, "1"),
    ad_v_names, paste0("mu.", ad_blocks), "Z", "p.a", "p.w",
    if (model == "A") paste0("N.", ad_blocks[3:6]) else "p.o")
}

ad_jags_engine <- function() {
  for (package in c("rjags", "coda")) {
    if (!requireNamespace(package, quietly = TRUE)) stop("Missing existing package: ", package)
  }
  list(version = as.character(rjags::jags.version()),
       package_version = as.character(utils::packageVersion("rjags")),
       modules = rjags::list.modules(), compile = rjags::jags.model,
       adapt = rjags::adapt, burn = stats::update, sample = rjags::coda.samples)
}

ad_run_jags <- function(model, contract_path, data_path, out) {
  start <- proc.time()[["elapsed"]]
  ad_new_dir(out)
  stage <- "setup"
  warnings <- list()
  phases <- list()
  event <- function(type, value) {
    item <- list(utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
                 model = model, stage = stage, type = type, value = value)
    cat(jsonlite::toJSON(item, auto_unbox = TRUE), "\n",
        file = file.path(out, "events.jsonl"), append = TRUE)
    cat(model, stage, type, value, "\n")
    flush.console()
  }
  timed <- function(label, code) {
    stage <<- label
    event("start", label)
    t0 <- proc.time()
    complete <- FALSE
    on.exit({
      dt <- proc.time() - t0
      phases[[label]] <<- c(as.list(dt[c("user.self", "sys.self", "elapsed")]),
                            list(completed = complete))
      event(if (complete) "complete" else "failed_elapsed", unname(dt[["elapsed"]]))
    })
    ans <- force(code)
    complete <- TRUE
    ans
  }
  result <- tryCatch(withCallingHandlers({
    timed("setup", {
      contract <- jsonlite::read_json(contract_path, simplifyVector = TRUE)
      stopifnot(contract$contract_id == "AD-DC2010-v2", model %in% c("A", "D"),
                contract$paired_design$chains == 4L,
                contract$paired_design$post_iterations == 2000L)
      payload <- readRDS(data_path)
      ad_check_payload(payload, contract)
      engine <- ad_jags_engine()
      stopifnot(engine$version == contract$paired_design$JAGS_version_required)
      model_path <- if (model == "A") contract$A$source else
        "models/experimental/mebane_ad/d_multinomial.jags"
      files <- c(contract_path, data_path, contract$case$source,
                 contract$A$specification_contract, model_path,
                 "R/experimental/mebane_ad/io.R", "R/experimental/mebane_ad/prepare_dc2010.R",
                 "R/experimental/mebane_ad/run_jags.R", "R/experimental/mebane_ad/timing.md")
      ad_snapshot(files, file.path(out, "consumed_sources"))
      dat <- ad_model_data(model, payload)
      inits <- ad_initial_values(model, payload, contract)
      saveRDS(dat, file.path(out, "actual_jags_data.rds"))
      saveRDS(inits, file.path(out, "actual_initial_values.rds"))
      ad_json(list(model = model, contract_sha256 = ad_sha(contract_path),
                   model_sha256 = ad_sha(model_path), data_sha256 = ad_sha(data_path),
                   sampling = contract$paired_design, monitored = ad_monitors(model),
                   R = R.version.string, JAGS = engine$version,
                   rjags = engine$package_version, modules = engine$modules,
                   executor_id = "019d795a-acfa-72c2-a210-d55a46c606c2"),
              file.path(out, "sampling_metadata.json"))
    })
    jm <- timed("compile", engine$compile(model_path, data = dat, inits = inits,
                                            n.chains = 4L, n.adapt = 0L, quiet = TRUE))
    adequate <- timed("adapt", engine$adapt(jm, contract$paired_design$adapt_iterations,
                                           end.adaptation = TRUE))
    event("adaptation_adequate", adequate)
    timed("burn", engine$burn(jm, contract$paired_design$burn_iterations,
                                 progress.bar = "none"))
    draws <- timed("sample", engine$sample(jm, ad_monitors(model),
                                                n.iter = contract$paired_design$post_iterations,
                                                thin = 1L, progress.bar = "none"))
    timed("persist_raw", {
      saveRDS(list(model = model, draws = draws, contract_sha256 = ad_sha(contract_path),
                 seeds = contract$paired_design$chain_seeds,
                 adaptation_adequate = adequate, phases = phases),
            file.path(out, "raw_chains.rds"), compress = "gzip")
      saveRDS(jm$state(internal = TRUE), file.path(out, "final_jags_state.rds"))
    })
    list(status = "sampled_not_diagnosed", adaptation_adequate = adequate,
         chains = length(draws), iterations = vapply(draws, nrow, integer(1)),
         raw_sha256 = ad_sha(file.path(out, "raw_chains.rds")))
  }, warning = function(w) {
    warnings[[length(warnings) + 1L]] <<- list(stage = stage, message = conditionMessage(w))
    event("warning", conditionMessage(w))
    invokeRestart("muffleWarning")
  }), error = function(e) {
    event("error", conditionMessage(e))
    list(status = "error", failed_stage = stage, message = conditionMessage(e))
  })
  result$model <- model
  result$warnings <- warnings
  result$phases <- phases
  result$elapsed_seconds <- unname(proc.time()[["elapsed"]] - start)
  result$timing_scope <- paste("Internal generation: function entry through raw persistence/error handling;",
                              "excludes R bootstrap and final result/manifest writes.",
                              "Supervisor measures the whole generation process; diagnostics have a separate clock.")
  result$posterior_or_model_validated <- FALSE
  ad_json(result, file.path(out, "run_result.json"))
  ad_manifest(out, note = "Bounded raw run; independent diagnostics and review pending")
  print(result)
  invisible(result)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 4L) stop("Usage: run_jags.R A|D CONTRACT_JSON DATA_RDS NEW_OUT_DIR")
  result <- ad_run_jags(args[1], args[2], args[3], args[4])
  if (result$status == "error") quit(status = 2L)
}
