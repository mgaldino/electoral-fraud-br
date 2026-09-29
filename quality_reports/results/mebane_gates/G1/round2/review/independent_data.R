#!/usr/bin/env Rscript
# Independent G1 controls: raw section CSVs versus archived official ZIP members.
suppressPackageStartupMessages(library(data.table))
root <- "."
round_dir <- "quality_reports/results/mebane_gates/G1/round2"
out <- file.path(round_dir, "review")
candidate_out <- file.path(out, "cli_2022")
cfg <- jsonlite::fromJSON("config/mebane/2022.json")
run <- jsonlite::fromJSON(file.path(round_dir, "run.json"), simplifyVector = TRUE)
manifest <- jsonlite::fromJSON(file.path(round_dir, "candidate_manifest.json"))
key <- c("ANO_ELEICAO", "NR_TURNO", "CD_CARGO", "SG_UF", "CD_MUNICIPIO", "NR_ZONA", "NR_SECAO")
zone_key <- key[key != "NR_SECAO"]
section_fields <- c(key, "QT_APTOS", "QT_COMPARECIMENTO", "QT_ABSTENCOES",
                    "QT_VOTOS_NOMINAIS", "QT_VOTOS_BRANCOS", "QT_VOTOS_NULOS",
                    "QT_VOTOS_LEGENDA", "QT_VOTOS_ANULADOS_APU_SEP", "CD_ELEICAO",
                    "DT_ELEICAO", "DT_GERACAO", "CD_TIPO_ELEICAO")
vote_fields <- c(key, "NR_VOTAVEL", "QT_VOTOS", "CD_ELEICAO", "DT_ELEICAO", "DT_GERACAO", "CD_TIPO_ELEICAO")
read_raw <- function(path, columns) {
  header <- names(fread(path, sep = ";", nrows = 0L))
  stopifnot(!anyDuplicated(header), all(columns %in% header))
  fread(path, sep = ";", select = columns, encoding = "Latin-1", showProgress = FALSE)
}
compare_tables <- function(left, right, by, metrics, label) {
  stopifnot(!anyDuplicated(left, by = by), !anyDuplicated(right, by = by))
  joined <- merge(left, right, by = by, all = TRUE, suffixes = c("_raw", "_other"))
  stopifnot(nrow(joined) == nrow(left), nrow(joined) == nrow(right))
  for (metric in metrics) {
    x <- joined[[paste0(metric, "_raw")]]
    y <- joined[[paste0(metric, "_other")]]
    if (anyNA(x) || anyNA(y) || any(x != y)) stop(label, ": ", metric, " mismatch")
  }
  data.table(control = label, rows = nrow(joined), metrics = paste(metrics, collapse = ","), pass = TRUE)
}
zip_member <- function(stem, fields) {
  zip <- file.path("quality_reports/results/mebane_gates/coordination", paste0(stem, ".zip"))
  member <- paste0(stem, "_BR.csv")
  header <- names(fread(cmd = sprintf("unzip -p %s %s", shQuote(zip), shQuote(member)),
                        sep = ";", nrows = 0L, showProgress = FALSE))
  stopifnot(!anyDuplicated(header), all(fields %in% header))
  fread(cmd = sprintf("unzip -p %s %s", shQuote(zip), shQuote(member)),
        sep = ";", select = fields, encoding = "Latin-1", showProgress = FALSE)
}

# Check all frozen file bytes and the run-to-manifest closure before using outputs.
paths <- manifest$files$path
stopifnot(!anyDuplicated(paths), all(file.exists(paths)))
hashes <- vapply(paths, function(path) digest::digest(file = path, algo = "sha256"), character(1))
sizes <- unname(file.info(paths)$size)
stopifnot(identical(unname(hashes), manifest$files$sha256),
          identical(as.numeric(sizes), as.numeric(manifest$files$bytes)))
declared <- unique(c(unlist(run[c("inputs", "code", "configuration", "outputs")], use.names = FALSE),
                     file.path(round_dir, "run.json")))
stopifnot(setequal(paths, declared),
          identical(run$dependency_manifests$G0,
                    "f71333db477385fc78dad8a7a1a7ca78e48479226dcdbde80ce97d724409fec7"))
writeLines(paste("manifest files", length(paths), "hash and size match; declared closure PASS"),
           file.path(out, "manifest_bytes.txt"))

