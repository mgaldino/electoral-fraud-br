args <- commandArgs(trailingOnly=TRUE)
stopifnot(length(args)==1L,!dir.exists(args[1]))
out <- args[1];dir.create(out,recursive=TRUE)
base <- "quality_reports/results/mebane_gates/G3/round1"
code <- file.path(base,"revision1/snapshots/R/lib/mebane_model.R")
source(code)
protocol <- jsonlite::fromJSON(file.path(base,"review/preparation/protocol.json"),simplifyVector=FALSE)
own <- read.csv(file.path(base,"review/attempt_20260929T164404110482Z_math/kernel_cells.csv"))
checks <- list();numeric_checks <- list()
record <- function(id,ok,value=NULL)checks[[length(checks)+1L]]<<-list(id=id,pass=isTRUE(ok),value=value)
for(j in seq_len(nrow(own))) {
  r <- own[j,];p <- protocol$math$parameter_sets[[r$parameter_set]]
  full <- mebane_enumerate(r$N,r$A,r$W,p$tau,p$nu,unlist(p$q),unlist(p$pi))
  pair <- mebane_factorized(r$N,r$A,r$W,p$tau,p$nu,unlist(p$q),unlist(p$pi))
  numeric_checks[[j]] <- data.frame(r[,c("parameter_set","N","A","W")],independent=r$kernel_zero_invalid,
    candidate_full=full,candidate_factorized=pair,max_error=max(abs(c(full,pair)-r$kernel_zero_invalid)))
}
numeric_result <- do.call(rbind,numeric_checks)
write.csv(numeric_result,file.path(out,"independent_kernel_comparison.csv"),row.names=FALSE)
record("all_87_cells_independent_tolerance_1e12",all(numeric_result$max_error<=1e-12),max(numeric_result$max_error))
published <- read.csv(file.path(base,"deterministic_attempt3/enumeration.csv"))
joined <- merge(published,own[own$parameter_set==3,],by=c("N","A","W"))
record("published_29_cells_recomputed",nrow(joined)==29 && all(abs(joined$complete-joined$kernel_zero_invalid)<=1e-12))
exact <- read.csv(file.path(base,"jags_attempt5/conditional_exact_states.csv"))
ref <- read.csv(file.path(base,"review/attempt_20260929T164404110482Z_math/v2_conditioned_exact_states.csv"))
names(ref)[match(c("rm","rs","cm","cs"),names(ref))] <- c("r_im","r_is","r_cm","r_cs")
joined <- merge(exact,ref,by=c("Z","r_im","r_is","r_cm","r_cs"),suffixes=c("_candidate","_independent"))
record("all_48_joint_states",nrow(joined)==48 && max(abs(joined$posterior-joined$probability))<=1e-12)
record("joint_M_and_S_per_state",all(abs(joined$M_candidate-joined$M_independent)<=1e-12) &&
  all(abs(joined$S_candidate-joined$S_independent)<=1e-12))
record("S_zero_positive_support",all(exact$S[exact$posterior>0]==0))
record("Dobs_algebraic_flag",all(!exact$observed_margin_compatible),"N=1,A=0,W=0 cannot have observed leader margin +1")
write.csv(joined,file.path(out,"exact_joint_states_comparison.csv"),row.names=FALSE)

generated <- mebane_attempts(32,31101,3)
published_generation <- read.csv(file.path(base,"deterministic_attempt3/generation_attempts.csv"))
record("generation_32_rows_reproduce",isTRUE(all.equal(generated,published_generation,check.attributes=FALSE,tolerance=1e-12)))
record("generator_keeps_attempt_ids",identical(generated$attempt,1:32))
record("generation_status_strict_support",all(generated$status==ifelse(!is.finite(generated$pa)|!is.finite(generated$pw)|
  generated$pa<0|generated$pa>1|generated$pw<0|generated$pw>1,"invalid_probability",
  ifelse(generated$A+generated$W>generated$N,"invalid_physical","valid"))))
write.csv(generated,file.path(out,"reproduced_generation.csv"),row.names=FALSE)

joint <- read.csv(file.path(base,"deterministic_attempt3/joint_input.csv"))
recorded <- read.csv(file.path(base,"deterministic_attempt3/joint_functionals.csv"))
outputs <- mebane_joint_functionals(joint)
Munit <- numeric(nrow(joint));Sunit <- numeric(nrow(joint))
for(i in seq_len(nrow(joint))) {
  x <- joint[i,]
  r <- if(x$Z==1)0 else if(x$Z==2)x$r_im else x$r_cm
  m <- if(x$Z==1)0 else if(r==x$N).999 else r/x$N
  s <- if(x$Z==1)0 else if(x$Z==2)x$r_is/x$N else x$r_cs/x$N
  Munit[i] <- x$N*m*(1-x$tau);Sunit[i] <- x$N*s*x$tau*(1-x$nu)
}
truth <- aggregate(cbind(M=Munit,S=Sunit),list(draw=joint$draw),sum)
record("joint_aggregation_independent",all(abs(outputs$M-truth$M)<=1e-12) && all(abs(outputs$S-truth$S)<=1e-12))
record("joint_published_reproduced",isTRUE(all.equal(outputs,recorded,check.attributes=FALSE,tolerance=1e-12)))
record("margin_flags_no_clipping",all(!outputs$observed_margin_compatible) && all(!outputs$physical_counterfactual_validated))

floating <- data.frame(N=3,A=3,rm=c(2,3,3),rs=c(1,1,2))
floating$pW <- vapply(seq_len(3),function(i)mebane_probabilities(3,3,2,c(floating$rm[i],floating$rs[i],0,0),.5,1)["pw"],numeric(1))
floating$exact_rational_pW <- 0
floating$strict_numeric_valid <- floating$pW>=0 & floating$pW<=1
floating$kernel <- vapply(seq_len(3),function(i)mebane_kernel(3,3,0,2,c(floating$rm[i],floating$rs[i],0,0),.5,1),numeric(1))
record("no_clamp_on_roundoff",all(!floating$strict_numeric_valid) && all(floating$kernel==0))
write.csv(floating,file.path(out,"floating_vs_exact_boundary.csv"),row.names=FALSE)

jsonlite::write_json(list(code_sha256=digest::digest(file=code,algo="sha256"),checks=checks,
  failed=sum(!vapply(checks,function(x)x$pass,logical(1))),candidate_revision="revision1",
  no_MCMC_run=TRUE,generator_certified=FALSE),file.path(out,"checks.json"),pretty=TRUE,auto_unbox=TRUE,digits=17)
stopifnot(all(vapply(checks,function(x)x$pass,logical(1))))
