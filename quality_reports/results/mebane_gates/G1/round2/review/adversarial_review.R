# Reviewer-designed fixtures. Candidate functions are the system under test only.
suppressPackageStartupMessages(library(data.table))
source("R/lib/mebane_data.R")
out <- "quality_reports/results/mebane_gates/G1/round2/review"
fixtures <- file.path(out, "fixtures")
dir.create(fixtures, showWarnings = FALSE)
base_json <- jsonlite::fromJSON("config/mebane/2022.json", simplifyVector = FALSE)
d <- data.table(
  ANO_ELEICAO = 2022L, NR_TURNO = rep(1:2, each = 2L), CD_CARGO = 1L,
  SG_UF = "SP", CD_MUNICIPIO = 71072L, NR_ZONA = 1L, NR_SECAO = rep(1:2, 2L),
  DT_GERACAO = "01/11/2022", CD_ELEICAO = rep(c(544L, 545L), each = 2L),
  DT_ELEICAO = rep(c("02/10/2022", "30/10/2022"), each = 2L),
  CD_TIPO_ELEICAO = 2L, NM_MUNICIPIO = "SAO PAULO",
  QT_APTOS = rep(c(20L, 10L), 2L), QT_COMPARECIMENTO = rep(c(12L, 0L), 2L),
  QT_ABSTENCOES = rep(c(8L, 10L), 2L), QT_VOTOS_NOMINAIS = rep(c(10L, 0L), 2L),
  QT_VOTOS_BRANCOS = rep(c(1L, 0L), 2L), QT_VOTOS_NULOS = rep(c(1L, 0L), 2L),
  QT_VOTOS_LEGENDA = 0L, QT_VOTOS_ANULADOS_APU_SEP = 0L)
identity <- c("DT_GERACAO", "CD_ELEICAO", "DT_ELEICAO", "CD_TIPO_ELEICAO")
key <- c("ANO_ELEICAO", "NR_TURNO", "CD_CARGO", "SG_UF", "CD_MUNICIPIO", "NR_ZONA", "NR_SECAO")
v <- d[c(rep(1L, 6L), rep(3L, 4L)), c(key, identity, "NM_MUNICIPIO"), with = FALSE]
v[, NR_VOTAVEL := c(12L, 13L, 22L, 30L, 95L, 96L, 13L, 22L, 95L, 96L)]
v[, QT_VOTOS := c(2L, 4L, 3L, 1L, 1L, 1L, 6L, 4L, 1L, 1L)]
v[, NM_VOTAVEL := "CANDIDATO OU CATEGORIA"]
totals <- list(sections = 2L, aptos = 30L, comparecimento = 12L,
               abstencoes_reportadas = 18L, nominais = 10L, brancos = 1L, nulos = 1L)
base_json$official_controls <- list(
  `1` = c(totals, list(candidate_30 = 1L, candidate_12 = 2L,
                       candidate_13 = 4L, candidate_22 = 3L, candidate_15 = 0L)),
  `2` = c(totals, list(candidate_22 = 4L, candidate_13 = 6L)))
fixture_path <- function(name, object) {
  path <- file.path(fixtures, paste0(name, ".json"))
  jsonlite::write_json(object, path, auto_unbox = TRUE, null = "null", na = "null", digits = NA)
  path
}
cfg <- mebane_config(fixture_path("valid", base_json))
results <- list()
probe <- function(name, action, accept = FALSE, pattern = NULL) {
  error <- tryCatch({ action(); NA_character_ }, error = function(e) conditionMessage(e))
  matched <- is.null(pattern) || (!is.na(error) && grepl(pattern, error, fixed = TRUE))
  results[[length(results) + 1L]] <<- data.table(
    case = name, expected_acceptance = accept, actual_acceptance = is.na(error),
    error = error, passed = identical(is.na(error), accept) && matched)
}
validate <- function(dd = d, vv = v, cc = cfg) mebane_validate(copy(vv), copy(dd), cc)
probe("valid_all_declared_candidates_and_omitted_zero_sections", function() validate(), TRUE)

