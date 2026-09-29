# Coordinator reproduction of G1-R1-QAD-F01 on the frozen candidate.
suppressPackageStartupMessages(library(data.table))
source("R/lib/mebane_data.R")
cfg <- mebane_config("config/mebane/2022.json")
d <- data.table(
  ANO_ELEICAO = 2022L, NR_TURNO = 1:2, CD_CARGO = 1L, SG_UF = "SP",
  CD_MUNICIPIO = 71072L, NR_ZONA = 1L, NR_SECAO = 1L,
  DT_GERACAO = "01/11/2022", CD_ELEICAO = c(544L, 545L),
  DT_ELEICAO = c("02/10/2022", "30/10/2022"), NM_MUNICIPIO = "SAO PAULO",
  QT_APTOS = 10L, QT_COMPARECIMENTO = 6L, QT_ABSTENCOES = 4L,
  QT_VOTOS_NOMINAIS = 4L, QT_VOTOS_BRANCOS = 1L, QT_VOTOS_NULOS = 1L,
  QT_VOTOS_LEGENDA = 0L, QT_VOTOS_ANULADOS_APU_SEP = 0L
)
v <- d[rep(1:2, each = 4L), c(mebane_key, mebane_meta, "NM_MUNICIPIO"), with = FALSE]
v[, `:=`(NR_VOTAVEL = rep(c(13L, 22L, 95L, 96L), 2L),
         QT_VOTOS = rep(c(2L, 2L, 1L, 1L), 2L), NM_VOTAVEL = "CATEGORIA")]
control <- list(sections = 1, aptos = 10, comparecimento = 6,
                abstencoes_reportadas = 4, nominais = 4, brancos = 1,
                nulos = 1, candidate_13 = 2, candidate_22 = 2)
cfg$official_controls <- list(`1` = control, `2` = control)
probe <- function(label, column = NULL, value = NULL) {
  vv <- copy(v)
  dd <- copy(d)
  if (!is.null(column)) {
    set(vv, j = column, value = value)
    set(dd, j = column, value = value)
  }
  err <- tryCatch({ mebane_validate(vv, dd, cfg); NA_character_ },
                  error = function(e) conditionMessage(e))
  data.table(case = label, accepted = is.na(err), error = err)
}
result <- rbindlist(list(
  probe("valid"), probe("wrong_code_both", "CD_ELEICAO", 999L),
  probe("wrong_date_both", "DT_ELEICAO", "02/10/2020")
))
stopifnot(all(result$accepted))
fwrite(result, "quality_reports/results/mebane_gates/G1/round1/adjudication_checks.csv")
print(result)
cat("Confirmed candidate defect; this is not a passing regression test.\n")