d <- read_raw(cfg$detail_file, section_fields)
v <- read_raw(cfg$vote_file, vote_fields)
d <- d[ANO_ELEICAO == 2022L & CD_CARGO == 1L & NR_TURNO %in% 1:2]
v <- v[ANO_ELEICAO == 2022L & CD_CARGO == 1L & NR_TURNO %in% 1:2]
stopifnot(!anyNA(d[, ..key]), !anyNA(v[, ..key]),
          !anyDuplicated(d, by = key), !anyDuplicated(v, by = c(key, "NR_VOTAVEL")),
          setequal(unique(d$SG_UF), unique(v$SG_UF)), uniqueN(d$SG_UF) == 28L,
          setequal(unique(d$NR_TURNO), 1:2), setequal(unique(v$NR_TURNO), 1:2))
stopifnot(all(v$QT_VOTOS >= 0), all(d$QT_APTOS >= 0),
          all(d$QT_COMPARECIMENTO <= d$QT_APTOS),
          all(d$QT_COMPARECIMENTO == d$QT_VOTOS_NOMINAIS + d$QT_VOTOS_BRANCOS +
                d$QT_VOTOS_NULOS + d$QT_VOTOS_LEGENDA + d$QT_VOTOS_ANULADOS_APU_SEP))
stopifnot(fsetequal(unique(d[, .(NR_TURNO, CD_ELEICAO, DT_ELEICAO)]),
                    unique(v[, .(NR_TURNO, CD_ELEICAO, DT_ELEICAO)])))
stopifnot(nrow(fsetdiff(unique(v[, ..key]), d[, ..key])) == 0L)

category <- v[, .(nominal = sum(QT_VOTOS[!NR_VOTAVEL %in% c(95L, 96L)]),
                  blank = sum(QT_VOTOS[NR_VOTAVEL == 95L]),
                  null = sum(QT_VOTOS[NR_VOTAVEL == 96L])), by = key]
joined <- merge(d, category, by = key, all.x = TRUE)
stopifnot(nrow(joined) == nrow(d))
for (name in c("nominal", "blank", "null")) set(joined, which(is.na(joined[[name]])), name, 0)
stopifnot(all(joined$nominal == joined$QT_VOTOS_NOMINAIS),
          all(joined$blank == joined$QT_VOTOS_BRANCOS),
          all(joined$null == joined$QT_VOTOS_NULOS))

raw_uf <- d[, .(sections = .N, aptos = sum(QT_APTOS),
                comparecimento = sum(QT_COMPARECIMENTO),
                abstencoes_reportadas = sum(QT_ABSTENCOES),
                abstencoes_derivadas = sum(QT_APTOS - QT_COMPARECIMENTO),
                nominais = sum(QT_VOTOS_NOMINAIS), brancos = sum(QT_VOTOS_BRANCOS),
                nulos = sum(QT_VOTOS_NULOS),
                nominal_zero_sections = sum(QT_VOTOS_NOMINAIS == 0L)),
            by = .(SG_UF, NR_TURNO)]
candidate_uf <- v[!NR_VOTAVEL %in% c(95L, 96L),
                  .(votes = sum(QT_VOTOS)), by = .(SG_UF, NR_TURNO, NR_VOTAVEL)]
tests <- list(compare_tables(raw_uf, fread(file.path(candidate_out, "uf_turn_reconciliation.csv")),
                             c("SG_UF", "NR_TURNO"), setdiff(names(raw_uf), c("SG_UF", "NR_TURNO")),
                             "raw_vs_candidate_uf"))
raw_candidate <- candidate_uf[, .(QT_VOTOS = sum(votes)), by = .(NR_TURNO, NR_VOTAVEL)]
tests[[length(tests) + 1L]] <- compare_tables(
  raw_candidate, fread(file.path(candidate_out, "candidate_turn_totals.csv")),
  c("NR_TURNO", "NR_VOTAVEL"), "QT_VOTOS", "raw_vs_candidate_totals")

detail_official <- zip_member("detalhe_votacao_munzona_2022", c(
  zone_key, "DT_GERACAO", "CD_ELEICAO", "DT_ELEICAO", "CD_TIPO_ELEICAO", "QT_APTOS", "QT_COMPARECIMENTO", "QT_ABSTENCOES",
  "QT_VOTOS_NOMINAIS_VALIDOS", "QT_VOTOS_BRANCOS", "QT_VOTOS_NULOS",
  "QT_SECOES_PRINCIPAIS", "QT_SECOES_NAO_INSTALADAS",
  "QT_ELEITORES_SECOES_NAO_INSTALADAS"))
