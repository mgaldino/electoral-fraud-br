#!/usr/bin/env Rscript
# Separate reviewer fixtures for the candidate validator. Not used for raw controls.
suppressPackageStartupMessages(library(data.table))
source("R/lib/mebane_data.R")
out <- "quality_reports/results/mebane_gates/G1/round1/review"
cfg <- mebane_config("config/mebane/2022.json")
detail <- data.table(
  DT_GERACAO = "01/11/2022", CD_ELEICAO = c(544L, 545L),
  DT_ELEICAO = c("02/10/2022", "30/10/2022"), ANO_ELEICAO = 2022L,
  NR_TURNO = c(1L, 2L), CD_CARGO = 1L, SG_UF = "SP",
  CD_MUNICIPIO = 71072L, NR_ZONA = 1L, NR_SECAO = 1L,
  NM_MUNICIPIO = "SAO PAULO", QT_APTOS = 10L, QT_COMPARECIMENTO = 6L,
  QT_ABSTENCOES = 4L, QT_VOTOS_NOMINAIS = 4L,
  QT_VOTOS_BRANCOS = 1L, QT_VOTOS_NULOS = 1L,
  QT_VOTOS_LEGENDA = 0L, QT_VOTOS_ANULADOS_APU_SEP = 0L)
vote <- detail[rep(1:2, each = 4L),
               c(mebane_meta, mebane_key, "NM_MUNICIPIO"), with = FALSE]
vote[, NR_VOTAVEL := rep(c(13L, 22L, 95L, 96L), 2L)]
vote[, QT_VOTOS := c(2L, 2L, 1L, 1L, 3L, 1L, 1L, 1L)]
vote[, NM_VOTAVEL := ifelse(NR_VOTAVEL == 95L, "BRANCO",
                            ifelse(NR_VOTAVEL == 96L, "NULO", "CANDIDATO"))]
cfg$official_controls <- list(
  `1` = list(sections = 1L, aptos = 10L, comparecimento = 6L,
             abstencoes_reportadas = 4L, nominais = 4L, brancos = 1L,
             nulos = 1L, candidate_13 = 2L, candidate_22 = 2L),
  `2` = list(sections = 1L, aptos = 10L, comparecimento = 6L,
             abstencoes_reportadas = 4L, nominais = 4L, brancos = 1L,
             nulos = 1L, candidate_13 = 3L, candidate_22 = 1L))

probe <- function(label, vv, dd, cc = cfg) {
  err <- tryCatch({ mebane_validate(copy(vv), copy(dd), cc); NA_character_ },
                  error = function(e) conditionMessage(e))
  data.table(case = label, accepted = is.na(err), message = ifelse(is.na(err), "", err))
}
cases <- list(probe("valid", vote, detail))
wrong_code_v <- copy(vote)
wrong_code_d <- copy(detail)
wrong_code_v[, CD_ELEICAO := 999L]
wrong_code_d[, CD_ELEICAO := 999L]
cases[[length(cases) + 1L]] <- probe("wrong_election_code_both_sources", wrong_code_v, wrong_code_d)
wrong_date_v <- copy(vote)
wrong_date_d <- copy(detail)
wrong_date_v[, DT_ELEICAO := "02/10/2020"]
wrong_date_d[, DT_ELEICAO := "02/10/2020"]
cases[[length(cases) + 1L]] <- probe("wrong_election_year_both_sources", wrong_date_v, wrong_date_d)
duplicate <- rbind(copy(vote), copy(vote[1L]))
duplicate[nrow(duplicate), QT_VOTOS := 9L]
cases[[length(cases) + 1L]] <- probe("divergent_duplicate_vote", duplicate, detail)
cases[[length(cases) + 1L]] <- probe("omitted_positive_vote", vote[-1L], detail)
wrong_turn <- copy(vote)
wrong_turn[NR_TURNO == 2L & NR_VOTAVEL == 22L, NR_VOTAVEL := 12L]
cases[[length(cases) + 1L]] <- probe("ineligible_candidate_turn", wrong_turn, detail)
missing <- copy(detail)
missing[1L, QT_APTOS := NA_integer_]
cases[[length(cases) + 1L]] <- probe("missing_aptos", vote, missing)

result <- rbindlist(cases)
fwrite(result, file.path(out, "adversarial_results.csv"))
stopifnot(result[case == "valid", accepted],
          all(result[case %in% c("wrong_election_code_both_sources",
                                 "wrong_election_year_both_sources"), accepted]),
          all(!result[case %in% c("divergent_duplicate_vote", "omitted_positive_vote",
                                  "ineligible_candidate_turn", "missing_aptos"), accepted]))
cat("reviewer adversarial probes: 4 expected rejections; 2 wrong-election cases accepted\n")
