ad_stan_setup <- function(repo) {
  lib <- file.path(repo, "renv/library/macos/R-4.4/aarch64-apple-darwin20")
  if (dir.exists(lib)) .libPaths(c(lib, .libPaths()))
  for (p in c("cmdstanr", "jsonlite", "digest", "posterior", "processx")) {
    if (!requireNamespace(p, quietly = TRUE)) stop("Existing package unavailable: ", p)
  }
  if (as.character(cmdstanr::cmdstan_version()) != "2.37.0") stop("Expected CmdStan 2.37.0")
}

ad_stan_sha <- function(path) digest::digest(file = path, algo = "sha256", serialize = FALSE)

ad_stan_new_dir <- function(path) {
  if (file.exists(path) || dir.exists(path)) stop("Refusing existing output: ", path)
  if (!dir.create(path, recursive = TRUE)) stop("Cannot create output: ", path)
  normalizePath(path)
}

ad_stan_json <- function(x, path) {
  if (file.exists(path)) stop("Refusing overwrite: ", path)
  jsonlite::write_json(x, path, auto_unbox = TRUE, pretty = TRUE, digits = NA,
                       null = "null", na = "null")
}

ad_stan_source_paths <- function() {
  c("R/experimental/mebane_ad_stan/common.R",
    "R/experimental/mebane_ad_stan/reference.R",
    "R/experimental/mebane_ad_stan/run_stan.R",
    "R/experimental/mebane_ad_stan/prepare_stan.py",
    "R/experimental/mebane_ad_stan/supervise_stan.py",
    "models/experimental/mebane_ad_stan/d_multinomial.stan",
    "tests/mebane/ad_stan/test_stan.R",
    "tests/mebane/ad_stan/test_supervisor.py",
    "tests/mebane/ad_stan/run_preflight.R",
    "quality_reports/results/mebane_gates/coordination/2026-10-01_ad_long_stan/stan_impl/IMPLEMENTATION.md",
    "models/experimental/mebane_ad/d_multinomial.jags",
    "R/experimental/mebane_ad/model_d.R",
    "quality_reports/results/mebane_gates/coordination/2026-10-01_ad_long_stan/contract.json",
    "quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/final_manifest.json",
    "quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/data/run-20260930T235038Z-pid61600/dc2010_ad_data.rds")
}

ad_stan_snapshot <- function(repo, out, executor_id) {
  ad_stan_new_dir(out)
  records <- lapply(ad_stan_source_paths(), function(rel) {
    src <- file.path(repo, rel)
    dst <- file.path(out, rel)
    hash <- ad_stan_sha(src)
    dir.create(dirname(dst), recursive = TRUE, showWarnings = FALSE)
    if (!file.copy(src, dst, overwrite = FALSE)) stop("Snapshot copy failed: ", rel)
    stopifnot(identical(hash, ad_stan_sha(dst)), identical(hash, ad_stan_sha(src)))
    list(path = rel, sha256 = hash, bytes = unname(file.info(dst)$size))
  })
  ad_stan_json(list(executor_id = executor_id, created_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
                    files = records), file.path(out, "sources_manifest.json"))
  records
}

ad_stan_settings <- function(contract) {
  expected <- "fb4a296c9bf0af25812d7d8dd2ab63340fe10d4e73e806e64b5dba3f7dcf481a"
  if (ad_stan_sha(contract) != expected) stop("LONG contract hash mismatch")
  cfg <- jsonlite::read_json(contract, simplifyVector = TRUE)$stan_design
  stopifnot(cfg$chains == 4, cfg$parallel_chains == 1, cfg$warmup_iterations == 2000,
            cfg$post_iterations == 2000, cfg$seed == 1001261, cfg$adapt_delta == 0.99,
            cfg$max_treedepth == 12, cfg$max_elapsed_seconds == 3600, cfg$thin == 1,
            identical(as.integer(cfg$chain_ids), 1:4), isTRUE(cfg$save_warmup))
  cfg
}

ad_stan_data <- function(path) {
  if (ad_stan_sha(path) != "b2ef611dabb751f9286acbaae841a23c34948ed0a4b6306364cbe94d9d24903e") {
    stop("Prepared D.C. data hash mismatch")
  }
  x <- readRDS(path)
  stopifnot(x$D$n == 143L, is.integer(x$D$N), is.integer(x$D$observed),
            identical(colnames(x$D$observed), c("A", "W", "O")),
            all(rowSums(x$D$observed) == x$D$N), !anyNA(x$D$observed),
            all(x$D$observed >= 0), all(x$D$N >= 1),
            identical(unname(x$D$observed[, 1]), x$A$a),
            identical(unname(x$D$observed[, 2]), x$A$w))
  list(n = x$D$n, N = unname(x$D$N), observed = unname(x$D$observed))
}

ad_stan_inits <- function(data) {
  tau <- sum(data$N - data$observed[, 1]) / sum(data$N)
  nu <- sum(data$observed[, 2]) / sum(data$N - data$observed[, 1])
  lapply(1:4, function(chain) {
    list(alpha = c(qlogis(tau) + c(-0.4, -0.1, 0.1, 0.4)[chain],
                   qlogis(nu) + c(0.4, 0.1, -0.1, -0.4)[chain],
                   rep(c(-1, 0, 1, -0.5)[chain], 4)),
         b0 = rep(0, 6), v = rep(c(0.1, 0.2, 0.3, 0.4)[chain], 6),
         z = matrix(0, data$n, 6), r = c(0.25, 0.125))
  })
}