vote_official <- zip_member("votacao_candidato_munzona_2022", c(
  zone_key, "DT_GERACAO", "CD_ELEICAO", "DT_ELEICAO", "CD_TIPO_ELEICAO", "NR_CANDIDATO", "QT_VOTOS_NOMINAIS_VALIDOS"))
detail_official <- detail_official[ANO_ELEICAO == 2022L & CD_CARGO == 1L & NR_TURNO %in% 1:2]
vote_official <- vote_official[ANO_ELEICAO == 2022L & CD_CARGO == 1L & NR_TURNO %in% 1:2]
stopifnot(uniqueN(detail_official$DT_GERACAO) == 1L,
          uniqueN(vote_official$DT_GERACAO) == 1L,
          !anyDuplicated(detail_official, by = zone_key),
          !anyDuplicated(vote_official, by = c(zone_key, "NR_CANDIDATO")),
          uniqueN(detail_official$SG_UF) == 28L,
          setequal(unique(detail_official$SG_UF), unique(vote_official$SG_UF)))
official_uf <- detail_official[, .(
  sections = sum(QT_SECOES_PRINCIPAIS), aptos = sum(QT_APTOS),
  comparecimento = sum(QT_COMPARECIMENTO), abstencoes_reportadas = sum(QT_ABSTENCOES),
  nominais = sum(QT_VOTOS_NOMINAIS_VALIDOS), brancos = sum(QT_VOTOS_BRANCOS),
  nulos = sum(QT_VOTOS_NULOS), not_installed = sum(QT_SECOES_NAO_INSTALADAS),
  electors_not_installed = sum(QT_ELEITORES_SECOES_NAO_INSTALADAS)),
  by = .(SG_UF, NR_TURNO)]
tests[[length(tests) + 1L]] <- compare_tables(
  raw_uf, official_uf, c("SG_UF", "NR_TURNO"),
  c("sections", "aptos", "comparecimento", "abstencoes_reportadas",
    "nominais", "brancos", "nulos"), "raw_vs_official_uf")
official_candidate <- vote_official[, .(votes = sum(QT_VOTOS_NOMINAIS_VALIDOS)),
                                    by = .(SG_UF, NR_TURNO, NR_CANDIDATO)]
setnames(official_candidate, "NR_CANDIDATO", "NR_VOTAVEL")
tests[[length(tests) + 1L]] <- compare_tables(
  candidate_uf, official_candidate, c("SG_UF", "NR_TURNO", "NR_VOTAVEL"),
  "votes", "raw_vs_official_candidate_uf")

exception <- d[QT_APTOS > 0L & QT_COMPARECIMENTO == 0L & QT_ABSTENCOES == 0L,
               .(not_installed = .N, electors_not_installed = sum(QT_APTOS)),
               by = .(SG_UF, NR_TURNO)]
official_exc <- official_uf[, .(SG_UF, NR_TURNO, not_installed, electors_not_installed)]
official_exc <- official_exc[not_installed > 0L]
tests[[length(tests) + 1L]] <- compare_tables(
  exception, official_exc, c("SG_UF", "NR_TURNO"),
  c("not_installed", "electors_not_installed"), "raw_vs_official_noninstalled_uf")
exc_zone <- d[QT_APTOS > 0L & QT_COMPARECIMENTO == 0L & QT_ABSTENCOES == 0L,
              .(not_installed = .N, electors_not_installed = sum(QT_APTOS)), by = zone_key]
off_zone <- detail_official[QT_SECOES_NAO_INSTALADAS > 0L,
                            c(zone_key, "QT_SECOES_NAO_INSTALADAS",
                              "QT_ELEITORES_SECOES_NAO_INSTALADAS"), with = FALSE]
setnames(off_zone, c("QT_SECOES_NAO_INSTALADAS", "QT_ELEITORES_SECOES_NAO_INSTALADAS"),
         c("not_installed", "electors_not_installed"))
tests[[length(tests) + 1L]] <- compare_tables(
  exc_zone, off_zone, zone_key,
  c("not_installed", "electors_not_installed"), "raw_vs_official_noninstalled_zone")

