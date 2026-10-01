# Exercise production phase/error instrumentation with a fake engine, never MCMC.
source("R/experimental/mebane_ad_long/run_jags.R")
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 3L)
contract_path <- args[1]; data_path <- args[2]; out <- args[3]
ad_new_dir(out)
ad_snapshot(c("R/experimental/mebane_ad_long/run_jags.R",
              "R/experimental/mebane_ad/timing.md", "R/experimental/mebane_ad/io.R",
              "R/experimental/mebane_ad/prepare_dc2010.R", contract_path, data_path,
              "tests/mebane/ad_long/test_timing.R"), file.path(out, "sources"))
calls <- character()
fake <- function(name, value) {
  calls <<- c(calls, name)
  Sys.sleep(.03)
  force(value)
}
ad_jags_engine <- function() fake("setup", list(
  version = "4.3.2", package_version = "fixture_only", modules = "fixture_only",
  compile = function(...) fake("compile", list(state = function(...) list(fixture = TRUE))),
  adapt = function(...) fake("adapt", TRUE),
  burn = function(...) fake("burn", NULL),
  sample = function(...) fake("sample", rep(list(matrix(0, 20000, 1)), 4))))
saveRDS <- function(...) { Sys.sleep(.02); base::saveRDS(...) }
r <- ad_run_jags("A", contract_path, data_path, file.path(out, "success"))
expected <- c("setup", "compile", "adapt", "burn", "sample", "persist_raw")
stopifnot(r$status == "sampled_not_diagnosed", identical(names(r$phases), expected),
          identical(calls, expected[1:5]),
          all(vapply(r$phases, function(x) x$completed && x$elapsed >= .02, logical(1))),
          r$elapsed_seconds >= sum(vapply(r$phases, `[[`, numeric(1), "elapsed")) - .01)
ad_jags_engine <- function() list(version = "4.3.2", package_version = "fixture_only",
  modules = "fixture_only", compile = function(...) {Sys.sleep(.03); stop("fixture compile failure")})
f <- ad_run_jags("D", contract_path, data_path, file.path(out, "compile_failure"))
stopifnot(f$status == "error", f$failed_stage == "compile",
          !f$phases$compile$completed, f$phases$compile$elapsed >= .02,
          !file.exists(file.path(out,"compile_failure/raw_chains.rds")))
s <- ad_run_jags("D", contract_path, paste0(data_path,".absent"), file.path(out,"setup_failure"))
stopifnot(s$status == "error", s$failed_stage == "setup", !s$phases$setup$completed,
          length(s$phases)==1L, !file.exists(file.path(out,"setup_failure/raw_chains.rds")))
ad_json(list(status="pass", scenarios=c("success","compile_failure","setup_failure"),
              actual_MCMC=FALSE, fake_engine=TRUE), file.path(out,"result.json"))
ad_manifest(out, note="Fake-engine phase instrumentation fixtures; no MCMC")
cat("PASS timing, partial-error phases and persistence; fake engine only\n")
