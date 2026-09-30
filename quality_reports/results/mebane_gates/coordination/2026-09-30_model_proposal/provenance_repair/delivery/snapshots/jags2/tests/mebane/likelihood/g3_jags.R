lib <- "renv/library/macos/R-4.4/aarch64-apple-darwin20"
.libPaths(c(lib, .libPaths()))
stopifnot(requireNamespace("rjags", quietly = TRUE),
          requireNamespace("coda", quietly = TRUE),
          requireNamespace("jsonlite", quietly = TRUE))
source("R/lib/mebane_model.R")
outdir <- "quality_reports/results/mebane_gates/G3/round1/jags_attempt2"
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
model <- "quality_reports/results/mebane_gates/G0/round1/qbl_installed_3017de5.jags"
actual_sha <- strsplit(system2("shasum", c("-a", "256", model), stdout = TRUE), " ")[[1]][1]
stopifnot(actual_sha == "f8360126424b7a463f76a1c99efc89a8a5cb81339213bd4931559f14595fbab6",
          as.character(rjags::jags.version()) == "4.3.2")
save_json <- function(x, name) jsonlite::write_json(x, file.path(outdir, name),
  auto_unbox = TRUE, pretty = TRUE, na = "null")
base <- function() {
  x <- list(n = 1L, N = 1L, a = 0L, w = 0L,
            "pi.aux1" = 1, "pi.aux2" = .5, "pi.aux3" = .25)
  for (nm in c("tau", "nu", "iota.m", "iota.s", "chi.m", "chi.s")) {
    x[[paste0("X", if (nm %in% c("tau", "nu"))
      if (nm == "tau") "a" else "w" else paste0(".", nm))]] <- matrix(1, 1, 1)
    x[[paste0("dx", if (nm %in% c("tau", "nu"))
      if (nm == "tau") "a" else "w" else paste0(".", nm))]] <- 1L
    h <- switch(nm, tau = "th", nu = "nh", "iota.m" = "imh",
                "iota.s" = "ish", "chi.m" = "cmh", "chi.s" = "csh")
    x[[h]] <- 0
    x[[paste0("beta.", nm, "1")]] <- 0
  }
  x$Z <- 1L
  for (nm in c("iota.m", "iota.s", "chi.m", "chi.s"))
    x[[paste0("N.", nm)]] <- 0L
  x
}
probe <- function(id, data, inits = NULL, update_steps = 1L) {
  stage <- "compile"
  started <- Sys.time()
  result <- tryCatch({
    jm <- rjags::jags.model(model, data = data, inits = inits,
                           n.chains = 1L, n.adapt = 1L, quiet = TRUE)
    stage <- "update"
    stats::update(jm, update_steps, progress.bar = "none")
    stage <- "sample"
    smp <- rjags::coda.samples(jm, c("p.a", "p.w", "a", "w", "Z"),
                                n.iter = 1L, progress.bar = "none")
    list(id = id, outcome = "success", stage = stage,
         values = as.list(as.numeric(as.matrix(smp[[1]])[1, ])),
         variables = colnames(as.matrix(smp[[1]])),
         seconds = as.numeric(difftime(Sys.time(), started, units = "secs")))
  }, error = function(e) list(id = id, outcome = "error", stage = stage,
      message = conditionMessage(e),
      seconds = as.numeric(difftime(Sys.time(), started, units = "secs"))))
  result
}
probes <- list()
add <- function(id, data, inits = NULL, update_steps = 1L) {
  probes[[length(probes) + 1L]] <<- probe(id, data, inits, update_steps)
  save_json(probes, "jags_probes.json")
}
d <- base(); add("valid_control_observed", d)
d <- base(); d$a <- 1L; d$Z <- 2L; d[["N.iota.m"]] <- 1L
add("invalid_active_class2_data", d)
d <- base(); d$a <- 1L; d[["N.iota.m"]] <- 1L
add("invalid_inactive_class1_data", d)
d <- base(); d$a <- 1L; d$Z <- 3L; d[["N.chi.m"]] <- 1L
add("invalid_active_class3_data", d)
d <- base(); d$a <- 1L; d$Z <- 2L; d[["N.chi.m"]] <- 1L
add("invalid_inactive_chi_class2_data", d)
d <- base(); d$a <- 1L; d$Z <- 2L; d[["N.iota.m"]] <- NULL
add("invalid_active_class2_init", d, list("N.iota.m" = 1L))
d <- base(); d$a <- 1L; d$Z <- 2L; d[["N.iota.m"]] <- NULL
add("stochastic_count_update", d, update_steps = 20L)
d <- base(); d$a <- NA_integer_; d$w <- NA_integer_
add("a_w_missing", d)
d <- base(); d$w <- NA_integer_; add("a_conditioned_w_missing", d)
d <- base(); d$a <- NA_integer_; add("a_missing_w_conditioned", d)
cat("JAGS probes complete:", length(probes), "cases\n")

# This comparison conditions on continuous effects, coefficients and pi auxiliaries.
cmp <- base()
cmp$Z <- NULL
for (nm in c("iota.m", "iota.s", "chi.m", "chi.s"))
  cmp[[paste0("N.", nm)]] <- NULL
