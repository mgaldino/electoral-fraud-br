# Deterministic-only preflight. Do not launch during timed JAGS work.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("Usage: run_preflight.R REPO NEW_OUTPUT_DIRECTORY")
repo <- normalizePath(args[1], mustWork = TRUE)
source(file.path(repo, "R/experimental/mebane_ad_stan/common.R"))
ad_stan_setup(repo)
ad_stan_require_scoped_temp(repo)
executor_id <- Sys.getenv("CODEX_THREAD_ID")
if (!nzchar(executor_id)) stop("A real CODEX_THREAD_ID is required")
out <- ad_stan_new_dir(args[2])
sources <- file.path(out, "sources")
records <- ad_stan_snapshot(repo, sources, executor_id)

# From this point forward, all implementation and test functions use the snapshot.
frozen <- new.env(parent = globalenv())
for (f in c("common.R", "reference.R", "run_stan.R")) {
  sys.source(file.path(sources, "R/experimental/mebane_ad_stan", f), envir = frozen)
}
sys.source(file.path(sources, "tests/mebane/ad_stan/test_stan.R"), envir = frozen)
ad_stan_json(list(executor_id = executor_id, started_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
                  command = commandArgs(), source_snapshot_manifest_sha256 = ad_stan_sha(file.path(sources, "sources_manifest.json")),
                  runtime = ad_stan_runtime(), empirical_sampling = FALSE,
                  allowed_execution = "Compilation, compiled log density/gradient calls, and fixed-parameter generated quantities on three synthetic rows only"),
             file.path(out, "run_started.json"))
start <- Sys.time()
result <- tryCatch({
  prepared <- frozen$ad_stan_compile_preparation(repo, out, executor_id, compile_methods = TRUE)
  test_dir <- ad_stan_new_dir(file.path(out, "tests"))
  suite <- frozen$ad_stan_logged(file.path(test_dir, "test.log"), {
    cat("executor_id:", executor_id, "\nsource_manifest_sha256:",
        ad_stan_sha(file.path(sources, "sources_manifest.json")), "\n")
    frozen$ad_stan_test_suite(prepared$model, test_dir, sources, executor_id)
  })
  python_dir <- ad_stan_new_dir(file.path(out, "supervisor_tests"))
  python <- Sys.which("python3")
  if (!nzchar(python)) stop("Existing python3 is required for supervisor regression tests")
  py_args <- c("-B", file.path(sources, "tests/mebane/ad_stan/test_supervisor.py"),
               file.path(sources, "R/experimental/mebane_ad_stan/supervise_stan.py"), python_dir)
  ad_stan_json(list(executor_id = executor_id, command = c(python, py_args)),
               file.path(python_dir, "command.json"))
  py <- processx::run(python, py_args, error_on_status = FALSE, echo = FALSE, timeout = 30000)
  writeLines(c(py$stdout, py$stderr), file.path(python_dir, "test.log"))
  if (py$status != 0L) stop("Supervisor regression tests failed: ", py$stderr)
  for (record in records) {
    if (ad_stan_sha(file.path(repo, record$path)) != record$sha256) stop("Live source changed during attempt: ", record$path)
    if (ad_stan_sha(file.path(sources, record$path)) != record$sha256) stop("Snapshot changed during attempt: ", record$path)
  }
  list(status = if (suite$failed == 0L) "deterministic_tests_pass_candidate_requires_independent_QA" else "deterministic_tests_failed",
       R_checks_passed = suite$passed, R_checks_failed = suite$failed, supervisor_exit_code = py$status)
}, error = function(e) {
  list(status = "preflight_failed_artifacts_retained", error = conditionMessage(e))
})
result$executor_id <- executor_id
result$empirical_sampling <- FALSE
result$independent_QA_pass <- FALSE
result$production_or_G10_approved <- FALSE
result$completed_utc <- format(Sys.time(), tz = "UTC", usetz = TRUE)
result$elapsed_seconds <- as.numeric(difftime(Sys.time(), start, units = "secs"))
ad_stan_json(result, file.path(out, "result.json"))
# R may clean its own temporary session at exit. Retain compiler products first.
products <- list.files(tempdir(), pattern = "\\.(cpp|cc|hpp|h|o|so|dylib)$",
                       recursive = TRUE, full.names = TRUE)
if (length(products)) {
  for (path in products) {
    relative <- substring(path, nchar(tempdir()) + 2L)
    destination <- file.path(out, "compiler_products", relative)
    dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
    if (!file.copy(path, destination, overwrite = FALSE)) stop("Cannot preserve compiler product: ", path)
    stopifnot(ad_stan_sha(path) == ad_stan_sha(destination))
  }
}
frozen$ad_stan_seal(out, result)
cat(jsonlite::toJSON(result, auto_unbox = TRUE, pretty = TRUE), "\n")
if (!identical(result$status, "deterministic_tests_pass_candidate_requires_independent_QA")) quit(status = 1L)