wrong <- list(CD_ELEICAO = 999L, DT_ELEICAO = "03/10/2022", CD_TIPO_ELEICAO = 1L)
for (field in names(wrong)) {
  for (side in c("both", "detail", "vote")) {
    probe(paste("identity", field, side, sep = "_"), function() {
      dd <- copy(d); vv <- copy(v)
      if (side %in% c("both", "detail")) set(dd, j = field, value = wrong[[field]])
      if (side %in% c("both", "vote")) set(vv, j = field, value = wrong[[field]])
      validate(dd, vv)
    }, pattern = "Election identity mismatch")
  }
}
probe("identity_wrong_year_concordant", function() {
  dd <- copy(d); vv <- copy(v)
  dd[, DT_ELEICAO := "02/10/2020"]; vv[, DT_ELEICAO := "02/10/2020"]
  validate(dd, vv)
}, pattern = "Election identity mismatch")
probe("identity_type_missing_from_both", function() {
  dd <- copy(d); vv <- copy(v)
  dd[, CD_TIPO_ELEICAO := NULL]; vv[, CD_TIPO_ELEICAO := NULL]
  validate(dd, vv)
}, pattern = "Incompatible in-memory schema")
for (candidate in c(12L, 13L, 15L, 22L, 30L)) {
  probe(paste0("candidate_", candidate, "_wrong_positive_control"), function() {
    cc <- cfg
    field <- paste0("candidate_", candidate)
    cc$official_controls$`1`[[field]] <- cc$official_controls$`1`[[field]] + 1L
    validate(cc = cc)
  }, pattern = "Official candidate control disagreement")
}
probe("candidate_30_wrong_zero_control", function() {
  cc <- cfg; cc$official_controls$`1`$candidate_30 <- 0L; validate(cc = cc)
}, pattern = "Official candidate control disagreement")

config_probe <- function(name, mutate, accept = FALSE) {
  probe(name, function() {
    changed <- mutate(base_json)
    loaded <- mebane_config(fixture_path(name, changed))
    validate(cc = loaded)
  }, accept)
}
for (field in c("candidate_012", "candidate_13.0", "candidate_1e1", "candidate_",
                "candidate_0", "candidate_-12", "Candidate_12", "candidate_12x")) {
  config_probe(paste0("invalid_name_", gsub("[^A-Za-z0-9]", "_", field)), function(x) {
    x$official_controls$`1`[[field]] <- 2L; x
  })
}
bad_values <- list(string = "2", negative = -2L, fractional = 2.5, boolean = TRUE,
                   null = NULL, array = list(2L), vector = c(2L, 3L), infinity = Inf,
                   too_large = 2147483648)
for (label in names(bad_values)) {
  config_probe(paste0("invalid_value_", label), function(x) {
    x$official_controls$`1`["candidate_12"] <- list(bad_values[[label]]); x
  })
}
config_probe("duplicate_candidate_control", function(x) {
  x$official_controls$`1` <- c(x$official_controls$`1`, list(candidate_12 = 2L)); x
})
config_probe("candidate_ineligible_turn2", function(x) {
  x$official_controls$`2`$candidate_12 <- 0L; x
})
config_probe("pseudo_candidate_control", function(x) {
  x$official_controls$`1`$candidate_95 <- 1L; x
})
config_probe("identity_duplicate_code_config", function(x) {
  x$election_identity$`2`$CD_ELEICAO <- 544L; x
})
config_probe("identity_wrong_config_year", function(x) {
  x$election_identity$`1`$DT_ELEICAO <- "02/10/2020"; x
})
probe("divergent_duplicate_vote", function() {
  vv <- rbind(v, v[1L]); vv[nrow(vv), QT_VOTOS := 99L]; validate(vv = vv)
}, pattern = "duplicate key")
probe("omitted_positive_candidate", function() validate(vv = v[-1L]),
      pattern = "category totals disagree")
probe("missing_detail_count", function() {
  dd <- copy(d); dd[1L, QT_APTOS := NA_integer_]; validate(dd = dd)
}, pattern = "invalid integer")
result <- rbindlist(results)
fwrite(result, file.path(out, "adversarial_results.csv"))
print(result[passed == FALSE])
stopifnot(all(result$passed))
cat(nrow(result), "independent probes PASS;", sum(!result$actual_acceptance), "rejections.\n")
