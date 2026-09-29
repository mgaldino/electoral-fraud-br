# Independently compare configured identities to the archived official BR extracts.
library(data.table)
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) stop("Usage: check_round2_identity_sources.R REPORT_DIR")
cfg <- jsonlite::fromJSON("config/mebane/2022.json")
expected <- rbindlist(lapply(names(cfg$election_identity), function(turn) {
  data.table(NR_TURNO = as.integer(turn), as.data.table(cfg$election_identity[[turn]]))
}))
columns <- c("NR_TURNO", "CD_ELEICAO", "DT_ELEICAO", "CD_TIPO_ELEICAO")
setorderv(expected, "NR_TURNO")
checks <- list()
for (stem in c("detalhe_votacao_munzona_2022", "votacao_candidato_munzona_2022")) {
  zip <- file.path("quality_reports/results/mebane_gates/coordination", paste0(stem, ".zip"))
  member <- paste0(stem, "_BR.csv")
  actual <- fread(cmd = sprintf("unzip -p %s %s", shQuote(zip), shQuote(member)),
                  sep = ";", select = c("DT_GERACAO", "ANO_ELEICAO", "CD_CARGO", columns),
                  showProgress = FALSE)
  actual <- unique(actual[ANO_ELEICAO == cfg$year & CD_CARGO == cfg$cargo &
                            NR_TURNO %in% cfg$turns])
  setorderv(actual, "NR_TURNO")
  if (nrow(actual) != length(cfg$turns)) stop("Official identity has mixed metadata")
  for (field in columns) {
    checks[[length(checks) + 1L]] <- data.table(
      zip_path = zip, member = member, generation = actual$DT_GERACAO,
      NR_TURNO = actual$NR_TURNO, field = field,
      configured = as.character(expected[[field]]), official = as.character(actual[[field]]),
      matches = expected[[field]] == actual[[field]])
  }
}
result <- rbindlist(checks)
fwrite(result, file.path(args[[1L]], "identity_official_anchors.csv"))
stopifnot(all(result$matches))
cat("Configured 2022 identities match both archived official BR extracts: PASS\n")
