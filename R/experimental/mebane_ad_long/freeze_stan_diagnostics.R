# Freeze only the new diagnostic adapter, without duplicating old result trees.
source("R/experimental/mebane_ad/io.R")
ad_setup()
root <- "quality_reports/results/mebane_gates/coordination/2026-10-01_ad_long_stan"
test <- file.path(root,"stan_bridge_checks01.json")
stopifnot(jsonlite::read_json(test)$status=="pass")
ad_snapshot(c("R/experimental/mebane_ad_long/stan_bridge.R",
              "R/experimental/mebane_ad_long/postprocess_stan.R",
              "R/experimental/mebane_ad_long/diagnostics_stan.R",
              "R/experimental/mebane_ad_long/prepare_stan_diagnostics.R",
              "R/experimental/mebane_ad_long/supervise_diagnostics.py",
              "R/experimental/mebane_ad_long/freeze_stan_diagnostics.R",
              "R/experimental/mebane_ad/diagnostics.R",
              "R/experimental/mebane_ad/io.R",
              "R/experimental/mebane_ad/run_pair.py",
              "tests/mebane/ad_long/test_stan_bridge.R",
              file.path(root,c("contract.json","contract_stan_diagnostics.json","stan_diagnostic_derivation.json")),
              test),file.path(root,"stan_diagnostic_candidate"))
