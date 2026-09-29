# Check final cumulative national TSE history records against G1 raw-derived totals.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) stop("Usage: Rscript tests/mebane/data/check_official_histories.R OUTPUT_DIR")
library(data.table)
out <- args[[1L]]
source_dir <- "quality_reports/results/mebane_gates/coordination"
raw_totals <- fread(file.path(out, "uf_turn_reconciliation.csv"))[
  , .(sections = sum(sections), aptos = sum(aptos),
      comparecimento = sum(comparecimento), nominais = sum(nominais),
      brancos = sum(brancos), nulos = sum(nulos)), by = NR_TURNO]
candidates <- fread(file.path(out, "candidate_turn_totals.csv"))
fields <- c(sections = "QT_SECOES_TOT_ACUMULADO",
            aptos = "QT_APTOS_TOT_ACUMULADO",
            comparecimento = "QT_VOTOS_TOTAL_ACUMULADO",
            nominais = "QT_VOTOS_CONCORRENTES_ACUMULADO",
            brancos = "BRANCO_QT_VOTOS_TOT_ACUMULADO",
            nulos = "NULO_QT_VOTOS_TOT_ACUMULADO")
result <- list()
for (turn in 1:2) {
  name <- sprintf("Historico_Totalizacao_Presidente_BR_%dT_2022.csv", turn)
  zip_path <- file.path(source_dir, sub("[.]csv$", ".zip", name))
  if (!file.exists(zip_path)) stop("Missing official history ZIP: ", zip_path)
  connection <- unz(zip_path, name, open = "rb")
  bytes <- readBin(connection, "raw", n = 100000000L)
  close(connection)
  lines <- strsplit(rawToChar(bytes), "\n", fixed = TRUE)[[1L]]
  if (length(lines) < 2L) stop("Empty official history: ", name)
  header <- trimws(strsplit(lines[[1L]], ";", fixed = TRUE)[[1L]])
  last <- trimws(strsplit(tail(lines, 1L), ";", fixed = TRUE)[[1L]])
  if (length(header) != length(last) || anyDuplicated(header)) stop("Bad history schema: ", name)
  record <- stats::setNames(last, header)
  if (as.numeric(record[["QT_SECOES_TOT_ACUMULADO"]]) !=
      as.numeric(record[["QT_SECOES_TOTAL"]])) stop("History not fully totalized: ", name)
  observed <- raw_totals[NR_TURNO == turn]
  for (metric in names(fields)) {
    official <- as.numeric(record[[fields[[metric]]]])
    got <- observed[[metric]]
    result[[length(result) + 1L]] <- data.table(
      NR_TURNO = turn, metric = metric, history = official,
      raw_sections = got, difference = got - official)
  }
  for (candidate in c(13L, 22L)) {
    metric <- paste0("candidate_", candidate)
    field <- if (candidate == 13L) "LULA_QT_VOTOS_TOT_ACUMULADO" else
      "JAIR_BOLSONARO_QT_VOTOS_TOT_ACUMULADO"
    official <- as.numeric(record[[field]])
    got <- candidates[NR_TURNO == turn & NR_VOTAVEL == candidate, QT_VOTOS]
    result[[length(result) + 1L]] <- data.table(
      NR_TURNO = turn, metric = metric, history = official,
      raw_sections = got, difference = got - official)
  }
}
result <- rbindlist(result)
setorderv(result, c("NR_TURNO", "metric"))
fwrite(result, file.path(out, "official_history_reconciliation.csv"))
if (anyNA(result$difference) || any(result$difference != 0)) {
  stop("Official history and G1 raw-section totals disagree")
}
cat("Official TSE history final records versus raw section totals: PASS\n")
