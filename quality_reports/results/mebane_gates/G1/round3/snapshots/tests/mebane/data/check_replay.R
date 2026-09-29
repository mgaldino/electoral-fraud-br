args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("Usage: Rscript tests/mebane/data/check_replay.R FINAL_DIR REPLAY_DIR")
files <- c("sections_validated.parquet", "votes_validated.parquet",
           "abstention_exceptions.csv", "source_metadata.csv", "load_config_sha256.txt",
           "model_counts.parquet", "uf_turn_reconciliation.csv",
           "candidate_turn_totals.csv", "rule_log.csv")
comparison <- data.table::data.table(
  file = files,
  final_sha256 = vapply(file.path(args[[1L]], files), digest::digest,
                        character(1), algo = "sha256", file = TRUE),
  replay_sha256 = vapply(file.path(args[[2L]], files), digest::digest,
                         character(1), algo = "sha256", file = TRUE))
comparison[, identical := final_sha256 == replay_sha256]
data.table::fwrite(comparison, file.path(args[[1L]], "deterministic_replay.csv"))
if (!all(comparison$identical)) stop("Repeated run differs")
cat("Byte-identical load and build products: PASS\n")
