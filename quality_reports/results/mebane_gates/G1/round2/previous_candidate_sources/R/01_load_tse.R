# G1: validated TSE section and vote inputs. Explicit arguments prevent legacy overwrites.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("Usage: Rscript R/01_load_tse.R CONFIG_JSON NEW_OUTPUT_DIR")
source("R/lib/mebane_data.R")
cfg <- mebane_config(args[[1L]])
out <- mebane_new_output(args[[2L]])
mebane_load(cfg, out)
