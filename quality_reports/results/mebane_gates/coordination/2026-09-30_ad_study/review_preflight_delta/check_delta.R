# Bounded independent delta: real production functions with a fake sampling engine.
root <- "/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud"
base <- "quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study"
out <- file.path(root, base, "review_preflight_delta")
.libPaths(c(file.path(root, "renv/library/macos/R-4.4/aarch64-apple-darwin20"), .libPaths()))
stopifnot(!file.exists(file.path(out, "checks_delta.json")),
          !file.exists(file.path(out, "checks_delta.log")))
sink(file.path(out, "checks_delta.log"), split=TRUE)
setwd(file.path(out, "tree"))
source("R/experimental/mebane_ad/run_jags.R")
source("R/experimental/mebane_ad/diagnostics.R")
checks <- list()
check <- function(id, ok, detail=NULL) {
  checks[[length(checks)+1L]] <<- list(id=id, pass=isTRUE(ok), detail=detail)
  cat(if (isTRUE(ok)) "PASS" else "FAIL", id, "\n")
  if (!isTRUE(ok)) stop(id)
}
contract_path <- file.path(base, "contract_v2.json")
data_path <- file.path(base, "data/run-20260930T235038Z-pid61600/dc2010_ad_data.rds")
payload <- readRDS(data_path)
contract <- jsonlite::read_json(contract_path, simplifyVector=TRUE)
real_factory <- ad_jags_engine
engine <- real_factory()
check("pure-forward-compile", identical(engine$compile, rjags::jags.model))
check("pure-forward-adapt", identical(engine$adapt, rjags::adapt))
check("pure-forward-burn", identical(engine$burn, stats::update))
check("pure-forward-sample", identical(engine$sample, rjags::coda.samples))
check("engine-version-modules-forward", identical(engine$version, as.character(rjags::jags.version())) &&
        identical(engine$modules, rjags::list.modules()))
prior <- new.env(parent=.GlobalEnv)
sys.source(file.path(root, base, "preflight_full01/sources/R/experimental/mebane_ad/run_jags.R"), prior)
for (name in c("ad_check_payload", "ad_model_data", "ad_initial_values", "ad_monitors")) {
  check(paste0("unchanged-body-", name), identical(body(get(name)), body(prior[[name]])) &&
          identical(formals(get(name)), formals(prior[[name]])))
}

