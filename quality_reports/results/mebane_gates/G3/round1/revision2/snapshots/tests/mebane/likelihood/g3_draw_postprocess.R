# Read only the persisted new replay; no JAGS compilation or sampling.
.libPaths(c("renv/library/macos/R-4.4/aarch64-apple-darwin20", .libPaths()))
stopifnot(requireNamespace("posterior", quietly = TRUE),
          requireNamespace("jsonlite", quietly = TRUE))
source("R/lib/mebane_model.R")
outdir <- "quality_reports/results/mebane_gates/G3/round1/revision2"
rds_path <- file.path(outdir, "raw_chains.rds")
meta <- jsonlite::read_json(file.path(outdir, "sampling_metadata.json"),
                            simplifyVector = TRUE)
sha <- function(path) strsplit(system2("shasum", c("-a", "256", path),
                                       stdout = TRUE), " ")[[1]][1]
stopifnot(sha(rds_path) == meta$raw_rds_sha256)
payload <- readRDS(rds_path)
stopifnot(inherits(payload$draws, "mcmc.list"),
          length(payload$draws) == 4L,
          all(vapply(payload$draws, nrow, integer(1)) == 2000L),
          identical(as.integer(payload$seeds), 31102:31105),
          payload$adapt == 200L, payload$burnin == 500L,
          payload$post_iterations_per_chain == 2000L,
          payload$data$n == 1L, payload$data$N == 1L,
          payload$data$a == 0L, payload$data$w == 0L)
matrices <- lapply(payload$draws, as.matrix)
node <- function(name) do.call(cbind, lapply(matrices, function(x) {
  key <- intersect(c(name, paste0(name, "[1]")), colnames(x))
  if (length(key) != 1L) stop("Missing monitored node: ", name)
  x[, key]
}))
Z <- node("Z"); im <- node("N.iota.m"); is <- node("N.iota.s")
cm <- node("N.chi.m"); cs <- node("N.chi.s")
M <- ifelse(Z == 1, 0, ifelse(Z == 2, ifelse(im == 1, .999, 0),
                              ifelse(cm == 1, .999, 0))) * .5
S <- ifelse(Z == 1, 0, ifelse(Z == 2, is, cs)) * .25
targets <- list(Z = Z, r_im = im, r_is = is, r_cm = cm, r_cs = cs,
  indicator_Z1 = (Z == 1) * 1, indicator_Z2 = (Z == 2) * 1,
  indicator_Z3 = (Z == 3) * 1, M = M, S = S,
  margin_lower = 1 - M - 2*S, margin_upper = 1 - M - S)
checks <- c(z_support = all(Z %in% 1:3),
  four_count_support = all(c(im, is, cm, cs) %in% 0:1),
  one_class_per_draw = all(targets$indicator_Z1 + targets$indicator_Z2 +
                            targets$indicator_Z3 == 1),
  nonnegative_functionals = all(M >= 0 & S >= 0),
  lower_identity = all(abs(targets$margin_lower - (1 - M - 2*S)) < 1e-12),
  upper_identity = all(abs(targets$margin_upper - (1 - M - S)) < 1e-12),
  bound_order = all(targets$margin_lower <= targets$margin_upper))
stopifnot(all(checks))
joint <- data.frame(chain = rep(1:4, each = 2000),
  iteration = rep(1:2000, 4), Z = as.vector(Z),
  r_im = as.vector(im), r_is = as.vector(is),
  r_cm = as.vector(cm), r_cs = as.vector(cs),
  M = as.vector(M), S = as.vector(S),
  margin_lower = as.vector(targets$margin_lower),
  margin_upper = as.vector(targets$margin_upper),
  observed_margin_compatible = FALSE,
  leader_capacity_necessary = as.vector(M + S <= 0),
  physical_counterfactual_validated = FALSE)
write.csv(joint, file.path(outdir, "functionals_by_draw.csv"), row.names = FALSE)

states <- list()
for (z in 1:3) for (r1 in 0:1) for (r2 in 0:1)
  for (r3 in 0:1) for (r4 in 0:1) {
    counts <- c(r1, r2, r3, r4)
    weight <- c(4, 2, 1)[z]/7 * prod(dbinom(counts, 1,
      c(.35, .35, .85, .85))) * mebane_kernel(1, 0, 0, z, counts, .5, .5)
    m <- if (z == 1) 0 else if (z == 2) if (r1 == 1) .999 else 0 else if (r3 == 1) .999 else 0
    s <- if (z == 1) 0 else if (z == 2) r2 else r4
    states[[length(states)+1L]] <- data.frame(Z=z, r_im=r1, r_is=r2,
      r_cm=r3, r_cs=r4, indicator_Z1=as.numeric(z==1),
      indicator_Z2=as.numeric(z==2), indicator_Z3=as.numeric(z==3),
      M=.5*m, S=.25*s, margin_lower=1-.5*m-.5*s,
      margin_upper=1-.5*m-.25*s, weight=weight)
  }
