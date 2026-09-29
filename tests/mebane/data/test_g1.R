# Small adversarial fixtures plus optional independent full raw aggregation.
source("R/lib/mebane_data.R")
library(data.table)

expect_failure <- function(expr, pattern) {
  result <- tryCatch({ force(expr); NULL }, error = function(e) conditionMessage(e))
  if (is.null(result) || !grepl(pattern, result, fixed = TRUE)) {
    stop("Expected error containing '", pattern, "'; got: ", result)
  }
}

cfg <- mebane_config("config/mebane/2022.json")
cfg$official_controls <- NULL
d <- data.table(
  DT_GERACAO = rep("01/11/2022", 4), CD_ELEICAO = c(544L, 544L, 545L, 545L),
  CD_TIPO_ELEICAO = 2L,
  DT_ELEICAO = c("02/10/2022", "02/10/2022", "30/10/2022", "30/10/2022"),
  ANO_ELEICAO = 2022L, NR_TURNO = c(1L, 1L, 2L, 2L), CD_CARGO = 1L,
  SG_UF = c("SP", "AM", "SP", "ZZ"), CD_MUNICIPIO = c(1L, 2L, 1L, 2L),
  NM_MUNICIPIO = c("SAO PAULO", "MANAUS", "SAO PAULO", "EXTERIOR"),
  NR_ZONA = 1L, NR_SECAO = 1L, QT_APTOS = c(10L, 7L, 10L, 7L),
  QT_COMPARECIMENTO = c(5L, 0L, 5L, 0L),
  QT_ABSTENCOES = c(5L, 0L, 5L, 0L),
  QT_VOTOS_NOMINAIS = c(3L, 0L, 3L, 0L),
  QT_VOTOS_BRANCOS = c(1L, 0L, 1L, 0L),
  QT_VOTOS_NULOS = c(1L, 0L, 1L, 0L),
  QT_VOTOS_LEGENDA = 0L, QT_VOTOS_ANULADOS_APU_SEP = 0L)
v <- d[c(1L, 3L), c(mebane_meta, mebane_key, "NM_MUNICIPIO"), with = FALSE]
v[, `:=`(NR_VOTAVEL = 22L, QT_VOTOS = 3L)]
v[, NM_VOTAVEL := "CANDIDATO"]
v <- rbind(v, data.table::data.table(
  d[c(1L, 3L), c(mebane_meta, mebane_key), with = FALSE],
  NM_MUNICIPIO = d$NM_MUNICIPIO[c(1L, 3L)],
  NR_VOTAVEL = 95L, NM_VOTAVEL = "BRANCO", QT_VOTOS = 1L),
  data.table::data.table(d[c(1L, 3L), c(mebane_meta, mebane_key), with = FALSE],
                         NM_MUNICIPIO = d$NM_MUNICIPIO[c(1L, 3L)],
                         NR_VOTAVEL = 96L, NM_VOTAVEL = "NULO", QT_VOTOS = 1L))
checked <- mebane_validate(copy(v), copy(d), cfg)
stopifnot(nrow(checked$sections) == 4L,
          nrow(checked$abstention_exceptions) == 2L,
          checked$sections[QT_COMPARECIMENTO == 0, sum(QT_APTOS - QT_COMPARECIMENTO)] == 14L)

