# Analyze one completed Stan run without changing the original draws or CSVs.
source("R/experimental/mebane_ad_long/stan_bridge.R")

ad_postprocess_stan <- function(run_dir,out) {
  start <- Sys.time()
  ad_new_dir(out)
  root <- "quality_reports/results/mebane_gates/coordination/2026-10-01_ad_long_stan"
  contract_path <- file.path(root,"contract_stan_diagnostics.json")
  data_path <- "quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/data/run-20260930T235038Z-pid61600/dc2010_ad_data.rds"
  consumed <- c(file.path(run_dir,c("draws_array.rds","sampler_diagnostics.rds","timing.json","manifest.json","supervisor_finished.json")),
                contract_path,file.path(root,"contract.json"),data_path,
                "R/experimental/mebane_ad_long/stan_bridge.R",
                "R/experimental/mebane_ad_long/postprocess_stan.R")
  ad_snapshot(consumed,file.path(out,"sources"))
  original <- jsonlite::read_json(file.path(run_dir,"manifest.json"),simplifyVector=FALSE)
  stopifnot(original$status=="sampling_completed_precision_not_assessed")
  for (f in original$artifacts) stopifnot(ad_sha(f$path)==f$sha256)
  outer <- jsonlite::read_json(file.path(run_dir,"supervisor_finished.json"),simplifyVector=TRUE)
  stopifnot(outer$exit_code==0L,!outer$timed_out)
  timing <- jsonlite::read_json(file.path(run_dir,"timing.json"),simplifyVector=TRUE)
  payload <- readRDS(data_path)
  draws <- readRDS(file.path(run_dir,"draws_array.rds"))
  sampler <- readRDS(file.path(run_dir,"sampler_diagnostics.rds"))
  checks <- ad_stan_sampler_checks(draws,sampler)
  write.csv(checks$chain_diagnostics,file.path(out,"HMC_by_chain.csv"),row.names=FALSE)
  write.csv(checks$internal_diagnostics,file.path(out,"NCP_diagnostics.csv"),row.names=FALSE)
  ad_json(ad_stan_functional_checks(draws,payload),file.path(out,"GQ_joint_checks.json"))
  rb <- do.call(rbind,lapply(c("M_RB_total","S_RB_total"),function(name)
    ad_diagnostic_row(as.matrix(draws[,,name]),name,"Rao_Blackwell_secondary",mandatory=FALSE)))
  write.csv(rb,file.path(out,"RB_diagnostics.csv"),row.names=FALSE)
  view <- file.path(out,"common_view")
  ad_new_dir(view)
  contract_sha <- ad_sha(contract_path)
  raw_path <- file.path(view,"raw_chains.rds")
  saveRDS(list(model="D",draws=ad_stan_common(draws),contract_sha256=contract_sha,
               seeds=rep(1001261L,4),adaptation_adequate=checks$pass,
               flag_definition="All HMC and NCP checks passed, not JAGS end.adaptation",
               original_draws_sha256=ad_sha(file.path(run_dir,"draws_array.rds"))),raw_path)
  ad_json(list(model="D",raw_sha256=ad_sha(raw_path),
               elapsed_seconds=timing$generation_wall_seconds,
               timing_definition="Stan sample call only; compilation, R loading and persistence separately reported"),
          file.path(view,"run_result.json"))
  ad_json(list(model="D",contract_sha256=contract_sha,data_sha256=ad_sha(data_path),
               engine="Stan",base_seed=1001261L,chain_ids=1:4,
               chains_are_distinct_streams=TRUE),file.path(view,"sampling_metadata.json"))
  bridge_seconds <- as.numeric(difftime(Sys.time(),start,units="secs"))
  common <- ad_process_draws(view,data_path,contract_path,file.path(out,"common_diagnostics"))
  result <- list(status=common$status,engine="Stan_D",shape=dim(draws),
                 HMC_checks_pass=all(checks$chain_diagnostics$divergences==0 &
                      checks$chain_diagnostics$treedepth_hits==0 &
                      is.finite(checks$chain_diagnostics$ebfmi) & checks$chain_diagnostics$ebfmi>=.3),
                 NCP_failed=sum(!checks$internal_diagnostics$diagnostic_pass),
                 internal_targets=nrow(checks$internal_diagnostics),
                 common_result=common,bridge_seconds=bridge_seconds,
                 total_internal_seconds=as.numeric(difftime(Sys.time(),start,units="secs")),
                 production_approved=FALSE,G10_approved=FALSE)
  ad_json(result,file.path(out,"result.json"))
  ad_manifest(out,note="Exact D augmented-posterior diagnostics; HMC, continuous, discrete and secondary RB statuses kept separate")
  invisible(result)
}

if (sys.nframe()==0L) {
  args <- commandArgs(trailingOnly=TRUE)
  stopifnot(length(args)==2L)
  ad_postprocess_stan(args[1],args[2])
}
