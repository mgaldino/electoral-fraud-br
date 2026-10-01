# Synthetic result-state fixtures only; no posterior sampling.
source("R/experimental/mebane_ad/io.R")
ad_setup()
args <- commandArgs(trailingOnly=TRUE)
stopifnot(length(args)==3L)
contract <- args[1]; data <- args[2]; out <- args[3]
ad_new_dir(out)
ad_snapshot(c(contract,data,"R/experimental/mebane_ad/compare_runs.R",
              "R/experimental/mebane_ad/io.R","tests/mebane/ad_study/test_comparison.R"),
            file.path(out,"sources"))
cases <- c("success","generation_timeout","diagnostic_failure","no_outputs")
for (case in cases) {
  root <- file.path(out,case)
  ad_new_dir(root)
  ad_json(list(synthetic=TRUE),file.path(root,"execution.json"))
  for (model in c("A","D")) {
    log <- file.path(root,paste0(model,".log"))
    writeLines("Synthetic fixture, not an empirical fit",log)
    record <- list(returncode=0L,timed_out=FALSE,elapsed_seconds=20,
                   log=log,log_sha256=ad_sha(log))
    if(case=="generation_timeout" && model=="D") record$timed_out <- TRUE
    ad_json(record,file.path(root,paste0(model,"_supervisor.json")))
    record$timed_out <- FALSE
    record$elapsed_seconds <- 5
    if(case=="diagnostic_failure" && model=="D") record$returncode <- 2L
    ad_json(record,file.path(root,paste0(model,"_diagnostics_supervisor.json")))
    if(case=="no_outputs") next
    raw <- file.path(root,model); post <- file.path(root,paste0(model,"_diagnostics"))
    ad_new_dir(raw); ad_new_dir(post)
    ad_json(list(status="sampled_not_diagnosed",adaptation_adequate=TRUE,elapsed_seconds=15,
                 phases=list(setup=list(elapsed=1),compile=list(elapsed=1),adapt=list(elapsed=2),
                   burn=list(elapsed=4),sample=list(elapsed=6),persist_raw=list(elapsed=1))),
            file.path(raw,"run_result.json"))
    ad_json(list(status="diagnostics_met_for_this_model",elapsed_seconds=3,
                 mandatory_targets=23,failed_targets=0,undefined_required_targets=0),
            file.path(post,"diagnostic_result.json"))
    tab <- data.frame(target=c("pi[1]","pi[2]","pi[3]","M_total","S_total"),
                      group="global",rhat=1,ess_bulk=800,ess_tail=600,mean=1)
    write.csv(tab,file.path(post,"diagnostics.csv"),row.names=FALSE)
    cl <- data.frame(precinct=rep("SYNTHETIC",3),class=1:3,probability=c(.8,.1,.1),
                     modal=c(TRUE,FALSE,FALSE))
    write.csv(cl,file.path(post,"class_probabilities.csv"),row.names=FALSE)
    ad_manifest(raw);ad_manifest(post)
  }
  result_dir <- file.path(out,paste0(case,"_comparison"))
  status <- system2("Rscript",c("--vanilla","R/experimental/mebane_ad/compare_runs.R",
                               root,contract,data,result_dir),
                    stdout=file.path(out,paste0(case,".log")),
                    stderr=file.path(out,paste0(case,".log")))
  stopifnot(status==0)
  result <- jsonlite::read_json(file.path(result_dir,"comparison_result.json"),simplifyVector=TRUE)
  expected <- if(case=="success") "exploratory-comparison-only" else "computationally_inconclusive"
  stopifnot(identical(result$status,expected), !result$production_approved, !result$G10_approved)
  if (case=="success") {
    timing <- read.csv(file.path(result_dir,"timings_diagnostics.csv"))
    common <- read.csv(file.path(result_dir,"common_functionals.csv"))
    stopifnot(all(timing$end_to_end_compute_seconds==25),
              all(common$ess_bulk_per_generation_process_second==40),
              all(common$ess_bulk_per_end_to_end_compute_second==32),
              all(abs(common$ess_tail_per_sampling_second-100)<1e-12))
  }
}
ad_json(list(status="pass",cases=cases,synthetic=TRUE,empirical_MCMC=FALSE),file.path(out,"result.json"))
ad_manifest(out,note="Synthetic reporter decision/timing tests; never empirical estimates")
cat("PASS four reporting cases and denominator arithmetic; synthetic only\n")
