# Adversarial regression for chain-preserving scalar diagnostics; no MCMC.
.libPaths(c("renv/library/macos/R-4.4/aarch64-apple-darwin20", .libPaths()))
stopifnot(requireNamespace("posterior", quietly = TRUE),
          requireNamespace("jsonlite", quietly = TRUE))
root <- "quality_reports/results/mebane_gates/G3/round1/revision3"
outdir <- file.path(root, "shape_regression")
stopifnot(!dir.exists(outdir))
dir.create(outdir, recursive = TRUE)
plan <- jsonlite::read_json(file.path(root, "repair_plan.json"), simplifyVector = TRUE)
ast <- parse("tests/mebane/likelihood/g3_draw_postprocess.R")
definitions <- Filter(function(x) is.call(x) && identical(x[[1L]], as.name("<-")) &&
  identical(x[[2L]], as.name("g3_chain_diagnostics")), as.list(ast))
stopifnot(length(definitions) == 1L)
eval(definitions[[1L]])
i <- seq_len(plan$regression$iterations)
wave <- .01*sin(2*pi*i/25) + .003*cos(2*pi*i/31)
x <- vapply(plan$regression$chain_means, function(mu) mu + wave, numeric(2000L))
stopifnot(identical(dim(x), c(2000L, 4L)), is.numeric(x))
array_input <- posterior::as_draws_array(array(x, dim=c(2000L,4L,1L),
  dimnames=list(NULL,NULL,"fixture")))
pooled <- as.matrix(array_input)
expected <- c(rhat=posterior::rhat(x), ess_bulk=posterior::ess_bulk(x),
              ess_tail=posterior::ess_tail(x))
actual <- g3_chain_diagnostics(x)
negative <- c(rhat=posterior::rhat(array_input),
              ess_bulk=posterior::ess_bulk(array_input),
              ess_tail=posterior::ess_tail(array_input))
rejects <- function(value) inherits(tryCatch(g3_chain_diagnostics(value),
  error=function(e) e), "error")
checks <- c(
  ordinary_matrix = identical(class(x), c("matrix", "array")),
  pooled_shape_demonstrated = identical(dim(pooled), c(8000L,1L)),
  production_equals_direct = all(abs(actual-expected) <
    plan$regression$direct_function_equality_tolerance),
  correct_rhat_detects_chain_disagreement = actual[["rhat"]] >
    plan$regression$correct_rhat_min_exclusive,
  pooled_rhat_hides_chain_disagreement = negative[["rhat"]] <
    plan$regression$incorrect_pooled_rhat_max_exclusive,
  rhat_gap = actual[["rhat"]] - negative[["rhat"]] >
    plan$regression$rhat_gap_min_exclusive,
  reject_draws_array = rejects(array_input),
  reject_pooled_matrix = rejects(pooled),
  reject_transposed_matrix = rejects(t(x)))
write.csv(x, file.path(outdir, "fixture.csv"), row.names=FALSE)
write.csv(data.frame(diagnostic=names(expected), direct=unname(expected),
  production=unname(actual), incorrect_pooled=unname(negative)),
  file.path(outdir, "diagnostics.csv"), row.names=FALSE)
jsonlite::write_json(list(checks=as.list(checks), all_pass=all(checks),
  actual_shape=dim(x), incorrect_coerced_shape=dim(pooled),
  posterior_version=as.character(utils::packageVersion("posterior")),
  no_new_sampling=TRUE), file.path(outdir, "result.json"),
  pretty=TRUE, auto_unbox=TRUE, na="null")
capture.output(sessionInfo(), file=file.path(outdir, "session.txt"))
stopifnot(all(checks))
cat("chain-shape regression PASS:", length(checks), "checks; correct Rhat",
    actual[["rhat"]], "incorrect pooled Rhat", negative[["rhat"]], "\n")
