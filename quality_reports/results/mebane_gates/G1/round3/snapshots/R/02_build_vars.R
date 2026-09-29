# G1: model counts from a validated, versioned load. No implicit legacy input.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("Usage: Rscript R/02_build_vars.R CONFIG_JSON EXISTING_OUTPUT_DIR")
source("R/lib/mebane_data.R")
cfg <- mebane_config(args[[1L]])
mebane_build(cfg, args[[2L]])
