# Compare retained outputs, separating model sensitivity from engine agreement.
source("R/experimental/mebane_ad/io.R")
ad_setup()
args <- commandArgs(trailingOnly=TRUE)
stopifnot(length(args)==1L)
out <- args[1]
ad_new_dir(out)
old <- "quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study"
new <- "quality_reports/results/mebane_gates/coordination/2026-10-01_ad_long_stan"
inputs <- "R/experimental/mebane_ad_long/compare_engines.R"
read_j <- function(path) {
  if (!file.exists(path)) return(NULL)
  inputs <<- c(inputs,path)
  jsonlite::read_json(path,simplifyVector=TRUE)
}
read_c <- function(path) {
  if (!file.exists(path)) return(NULL)
  inputs <<- c(inputs,path)
  read.csv(path,check.names=FALSE,stringsAsFactors=FALSE)
}
num <- function(x) if (is.null(x)||length(x)!=1L) NA_real_ else as.numeric(x)
extreme <- function(x,f) if(any(is.finite(x))) f(x[is.finite(x)]) else NA_real_
definitions <- data.frame(id=c("A_JAGS_2k","D_JAGS_2k","A_JAGS_20k","D_JAGS_20k","D_Stan_2k"),
                         model=c("A","D","A","D","D"),engine=c(rep("JAGS",4),"Stan"),
                         iterations=c(2000,2000,20000,20000,2000),stringsAsFactors=FALSE)
