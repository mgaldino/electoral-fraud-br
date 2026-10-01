# Controlled, additive copies of the reviewed 2k machinery; never edit old files.
source("R/experimental/mebane_ad/io.R")
ad_setup()
base <- "quality_reports/results/mebane_gates/coordination/2026-10-01_ad_long_stan"
old <- "quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study"
dir.create(base,recursive=TRUE,showWarnings=FALSE)
stopifnot(!file.exists(file.path(base,"contract.json")))
spec <- jsonlite::read_json(file.path(old,"contract_v2.json"),simplifyVector=FALSE)
spec$contract_id <- "AD-DC2010-LONG-v1"
spec$date <- "2026-10-01"
spec$authorization_quote <- "Em JAGS, as cadeias precisam ser bem grandes. Em Stan 2k pode ser efetivo, mas Jags precisa ser algo como 20k. Rode com 20k. Em paralelo, veja se dá para adaptar pra Stan e como fica rodando 2k cadeias."
spec$purpose <- "New authorized A/D JAGS20k experiment and same-target D Stan2k comparison; old pilot and its verdict preserved"
spec$paired_design$post_iterations <- 20000L
spec$paired_design$max_elapsed_seconds_per_model <- 3600L
spec$paired_design$max_postprocess_seconds_per_model <- 3600L
spec$paired_design$timing <- "One four-chain rjags object; A then D and diagnostics sequential; avoid compilation/other sampling during measured processes. Record overlap if accidental; no automatic resampling."
spec$stan_design <- list(model="D only, exact marginal target",chains=4L,
  warmup_iterations=2000L,post_iterations=2000L,parallel_chains=1L,thin=1L,
  seed=1001261L,chain_ids=as.list(1:4),adapt_delta=.99,max_treedepth=12L,
  max_elapsed_seconds=3600L,save_warmup=TRUE,
  parametrization="Noncentered h=alpha+sqrt(v)*z; z~N(0,1); v~Exp(5) on VARIANCE; b0 and alpha kept separate",
  pi="r2,r3 iid Uniform(0,1); pi=(1,r2,r3)/(1+r2+r3). Integrate nuisance u1 exactly; Jacobian u1^2 cancels conditional-uniform density 1/u1^2",
  likelihood="Sum all 3 class-weighted multinomial masses by log_sum_exp per precinct; no clamp or approximate A substitution",
  output="Conditional class probabilities and categorical Z reconstruction per draw; joint M/S and active pA/pW/pO from the SAME Z, plus Rao-Blackwell summaries separately",
  initialization="Map the previous four initial values: alpha/b0/v identical, z=0, r2=.25,r3=.125; no claim seeds match JAGS RNG",
  runtime_diagnostics=list(divergences_max=0L,treedepth_hits_max=0L,ebfmi_min=.3,
    internal_NCP_parameters="All z and r parameters require rank Rhat<1.01, bulk/tail ESS>=400. Common augmented targets retain prior thresholds; NAs never pass."),
  installation_allowed=FALSE,automatic_retry=FALSE)
spec$comparison$new_round <- list(
  historical="Compare old2k vs new20k descriptively; fresh run with same starting seeds/inits is not an independent replication and no prefix equivalence is presumed",
  D_engine="Same target not asserted by mean agreement: independent density/Jacobian/likelihood checks required first",
  MCSE="For the 23 common globals report difference and sqrt(MCSE_JAGS^2+MCSE_Stan^2), plus absolute standardized difference; no equivalence claim unless both relevant precision checks pass. No posthoc tolerance or new posterior acceptance test.",
  group_status="Report global continuous, local, discrete and sampler groups separately as diagnostics; all-target verdict still requires all mandatory targets. No waiver for rare classes or added GQ randomness.")
spec$checkpoints <- list("Independent delta review of JAGS copies and new protocol before JAGS sampling",
                        "Independent D/Stan target and executable review before Stan sampling",
                        "Independent quantitative result review before final comparative claims")
spec$supersedes <- list(path=paste0(old,"/contract_v2.json"),sha256=ad_sha(file.path(old,"contract_v2.json")),
                        reason="New explicit user authorization; prior pilot remains immutable, not retrospectively extended or reclassified")
ad_json(spec,file.path(base,"contract.json"))
copies <- list()
for (name in c("run_jags.R","diagnostics.R")) {
  src <- file.path("R/experimental/mebane_ad",name)
  dst <- file.path("R/experimental/mebane_ad_long",name)
  stopifnot(!file.exists(dst))
  code <- readLines(src,warn=FALSE)
  code <- gsub("AD-DC2010-v2","AD-DC2010-LONG-v1",code,fixed=TRUE)
  code <- gsub("2000","20000",code,fixed=TRUE)
  code <- gsub(src,dst,code,fixed=TRUE)
  writeLines(code,dst,useBytes=TRUE)
  invisible(parse(dst))
  copies[[name]] <- list(source=src,source_sha256=ad_sha(src),destination=dst,sha256=ad_sha(dst),
                         replacements=c("contract_id only","2000 -> 20000 only","self-source snapshot path only"))
}
ad_json(list(copies=copies,old_contract_sha256=ad_sha(file.path(old,"contract_v2.json")),
             new_contract_sha256=ad_sha(file.path(base,"contract.json")),MCMC=FALSE),
        file.path(base,"derivation.json"))
ad_snapshot(c("README.md","CLAUDE.md","quality_reports/plans/mebane_2022_2026_gates.json",
              "quality_reports/plans/2026-09-28_mebane_2022_2026_gates.md"),file.path(base,"before_live_docs"))
ad_json(list(status="preflight_preparation",date="2026-10-01",A_preserved=TRUE,
             old_study_preserved=TRUE,production_approved=FALSE,
             todos=list(JAGS20k="preflight",StanD2k="implementation",comparison="queued")),file.path(base,"state.json"))
cat("Prepared new protocol and mechanically derived 20k R scripts; old files untouched\n")
