# AR-02: exercise the archived eforensics wrapper up to, but not into, MCMC.
# Run from the repository root: Rscript tests/mebane/likelihood/test_ar02_interface.R

# The Codex sandbox skips renv activation; reuse its existing project library.
if (!requireNamespace("eforensics", quietly = TRUE)) {
  library_root <- file.path("renv", "library")
  for (os_dir in list.dirs(library_root, recursive = FALSE)) {
    for (r_dir in list.dirs(os_dir, recursive = FALSE)) {
      for (platform_dir in list.dirs(r_dir, recursive = FALSE)) {
        if (file.exists(file.path(platform_dir, "eforensics", "DESCRIPTION"))) {
          .libPaths(c(platform_dir, .libPaths()))
        }
      }
    }
  }
}

required <- c("eforensics", "runjags", "rjags")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Missing installed packages: ", paste(missing, collapse = ", "))

sha <- packageDescription("eforensics", fields = "RemoteSha")
expected_sha <- "3017de537450f97a01872d0157462a68bea348ee"
stopifnot(identical(sha, expected_sha))

source_path <- "quality_reports/results/mebane_gates/G2/round2/sources/ef_main_3017de5.R"
source_ast <- parse(source_path)
definition <- function(ast, name) {
  hits <- Filter(function(x) is.call(x) && identical(x[[1L]], as.name("<-")) &&
                   identical(x[[2L]], as.name(name)), as.list(ast))
  if (length(hits) != 1L) stop("Expected exactly one definition of ", name)
  eval(hits[[1L]][[3L]], envir = baseenv())
}
ef_ns <- asNamespace("eforensics")
for (name in c("eforensics", "eforensics_main_par", "getRegMatrix", "order.formulas")) {
  stopifnot(isTRUE(all.equal(body(get(name, ef_ns)), body(definition(source_ast, name)))))
}

paths <- c(
  "R/05_eforensics_umeforensics_qbl.R",
  "R/07_brasil_full_qbl.R"
)

calls_in <- function(ast) {
  calls <- list()
  walk <- function(x) {
    if (is.call(x)) {
      if (identical(x[[1L]], as.name("eforensics"))) {
        calls[[length(calls) + 1L]] <<- x
      }
      for (child in as.list(x)[-1L]) if (!missing(child)) walk(child)
    } else if (is.expression(x) || is.pairlist(x) || is.list(x)) {
      for (child in x) if (!missing(child)) walk(child)
    }
  }
  walk(ast)
  calls
}

script_ast <- lapply(paths, parse)
script_calls <- lapply(script_ast, calls_in)
stopifnot(identical(lengths(script_calls), c(3L, 1L)))

expected_formula <- list(
  c("w ~ x1.w", "a ~ x1.a"),
  c("w ~ 1", "a ~ 1"),
  c("w ~ 1", "a ~ 1"),
  c("w ~ 1", "a ~ 1")
)
all_calls <- c(script_calls[[1L]], script_calls[[2L]])
for (i in seq_along(all_calls)) {
  actual <- c(deparse1(all_calls[[i]]$formula1), deparse1(all_calls[[i]]$formula2))
  stopifnot(identical(actual, expected_formula[[i]]))
}
cat("AST PASS: 3 calls in R/05 and 1 in R/07 have the repaired formula mapping\n")

sentinel <- data.frame(
  N = c(10, 12), a = c(2, 5), w = c(7, 3),
  x1.a = c(0.2, 0.8), x1.w = c(0.9, 0.4),
  x1.iota.m = c(0.1, 0.3), x1.iota.s = c(0.4, 0.2),
  x1.chi.m = c(0.6, 0.5), x1.chi.s = c(0.7, 0.1)
)
stopifnot(all(sentinel$w <= sentinel$N - sentinel$a))
intercept <- matrix(1, nrow = 2L, ncol = 1L,
                    dimnames = list(NULL, "(Intercept)"))
direct <- list(
  N = sentinel$N, a = sentinel$a, w = sentinel$w, n = 2L,
  Xw_cov = cbind("(Intercept)" = c(1, 1), x1.w = sentinel$x1.w),
  Xa_cov = cbind("(Intercept)" = c(1, 1), x1.a = sentinel$x1.a),
  Xw_intercept = intercept, Xa_intercept = intercept
)
latent_names <- c("iota.m", "iota.s", "chi.m", "chi.s")
for (name in latent_names) {
  covariate <- paste0("x1.", name)
  design <- cbind("(Intercept)" = c(1, 1), sentinel[[covariate]])
  colnames(design)[2L] <- covariate
  direct[[paste0("X.", name, "_cov")]] <- design
  direct[[paste0("X.", name, "_intercept")]] <- intercept
}
same_vector <- function(x, y) identical(as.numeric(x), as.numeric(y))
same_matrix <- function(x, y) {
  identical(dim(x), dim(y)) && identical(colnames(x), colnames(y)) &&
    same_vector(x, y)
}

