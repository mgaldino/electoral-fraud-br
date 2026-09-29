# A control for an eligible third candidate must not be silently ignored.
suppressPackageStartupMessages(library(data.table))
source("R/lib/mebane_data.R")
cfg <- mebane_config("config/mebane/2022.json")
cfg$turns <- 1L
cfg$eligible_candidates <- list(`1` = c(12L, 13L, 22L))
cfg$target_candidates <- list(`1` = 13L)
d <- data.table(
  ANO_ELEICAO = 2022L, NR_TURNO = 1L, CD_CARGO = 1L, SG_UF = "SP",
  CD_MUNICIPIO = 71072L, NR_ZONA = 1L, NR_SECAO = 1L,
  DT_GERACAO = "01/11/2022", CD_ELEICAO = 544L, DT_ELEICAO = "02/10/2022",
  NM_MUNICIPIO = "SAO PAULO", QT_APTOS = 10L, QT_COMPARECIMENTO = 6L,
  QT_ABSTENCOES = 4L, QT_VOTOS_NOMINAIS = 4L, QT_VOTOS_BRANCOS = 1L,
  QT_VOTOS_NULOS = 1L, QT_VOTOS_LEGENDA = 0L, QT_VOTOS_ANULADOS_APU_SEP = 0L
)
v <- d[rep(1L, 5L), c(mebane_key, mebane_meta, "NM_MUNICIPIO"), with = FALSE]
v[, `:=`(NR_VOTAVEL = c(12L, 13L, 22L, 95L, 96L),
         QT_VOTOS = c(1L, 2L, 1L, 1L, 1L), NM_VOTAVEL = "CATEGORIA")]
cfg$official_controls <- list(`1` = list(
  sections = 1, aptos = 10, comparecimento = 6, abstencoes_reportadas = 4,
  nominais = 4, brancos = 1, nulos = 1, candidate_12 = 1,
  candidate_13 = 2, candidate_22 = 1
))
probe <- function(value) {
  cc <- cfg
  cc$official_controls$`1`$candidate_12 <- value
  err <- tryCatch({ mebane_validate(copy(v), copy(d), cc); NA_character_ },
                  error = function(e) conditionMessage(e))
  data.table(actual_candidate_12 = 1, configured_control = value,
             accepted = is.na(err), error = err)
}
result <- rbindlist(list(probe(1), probe(999)))
stopifnot(all(result$accepted))
fwrite(result, "quality_reports/results/mebane_gates/G1/round1/adjudication_candidate_controls.csv")
print(result)
cat("Confirmed ignored candidate control; not a passing regression.\n")