ad_stan_name_map <- function(n) {
  blocks <- c("tau", "nu", "iota.m", "iota.s", "chi.m", "chi.s")
  result <- data.frame(stan = c(sprintf("alpha[%d]", 1:6), sprintf("b0[%d]", 1:6),
                                sprintf("v[%d]", 1:6)),
                       jags = c(paste0(blocks, ".alpha"), paste0("beta.", blocks, "1"),
                                c("tb", "nb", "imb", "isb", "cmb", "csb")))
  for (j in 1:6) result <- rbind(result, data.frame(stan = sprintf("mu[%d,%d]", 1:n, j),
                                                   jags = sprintf("mu.%s[%d]", blocks[j], 1:n)))
  for (pair in list(c("pA", "p.a"), c("pW", "p.w"), c("pO", "p.o"), c("Z", "Z"))) {
    result <- rbind(result, data.frame(stan = sprintf("%s[%d]", pair[1], 1:n),
                                       jags = sprintf("%s[%d]", pair[2], 1:n)))
  }
  rbind(result, data.frame(stan = sprintf("pi[%d]", 1:3), jags = sprintf("pi[%d]", 1:3)))
}

ad_stan_require_qa <- function(qa_path, preparation_manifest, executor_id) {
  qa <- jsonlite::read_json(qa_path, simplifyVector = TRUE)
  if (!identical(qa$status, "PASS") || is.null(qa$reviewer_id) ||
      length(qa$reviewer_id) != 1L || !nzchar(qa$reviewer_id) ||
      identical(qa$reviewer_id, executor_id) ||
      !identical(qa$preparation_manifest_sha256, ad_stan_sha(preparation_manifest))) {
    stop("Independent PASS bound to this preparation manifest is required")
  }
  invisible(qa)
}

ad_stan_logged <- function(path, expr) {
  if (file.exists(path)) stop("Refusing existing log: ", path)
  con <- file(path, open = "wt", encoding = "UTF-8")
  sink(con, split = TRUE)
  sink(con, type = "message")
  old <- options(warn = 1)
  on.exit({
    options(old)
    sink(type = "message")
    sink()
    close(con)
  }, add = TRUE)
  eval(substitute(expr), envir = parent.frame())
}

ad_stan_file_records <- function(paths) {
  lapply(paths, function(p) list(path = normalizePath(p, mustWork = TRUE),
                               sha256 = ad_stan_sha(p), bytes = unname(file.info(p)$size)))
}

ad_stan_runtime <- function() {
  packages <- c("cmdstanr", "posterior", "jsonlite", "digest", "processx", "rstan")
  list(R = R.version.string, platform = R.version$platform,
       cmdstan_version = as.character(cmdstanr::cmdstan_version()),
       cmdstan_path = cmdstanr::cmdstan_path(),
       packages = as.list(setNames(vapply(packages, function(p) {
         as.character(utils::packageVersion(p))
       }, character(1)), packages)), library_paths = .libPaths())
}

ad_stan_validate_frozen_inputs <- function(sources) {
  paths <- c("models/experimental/mebane_ad/d_multinomial.jags",
             "R/experimental/mebane_ad/model_d.R",
             "quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/final_manifest.json")
  hashes <- c("6ddb9624f60b15e196cc27ed9694852c40b6553a684a9962003168da4ecfaf5b",
              "e5154c01c6f111cc47d5e9d9f49654f1ee081bb4001664038c840b8c0d86710a",
              "6720193e76b60e2b7d4c73910b2e4328b7cc2fb882b6e29f095160a8dce50db3")
  for (i in seq_along(paths)) {
    if (ad_stan_sha(file.path(sources, paths[i])) != hashes[i]) stop("Frozen reference mismatch: ", paths[i])
  }
  invisible(TRUE)
}

ad_stan_require_scoped_temp <- function(repo) {
  scope <- normalizePath(file.path(repo, "quality_reports/results/mebane_gates/coordination/2026-10-01_ad_long_stan/stan_impl"))
  if (!startsWith(normalizePath(tempdir()), paste0(scope, "/"))) {
    stop("Use prepare_stan.py: compiler temporaries must stay inside stan_impl")
  }
}

ad_stan_seal <- function(out, payload, filename = "preflight_manifest.json") {
  paths <- sort(list.files(out, full.names = TRUE, recursive = TRUE, all.files = TRUE,
                           no.. = TRUE))
  paths <- paths[!dir.exists(paths)]
  payload$files <- ad_stan_file_records(paths)
  ad_stan_json(payload, file.path(out, filename))
  paths <- c(paths, file.path(out, filename))
  checksum <- file.path(out, "SHA256SUMS")
  if (file.exists(checksum)) stop("Refusing existing checksum inventory")
  relative <- substring(paths, nchar(normalizePath(out)) + 2L)
  writeLines(paste(vapply(paths, ad_stan_sha, character(1)), relative, sep = "  "), checksum)
  invisible(payload)
}
