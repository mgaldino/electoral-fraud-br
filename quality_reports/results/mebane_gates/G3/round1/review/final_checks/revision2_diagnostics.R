args <- commandArgs(trailingOnly=TRUE)
stopifnot(length(args)==1L,!dir.exists(args[1]))
out <- args[1];dir.create(out,recursive=TRUE)
base <- "quality_reports/results/mebane_gates/G3/round1"
source(file.path(base,"review/final_checks/diagnostic_helpers.R"))
raw_path <- file.path(base,"revision2/raw_chains.rds")
stopifnot(digest::digest(file=raw_path,algo="sha256")=="66ddb0aaef7448b25e817e25c931d5608ee9c7141165842613925e9e145baf6d")
payload <- readRDS(raw_path)
checks <- list()
record <- function(id,ok,value=NULL)checks[[length(checks)+1L]]<<-list(id=id,pass=isTRUE(ok),value=value)
near <- function(a,b)all((is.na(a)&is.na(b)) | (!is.na(a)&!is.na(b)&abs(a-b)<=1e-12+1e-10*abs(b)))
record("source_hash",identical(payload$model_sha256,digest::digest(file=payload$model_path,algo="sha256")))
record("protocol_hash",identical(payload$protocol_sha256,digest::digest(file=payload$protocol_path,algo="sha256")))
record("seeds_inits_exact",identical(payload$seeds,31102:31105) &&
  identical(vapply(payload$inits,function(x)x$.RNG.seed,integer(1)),31102:31105) &&
  all(vapply(payload$inits,function(x)identical(x$.RNG.name,"base::Mersenne-Twister"),logical(1))))
record("sampling_schedule",payload$adapt==200L && payload$burnin==500L &&
  payload$post_iterations_per_chain==2000L && payload$thin==1L && payload$chains==4L)
raw <- payload$draws
record("four_chain_shape",inherits(raw,"mcmc.list") && length(raw)==4L &&
  all(vapply(raw,nrow,integer(1))==2000L) && all(vapply(raw,ncol,integer(1))==5L))
record("mcpar_701_2700_thin1",all(vapply(raw,function(x)identical(as.numeric(attr(x,"mcpar")),c(701,2700,1)),logical(1))))
d <- payload$data
record("conditioned_response_case",d$n==1L && d$N==1L && d$a==0L && d$w==0L)
record("pi_auxiliary_case",identical(c(d$pi.aux1,d$pi.aux2,d$pi.aux3),c(1,.5,.25)))
record("six_designs",all(vapply(d[c("Xa","Xw","X.iota.m","X.iota.s","X.chi.m","X.chi.s")],
  function(x)identical(dim(x),c(1L,1L)) && all(x==1),logical(1))))
record("continuous_effects_beta0_conditioned",all(unlist(d[c("th","nh","imh","ish","cmh","csh",
  "beta.tau1","beta.nu1","beta.iota.m1","beta.iota.s1","beta.chi.m1","beta.chi.s1")])==0))
record("class_counts_not_conditioned",!any(c("Z","N.iota.m","N.iota.s","N.chi.m","N.chi.s") %in% names(d)))

