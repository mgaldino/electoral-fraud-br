# Adapt only diagnostic metadata, preserving the original 2k processor and target.
source("R/experimental/mebane_ad/io.R")
ad_setup()
base <- "quality_reports/results/mebane_gates/coordination/2026-10-01_ad_long_stan"
c <- jsonlite::read_json(file.path(base,"contract.json"),simplifyVector=FALSE)
c$contract_id <- "AD-DC2010-LONG-STAN-v1"
c$paired_design$engine <- "Stan D; common augmented-posterior diagnostic view only"
c$paired_design$post_iterations <- 2000L
c$paired_design$adapt_iterations <- NULL
c$paired_design$burn_iterations <- 2000L
c$paired_design$chain_seeds <- rep(list(1001261L),4)
c$paired_design$chain_ids <- as.list(1:4)
c$paired_design$RNG_name <- "Stan base seed plus distinct chain IDs; not JAGS RNG-equivalent"
c$paired_design$model_execution_order <- list("D")
c$paired_design$execution <- "4 serial Stan chains; compatibility view does not run a JAGS engine"
c$paired_design$initialization$class <- "Z marginalized and reconstructed conditionally per draw, not initialized"
c$source_main_contract <- list(path=file.path(base,"contract.json"),sha256=ad_sha(file.path(base,"contract.json")))
c$diagnostics$compatibility_scope <- "The shared processor checks common augmented-posterior draws. HMC divergences/depth/energy and all z/r precision also must pass independently; GQ randomness cannot rescue the underlying sampler."
ad_json(c,file.path(base,"contract_stan_diagnostics.json"))
src <- "R/experimental/mebane_ad/diagnostics.R"
dst <- "R/experimental/mebane_ad_long/diagnostics_stan.R"
stopifnot(!file.exists(dst))
code <- readLines(src,warn=FALSE)
code <- gsub("AD-DC2010-v2","AD-DC2010-LONG-STAN-v1",code,fixed=TRUE)
code <- gsub(src,dst,code,fixed=TRUE)
writeLines(code,dst,useBytes=TRUE)
invisible(parse(dst))
ad_json(list(source=src,source_sha256=ad_sha(src),destination=dst,sha256=ad_sha(dst),
             changes=c("contract ID","self-source snapshot path"),MCMC=FALSE),
        file.path(base,"stan_diagnostic_derivation.json"))
