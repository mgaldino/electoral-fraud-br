# F01/F03 regressions: controls remain active while election identities are corrupted.
source("R/lib/mebane_data.R")
library(data.table)
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) stop("Usage: test_round2_repairs.R REPORT_DIR")
report_dir <- args[[1L]]
dir.create(report_dir, recursive = TRUE, showWarnings = FALSE)
cfg <- mebane_config("config/mebane/2022.json")
d <- data.table(
  ANO_ELEICAO = 2022L, NR_TURNO = 1:2, CD_CARGO = 1L, SG_UF = "SP",
  CD_MUNICIPIO = 71072L, NR_ZONA = 1L, NR_SECAO = 1L,
  DT_GERACAO = "01/11/2022", CD_ELEICAO = c(544L, 545L),
  DT_ELEICAO = c("02/10/2022", "30/10/2022"), CD_TIPO_ELEICAO = 2L,
  NM_MUNICIPIO = "SAO PAULO", QT_APTOS = 10L, QT_COMPARECIMENTO = 6L,
  QT_ABSTENCOES = 4L, QT_VOTOS_NOMINAIS = 4L, QT_VOTOS_BRANCOS = 1L,
  QT_VOTOS_NULOS = 1L, QT_VOTOS_LEGENDA = 0L, QT_VOTOS_ANULADOS_APU_SEP = 0L)
v <- d[c(rep(1L, 5L), rep(2L, 4L)),
       c(mebane_key, mebane_meta, "NM_MUNICIPIO"), with = FALSE]
v[, `:=`(NR_VOTAVEL = c(12L, 13L, 22L, 95L, 96L, 13L, 22L, 95L, 96L),
         QT_VOTOS = c(1L, 2L, 1L, 1L, 1L, 2L, 2L, 1L, 1L),
         NM_VOTAVEL = "CATEGORIA")]
control <- list(sections = 1, aptos = 10, comparecimento = 6,
                abstencoes_reportadas = 4, nominais = 4, brancos = 1, nulos = 1)
cfg$official_controls <- list(
  `1` = c(control, list(candidate_12 = 1, candidate_13 = 2, candidate_22 = 1)),
  `2` = c(control, list(candidate_13 = 2, candidate_22 = 2)))
results <- list()
record <- function(label, action, accepted = FALSE, error_pattern = NULL) {
  err <- tryCatch({ action(); NA_character_ }, error = function(e) conditionMessage(e))
  passed <- identical(is.na(err), accepted) &&
    (is.null(error_pattern) || (!is.na(err) && grepl(error_pattern, err, fixed = TRUE)))
  results[[length(results) + 1L]] <<- data.table(
    case = label, expected_acceptance = accepted, actual_acceptance = is.na(err),
    passed = passed, error = err)
}
validate <- function(dd = copy(d), vv = copy(v), cc = cfg) mebane_validate(vv, dd, cc)
record("valid_identity_and_active_candidate_controls", function() validate(), TRUE)
for (field in mebane_identity_fields) {
  wrong <- switch(field, CD_ELEICAO = 999L, DT_ELEICAO = "02/10/2020", CD_TIPO_ELEICAO = 1L)
  for (side in c("both", "detail", "vote")) {
    record(paste("wrong", field, side, sep = "_"), function() {
      dd <- copy(d)
      vv <- copy(v)
      if (side %in% c("both", "detail")) set(dd, j = field, value = wrong)
      if (side %in% c("both", "vote")) set(vv, j = field, value = wrong)
      validate(dd, vv)
    }, error_pattern = "Election identity mismatch")
  }
}
record("same_year_wrong_date_both", function() {
  dd <- copy(d); vv <- copy(v)
  dd[NR_TURNO == 1L, DT_ELEICAO := "03/10/2022"]
  vv[NR_TURNO == 1L, DT_ELEICAO := "03/10/2022"]
  validate(dd, vv)
}, error_pattern = "Election identity mismatch")
record("swapped_codes_both", function() {
  dd <- copy(d); vv <- copy(v)
  dd[, CD_ELEICAO := ifelse(NR_TURNO == 1L, 545L, 544L)]
  vv[, CD_ELEICAO := ifelse(NR_TURNO == 1L, 545L, 544L)]
  validate(dd, vv)
}, error_pattern = "Election identity mismatch")
record("source_type_column_missing", function() {
  dd <- copy(d); dd[, CD_TIPO_ELEICAO := NULL]; validate(dd)
}, error_pattern = "Incompatible in-memory schema")
record("trailing_date_characters_both", function() {
  dd <- copy(d); vv <- copy(v)
  dd[, DT_ELEICAO := paste0(DT_ELEICAO, "extra")]
  vv[, DT_ELEICAO := paste0(DT_ELEICAO, "extra")]
  validate(dd, vv)
}, error_pattern = "Invalid source dates")