draws <- lapply(raw,qa_targets)
exact <- read.csv(file.path(base,"review/attempt_20260929T164404110482Z_math/v2_conditioned_exact_states.csv"))
exact_targets <- qa_exact_targets(exact)
published <- read.csv(file.path(base,"revision2/conditional_comparison.csv"))
map <- c(r_im="N.iota.m",r_is="N.iota.s",r_cm="N.chi.m",r_cs="N.chi.s")
mapped <- unname(map[published$target])
published$target <- ifelse(is.na(mapped),published$target,mapped)
rows <- list();details <- list()
for(target in colnames(draws[[1]])) {
  x <- vapply(draws,function(chain)chain[,target],numeric(2000))
  truth <- qa_exact_distribution(exact_targets[,target],exact$probability)
  batch <- qa_batch_mcse(x,50)
  rh <- if(truth$constant)NA_real_ else posterior::rhat(x)
  eb <- if(truth$constant)NA_real_ else posterior::ess_bulk(x)
  et <- if(truth$constant)NA_real_ else posterior::ess_tail(x)
  constant_match <- truth$constant && all(x==truth$support[1])
  diag <- if(truth$constant)constant_match else is.finite(rh)&&is.finite(eb)&&is.finite(et)&&rh<1.01&&eb>=400&&et>=400
  error <- abs(mean(x)-truth$mean)
  threshold <- max(1e-3,6*batch$mcse)
  rows[[length(rows)+1L]] <- data.frame(target=target,exact=truth$mean,mc_mean=mean(x),mcse=batch$mcse,
    difference=error,tolerance=threshold,mean_pass=error<=threshold,rhat=rh,ess_bulk=eb,ess_tail=et,
    constant=truth$constant,diagnostic_pass=diag,
    tail_indicator_degenerate=truth$q05_indicator_constant||truth$q95_indicator_constant)
  old <- published[published$target==target,]
  record(paste0("published_summary_",target),nrow(old)==1L &&
    near(unlist(rows[[length(rows)]][1,c("exact","mc_mean","mcse","difference","tolerance","rhat","ess_bulk","ess_tail")]),
         unlist(old[1,c("exact","mc_mean","mcse","difference","tolerance","rhat","ess_bulk","ess_tail")])) &&
    identical(old$constant,truth$constant) && identical(old$mean_pass,error<=threshold) && identical(old$diagnostic_pass,diag))
  details[[target]] <- list(exact=truth,mcse_sensitivity=lapply(c(25L,50L,100L),function(b){
    z<-qa_batch_mcse(x,b)
    list(batch_size=b,mcse=z$mcse,lag1_batch_acf=apply(z$batch_means,2,function(v)
      if(length(unique(v))==1L)NA_real_ else unname(acf(v,plot=FALSE,lag.max=1)$acf[2])))
  }),chain_means=colMeans(x),chain_variances=apply(x,2,var),
    inference_limit="conditioned discrete problem only; batch sensitivity does not replace frozen acceptance rule")
}
result <- do.call(rbind,rows)
write.csv(result,file.path(out,"independent_comparison.csv"),row.names=FALSE)
joint <- read.csv(file.path(base,"revision2/functionals_by_draw.csv"))
combined <- do.call(rbind,draws)
record("8000_joint_rows",nrow(joint)==8000 && !anyDuplicated(joint[c("chain","iteration")]) &&
  identical(joint$chain,rep(1:4,each=2000)) && identical(joint$iteration,rep(1:2000,4)))
for(n in c("Z","r_im","r_is","r_cm","r_cs","M","S","margin_lower","margin_upper")) {
  target <- if(n %in% names(map))unname(map[n]) else n
  record(paste0("per_draw_",n),near(joint[[n]],combined[,target]))
}
record("margin_physical_flags",all(!joint$observed_margin_compatible) &&
  all(!joint$physical_counterfactual_validated) && all(joint$leader_capacity_necessary==(combined[,"M"]+combined[,"S"]<=0)))
record("S_constant_exact_and_sampled",all(exact_targets[exact$probability>0,"S"]==0) && all(combined[,"S"]==0))
new_exact <- read.csv(file.path(base,"revision2/conditional_exact_states.csv"))
names(exact)[match(c("rm","rs","cm","cs"),names(exact))]<-c("r_im","r_is","r_cm","r_cs")
j<-merge(new_exact,exact,by=c("Z","r_im","r_is","r_cm","r_cs"),suffixes=c("_candidate","_independent"))
record("48_states_match",nrow(j)==48L&&near(j$posterior,j$probability)&&near(j$M_candidate,j$M_independent)&&near(j$S_candidate,j$S_independent))
jsonlite::write_json(details,file.path(out,"diagnostic_details.json"),pretty=TRUE,auto_unbox=TRUE,digits=17,na="null")
jsonlite::write_json(list(checks=checks,failed=sum(!vapply(checks,function(x)x$pass,logical(1))),
  all_mean_pass=all(result$mean_pass),all_diagnostic_pass=all(result$diagnostic_pass),
  missing_tail_ess_targets=result$target[is.na(result$ess_tail)&!result$constant],
  raw_draws_sha256=digest::digest(file=raw_path,algo="sha256"),no_MCMC_run=TRUE,
  finite_rhat_max=max(result$rhat,na.rm=TRUE),bulk_ess_min=min(result$ess_bulk,na.rm=TRUE),
  finite_tail_ess_min=min(result$ess_tail,na.rm=TRUE)),
  file.path(out,"checks.json"),pretty=TRUE,auto_unbox=TRUE,digits=17,na="null")
for(n in c("ess_tail.default",".ess_quantile","should_return_NA"))writeLines(deparse(get(n,asNamespace("posterior"))),file.path(out,paste0(n,".R")))
writeLines(capture.output(sessionInfo()),file.path(out,"session_info.txt"))
stopifnot(all(vapply(checks,function(x)x$pass,logical(1))))