seeds <- 31102:31105
start <- Sys.time()
fit <- tryCatch({
  ini <- lapply(seeds, function(s) list(.RNG.name = "base::Mersenne-Twister",
                                        .RNG.seed = as.integer(s)))
  jm <- rjags::jags.model(model, data = cmp, inits = ini, n.chains = 4L,
                         n.adapt = 200L, quiet = TRUE)
  stats::update(jm, 500L, progress.bar = "none")
  rjags::coda.samples(jm,
    c("Z", "N.iota.m", "N.iota.s", "N.chi.m", "N.chi.s"),
    n.iter = 2000L, progress.bar = "none")
}, error = function(e) e)
if (inherits(fit, "error")) {
  save_json(list(status = "inconclusive", message = conditionMessage(fit),
                 seconds = as.numeric(difftime(Sys.time(), start, units = "secs"))),
            "comparison_result.json")
  cat("conditioned JAGS comparison INCONCLUSIVE:", conditionMessage(fit), "\n")
  quit(status = 0)
}
matrices <- lapply(fit, as.matrix)
node <- function(name) do.call(cbind, lapply(matrices, function(x) x[, paste0(name, "[1]")]))
Z <- node("Z"); im <- node("N.iota.m"); is <- node("N.iota.s")
cm <- node("N.chi.m"); cs <- node("N.chi.s")
M <- ifelse(Z == 1, 0, ifelse(Z == 2, ifelse(im == 1, .999, 0),
                              ifelse(cm == 1, .999, 0))) * .5
S <- ifelse(Z == 1, 0, ifelse(Z == 2, is, cs)) * .25
targets <- list(Z = Z, r_im = im, r_is = is, r_cm = cm, r_cs = cs,
  indicator_Z1 = (Z == 1) * 1, indicator_Z2 = (Z == 2) * 1,
  indicator_Z3 = (Z == 3) * 1, M = M, S = S,
  margin_lower = 1 - M - 2*S, margin_upper = 1 - M - S)
states <- list()
for (z in 1:3) for (r1 in 0:1) for (r2 in 0:1)
  for (r3 in 0:1) for (r4 in 0:1) {
    counts <- c(r1,r2,r3,r4)
    weight <- c(4,2,1)[z]/7 * prod(dbinom(counts, 1,
      c(.35,.35,.85,.85))) * mebane_kernel(1,0,0,z,counts,.5,.5)
    m <- if (z == 1) 0 else if (z == 2) if (r1 == 1) .999 else 0 else if (r3 == 1) .999 else 0
    s <- if (z == 1) 0 else if (z == 2) r2 else r4
    states[[length(states)+1L]] <- data.frame(Z=z,r_im=r1,r_is=r2,r_cm=r3,r_cs=r4,
      indicator_Z1=as.numeric(z==1),indicator_Z2=as.numeric(z==2),
      indicator_Z3=as.numeric(z==3),M=.5*m,S=.25*s,
      margin_lower=1-.5*m-.5*s,margin_upper=1-.5*m-.25*s,weight=weight)
  }
exact <- do.call(rbind, states)
exact$posterior <- exact$weight/sum(exact$weight)
exact$observed_margin_compatible <- FALSE
exact$leader_capacity_necessary <- exact$M + exact$S <= 0
exact$physical_counterfactual_validated <- FALSE
write.csv(exact, file.path(outdir,"conditional_exact_states.csv"), row.names=FALSE)
save_json(list(Dobs_kind="algebraic_fixture_offset_not_observed_margin",
  N=1,A=0,W=0,Dobs_offset=1,observed_margin_compatible=FALSE,
  leader_capacity_necessary_fraction=sum(exact$posterior[exact$leader_capacity_necessary]),
  source_capacity_fully_verified=FALSE,physical_counterfactual_validated=FALSE,
  note="Expected-vote functionals; necessary flags do not establish physical origin/ballot feasibility"),
  "margin_feasibility.json")
if (!requireNamespace("posterior", quietly = TRUE)) {
  save_json(list(status="inconclusive",reason="posterior package unavailable"),
            "comparison_result.json")
  quit(status=0)
}
mcse_batch <- function(x) {
  stopifnot(nrow(x)==2000L,ncol(x)==4L)
  batches <- sapply(1:4,function(chain) colMeans(matrix(x[,chain],nrow=50L,ncol=40L)))
  sqrt(sum(apply(batches,2,var)/40))/4
}
summary <- do.call(rbind,lapply(names(targets),function(nm) {
  x <- targets[[nm]]
  expectation <- sum(exact[[nm]]*exact$posterior)
  constant <- length(unique(as.vector(x)))==1L && length(unique(exact[[nm]]))==1L
  mcse <- if (constant) 0 else mcse_batch(x)
  draws <- posterior::as_draws_array(array(x, dim=c(2000L,4L,1L),
    dimnames=list(NULL,NULL,nm)))
  rh <- if (constant) NA_real_ else posterior::rhat(draws)[[1]]
  eb <- if (constant) NA_real_ else posterior::ess_bulk(draws)[[1]]
  et <- if (constant) NA_real_ else posterior::ess_tail(draws)[[1]]
  tol <- max(1e-3,6*mcse)
  data.frame(target=nm,exact=expectation,mc_mean=mean(x),mcse=mcse,
    tolerance=tol,difference=abs(mean(x)-expectation),rhat=rh,
    ess_bulk=eb,ess_tail=et,constant=constant)
}))
summary$mean_pass <- summary$difference <= summary$tolerance
summary$diagnostic_pass <- with(summary,constant |
  (!is.na(rhat) & rhat < 1.01 & ess_bulk >= 400 & ess_tail >= 400))
write.csv(summary,file.path(outdir,"conditional_comparison.csv"),row.names=FALSE)
save_json(list(status=if(all(summary$mean_pass & summary$diagnostic_pass)) "pass_conditioned" else "inconclusive",
  continuous_fixed=list(tau=.5,nu=.5,Dobs=1),chains=4L,iterations=2000L,
  seconds=as.numeric(difftime(Sys.time(),start,units="secs")),
  all_mean_pass=all(summary$mean_pass),all_diagnostic_pass=all(summary$diagnostic_pass)),
  "comparison_result.json")
cat("conditioned comparison complete:", all(summary$mean_pass),
    all(summary$diagnostic_pass),"\n")
