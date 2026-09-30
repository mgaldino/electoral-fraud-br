args <- commandArgs(trailingOnly = TRUE)
out <- args[1]
stopifnot(!dir.exists(out))
dir.create(out, recursive = TRUE)
stopifnot(requireNamespace("posterior", quietly = TRUE))
u <- sin(seq_len(2000L))
x <- cbind(u - 4, u + 4, u - 4, u + 4)
wrapped <- posterior::as_draws_array(array(x, c(2000L, 4L, 1L),
  dimnames = list(NULL, NULL, "fixture")))
rh_correct <- posterior::rhat(x)
rh_wrong <- posterior::rhat(wrapped)
ok <- rh_correct > 1.1 && rh_wrong < 1.05
saveRDS(x, file.path(out, "deterministic_matrix.rds"))
jsonlite::write_json(list(correct_dimensions = dim(x),
  wrong_dimensions = dim(as.matrix(wrapped)), correct_rhat = rh_correct,
  pooled_rhat = rh_wrong, detects_chain_collapse = ok,
  RNG_used = FALSE, no_MCMC = TRUE, criterion_scope = "deterministic unit test only"),
  file.path(out, "result.json"), pretty = TRUE, auto_unbox = TRUE, digits = 17)
stopifnot(ok)