record("nonleader_candidate_12_wrong_control_999", function() {
  cc <- cfg; cc$official_controls$`1`$candidate_12 <- 999L; validate(cc = cc)
}, error_pattern = "Official candidate control disagreement: turn 1 candidate_12")
record("nonleader_candidate_12_wrong_control_zero", function() {
  cc <- cfg; cc$official_controls$`1`$candidate_12 <- 0L; validate(cc = cc)
}, error_pattern = "Official candidate control disagreement")
record("eligible_absent_candidate_15_correct_zero_control", function() {
  cc <- cfg; cc$official_controls$`1`$candidate_15 <- 0L; validate(cc = cc)
}, TRUE)
record("eligible_absent_candidate_15_wrong_control", function() {
  cc <- cfg; cc$official_controls$`1`$candidate_15 <- 1L; validate(cc = cc)
}, error_pattern = "Official candidate control disagreement")
for (field in c("candidate_012", "candidate_", "candidate_12x", "candiate_12")) {
  record(paste0("malformed_control_name_", field), function() {
    cc <- cfg; cc$official_controls$`1`[[field]] <- 1L; validate(cc = cc)
  }, error_pattern = "invalid candidate control name")
}
record("candidate_ineligible_for_control_turn", function() {
  cc <- cfg; cc$official_controls$`2`$candidate_12 <- 0L; validate(cc = cc)
}, error_pattern = "ineligible candidate control")
record("pseudo_candidate_control", function() {
  cc <- cfg; cc$official_controls$`1`$candidate_95 <- 1L; validate(cc = cc)
}, error_pattern = "ineligible candidate control")
for (bad in list("1", -1L, 0.5, c(1L, 2L), NA_real_, list(1L))) {
  record(paste0("malformed_control_value_", length(results)), function() {
    cc <- cfg; cc$official_controls$`1`$candidate_12 <- bad; validate(cc = cc)
  }, error_pattern = "scalar nonnegative integer control")
}
record("duplicate_candidate_control", function() {
  cc <- cfg; cc$official_controls$`1` <- c(cc$official_controls$`1`, list(candidate_12 = 1L))
  validate(cc = cc)
}, error_pattern = "incomplete or duplicate controls")

original_json <- jsonlite::fromJSON("config/mebane/2022.json", simplifyVector = FALSE)
config_case <- function(label, mutate, accepted = FALSE) {
  record(paste0("config_", label), function() {
    altered <- mutate(original_json)
    path <- tempfile(fileext = ".json")
    on.exit(unlink(path))
    jsonlite::write_json(altered, path, auto_unbox = TRUE, null = "null", digits = NA)
    mebane_config(path)
  }, accepted)
}
config_case("valid", function(x) x, TRUE)
config_case("identity_missing", function(x) { x$election_identity <- NULL; x })
config_case("identity_turn_missing", function(x) { x$election_identity$`2` <- NULL; x })
config_case("identity_turn_extra", function(x) { x$election_identity$`3` <- x$election_identity$`2`; x })
config_case("identity_turn_duplicate", function(x) { x$election_identity <- c(x$election_identity, x$election_identity[1L]); x })
config_case("identity_field_duplicate", function(x) { x$election_identity$`1` <- c(x$election_identity$`1`, list(CD_ELEICAO = 544L)); x })
config_case("identity_type_missing", function(x) { x$election_identity$`1`$CD_TIPO_ELEICAO <- NULL; x })
config_case("identity_type_string", function(x) { x$election_identity$`1`$CD_TIPO_ELEICAO <- "2"; x })
config_case("identity_type_array", function(x) { x$election_identity$`1`$CD_TIPO_ELEICAO <- list(2L); x })
config_case("identity_code_fractional", function(x) { x$election_identity$`1`$CD_ELEICAO <- 544.5; x })
config_case("identity_code_duplicate", function(x) { x$election_identity$`2`$CD_ELEICAO <- 544L; x })
config_case("identity_date_wrong_year", function(x) { x$election_identity$`1`$DT_ELEICAO <- "02/10/2020"; x })
config_case("identity_date_invalid_day", function(x) { x$election_identity$`1`$DT_ELEICAO <- "31/02/2022"; x })
config_case("identity_date_trailing", function(x) { x$election_identity$`1`$DT_ELEICAO <- "02/10/2022x"; x })
config_case("identity_date_unpadded", function(x) { x$election_identity$`1`$DT_ELEICAO <- "2/10/2022"; x })
config_case("identity_date_reverse_turns", function(x) { x$election_identity$`1`$DT_ELEICAO <- "31/10/2022"; x })
config_case("year_string", function(x) { x$year <- "2022"; x })
config_case("year_array", function(x) { x$year <- list(2022L); x })
config_case("year_null", function(x) { x["year"] <- list(NULL); x })
config_case("turns_empty", function(x) { x$turns <- list(); x })
config_case("turns_scalar", function(x) { x$turns <- 1L; x })
config_case("turns_duplicate", function(x) { x$turns <- list(1L, 1L); x })
config_case("turns_fractional", function(x) { x$turns <- list(1L, 1.5); x })
config_case("cargo_array", function(x) { x$cargo <- list(1L); x })
config_case("eligible_empty", function(x) { x$eligible_candidates$`1` <- list(); x })
config_case("eligible_fractional", function(x) { x$eligible_candidates$`1` <- list(12.5, 13L); x })
config_case("target_ineligible", function(x) { x$target_candidates$`2` <- list(12L); x })
config_case("control_name_malformed", function(x) { x$official_controls$`1`$candidate_012 <- 1L; x })
config_case("control_ineligible", function(x) { x$official_controls$`2`$candidate_12 <- 0L; x })
config_case("control_null", function(x) { x$official_controls$`1`["candidate_13"] <- list(NULL); x })
config_case("control_turn_missing", function(x) { x$official_controls$`2` <- NULL; x })
config_case("control_extra_typo", function(x) { x$official_controls$`1`$nominal <- 1L; x })
config_case("control_nonleader_correct_form", function(x) { x$official_controls$`1`$candidate_12 <- 3599287L; x }, TRUE)

result <- rbindlist(results)
fwrite(result, file.path(report_dir, "repair_regressions.csv"))
print(result[, .(cases = .N, passed = sum(passed), rejected_as_expected = sum(!actual_acceptance & passed))])
if (!all(result$passed)) { print(result[!passed]); stop("Repair regression failed") }
cat("F01 identity and F03 candidate-control regressions: PASS\n")
