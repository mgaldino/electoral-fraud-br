# Independent review of persisted draws. Does not source either engine or processor.
root <- "/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud"
base <- file.path(root,"quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study")
out <- file.path(base,"review_results")
.libPaths(c(file.path(root,"renv/library/macos/R-4.4/aarch64-apple-darwin20"),.libPaths()))
stopifnot(!file.exists(file.path(out,"checks_results.json")),
          !file.exists(file.path(out,"checks_results_attempt2.log")))
sink(file.path(out,"checks_results_attempt2.log"),split=TRUE)
checks <- list()
check <- function(id, ok, detail=NULL) {
  checks[[length(checks)+1L]] <<- list(id=id,pass=isTRUE(ok),detail=detail)
  cat(if(isTRUE(ok)) "PASS" else "FAIL",id,"\n")
  if(!isTRUE(ok)) stop(id)
}
eq <- function(x,y,tol=1e-10) {
  if(length(x)==length(y) && all(is.na(x)) && all(is.na(y))) return(TRUE)
  isTRUE(all.equal(unname(x),unname(y),tolerance=tol,check.attributes=FALSE))
}
sha <- function(path) digest::digest(file=path,algo="sha256",serialize=FALSE)
readj <- function(path) jsonlite::read_json(path,simplifyVector=TRUE)
readc <- function(path) read.csv(path,check.names=FALSE,stringsAsFactors=FALSE)
contract <- readj(file.path(base,"contract_v2.json"))
payload <- readRDS(file.path(base,"data/run-20260930T235038Z-pid61600/dc2010_ad_data.rds"))
arch <- new.env(parent=emptyenv())
load(file.path(root,contract$case$source),envir=arch)
original <- get("dc2010",envir=arch)
N <- original$NVoters; W <- original$Votes; n <- length(N)
check("actual-source-rowmapping-no-exclusions", n==143L &&
        identical(payload$precinct,as.character(original$precinct)) && identical(payload$A$N,N) &&
        identical(payload$A$a,original$NVoters-original$NValid) && identical(payload$A$w,W) &&
        identical(unname(payload$D$observed),unname(cbind(original$a,W,original$NValid-W))))
comparison <- file.path(base,"comparison01")
runtime <- readc(file.path(comparison,"timings_diagnostics.csv"))
common <- readc(file.path(comparison,"common_functionals.csv"))
class_comp <- readc(file.path(comparison,"class_probabilities_compared.csv"))
comp <- readj(file.path(comparison,"comparison_result.json"))
blocks <- c("tau","nu","iota.m","iota.s","chi.m","chi.s")
vars <- c("tb","nb","imb","isb","cmb","csb")
global_names <- c(paste0("pi[",1:3,"]"),paste0(blocks,".alpha"),vars,
                  paste0("beta.",blocks,"1"),"M_total","S_total")