tables <- list(); rows <- list(); groups <- list()
for (i in seq_len(nrow(definitions))) {
  id <- definitions$id[i];model <- definitions$model[i]
  if (definitions$engine[i]=="JAGS") {
    base <- file.path(if(i<=2) old else new,if(i<=2) "pilot01" else "jags20k01")
    r <- read_j(file.path(base,model,"run_result.json"))
    gen <- read_j(file.path(base,paste0(model,"_supervisor.json")))
    post <- read_j(file.path(base,paste0(model,"_diagnostics_supervisor.json")))
    result <- read_j(file.path(base,paste0(model,"_diagnostics"),"diagnostic_result.json"))
    table <- read_c(file.path(base,paste0(model,"_diagnostics"),"diagnostics.csv"))
    completed <- isTRUE(gen$returncode==0L)&&isTRUE(post$returncode==0L)&&
      identical(gen$timed_out,FALSE)&&identical(post$timed_out,FALSE)&&!is.null(result)
    generation <- num(gen$elapsed_seconds);post_seconds <- num(post$elapsed_seconds)
    compilation <- num(r$phases$compile$elapsed);sampling <- num(r$phases$sample$elapsed)
    warmup <- num(r$phases$burn$elapsed);adapt <- num(r$phases$adapt$elapsed)
    adaptation <- isTRUE(r$adaptation_adequate)
    hmc_pass <- NA; ncp_fail <- NA_real_
  } else {
    base <- file.path(new,"stan2k01")
    gen <- read_j(file.path(base,"supervisor_finished.json"))
    tm <- read_j(file.path(base,"timing.json"))
    post <- read_j(file.path(new,"stan_diagnostics01_supervisor.json"))
    result <- read_j(file.path(new,"stan_diagnostics01/common_diagnostics/diagnostic_result.json"))
    extended <- read_j(file.path(new,"stan_diagnostics01/result.json"))
    table <- read_c(file.path(new,"stan_diagnostics01/common_diagnostics/diagnostics.csv"))
    completed <- isTRUE(gen$exit_code==0L)&&isTRUE(post$returncode==0L)&&
      identical(gen$timed_out,FALSE)&&identical(post$timed_out,FALSE)&&!is.null(result)
    generation <- num(gen$wall_seconds);post_seconds <- num(post$elapsed_seconds)
    compilation <- num(tm$compilation_seconds_separate)
    ct <- read_c(file.path(base,"chain_timing.csv"))
    sampling <- if(!is.null(ct)&&"sampling" %in% names(ct))sum(ct$sampling) else NA_real_
    warmup <- if(!is.null(ct)&&"warmup" %in% names(ct))sum(ct$warmup) else NA_real_
    adapt <- NA_real_; adaptation <- NA
    hmc_pass <- if(is.null(extended))NA else isTRUE(extended$HMC_checks_pass)
    ncp_fail <- num(extended$NCP_failed)
  }
  tables[[id]] <- table
  globals <- if(!is.null(table)) table[table$group=="global",] else NULL
  total <- generation+post_seconds+if(definitions$engine[i]=="Stan") compilation else 0
  rows[[id]] <- data.frame(definitions[i,],completed=completed,chains=4,
       adaptation_adequate=adaptation,HMC_pass=hmc_pass,NCP_failed=ncp_fail,
       generation_process_seconds=generation,diagnostic_process_seconds=post_seconds,
       compilation_seconds=compilation,compilation_is_inside_generation=definitions$engine[i]=="JAGS",
       sampling_seconds=sampling,warmup_seconds=warmup,adaptation_seconds=adapt,
       total_compute_including_compilation_seconds=total,
       max_global_Rhat=extreme(globals$rhat,max),min_global_bulk_ESS=extreme(globals$ess_bulk,min),
       min_global_tail_ESS=extreme(globals$ess_tail,min),
       global_failures=if(is.null(globals))NA else sum(!globals$diagnostic_pass),
       mandatory_targets=num(result$mandatory_targets),failed_targets=num(result$failed_targets),
       undefined_targets=num(result$undefined_required_targets),
       status=if(is.null(result))"not_available" else result$status)
  if(!is.null(table)) {
    for(g in unique(table$group[table$mandatory])) {
      t <- table[table$mandatory & table$group==g,]
      groups[[paste(id,g)]] <- data.frame(id=id,group=g,targets=nrow(t),
        failed=sum(!t$diagnostic_pass),undefined=sum(!is.finite(t$rhat)|!is.finite(t$ess_bulk)|!is.finite(t$ess_tail)),
        max_Rhat=extreme(t$rhat,max),min_bulk_ESS=extreme(t$ess_bulk,min),min_tail_ESS=extreme(t$ess_tail,min))
    }
  }
}
runtime <- do.call(rbind,rows)
common <- do.call(rbind,lapply(names(tables),function(id) {
  t <- tables[[id]];if(is.null(t))return(NULL)
  t <- t[t$group=="global",]
  t$id <- id
  denom <- runtime$total_compute_including_compilation_seconds[runtime$id==id]
  t$bulk_ESS_per_total_compute_second <- t$ess_bulk/denom
  t$tail_ESS_per_total_compute_second <- t$ess_tail/denom
  t
}))
engine <- NULL
if(all(c("D_JAGS_20k","D_Stan_2k") %in% names(tables)) &&
   !is.null(tables$D_JAGS_20k)&&!is.null(tables$D_Stan_2k)) {
  j <- tables$D_JAGS_20k;s <- tables$D_Stan_2k
  j <- j[j$group=="global",];s <- s[match(j$target,s$target),]
  stopifnot(identical(j$target,s$target))
  mcse <- sqrt(j$mcse_mean^2+s$mcse_mean^2)
  engine <- data.frame(target=j$target,JAGS_mean=j$mean,Stan_mean=s$mean,
                      difference_Stan_minus_JAGS=s$mean-j$mean,combined_MCSE=mcse,
                      descriptive_MCSE_units=ifelse(is.finite(mcse)&mcse>0,(s$mean-j$mean)/mcse,NA_real_),
                      JAGS_target_pass=j$diagnostic_pass,Stan_target_pass=s$diagnostic_pass,
                      posterior_equivalence_demonstrated=FALSE)
  write.csv(engine,file.path(out,"D_engine_differences.csv"),row.names=FALSE)
}
write.csv(runtime,file.path(out,"timings_diagnostics.csv"),row.names=FALSE)
write.csv(do.call(rbind,groups),file.path(out,"diagnostic_groups.csv"),row.names=FALSE)
write.csv(common,file.path(out,"global_functionals.csv"),row.names=FALSE)
ad_snapshot(unique(inputs),file.path(out,"sources"))
ad_json(list(status="descriptive_comparison_no_adoption",all_five_runs_complete=all(runtime$completed),
             all_current_common_diagnostics_met=all(runtime$status[3:5]=="diagnostics_met_for_this_model"),
             old_study_unchanged=TRUE,model_A_preserved=TRUE,
             comparison_type="A versus D is model sensitivity; D JAGS versus Stan is same-target engine comparison",
             MCSE_standardized_difference_is_not_equivalence_test=TRUE,
             production_approved=FALSE,G10_approved=FALSE),file.path(out,"result.json"))
ad_manifest(out,note="Descriptive 2k/20k JAGS and exact-D Stan comparison; not proof of convergence or election inference")