exact <- do.call(rbind, states)
exact$posterior <- exact$weight/sum(exact$weight)
write.csv(exact, file.path(outdir, "conditional_exact_states.csv"), row.names = FALSE)
mcse_batch <- function(x) {
  stopifnot(nrow(x) == 2000L, ncol(x) == 4L)
  batches <- sapply(1:4, function(chain)
    colMeans(matrix(x[, chain], nrow = 50L, ncol = 40L)))
  sqrt(sum(apply(batches, 2, var)/40))/4
}
summary <- do.call(rbind, lapply(names(targets), function(nm) {
  x <- targets[[nm]]
  expectation <- sum(exact[[nm]] * exact$posterior)
  constant <- length(unique(as.vector(x))) == 1L &&
    length(unique(exact[[nm]][exact$posterior > 0])) == 1L
  mcse <- if (constant) 0 else mcse_batch(x)
  draws <- posterior::as_draws_array(array(x, dim=c(2000L,4L,1L),
    dimnames=list(NULL,NULL,nm)))
  rh <- if (constant) NA_real_ else posterior::rhat(draws)[[1]]
  eb <- if (constant) NA_real_ else posterior::ess_bulk(draws)[[1]]
  et <- if (constant) NA_real_ else posterior::ess_tail(draws)[[1]]
  tol <- max(1e-3, 6*mcse)
  data.frame(target=nm, exact=expectation, mc_mean=mean(x), mcse=mcse,
    tolerance=tol, difference=abs(mean(x)-expectation), rhat=rh,
    ess_bulk=eb, ess_tail=et, constant=constant)
}))
summary$mean_pass <- summary$difference <= summary$tolerance
summary$diagnostic_pass <- with(summary, constant |
  (!is.na(rhat) & !is.na(ess_bulk) & !is.na(ess_tail) &
    rhat < 1.01 & ess_bulk >= 400 & ess_tail >= 400))
write.csv(summary, file.path(outdir, "conditional_comparison.csv"), row.names = FALSE)
old <- read.csv("quality_reports/results/mebane_gates/G3/round1/jags_attempt5/conditional_comparison.csv")
stopifnot(identical(as.character(old$target), as.character(summary$target)))
prior_check <- data.frame(target=summary$target,
  revision1_mean=old$mc_mean, revision2_mean=summary$mc_mean,
  absolute_mean_difference=abs(summary$mc_mean-old$mc_mean),
  revision1_mcse=old$mcse, revision2_mcse=summary$mcse,
  combined_mcse=sqrt(old$mcse^2+summary$mcse^2),
  same_seeds_declared=TRUE)
write.csv(prior_check, file.path(outdir, "replay_vs_revision1.csv"),
          row.names = FALSE)
result <- list(status="inconclusive", repair_id="G3-COORD-DRAW-01",
  source="reopened_raw_chains_rds", raw_rds_sha256=sha(rds_path),
  prior_summary_sha256=sha("quality_reports/results/mebane_gates/G3/round1/jags_attempt5/conditional_comparison.csv"),
  all_mean_pass=all(summary$mean_pass),
  all_diagnostic_pass=all(summary$diagnostic_pass),
  degenerate_targets=as.character(summary$target[summary$constant]),
  missing_tail_ess_targets=as.character(summary$target[is.na(summary$ess_tail) & !summary$constant]),
  per_draw_identities=as.list(checks),
  replay_comparison="descriptive; no stochastic identity or new acceptance criterion",
  margin="Dobs=1 algebraic offset; observed margin incompatible with N=1,A=0,W=0",
  physical_counterfactual_validated=FALSE)
jsonlite::write_json(result, file.path(outdir, "postprocess_result.json"),
                     auto_unbox=TRUE, pretty=TRUE, na="null")
cat("postprocess from reopened RDS:", nrow(joint), "joint rows; means",
    result$all_mean_pass, "diagnostics", result$all_diagnostic_pass, "\n")
