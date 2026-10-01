# Coordinator check of the proposed ranking against independently reviewed
# summaries. This does not recompute MCMC diagnostics or certify precision.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 1L, !file.exists(args[[1]]))
base <- "quality_reports/results/mebane_gates/coordination"
source_path <- file.path(base, "2026-10-01_ad_long_stan/comparison_final01/global_functionals.csv")
candidate_path <- file.path(base, "2026-10-01_longer_chains_proposals/diagnostics/analysis01/global_rankings.csv")
reference <- read.csv(source_path, check.names = FALSE)
candidate <- read.csv(candidate_path, check.names = FALSE)
stopifnot(nrow(candidate) == 69L,
          !anyDuplicated(paste(candidate$run, candidate$target)),
          all(table(candidate$run) == 23L))
idx <- match(paste(candidate$run, candidate$target),
             paste(reference$id, reference$target))
stopifnot(!anyNA(idx))
columns <- c("mean", "sd", "q025", "q50", "q975", "rhat", "ess_bulk",
             "ess_tail", "mcse_mean", paste0("chain", 1:4))
largest <- 0
for (column in columns) {
  delta <- abs(candidate[[column]] - reference[[column]][idx])
  stopifnot(all(is.finite(delta)), all(delta <= 1e-9))
  largest <- max(largest, delta)
}
stopifnot(identical(candidate$diagnostic_pass, reference$diagnostic_pass[idx]),
          identical(candidate$bulk_below_400, candidate$ess_bulk < 400),
          identical(candidate$tail_below_400, candidate$ess_tail < 400))
for (run in unique(candidate$run)) {
  x <- candidate[candidate$run == run, ]
  stopifnot(all(diff(x$ess_bulk) >= 0),
            identical(x$rank_bulk, as.integer(rank(x$ess_bulk, ties.method = "min"))))
}
summary <- do.call(rbind, lapply(split(candidate, candidate$run), function(x) {
  data.frame(run = x$run[1], global_targets = nrow(x),
             failed_globals = sum(!x$diagnostic_pass),
             bulk_below_400 = sum(x$bulk_below_400),
             tail_below_400 = sum(x$tail_below_400),
             min_bulk = min(x$ess_bulk), max_Rhat = max(x$rhat))
}))
stopifnot(identical(as.integer(summary$failed_globals), c(14L, 13L, 10L)))
result <- c("PASS: 69 global ranking rows matched the reviewed comparison.",
            paste("Numeric cells checked:", nrow(candidate) * length(columns)),
            paste("Largest absolute numeric difference:", format(largest)),
            "Rank order, diagnostic decisions and bulk/tail thresholds also matched.",
            "No raw chains reloaded, no MCMC, no prior change, no precision approval.",
            capture.output(print(summary, row.names = FALSE)))
writeLines(result, args[[1]])
cat(paste(result, collapse = "\n"), "\n")
