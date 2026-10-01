source("R/experimental/mebane_ad/io.R")
ad_setup()
base <- "quality_reports/results/mebane_gates/coordination/2026-10-01_ad_long_stan"
old <- "quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study"
contract_path <- file.path(base,"contract.json")
c <- jsonlite::read_json(contract_path,simplifyVector=TRUE)
files <- c(contract_path,file.path(base,"derivation.json"),
           list.files("R/experimental/mebane_ad_long",full.names=TRUE),
           list.files("tests/mebane/ad_long",full.names=TRUE),
           "R/experimental/mebane_ad/run_pair.py","R/experimental/mebane_ad/io.R",
           "R/experimental/mebane_ad/prepare_dc2010.R","R/experimental/mebane_ad/timing.md",
           "models/experimental/mebane_ad/d_multinomial.jags",c$A$source,c$A$specification_contract,
           c$case$source,file.path(old,"data/run-20260930T235038Z-pid61600/dc2010_ad_data.rds"),
           file.path(base,"checks_runner/result.json"),file.path(base,"checks_timing/result.json"))
snap <- ad_snapshot(files,file.path(base,"jags_candidate"))
cat("JAGS candidate SHA256:",ad_sha(file.path(base,"jags_candidate/manifest.json")),"\n")
