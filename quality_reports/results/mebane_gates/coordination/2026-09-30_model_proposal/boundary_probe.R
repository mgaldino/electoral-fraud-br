# Reproduce the floating-point cause of the first deterministic failure.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 1L, !file.exists(args[1]))
pA <- 0.8
pW <- 0.2
pO <- 0
direct <- pW / (1 - pA)
stable <- pW / (pW + pO)
stopifnot(direct > 1, stable == 1,
          is.nan(suppressWarnings(dbinom(1, 1, direct))),
          dbinom(1, 1, stable) == 1)
writeLines(c(sprintf("direct_ratio=%.17g", direct),
             sprintf("positive_sum_ratio=%.17g", stable),
             "No clamp, tolerance change or new probability model."), args[1])