for (turn in 1:2) {
  stem <- sprintf("Historico_Totalizacao_Presidente_BR_%dT_2022", turn)
  zip <- file.path("quality_reports/results/mebane_gates/coordination", paste0(stem, ".zip"))
  con <- unz(zip, paste0(stem, ".csv"), open = "rb")
  bytes <- readBin(con, "raw", n = 50000000L)
  close(con)
  lines <- strsplit(rawToChar(bytes), "\n", fixed = TRUE)[[1L]]
  lines <- lines[nzchar(lines)]
  header <- trimws(strsplit(lines[[1L]], ";", fixed = TRUE)[[1L]])
  last <- trimws(strsplit(tail(lines, 1L), ";", fixed = TRUE)[[1L]])
  stopifnot(length(header) == length(last), !anyDuplicated(header))
  record <- setNames(last, header)
  stopifnot(as.numeric(record[["QT_SECOES_TOT_ACUMULADO"]]) ==
              as.numeric(record[["QT_SECOES_TOTAL"]]))
  observed <- raw_uf[NR_TURNO == turn, .(
    sections = sum(sections), aptos = sum(aptos), comparecimento = sum(comparecimento),
    nominais = sum(nominais), brancos = sum(brancos), nulos = sum(nulos))]
  historical_fields <- c(sections = "QT_SECOES_TOT_ACUMULADO",
                         aptos = "QT_APTOS_TOT_ACUMULADO",
                         comparecimento = "QT_VOTOS_TOTAL_ACUMULADO",
                         nominais = "QT_VOTOS_CONCORRENTES_ACUMULADO",
                         brancos = "BRANCO_QT_VOTOS_TOT_ACUMULADO",
                         nulos = "NULO_QT_VOTOS_TOT_ACUMULADO")
  for (metric in names(historical_fields)) {
    stopifnot(observed[[metric]] == as.numeric(record[[historical_fields[[metric]]]]))
  }
  for (candidate in c(13L, 22L)) {
    field <- if (candidate == 13L) "LULA_QT_VOTOS_TOT_ACUMULADO" else
      "JAIR_BOLSONARO_QT_VOTOS_TOT_ACUMULADO"
    stopifnot(raw_candidate[NR_TURNO == turn & NR_VOTAVEL == candidate, QT_VOTOS] ==
                as.numeric(record[[field]]))
  }
  tests[[length(tests) + 1L]] <- data.table(
    control = paste0("raw_vs_official_history_turn_", turn), rows = 1L,
    metrics = "sections,aptos,comparecimento,nominais,brancos,nulos,candidate_13,candidate_22",
    pass = TRUE)
}

national <- raw_uf[, lapply(.SD, sum), by = NR_TURNO,
                   .SDcols = c("sections", "aptos", "comparecimento",
                               "abstencoes_reportadas", "abstencoes_derivadas",
                               "nominais", "brancos", "nulos", "nominal_zero_sections")]
setorderv(national, "NR_TURNO")
fwrite(national, file.path(out, "independent_national.csv"))
fwrite(raw_uf[order(SG_UF, NR_TURNO)], file.path(out, "independent_uf_turn.csv"))
fwrite(rbindlist(tests), file.path(out, "independent_controls.csv"))
summary <- list(raw_detail_rows = nrow(d), raw_vote_rows = nrow(v),
                raw_uf_turn_rows = nrow(raw_uf), raw_candidate_uf_turn_rows = nrow(candidate_uf),
                absent_all_vote_categories = nrow(fsetdiff(d[, ..key], unique(v[, ..key]))),
                nominal_zero_sections = d[, sum(QT_VOTOS_NOMINAIS == 0L), by = NR_TURNO],
                source_dates = list(raw_detail = unique(d$DT_GERACAO), raw_vote = unique(v$DT_GERACAO),
                                    official_detail = unique(detail_official$DT_GERACAO),
                                    official_vote = unique(vote_official$DT_GERACAO)),
                noninstalled_rows = nrow(d[QT_APTOS > 0L & QT_COMPARECIMENTO == 0L & QT_ABSTENCOES == 0L]),
                noninstalled_electors = sum(exception$electors_not_installed))
jsonlite::write_json(summary, file.path(out, "independent_summary.json"),
                     auto_unbox = TRUE, pretty = TRUE)
cat("independent raw/official controls PASS; ", nrow(d), " sections; ",
    nrow(v), " vote rows; ", nrow(rbindlist(tests)), " control groups\n", sep = "")

# Fresh round2 identity anchors, model reconstruction and rowwise preservation.
id <- c("NR_TURNO", "CD_ELEICAO", "DT_ELEICAO", "CD_TIPO_ELEICAO")
expected_id <- rbindlist(lapply(names(cfg$election_identity), function(turn) {
  data.table(NR_TURNO = as.integer(turn), as.data.table(cfg$election_identity[[turn]]))
}))
setorderv(expected_id, "NR_TURNO")
identity_checks <- rbindlist(lapply(list(raw_detail = d, raw_vote = v,
                                       official_detail = detail_official,
                                       official_vote = vote_official), function(tbl) {
  observed <- unique(tbl[, ..id])
  setorderv(observed, "NR_TURNO")
  stopifnot(identical(as.data.frame(observed), as.data.frame(expected_id)))
  observed
}), idcol = "source")
fwrite(identity_checks, file.path(out, "identity_anchors.csv"))

