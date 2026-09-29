# Stream only the compact BR members. The 2026-generated extract is a separate version.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) stop("Usage: Rscript tests/mebane/data/check_official_munzona.R OUTPUT_DIR")
source("R/lib/mebane_data.R")
library(data.table)
out <- args[[1L]]
source_dir <- "quality_reports/results/mebane_gates/coordination"

read_member <- function(stem, columns) {
  zip_path <- file.path(source_dir, paste0(stem, ".zip"))
  member <- paste0(stem, "_BR.csv")
  if (!file.exists(zip_path)) stop("Missing official ZIP: ", zip_path)
  command <- sprintf("unzip -p %s %s", shQuote(zip_path), shQuote(member))
  header <- names(fread(cmd = command, sep = ";", nrows = 0L, showProgress = FALSE))
  if (!all(columns %in% header)) stop("Official BR member schema changed: ", member)
  fread(cmd = command, sep = ";", encoding = "Latin-1", select = columns,
        showProgress = FALSE)
}

detail <- read_member("detalhe_votacao_munzona_2022", c(
  "DT_GERACAO", "ANO_ELEICAO", "NR_TURNO", "CD_CARGO", "SG_UF",
  "CD_MUNICIPIO", "NR_ZONA", "QT_APTOS", "QT_COMPARECIMENTO",
  "QT_ABSTENCOES", "QT_VOTOS_NOMINAIS_VALIDOS", "QT_VOTOS_BRANCOS",
  "QT_VOTOS_NULOS", "QT_SECOES_PRINCIPAIS", "QT_SECOES_NAO_INSTALADAS"))
vote <- read_member("votacao_candidato_munzona_2022", c(
  "DT_GERACAO", "ANO_ELEICAO", "NR_TURNO", "CD_CARGO", "SG_UF",
  "CD_MUNICIPIO", "NR_ZONA", "NR_CANDIDATO", "SQ_COLIGACAO",
  "TP_AGREMIACAO", "QT_VOTOS_NOMINAIS_VALIDOS"))
detail <- detail[ANO_ELEICAO == 2022L & CD_CARGO == 1L & NR_TURNO %in% 1:2]
vote <- vote[ANO_ELEICAO == 2022L & CD_CARGO == 1L & NR_TURNO %in% 1:2]
if (!nrow(detail) || !nrow(vote) ||
    anyDuplicated(detail, by = c("ANO_ELEICAO", "NR_TURNO", "CD_CARGO", "SG_UF",
                                  "CD_MUNICIPIO", "NR_ZONA")) ||
    anyDuplicated(vote, by = c("ANO_ELEICAO", "NR_TURNO", "CD_CARGO", "SG_UF",
                                "CD_MUNICIPIO", "NR_ZONA", "NR_CANDIDATO"))) {
  stop("Official BR extract has missing coverage or duplicate key")
}
if (!setequal(unique(detail$SG_UF), unique(vote$SG_UF)) ||
    uniqueN(detail$SG_UF) != 28L ||
    !setequal(unique(detail$NR_TURNO), 1:2) ||
    !setequal(unique(vote$NR_TURNO), 1:2)) stop("Official BR extract coverage differs")
if (length(unique(detail$DT_GERACAO)) != 1L ||
    length(unique(vote$DT_GERACAO)) != 1L) stop("Mixed generation dates")

official <- detail[, .(
  sections = sum(QT_SECOES_PRINCIPAIS),
  not_installed = sum(QT_SECOES_NAO_INSTALADAS),
  aptos = sum(QT_APTOS), comparecimento = sum(QT_COMPARECIMENTO),
  abstencoes_reportadas = sum(QT_ABSTENCOES),
  nominais = sum(QT_VOTOS_NOMINAIS_VALIDOS),
  brancos = sum(QT_VOTOS_BRANCOS), nulos = sum(QT_VOTOS_NULOS)),
  by = .(SG_UF, NR_TURNO)]
raw <- fread(file.path(out, "uf_turn_reconciliation.csv"))
exception_rows <- fread(file.path(out, "abstention_exceptions.csv"))
exception <- exception_rows[
  , .(not_installed = .N), by = .(SG_UF, NR_TURNO)]