dupe <- rbind(copy(v), copy(v[1L]))
dupe[nrow(dupe), QT_VOTOS := 2L]
expect_failure(mebane_validate(dupe, copy(d), cfg), "duplicate key")
expect_failure(mebane_validate(copy(v), rbind(copy(d), copy(d[1L])), cfg), "duplicate key")
missing_vote <- copy(v)[!(NR_TURNO == 1L & NR_VOTAVEL == 22L)]
expect_failure(mebane_validate(missing_vote, copy(d), cfg), "cannot be distinguished from zero")
missing_count <- copy(d)
missing_count[1L, QT_APTOS := NA_integer_]
expect_failure(mebane_validate(copy(v), missing_count, cfg), "invalid integer")
wrong_turn <- copy(v)
wrong_turn[NR_TURNO == 2L & NR_VOTAVEL == 22L, NR_VOTAVEL := 12L]
expect_failure(mebane_validate(wrong_turn, copy(d), cfg), "Candidate in wrong turn")
bad_balance <- copy(d)
bad_balance[1L, QT_VOTOS_NULOS := 2L]
expect_failure(mebane_validate(copy(v), bad_balance, cfg), "category totals disagree")
bad_abst <- copy(d)
bad_abst[1L, QT_ABSTENCOES := 0L]
expect_failure(mebane_validate(copy(v), bad_abst, cfg), "Unrecognized aptos/abstention")
bad_schema <- copy(d)
bad_schema[, QT_APTOS := NULL]
expect_failure(mebane_validate(copy(v), bad_schema, cfg), "Incompatible in-memory schema")
bad_election <- copy(v)
bad_election[NR_TURNO == 2L, CD_ELEICAO := 999L]
expect_failure(mebane_validate(bad_election, copy(d), cfg), "Election identity mismatch")
bad_text <- copy(v)
bad_text[1L, NM_VOTAVEL := ""]
expect_failure(mebane_validate(bad_text, copy(d), cfg), "Invalid Latin-1 vote text")
bad_csv <- tempfile(fileext = ".csv")
fwrite(d[, .(ANO_ELEICAO)], bad_csv, sep = ";")
expect_failure(mebane_read_csv(bad_csv, c("ANO_ELEICAO", "NR_TURNO")),
               "Incompatible raw schema")
unlink(bad_csv)
stopifnot(mebane_validate(copy(v), copy(d), cfg)$sections[QT_COMPARECIMENTO == 0, .N] == 2L)
cat("fixture adversarial checks: PASS\n")

args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 2L && args[[1L]] == "--full") {
  cfg <- mebane_config("config/mebane/2022.json")
  out <- args[[2L]]
  raw <- mebane_read_csv(cfg$detail_file, c(mebane_key, mebane_detail_counts))
  raw <- raw[ANO_ELEICAO == cfg$year & NR_TURNO %in% cfg$turns & CD_CARGO == cfg$cargo]
  independent <- raw[, .(sections = .N, aptos = sum(QT_APTOS),
                          comparecimento = sum(QT_COMPARECIMENTO),
                          abstencoes_reportadas = sum(QT_ABSTENCOES),
                          abstencoes_derivadas = sum(QT_APTOS - QT_COMPARECIMENTO),
                          nominais = sum(QT_VOTOS_NOMINAIS),
                          brancos = sum(QT_VOTOS_BRANCOS), nulos = sum(QT_VOTOS_NULOS),
                          nominal_zero_sections = sum(QT_VOTOS_NOMINAIS == 0)),
                     by = .(SG_UF, NR_TURNO)]
  setorderv(independent, c("SG_UF", "NR_TURNO"))
  actual <- fread(file.path(out, "uf_turn_reconciliation.csv"))
  stopifnot(identical(independent, actual))
  fwrite(independent, file.path(out, "independent_raw_uf_turn.csv"))
  vote <- mebane_read_csv(cfg$vote_file,
                          c(mebane_key, "NR_VOTAVEL", "QT_VOTOS"))
  vote <- vote[ANO_ELEICAO == cfg$year & NR_TURNO %in% cfg$turns & CD_CARGO == cfg$cargo]
  by_candidate <- vote[!NR_VOTAVEL %in% unlist(cfg$pseudo_candidates),
                       .(QT_VOTOS = sum(QT_VOTOS)), by = .(NR_TURNO, NR_VOTAVEL)]
  setorderv(by_candidate, c("NR_TURNO", "NR_VOTAVEL"))
  stopifnot(identical(by_candidate,
                      fread(file.path(out, "candidate_turn_totals.csv"))))
  model <- as.data.table(arrow::read_parquet(file.path(out, "model_counts.parquet")))
  stopifnot(nrow(model) == nrow(raw), all(model$N >= model$a),
            all(model$w <= model$N - model$a),
            model[, sum(flag_zero_nominal)] == raw[, sum(QT_VOTOS_NOMINAIS == 0)])
  cat("independent full raw UF/turn and candidate reconciliation: PASS\n")
}