test_root <- "delta_fixtures"
ad_new_dir(test_root)
calls <- list()
fail_stage <- NULL
fixture_model <- "A"
tick <- function(stage, args=list()) {
  calls[[length(calls)+1L]] <<- list(stage=stage, args=args)
  Sys.sleep(.015)
  if (identical(stage, fail_stage)) stop(paste("SYNTHETIC failure", stage))
}
ad_jags_engine <- function() {
  tick("setup")
  list(version=engine$version, package_version="SYNTHETIC-no-MCMC", modules="SYNTHETIC",
       compile=function(file, data, inits, n.chains, n.adapt, quiet) {
         tick("compile", list(file=file, data=data, inits=inits,
                              n.chains=n.chains, n.adapt=n.adapt, quiet=quiet))
         list(state=function(internal) {tick("persist_raw", list(internal=internal)); list(SYNTHETIC=TRUE)})
       },
       adapt=function(object, n.iter, end.adaptation) {
         tick("adapt", list(n.iter=n.iter, end.adaptation=end.adaptation)); TRUE
       },
       burn=function(object, n.iter, progress.bar) {
         tick("burn", list(n.iter=n.iter, progress.bar=progress.bar)); invisible(NULL)
       },
       sample=function(object, variable.names, n.iter, thin, progress.bar) {
         tick("sample", list(variable.names=variable.names, n.iter=n.iter, thin=thin,
                             progress.bar=progress.bar))
         readRDS(file.path("prior_synthetic", paste0(fixture_model, "_raw"), "raw_chains.rds"))$draws
       })
}
expected_phases <- c("setup", "compile", "adapt", "burn", "sample", "persist_raw")
for (model in c("A", "D")) {
  fixture_model <- model; fail_stage <- NULL; calls <- list()
  run_dir <- file.path(test_root, paste0(model, "_FAKE_ENGINE"))
  result <- ad_run_jags(model, contract_path, data_path, run_dir)
  check(paste(model,"success-phase-order"), identical(names(result$phases), expected_phases) &&
          result$status == "sampled_not_diagnosed" &&
          identical(vapply(calls, `[[`, character(1), "stage"), expected_phases))
  check(paste(model,"phase-times-inclusive-internal-total"),
        all(vapply(result$phases, function(x) isTRUE(x$completed) && x$elapsed >= .01, logical(1))) &&
          result$elapsed_seconds >= sum(vapply(result$phases, `[[`, numeric(1), "elapsed"))-.01)
  call <- calls[[2]]$args
  check(paste(model,"same-compile-args-data-inits"),
        identical(call$file, if(model=="A") contract$A$source else "models/experimental/mebane_ad/d_multinomial.jags") &&
          identical(call$data, payload[[model]]) && identical(call$inits, prior$ad_initial_values(model,payload,contract)) &&
          identical(call$n.chains, 4L) && identical(call$n.adapt,0L) && isTRUE(call$quiet))
  check(paste(model,"unchanged-iteration-and-monitor-args"),
        calls[[3]]$args$n.iter == 1000 && isTRUE(calls[[3]]$args$end.adaptation) &&
          calls[[4]]$args$n.iter == 5000 && calls[[4]]$args$progress.bar == "none" &&
          calls[[5]]$args$n.iter == 2000 && identical(calls[[5]]$args$thin,1L) &&
          identical(calls[[5]]$args$variable.names,prior$ad_monitors(model)))
  check(paste(model,"actual-input-files-match-arguments"),
        identical(readRDS(file.path(run_dir,"actual_jags_data.rds")),call$data) &&
          identical(readRDS(file.path(run_dir,"actual_initial_values.rds")),call$inits))
  raw <- readRDS(file.path(run_dir,"raw_chains.rds"))
  check(paste(model,"raw-retains-pre-persistence-phases"),
        identical(names(raw$phases),expected_phases[1:5]) &&
          identical(raw$phases,result$phases[1:5]) && result$phases$persist_raw$completed)
  check(paste(model,"internal-total-labelled-as-partial"),
        grepl("excludes R bootstrap and final result/manifest writes",result$timing_scope,fixed=TRUE))
  process_out <- file.path(test_root,paste0(model,"_processed"))
  processed <- ad_process_draws(run_dir,data_path,contract_path,process_out)
  diag <- read.csv(file.path(process_out,"diagnostics.csv"),check.names=FALSE)
  previous <- read.csv(file.path("prior_synthetic",paste0(model,"_processed"),"diagnostics.csv"),check.names=FALSE)
  old_metrics <- c("ess_bulk_per_total_run_second","ess_tail_per_total_run_second")
  new_metrics <- c("ess_bulk_per_internal_generation_second","ess_tail_per_internal_generation_second")
  check(paste(model,"ESS-denominator-columns-renamed-only"),
        all(new_metrics %in% names(diag)) && !any(old_metrics %in% names(diag)) &&
          identical(diag[setdiff(names(diag),new_metrics)],previous[setdiff(names(previous),old_metrics)]))
  check(paste(model,"ESS-denominator-exact-internal-total"),
        isTRUE(all.equal(diag[[new_metrics[1]]],diag$ess_bulk/result$elapsed_seconds,tolerance=1e-12)) &&
          isTRUE(all.equal(diag[[new_metrics[2]]],diag$ess_tail/result$elapsed_seconds,tolerance=1e-12)))
  for (file in c("joint_functionals.csv","class_probabilities.csv")) {
    check(paste(model,"unchanged",file),
          identical(ad_sha(file.path(process_out,file)),ad_sha(file.path("prior_synthetic",paste0(model,"_processed"),file))))
  }
  if (model == "D") check("unchanged-D-secondary-counts",
                          identical(readRDS(file.path(process_out,"secondary_counts_by_unit.rds")),
                                    readRDS("prior_synthetic/D_processed/secondary_counts_by_unit.rds")))
  check(paste(model,"same-targets-verdict-no-pair-release"),
        processed$mandatory_targets == if(model=="A") 2171L else 1742L)
  check(paste(model,"synthetic-diagnostic-failures-not-waived"),
        processed$status=="computationally_inconclusive" &&
          processed$paired_verdict=="not_assigned_by_per_model_processor")
}
# Ordinary R errors in every phase must retain its partial duration and stop.
fixture_model <- "D"
for (phase in expected_phases) {
  fail_stage <- phase; calls <- list()
  run_dir <- file.path(test_root,paste0("FAIL_",phase))
  r <- ad_run_jags("D",contract_path,data_path,run_dir)
  prefix <- expected_phases[seq_len(match(phase,expected_phases))]
  check(paste("partial-error",phase), r$status=="error" && r$failed_stage==phase &&
          identical(names(r$phases),prefix) && !r$phases[[phase]]$completed &&
          r$phases[[phase]]$elapsed>=.01 &&
          identical(vapply(calls,`[[`,character(1),"stage"),prefix))
  events <- readLines(file.path(run_dir,"events.jsonl"))
  check(paste("failure-event-and-result",phase), any(grepl("failed_elapsed",events)) &&
          file.exists(file.path(run_dir,"run_result.json")) && file.exists(file.path(run_dir,"manifest.json")))
}
fail_stage <- NULL
missing <- ad_run_jags("A",contract_path,paste0(data_path,".missing"),file.path(test_root,"FAIL_input_read"))
check("input-read-error-is-setup-with-partial-time",missing$status=="error" &&
        missing$failed_stage=="setup" && identical(names(missing$phases),"setup") &&
        !missing$phases$setup$completed && missing$phases$setup$elapsed>=0)
ad_jags_engine <- real_factory
ad_json(list(status="pass",checks=checks,created_utc=format(Sys.time(),tz="UTC",usetz=TRUE),
             reviewer_id="01a0f4b8-962b-77a3-a418-6247c6219e8b",empirical_MCMC=FALSE,
             engine_real_functions_invoked=FALSE,synthetic_draws_reused=TRUE,
             R=R.version.string,JAGS=engine$version),file.path(out,"checks_delta.json"))
cat("PASS",length(checks),"delta checks; no MCMC; prior draws reused\n")
sink()
