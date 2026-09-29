# Independent AR-02 boundary probe. This file never sources or runs a runner.
if (!requireNamespace("eforensics", quietly = TRUE)) {
  for (os_dir in list.dirs("renv/library", recursive = FALSE)) {
    for (r_dir in list.dirs(os_dir, recursive = FALSE)) {
      for (platform_dir in list.dirs(r_dir, recursive = FALSE)) {
        if (file.exists(file.path(platform_dir, "eforensics", "DESCRIPTION"))) {
          .libPaths(c(platform_dir, .libPaths()))
        }
      }
    }
  }
}
stopifnot(all(vapply(c("eforensics", "runjags", "rjags"), requireNamespace,
                     logical(1), quietly = TRUE)))
cat("R=", as.character(getRversion()), " eforensics=",
    as.character(packageVersion("eforensics")), " RemoteSha=",
    packageDescription("eforensics", fields = "RemoteSha"),
    " runjags=", as.character(packageVersion("runjags")),
    " rjags=", as.character(packageVersion("rjags")), "\n", sep = "")

ast <- parse("R/05_eforensics_umeforensics_qbl.R")
find_one <- function(x, name) {
  hits <- list()
  walk <- function(y) {
    if (is.call(y)) {
      if (identical(y[[1L]], as.name(name))) hits[[length(hits) + 1L]] <<- y
      for (z in as.list(y)[-1L]) if (!missing(z)) walk(z)
    } else if (is.expression(y) || is.list(y)) {
      for (z in y) if (!missing(z)) walk(z)
    }
  }
  walk(x)
  hits
}
calls <- find_one(ast, "eforensics")
stopifnot(length(calls) == 3L)
patches <- Filter(function(x) is.call(x) && identical(x[[1L]], as.name("<-")) &&
                    identical(x[[2L]], as.name("fixed_order_formulas")), as.list(ast))
stopifnot(length(patches) == 1L)
patch_fun <- eval(patches[[1L]][[3L]], envir = baseenv())

ef_ns <- asNamespace("eforensics")
run_ns <- asNamespace("runjags")
rj_ns <- asNamespace("rjags")
old <- list(order = get("order.formulas", ef_ns), check = get("ef_check_jags", ef_ns),
            sample = get("run.jags", run_ns), compile = get("jags.model", rj_ns))

probe <- function() {
  on.exit({
    assignInNamespace("order.formulas", old$order, ns = "eforensics")
    assignInNamespace("ef_check_jags", old$check, ns = "eforensics")
    assignInNamespace("run.jags", old$sample, ns = "runjags")
    assignInNamespace("jags.model", old$compile, ns = "rjags")
  }, add = TRUE)
  captures <- 0L
  compiler_entries <- 0L
  sampler_stub <- function(..., data) {
    captures <<- captures + 1L
    stop(structure(list(message = "boundary", call = NULL, data = data),
                   class = c("probe_capture", "error", "condition")))
  }
  compiler_guard <- function(...) {
    compiler_entries <<- compiler_entries + 1L
    stop("Unexpected JAGS compiler entry")
  }
  assignInNamespace("order.formulas", patch_fun, ns = "eforensics")
  assignInNamespace("ef_check_jags", function() invisible(NULL), ns = "eforensics")
  assignInNamespace("run.jags", sampler_stub, ns = "runjags")
  assignInNamespace("jags.model", compiler_guard, ns = "rjags")
  stopifnot(identical(getExportedValue("runjags", "run.jags"), sampler_stub),
            identical(getExportedValue("rjags", "jags.model"), compiler_guard))

  values <- data.frame(N = c(10, 12), a = c(2, 5), w = c(7, 3),
                       x1.a = c(.2, .8), x1.w = c(.9, .4),
                       x1.iota.m = c(.1, .3), x1.iota.s = c(.4, .2),
                       x1.chi.m = c(.6, .5), x1.chi.s = c(.7, .1))
  env <- new.env(parent = globalenv())
  env$eforensics <- getExportedValue("eforensics", "eforensics")
  env$sim <- list(data = values)
  capture <- function(expr) {
    result <- tryCatch(eval(expr, envir = env), probe_capture = identity)
    stopifnot(inherits(result, "probe_capture"))
    result$data
  }
  good <- capture(calls[[1L]])
  bad_call <- calls[[1L]]
  bad_call$formula1 <- w ~ x1.a
  bad_call$formula2 <- a ~ x1.w
  bad <- capture(bad_call)
  stopifnot(identical(as.numeric(good$w), values$w),
            identical(as.numeric(good$a), values$a),
            identical(as.numeric(bad$w), values$w),
            identical(as.numeric(bad$a), values$a),
            identical(as.numeric(good$N), values$N),
            identical(as.numeric(bad$N), values$N),
            identical(as.numeric(good$Xw[, 2L]), values$x1.w),
            identical(as.numeric(good$Xa[, 2L]), values$x1.a),
            identical(as.numeric(bad$Xw[, 2L]), values$x1.a),
            identical(as.numeric(bad$Xa[, 2L]), values$x1.w),
            !identical(good$Xw, bad$Xw), !identical(good$Xa, bad$Xa),
            identical(captures, 2L), identical(compiler_entries, 0L))
  cat("COVARIATE MUTATION DETECTED: responses unchanged; Xw and Xa differ\n")
  cat("SAMPLING BLOCKED: 2 sampler-stub captures; 0 compiler entries\n")
}

probe()
stopifnot(identical(get("order.formulas", ef_ns), old$order),
          identical(get("ef_check_jags", ef_ns), old$check),
          identical(get("run.jags", run_ns), old$sample),
          identical(get("jags.model", rj_ns), old$compile))
cat("NAMESPACES RESTORED\n")
