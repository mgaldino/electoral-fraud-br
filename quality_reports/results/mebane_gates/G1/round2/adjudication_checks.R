# Reapply the coordinator's round1 counterexamples without changing frozen evidence.
suppressPackageStartupMessages(library(data.table))
source("R/lib/mebane_data.R")
cfg <- mebane_config("config/mebane/2022.json")
d <- data.table(
  ANO_ELEICAO = 2022L, NR_TURNO = 1:2, CD_CARGO = 1L, SG_UF = "SP",
  CD_MUNICIPIO = 71072L, NR_ZONA = 1L, NR_SECAO = 1L,
  DT_GERACAO = "01/11/2022", CD_ELEICAO = c(544L, 545L),
  CD_TIPO_ELEICAO = 2L, DT_ELEICAO = c("02/10/2022", "30/10/2022"),
  NM_MUNICIPIO = "SAO PAULO", QT_APTOS = 10L, QT_COMPARECIMENTO = 6L,
  QT_ABSTENCOES = 4L, QT_VOTOS_NOMINAIS = 4L, QT_VOTOS_BRANCOS = 1L,
  QT_VOTOS_NULOS = 1L, QT_VOTOS_LEGENDA = 0L, QT_VOTOS_ANULADOS_APU_SEP = 0L
)
v <- d[c(rep(1L, 5L), rep(2L, 4L)),
       c(mebane_key, mebane_meta, "NM_MUNICIPIO"), with = FALSE]
v[, `:=`(NR_VOTAVEL = c(12L, 13L, 22L, 95L, 96L, 13L, 22L, 95L, 96L),
         QT_VOTOS = c(1L, 2L, 1L, 1L, 1L, 2L, 2L, 1L, 1L),
         NM_VOTAVEL = "CATEGORIA")]
control <- list(sections = 1, aptos = 10, comparecimento = 6,
                abstencoes_reportadas = 4, nominais = 4, brancos = 1,
                nulos = 1, candidate_13 = 2, candidate_22 = 2)
cfg$official_controls <- list(`1` = control, `2` = control)
cfg$official_controls$`1`$candidate_22 <- 1
cfg$official_controls$`1`$candidate_12 <- 1

probe <- function(label, field = NULL, value = NULL, candidate_control = NULL,
                  expected_error = NULL) {
  vv <- copy(v)
  dd <- copy(d)
  cc <- cfg
  if (!is.null(field)) {
    set(vv, j = field, value = value)
    set(dd, j = field, value = value)
  }
  if (!is.null(candidate_control)) cc$official_controls$`1`$candidate_12 <- candidate_control
  err <- tryCatch({ mebane_validate(vv, dd, cc); NA_character_ },
                  error = function(e) conditionMessage(e))
  passed <- if (is.null(expected_error)) is.na(err) else
    !is.na(err) && grepl(expected_error, err, fixed = TRUE)
  data.table(case = label, accepted = is.na(err), passed = passed, error = err)
}
result <- rbindlist(list(
  probe("valid_including_candidate12"),
  probe("wrong_code_both", "CD_ELEICAO", 999L, expected_error = "CD_ELEICAO"),
  probe("wrong_date_both", "DT_ELEICAO", "02/10/2020", expected_error = "DT_ELEICAO"),
  probe("wrong_type_both", "CD_TIPO_ELEICAO", 99L, expected_error = "CD_TIPO_ELEICAO"),
  probe("wrong_candidate12_control", candidate_control = 999, expected_error = "candidate_12")
))
fwrite(result, "quality_reports/results/mebane_gates/G1/round2/adjudication_checks.csv")
print(result)
stopifnot(all(result$passed))
cat("PASS: original defects now rejected for the intended reason; valid input accepted.\n")