run_ns <- asNamespace("runjags")
rj_ns <- asNamespace("rjags")
original <- list(
  order = get("order.formulas", ef_ns),
  check = get("ef_check_jags", ef_ns),
  sample = get("run.jags", run_ns),
  compile = get("jags.model", rj_ns)
)

run_test <- function() {
  on.exit({
    assignInNamespace("order.formulas", original$order, ns = "eforensics")
    assignInNamespace("ef_check_jags", original$check, ns = "eforensics")
    assignInNamespace("run.jags", original$sample, ns = "runjags")
    assignInNamespace("jags.model", original$compile, ns = "rjags")
  }, add = TRUE)

  sample_intercepts <- 0L
  compile_intercepts <- 0L
  capture_sampler <- function(..., data) {
    sample_intercepts <<- sample_intercepts + 1L
    stop(structure(list(message = "Captured before original run.jags", call = NULL,
                        data = data), class = c("ar02_capture", "error", "condition")))
  }
  block_compiler <- function(...) {
    compile_intercepts <<- compile_intercepts + 1L
    stop("MCMC compiler reached; AR-02 test must not compile")
  }
  assignInNamespace("run.jags", capture_sampler, ns = "runjags")
  assignInNamespace("jags.model", block_compiler, ns = "rjags")
  assignInNamespace("ef_check_jags", function() invisible(NULL), ns = "eforensics")
  stopifnot(identical(getExportedValue("runjags", "run.jags"), capture_sampler))
  stopifnot(identical(getExportedValue("rjags", "jags.model"), block_compiler))

  eval_env <- new.env(parent = globalenv())
  eval_env$eforensics <- getExportedValue("eforensics", "eforensics")
  eval_env$sim <- list(data = sentinel)
  eval_env$dat_bsb <- sentinel
  eval_env$dat <- sentinel
  eval_env$BURN_IN <- 0L
  eval_env$N_ITER <- 1L
  eval_env$N_ADAPT <- 0L
  eval_env$RUN_TAG <- "canary"

  capture <- function(expr) {
    result <- tryCatch(eval(expr, envir = eval_env), ar02_capture = identity)
    if (!inherits(result, "ar02_capture")) stop("Wrapper did not abort at sampler stub")
    result$data
  }
  for (script in seq_along(script_calls)) {
    # Use the patch embedded in the corresponding script, without sourcing its runner.
    patch_fun <- definition(script_ast[[script]], "fixed_order_formulas")
    assignInNamespace("order.formulas", patch_fun, ns = "eforensics")
    for (j in seq_along(script_calls[[script]])) {
      i <- if (script == 1L) j else 4L
      call <- script_calls[[script]][[j]]
      got <- capture(call)
      expected_Xw <- if (i == 1L) direct$Xw_cov else direct$Xw_intercept
      expected_Xa <- if (i == 1L) direct$Xa_cov else direct$Xa_intercept
      if (!same_vector(got$w, direct$w) || !same_vector(got$a, direct$a)) {
        stop(sprintf("Response mismatch call %d: w=%s a=%s (expected w=%s a=%s)",
                     i, paste(got$w, collapse = ","), paste(got$a, collapse = ","),
                     paste(direct$w, collapse = ","), paste(direct$a, collapse = ",")))
      }
      stopifnot(
        same_vector(got$w, direct$w), same_vector(got$a, direct$a),
        same_vector(got$N, direct$N), identical(got$n, direct$n),
        same_matrix(got$Xw, expected_Xw), same_matrix(got$Xa, expected_Xa),
        identical(got$dxw, ncol(expected_Xw)),
        identical(got$dxa, ncol(expected_Xa))
      )
      for (name in latent_names) {
        expected_latent <- direct[[paste0("X.", name,
                                          if (i == 1L) "_cov" else "_intercept")]]
        stopifnot(same_matrix(got[[paste0("X.", name)]], expected_latent),
                  identical(got[[paste0("dx.", name)]], ncol(expected_latent)))
      }

      swapped <- call
      swapped$formula1 <- call$formula2
      swapped$formula2 <- call$formula1
      wrong <- capture(swapped)
      stopifnot(!same_vector(wrong$w, direct$w), !same_vector(wrong$a, direct$a))
      if (i == 1L) {
        stopifnot(!same_matrix(wrong$Xw, direct$Xw_cov),
                  !same_matrix(wrong$Xa, direct$Xa_cov))
      }
      cat(sprintf("WRAPPER PASS: call %d, direct-list match and swapped negative control\n", i))
    }
  }
  stopifnot(identical(sample_intercepts, 8L), identical(compile_intercepts, 0L))
  cat("MCMC BLOCKED: 8 captures in sampler stub, 0 compiler entries\n")
}

run_test()
stopifnot(
  identical(get("order.formulas", ef_ns), original$order),
  identical(get("ef_check_jags", ef_ns), original$check),
  identical(get("run.jags", run_ns), original$sample),
  identical(get("jags.model", rj_ns), original$compile)
)
cat("AR-02 PASS: original namespace functions restored in this disposable R process\n")
