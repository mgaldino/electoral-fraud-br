# Compare every common parquet column and key to the frozen round1 output.
library(data.table)
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3L) stop("Usage: check_round1_invariance.R ROUND1_OUTPUT ROUND2_OUTPUT REPORT_DIR")
old_dir <- args[[1L]]
new_dir <- args[[2L]]
report_dir <- args[[3L]]
base_key <- c("ANO_ELEICAO", "NR_TURNO", "CD_CARGO", "SG_UF",
              "CD_MUNICIPIO", "NR_ZONA", "NR_SECAO")
checks <- list()
for (name in c("sections_validated.parquet", "votes_validated.parquet", "model_counts.parquet")) {
  old <- as.data.table(arrow::read_parquet(file.path(old_dir, name)))
  new <- as.data.table(arrow::read_parquet(file.path(new_dir, name)))
  key <- if (name == "sections_validated.parquet") base_key else c(base_key, "NR_VOTAVEL")
  stopifnot(!anyDuplicated(old, by = key), !anyDuplicated(new, by = key))
  setorderv(old, key)
  setorderv(new, key)
  common <- intersect(names(old), names(new))
  changed <- common[!vapply(common, function(column) identical(old[[column]], new[[column]]), logical(1))]
  added <- setdiff(names(new), names(old))
  removed <- setdiff(names(old), names(new))
  old_key_sha <- digest::digest(as.data.frame(old[, ..key]), algo = "sha256")
  new_key_sha <- digest::digest(as.data.frame(new[, ..key]), algo = "sha256")
  checks[[length(checks) + 1L]] <- data.table(
    file = name, old_rows = nrow(old), new_rows = nrow(new),
    old_key_sha256_r_serialization = old_key_sha, new_key_sha256_r_serialization = new_key_sha,
    changed_common_columns = paste(changed, collapse = ";"),
    added_columns = paste(added, collapse = ";"), removed_columns = paste(removed, collapse = ";"),
    old_file_sha256 = digest::digest(file = file.path(old_dir, name), algo = "sha256"),
    new_file_sha256 = digest::digest(file = file.path(new_dir, name), algo = "sha256"),
    passed = nrow(old) == nrow(new) && old_key_sha == new_key_sha &&
      !length(changed) && !length(removed) && identical(added, "CD_TIPO_ELEICAO") &&
      all(new$CD_TIPO_ELEICAO == 2L))
  rm(old, new)
  invisible(gc())
}
result <- rbindlist(checks)
fwrite(result, file.path(report_dir, "round1_rowwise_invariance.csv"))
if (!all(result$passed)) stop("Rowwise counts/keys/previous metadata changed from round1")
stable_files <- c("candidate_turn_totals.csv", "uf_turn_reconciliation.csv", "rule_log.csv",
                  "independent_raw_uf_turn.csv", "official_history_reconciliation.csv",
                  "official_munzona_uf_turn_reconciliation.csv", "official_munzona_candidate_uf_turn.csv",
                  "candidate_coalition_metadata.csv", "official_noninstalled_zone.csv")
stable <- data.table(
  file = stable_files,
  old_sha256 = vapply(file.path(old_dir, stable_files), digest::digest, character(1),
                       algo = "sha256", file = TRUE),
  new_sha256 = vapply(file.path(new_dir, stable_files), digest::digest, character(1),
                       algo = "sha256", file = TRUE))
stable[, passed := old_sha256 == new_sha256]
fwrite(stable, file.path(report_dir, "round1_aggregate_invariance.csv"))
stopifnot(all(stable$passed))
cat("Round1 versus round2: keys and every prior parquet column unchanged; only CD_TIPO_ELEICAO added.\n")
cat("All nine aggregate/control reports byte-identical across rounds: PASS\n")