global_records <- group_records <- list()
summaries <- list()
class_prob <- list()
for(model in c("A","D")) {
  run_dir <- file.path(base,"pilot01",model)
  diag_dir <- file.path(base,"pilot01",paste0(model,"_diagnostics"))
  raw <- readRDS(file.path(run_dir,"raw_chains.rds"))
  run <- readj(file.path(run_dir,"run_result.json"))
  metadata <- readj(file.path(run_dir,"sampling_metadata.json"))
  diag_result <- readj(file.path(diag_dir,"diagnostic_result.json"))
  tab <- readc(file.path(diag_dir,"diagnostics.csv"))
  joint <- readc(file.path(diag_dir,"joint_functionals.csv"))
  classes <- readc(file.path(diag_dir,"class_probabilities.csv"))
  generation <- readj(file.path(base,"pilot01",paste0(model,"_supervisor.json")))
  post <- readj(file.path(base,"pilot01",paste0(model,"_diagnostics_supervisor.json")))
  chain <- lapply(raw$draws,as.matrix)
  check(paste(model,"raw-shape-and-chain-columns"),length(chain)==4L &&
          all(vapply(chain,nrow,integer(1))==2000L) &&
          all(vapply(chain,function(x)identical(colnames(x),colnames(chain[[1]])),logical(1))))
  check(paste(model,"iterations-thin-1"),all(vapply(raw$draws,function(x)
    identical(as.numeric(attr(x,"mcpar")[3]),1) && diff(attr(x,"mcpar")[1:2])==1999,logical(1))))
  check(paste(model,"metadata-raw-run-identity"),
        raw$model==model && metadata$model==model && run$model==model &&
          raw$contract_sha256==sha(file.path(base,"contract_v2.json")) &&
          raw$contract_sha256==metadata$contract_sha256 &&
          metadata$data_sha256==sha(file.path(base,"data/run-20260930T235038Z-pid61600/dc2010_ad_data.rds")) &&
          identical(as.integer(raw$seeds),as.integer(contract$paired_design$chain_seeds)) &&
          run$raw_sha256==sha(file.path(run_dir,"raw_chains.rds")))
  check(paste(model,"actual-JAGS-inputs-identical"),identical(readRDS(file.path(run_dir,"actual_jags_data.rds")),payload[[model]]))
  inits <- readRDS(file.path(run_dir,"actual_initial_values.rds"))
  init_ok <- vapply(1:4,function(c) {
    v <- inits[[c]]
    expected_alpha <- c(qlogis(sum(N-original$a)/sum(N))+c(-.4,-.1,.1,.4)[c],
                        qlogis(sum(W)/sum(N-original$a))-c(-.4,-.1,.1,.4)[c],
                        rep(c(-1,0,1,-.5)[c],4))
    all(v$Z==1) && v$.RNG.seed==contract$paired_design$chain_seeds[c] &&
      v$.RNG.name==contract$paired_design$RNG_name &&
      eq(unlist(v[paste0(blocks,".alpha")]),expected_alpha) &&
      all(unlist(v[vars])==c(.1,.2,.3,.4)[c]) &&
      all(unlist(v[paste0("beta.",blocks,"1")])==0)
  },logical(1))
  check(paste(model,"actual-inits-and-seeds"),all(init_ok))
  check(paste(model,"completed-adapted-no-timeout"),run$status=="sampled_not_diagnosed" &&
          isTRUE(run$adaptation_adequate) && isTRUE(raw$adaptation_adequate) &&
          generation$returncode==0 && !generation$timed_out && post$returncode==0 && !post$timed_out &&
          length(run$warnings)==0 && metadata$sampling$adapt_iterations==1000 &&
          metadata$sampling$burn_iterations==5000 && metadata$sampling$post_iterations==2000)
  node <- function(name) {
    keys <- intersect(c(name,paste0(name,"[1]")),colnames(chain[[1]]))
    stopifnot(length(keys)==1L)
    do.call(cbind,lapply(chain,function(x)x[,keys]))
  }
  local <- function(name,i) node(paste0(name,"[",i,"]"))
  M <- S <- CM <- CS <- matrix(0,2000,4)
  classes_expected <- matrix(0,n,3)
  range_ok <- sampled_constants_ok <- TRUE
  class_count <- lapply(1:3,function(k)matrix(0,2000,4))
  if(model=="D") {
    counts <- readRDS(file.path(diag_dir,"secondary_counts_by_unit.rds"))
    check("D-secondary-count-shape-IDs-seed",identical(dim(counts$M),c(2000L,4L,143L)) &&
            identical(dim(counts$S),c(2000L,4L,143L)) && identical(counts$precinct,payload$precinct) &&
            counts$postprocess_seed==contract$paired_design$postprocess_seed)
    count_support <- TRUE
  }
  for(i in seq_len(n)) {
    z <- local("Z",i); tau <- local("mu.tau",i); nu <- local("mu.nu",i)
    stopifnot(all(z %in% 1:3))
    if(model=="A") {
      magnitudes <- lapply(blocks[3:6],function(b)local(paste0("N.",b),i)/N[i])
      for(b in c(1,3)) magnitudes[[b]][magnitudes[[b]]==1] <- .999
    } else magnitudes <- lapply(blocks[3:6],function(b)local(paste0("mu.",b),i))
    m <- ifelse(z==1,0,ifelse(z==2,magnitudes[[1]],magnitudes[[3]]))
    s <- ifelse(z==1,0,ifelse(z==2,magnitudes[[2]],magnitudes[[4]]))
    unit_M <- N[i]*(1-tau)*m; unit_S <- N[i]*tau*(1-nu)*s
    M <- M+unit_M; S <- S+unit_S
    for(k in 1:3) {
      x <- (z==k)*1; class_count[[k]] <- class_count[[k]]+x
      classes_expected[i,k] <- mean(x)
      row <- tab[tab$target==paste0("class_indicator[",i,",",k,"]"),]
      range_ok <- range_ok && nrow(row)==1 && eq(row$chain_mean_range,diff(range(colMeans(x))))
      sampled_constants_ok <- sampled_constants_ok && identical(row$sampled_constant,length(unique(as.vector(x)))==1L)
      cl <- classes[classes$precinct==payload$precinct[i] & classes$class==k,]
      range_ok <- range_ok && nrow(cl)==1 && eq(cl$probability,mean(x)) &&
        eq(unlist(cl[paste0("chain",1:4)]),colMeans(x))
    }
    if(model=="D") {
      pw <- tau*nu+(1-tau)*m+tau*(1-nu)*s
      stopifnot(max(abs(pw-local("p.w",i)))<1e-11,all(pw>0))
      CM <- CM+W[i]*(1-tau)*m/pw; CS <- CS+W[i]*tau*(1-nu)*s/pw
      mc <- counts$M[,,i]; sc <- counts$S[,,i]
      count_support <- count_support && all(is.finite(mc)) && all(is.finite(sc)) &&
        all(mc>=0 & sc>=0 & mc+sc<=W[i]) && all(mc==floor(mc) & sc==floor(sc))
    }
  }
  check(paste(model,"class-probabilities-indicators-ranges-constants"),range_ok && sampled_constants_ok)
  for(k in 1:3) {
    row <- tab[tab$target==paste0("class_count[",k,"]"),]
    check(paste(model,"class-count-range-over-n",k),nrow(row)==1 &&
            eq(row$chain_mean_range,diff(range(colMeans(class_count[[k]])))/n))
  }
  class_prob[[model]] <- classes
  check(paste(model,"joint-draw-order-and-M-S"),identical(joint$iteration,rep(1:2000,4)) &&
          identical(joint$chain,rep(1:4,each=2000)) && eq(joint$M,as.vector(M)) &&
          eq(joint$S,as.vector(S)) && eq(joint$M_fraction_N,as.vector(M)/sum(N)) &&
          eq(joint$S_fraction_N,as.vector(S)/sum(N)))
  if(model=="D") check("D-secondary-count-support-aggregation-conditional-means",count_support &&
    eq(joint$M_count,as.vector(apply(counts$M,c(1,2),sum))) &&
    eq(joint$S_count,as.vector(apply(counts$S,c(1,2),sum))) &&
    eq(joint$M_count_conditional_mean,as.vector(CM)) && eq(joint$S_count_conditional_mean,as.vector(CS)))
  for(name in global_names) {
    x <- if(name=="M_total") M else if(name=="S_total") S else node(name)
    q <- quantile(x,c(.025,.5,.975),names=FALSE)
    val <- c(mean=mean(x),sd=sd(as.vector(x)),q025=q[1],q50=q[2],q975=q[3],
             rhat=posterior::rhat(x),ess_bulk=posterior::ess_bulk(x),ess_tail=posterior::ess_tail(x),
             mcse_mean=posterior::mcse_mean(x),setNames(colMeans(x),paste0("chain",1:4)))
    row <- tab[tab$target==name,]
    check(paste(model,"raw-global",name),nrow(row)==1L &&
            eq(as.numeric(row[1,names(val)]),as.numeric(val)))
    global_records[[length(global_records)+1L]] <- cbind(data.frame(model=model,target=name),as.data.frame(as.list(val)))
  }
  indexed <- function(name) paste0(name,"[",1:n,"]")
  expected <- c(global_names,unlist(lapply(c(paste0("mu.",blocks),"p.a","p.w",if(model=="D")"p.o"),indexed)),
                paste0("class_count[",1:3,"]"),
                unlist(lapply(1:3,function(k)paste0("class_indicator[",1:n,",",k,"]"))),
                if(model=="A")unlist(lapply(paste0("N.",blocks[3:6]),indexed)))
  required <- tab[tab$mandatory,]
  check(paste(model,"full-mandatory-universe"),length(expected)==if(model=="A")2171L else 1742L)
  check(paste(model,"mandatory-unique-complete-no-exemptions"),
        !anyDuplicated(tab$target) && setequal(expected,required$target) &&
          nrow(required)==length(expected) && !any(tab$analytic_constant) &&
          setequal(tab$target[tab$group=="global"],global_names))
  metrics <- is.finite(tab$rhat) & is.finite(tab$ess_bulk) & is.finite(tab$ess_tail)
  passed <- metrics & tab$rhat<1.01 & tab$ess_bulk>=400 & tab$ess_tail>=400 & is.finite(tab$chain_mean_range)
  discrete <- tab$group %in% c("class_indicator","class_count")
  passed[discrete] <- passed[discrete] & tab$chain_mean_range[discrete]<=.05
  passed[is.na(passed)] <- FALSE
  check(paste(model,"every-target-v2-decision"),identical(passed,tab$diagnostic_pass) &&
          all(tab$range_limit[discrete]==.05) && all(is.na(tab$range_limit[!discrete])) &&
          all(!tab$diagnostic_pass[tab$sampled_constant]) &&
          all(tab$precision_label==ifelse(passed,"diagnostics_met_only","inconclusive")))
  failed <- sum(!passed[tab$mandatory]); undefined <- sum(!metrics[tab$mandatory])
  check(paste(model,"counts-and-per-model-verdict"),
        diag_result$mandatory_targets==nrow(required) && diag_result$failed_targets==failed &&
          diag_result$undefined_required_targets==undefined &&
          diag_result$status==if(all(passed[tab$mandatory]))"diagnostics_met_for_this_model" else "computationally_inconclusive")
  clock <- runtime[runtime$model==model,]
  check(paste(model,"timing-sources-and-no-double-count"),
        eq(clock$total_process_seconds,generation$elapsed_seconds) &&
          eq(clock$postprocess_seconds,post$elapsed_seconds) &&
          eq(clock$end_to_end_compute_seconds,generation$elapsed_seconds+post$elapsed_seconds) &&
          eq(clock$internal_generation_seconds,run$elapsed_seconds) &&
          run$elapsed_seconds<=generation$elapsed_seconds &&
          sum(vapply(run$phases,`[[`,numeric(1),"elapsed"))<=run$elapsed_seconds+.01)
  field <- c(setup="setup_seconds",compile="compile_seconds",adapt="adapt_seconds",burn="burn_seconds",
             sample="sample_seconds",persist_raw="persistence_seconds")
  check(paste(model,"all-phase-times"),all(vapply(names(field),function(k)
    isTRUE(run$phases[[k]]$completed) && eq(clock[[field[[k]]]],run$phases[[k]]$elapsed),logical(1))))
  ct <- common[common$model==model,]
  tx <- tab[tab$group %in% c("global","scaled_functional"),]
  check(paste(model,"common-table-identical-source-rows"),identical(ct$target,tx$target) &&
          all(vapply(names(tx),function(k)eq(ct[[k]],tx[[k]]),logical(1))))
  denominators <- c(internal_generation=run$elapsed_seconds,generation_process=generation$elapsed_seconds,
                    end_to_end_compute=generation$elapsed_seconds+post$elapsed_seconds,
                    sampling=run$phases$sample$elapsed)
  check(paste(model,"all-four-ESS-s-denominators"),all(vapply(names(denominators),function(k)
    eq(ct[[paste0("ess_bulk_per_",k,"_second")]],ct$ess_bulk/denominators[k]) &&
      eq(ct[[paste0("ess_tail_per_",k,"_second")]],ct$ess_tail/denominators[k]),logical(1))))
  globals <- do.call(rbind,global_records); globals <- globals[globals$model==model,]
  check(paste(model,"global-extremes-complete-and-runtime-counts"),nrow(globals)==23 &&
          all(is.finite(globals$rhat)) && all(is.finite(globals$ess_bulk)) && all(is.finite(globals$ess_tail)) &&
          eq(clock$global_rhat_max,max(globals$rhat)) && eq(clock$global_bulk_ESS_min,min(globals$ess_bulk)) &&
          eq(clock$global_tail_ESS_min,min(globals$ess_tail)) && clock$required_targets==nrow(required) &&
          clock$failed_targets==failed && clock$undefined_targets==undefined)
  for(g in unique(required$group)) {
    rows <- which(tab$mandatory & tab$group==g)
    group_records[[length(group_records)+1L]] <- data.frame(model=model,group=g,n=length(rows),
      failed=sum(!passed[rows]),undefined=sum(!metrics[rows]),passed=sum(passed[rows]))
  }
  summaries[[model]] <- list(mandatory=nrow(required),failed=failed,undefined=undefined,
    global_failed=sum(!passed[tab$group=="global"]),global_rhat_max=max(globals$rhat),
    global_bulk_ESS_min=min(globals$ess_bulk),global_tail_ESS_min=min(globals$ess_tail),
    M_mean=mean(M),S_mean=mean(S),M_chain=colMeans(M),S_chain=colMeans(S),
    generation_seconds=generation$elapsed_seconds,postprocessing_seconds=post$elapsed_seconds,
    end_to_end_compute_seconds=generation$elapsed_seconds+post$elapsed_seconds,
    mcpar=attr(raw$draws[[1]],"mcpar"))
}
ca <- class_prob$A; cd <- class_prob$D
check("class-comparison-identities-values-ties",identical(ca$precinct,cd$precinct) &&
        identical(class_comp$precinct,ca$precinct) && identical(class_comp$class,ca$class) &&
        eq(class_comp$probability_A,ca$probability) && eq(class_comp$probability_D,cd$probability) &&
        eq(class_comp$difference_D_minus_A,cd$probability-ca$probability) &&
        identical(class_comp$modal_A,ca$modal) && identical(class_comp$modal_D,cd$modal))
check("paired-status-inconclusive-and-no-inferential-approval",comp$status=="computationally_inconclusive" &&
        all(unlist(comp$runs_complete)) && !any(unlist(comp$precision_met)) &&
        !comp$production_approved && !comp$G10_approved &&
        eq(unlist(comp$totals),c(sum(N),sum(original$a),sum(W),sum(original$NValid-W))))
write.csv(do.call(rbind,global_records),file.path(out,"globals_recomputed.csv"),row.names=FALSE)
write.csv(do.call(rbind,group_records),file.path(out,"mandatory_groups_recomputed.csv"),row.names=FALSE)
jsonlite::write_json(list(status="pass",created_utc=format(Sys.time(),tz="UTC",usetz=TRUE),
  reviewer_id="01a0f4b8-962b-77a3-a418-6247c6219e8b",checks=checks,models=summaries,
  global_statistics_recomputed_from_raw=46,all_mandatory_rules_recomputed=3913,
  local_Rhat_ESS_not_recomputed=TRUE,new_MCMC=FALSE),file.path(out,"checks_results.json"),
  pretty=TRUE,auto_unbox=TRUE,digits=NA,na="null")
cat("PASS",length(checks),"actual-results checks; no new MCMC\n")
sink()