model <- as.data.table(arrow::read_parquet(file.path(candidate_out, "model_counts.parquet")))
setorderv(model, key)
setorderv(d, key)
target <- v[NR_VOTAVEL == 13L, c(key, "QT_VOTOS"), with = FALSE]
target <- merge(d[, ..key], target, by = key, all.x = TRUE)
target[is.na(QT_VOTOS), QT_VOTOS := 0L]
setorderv(target, key)
stopifnot(nrow(model) == nrow(d),
          identical(as.data.frame(model[, ..key]), as.data.frame(d[, ..key])),
          all(model$N == d$QT_APTOS), all(model$a == d$QT_APTOS - d$QT_COMPARECIMENTO),
          all(model$w == target$QT_VOTOS), all(model$a >= 0), all(model$a <= model$N),
          all(model$w >= 0), all(model$w <= model$N - model$a),
          all(model$NR_VOTAVEL == 13L), all(model$national_leader == 13L),
          all(model$flag_exterior == (d$SG_UF == "ZZ")),
          all(model$flag_small == (d$QT_APTOS < 10)),
          all(model$flag_zero_nominal == (d$QT_VOTOS_NOMINAIS == 0)),
          all(model$model_eligible == (d$QT_APTOS > 0 &
                d$QT_APTOS == d$QT_COMPARECIMENTO + d$QT_ABSTENCOES)))
model_summary <- model[, .(rows = .N, eligible = sum(model_eligible),
  zero_nominal = sum(flag_zero_nominal), exterior = sum(flag_exterior),
  small = sum(flag_small), zero_target = sum(w == 0)), by = NR_TURNO]
fwrite(model_summary, file.path(out, "model_summary.csv"))
rm(model, target, joined, category, d, v)
invisible(gc())

old_dir <- "quality_reports/results/mebane_gates/G1/round1/outputs/2022_final"
new_dir <- file.path(round_dir, "outputs/2022_final")
invariance <- list()
for (file in c("sections_validated.parquet", "votes_validated.parquet", "model_counts.parquet")) {
  a <- as.data.table(arrow::read_parquet(file.path(old_dir, file)))
  b <- as.data.table(arrow::read_parquet(file.path(new_dir, file)))
  order_key <- if (file == "sections_validated.parquet") key else c(key, "NR_VOTAVEL")
  stopifnot(!anyDuplicated(a, by = order_key), !anyDuplicated(b, by = order_key))
  setorderv(a, order_key); setorderv(b, order_key)
  common <- names(a)
  stopifnot(setequal(setdiff(names(b), common), "CD_TIPO_ELEICAO"),
            all(common %in% names(b)), all(b$CD_TIPO_ELEICAO == 2L),
            nrow(a) == nrow(b))
  equal <- vapply(common, function(field) identical(a[[field]], b[[field]]), logical(1))
  invariance[[file]] <- data.table(file = file, column = common, identical = equal, rows = nrow(a))
  stopifnot(all(equal))
  rm(a, b); invisible(gc())
}
fwrite(rbindlist(invariance), file.path(out, "round1_column_invariance.csv"))
core <- c("sections_validated.parquet", "votes_validated.parquet", "abstention_exceptions.csv",
          "source_metadata.csv", "load_config_sha256.txt", "model_counts.parquet",
          "uf_turn_reconciliation.csv", "candidate_turn_totals.csv", "rule_log.csv")
dirs <- c(candidate = new_dir, candidate_replay = file.path(round_dir, "outputs/2022_replay"),
          qa = candidate_out, qa_replay = file.path(out, "cli_replay"))
replay <- data.table(file = core)
for (label in names(dirs)) {
  replay[, (label) := vapply(file.path(dirs[[label]], core), digest::digest,
                              character(1), algo = "sha256", file = TRUE)]
}
replay[, identical := candidate == candidate_replay & candidate == qa & candidate == qa_replay]
stopifnot(all(replay$identical))
fwrite(replay, file.path(out, "replay_hashes.csv"))
cat("Identity anchors, independent N/a/w reconstruction, all prior parquet columns, and four-way byte replay PASS.\n")