raw <- merge(raw, exception, by = c("SG_UF", "NR_TURNO"), all.x = TRUE)
raw[is.na(not_installed), not_installed := 0L]
metrics <- c("sections", "not_installed", "aptos", "comparecimento",
             "abstencoes_reportadas", "nominais", "brancos", "nulos")
comparison <- merge(raw[, c("SG_UF", "NR_TURNO", metrics), with = FALSE],
                    official, by = c("SG_UF", "NR_TURNO"), suffixes = c("_raw", "_official"))
if (nrow(comparison) != 56L) stop("Official UF/turn join cardinality changed")
differences <- rbindlist(lapply(metrics, function(metric) {
  data.table(SG_UF = comparison$SG_UF, NR_TURNO = comparison$NR_TURNO,
             metric = metric, raw_sections = comparison[[paste0(metric, "_raw")]],
             official_munzona = comparison[[paste0(metric, "_official")]],
             difference = comparison[[paste0(metric, "_raw")]] -
               comparison[[paste0(metric, "_official")]])
}))
setorderv(differences, c("NR_TURNO", "SG_UF", "metric"))
fwrite(differences, file.path(out, "official_munzona_uf_turn_reconciliation.csv"))

zone_key <- c("SG_UF", "NR_TURNO", "CD_MUNICIPIO", "NR_ZONA")
zone_exception <- exception_rows[, .(raw_flagged = .N), by = zone_key]
zone_official <- detail[QT_SECOES_NAO_INSTALADAS > 0,
                        c(zone_key, "QT_SECOES_NAO_INSTALADAS"), with = FALSE]
zone_comparison <- merge(zone_exception, zone_official, by = zone_key, all = TRUE)
if (anyNA(zone_comparison)) stop("Non-installed zone coverage disagrees")
zone_comparison[, difference := raw_flagged - QT_SECOES_NAO_INSTALADAS]
setorderv(zone_comparison, zone_key)
fwrite(zone_comparison, file.path(out, "official_noninstalled_zone.csv"))

official_candidates <- vote[, .(official_munzona = sum(QT_VOTOS_NOMINAIS_VALIDOS)),
                            by = .(SG_UF, NR_TURNO, NR_CANDIDATO)]
raw_vote <- mebane_read_csv("replication_authors/extracted/fingerprint_brazil/raw-data/votacao_secao_2022_BR.csv",
                            c("ANO_ELEICAO", "NR_TURNO", "CD_CARGO", "SG_UF",
                              "NR_VOTAVEL", "QT_VOTOS"))
raw_vote <- raw_vote[ANO_ELEICAO == 2022L & CD_CARGO == 1L & NR_TURNO %in% 1:2 &
                       !NR_VOTAVEL %in% c(95L, 96L),
                     .(raw_sections = sum(QT_VOTOS)),
                     by = .(SG_UF, NR_TURNO, NR_VOTAVEL)]
setnames(raw_vote, "NR_VOTAVEL", "NR_CANDIDATO")
cand_comparison <- merge(raw_vote, official_candidates,
                         by = c("SG_UF", "NR_TURNO", "NR_CANDIDATO"), all = TRUE)
if (anyNA(cand_comparison)) stop("Candidate UF/turn coverage changed")
cand_comparison[, difference := raw_sections - official_munzona]
setorderv(cand_comparison, c("NR_TURNO", "SG_UF", "NR_CANDIDATO"))
fwrite(cand_comparison, file.path(out, "official_munzona_candidate_uf_turn.csv"))

coalition <- unique(vote[, .(NR_TURNO, NR_CANDIDATO, SQ_COLIGACAO, TP_AGREMIACAO)])
coalition[, TP_AGREMIACAO := iconv(TP_AGREMIACAO, from = "latin1", to = "UTF-8")]
setorderv(coalition, c("NR_TURNO", "NR_CANDIDATO", "SQ_COLIGACAO"))
fwrite(coalition, file.path(out, "candidate_coalition_metadata.csv"))
if (any(differences$difference != 0) || any(cand_comparison$difference != 0) ||
    any(zone_comparison$difference != 0)) {
  stop("Drift between 2022 author raw and 2026 official munzona; inspect comparison CSVs")
}
cat("2026-generated official BR munzona versus 2022 author raw, UF/turn/candidate: PASS\n")
cat("Official generation dates: detail ", unique(detail$DT_GERACAO),
    ", candidate ", unique(vote$DT_GERACAO), "\n", sep = "")
