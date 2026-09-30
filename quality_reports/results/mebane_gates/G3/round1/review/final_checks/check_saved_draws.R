args <- commandArgs(trailingOnly=TRUE)
stopifnot(length(args)==4L)
# Run only after binding args[1] to the user-provided candidate manifest.
draw_path <- args[1]; exact_path <- args[2]; out <- args[3]; helper <- args[4]
source(helper)
stopifnot(!dir.exists(out))
dir.create(out,recursive=TRUE)
raw <- readRDS(draw_path)
stopifnot(inherits(raw,"mcmc.list"),length(raw)==4L,
          all(vapply(raw,nrow,integer(1))==2000L))
draws <- lapply(raw,qa_targets)
stopifnot(all(vapply(draws,function(x)identical(colnames(x),colnames(draws[[1]])),logical(1))))
exact <- read.csv(exact_path)
targets_exact <- qa_exact_targets(exact)
rows <- list(); detail <- list()
for(target in colnames(draws[[1]])) {
  x <- vapply(draws,function(chain)chain[,target],numeric(2000))
  truth <- qa_exact_distribution(targets_exact[,target],exact$probability)
  batch <- qa_batch_mcse(x,50)
  rhat <- posterior::rhat(x)
  bulk <- posterior::ess_bulk(x)
  tail <- posterior::ess_tail(x)
  exact_constant_match <- truth$constant && all(x==truth$support[1])
  diag_satisfied <- if(truth$constant) exact_constant_match else
    is.finite(rhat) && is.finite(bulk) && is.finite(tail) && rhat<1.01 && bulk>=400 && tail>=400
  error <- abs(mean(x)-truth$mean)
  threshold <- max(1e-3,6*batch$mcse)
  rows[[length(rows)+1L]] <- data.frame(target=target,exact=truth$mean,mc_mean=mean(x),
    error=error,mcse=batch$mcse,mean_threshold=threshold,mean_within=error<=threshold,
    exact_constant=truth$constant,empirical_constant=length(unique(as.vector(x)))==1L,
    constant_matches_exact=exact_constant_match,Rhat=rhat,ESS_bulk=bulk,ESS_tail=tail,
    v2_diagnostic_satisfied=diag_satisfied,
    diagnostic_interpretation=if(truth$constant)"analytical_constant" else if(is.na(tail) &&
      (truth$q05_indicator_constant||truth$q95_indicator_constant))"tail_indicator_degeneracy_not_mixing_failure" else "inspect_diagnostics",
    margin_interpretation=if(grepl("margin",target))"algebraic_Dobs_offset_not_feasible_electoral_margin" else "not_margin")
  sensitivity <- lapply(c(25L,50L,100L),function(b){
    z <- qa_batch_mcse(x,b)
    list(batch_size=b,mcse=z$mcse,
      lag1_batch_acf=apply(z$batch_means,2,function(v)if(length(unique(v))==1)NA_real_ else
        unname(stats::acf(v,plot=FALSE,lag.max=1)$acf[2])))
  })
  detail[[target]] <- list(exact=truth,mcse_sensitivity=sensitivity,
    quantiles=as.numeric(quantile(x,c(.025,.5,.975))),
    chain_means=colMeans(x),chain_variances=apply(x,2,var))
}
write.csv(do.call(rbind,rows),file.path(out,"independent_comparison.csv"),row.names=FALSE)
jsonlite::write_json(detail,file.path(out,"diagnostic_details.json"),pretty=TRUE,auto_unbox=TRUE,digits=17,na="null")
writeLines(capture.output(sessionInfo()),file.path(out,"session_info.txt"))
for(n in c("ess_tail.default",".ess_quantile","should_return_NA")) {
  writeLines(deparse(get(n,asNamespace("posterior"))),file.path(out,paste0(n,".R")))
}
jsonlite::write_json(list(draws_sha256=digest::digest(file=draw_path,algo="sha256"),
  exact_sha256=digest::digest(file=exact_path,algo="sha256"),scope="same conditioned N=1 A=0 W=0 problem only",
  no_MCMC_run=TRUE,no_diagnostic_threshold_relaxation=TRUE,
  no_gate_decision=TRUE),file.path(out,"scope.json"),pretty=TRUE,auto_unbox=TRUE)
