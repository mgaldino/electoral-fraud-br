# G1 data contract. No estimates or graph-specific exclusions are made here.
mebane_key <- c("ANO_ELEICAO", "NR_TURNO", "CD_CARGO", "SG_UF",
                "CD_MUNICIPIO", "NR_ZONA", "NR_SECAO")
mebane_detail_counts <- c("QT_APTOS", "QT_COMPARECIMENTO", "QT_ABSTENCOES",
                          "QT_VOTOS_NOMINAIS", "QT_VOTOS_BRANCOS", "QT_VOTOS_NULOS",
                          "QT_VOTOS_LEGENDA", "QT_VOTOS_ANULADOS_APU_SEP")
mebane_identity_fields <- c("CD_ELEICAO", "DT_ELEICAO", "CD_TIPO_ELEICAO")
mebane_meta <- c("DT_GERACAO", mebane_identity_fields)

mebane_fail <- function(...) stop(paste0(...), call. = FALSE)

mebane_config_object <- function(x, keys = NULL) {
  is.list(x) && !is.null(names(x)) && !anyDuplicated(names(x)) &&
    all(nzchar(names(x))) && (is.null(keys) || setequal(names(x), keys))
}

mebane_config_integer <- function(x, minimum = 1) {
  is.numeric(x) && length(x) == 1L && !is.na(x) && is.finite(x) &&
    x == floor(x) && x >= minimum && x <= .Machine$integer.max
}

mebane_config_string <- function(x) {
  is.character(x) && length(x) == 1L && !is.na(x) && nzchar(x)
}

mebane_config_array <- function(x, label) {
  if (!is.list(x) || !is.null(names(x)) || !length(x) ||
      !all(vapply(x, mebane_config_integer, logical(1)))) {
    mebane_fail("Configuration requires a nonempty integer array: ", label)
  }
  unlist(x, use.names = FALSE)
}

mebane_valid_dates <- function(x) {
  if (!is.character(x) || anyNA(x)) return(FALSE)
  x <- unique(x)
  if (any(!grepl("^[0-9]{2}/[0-9]{2}/[0-9]{4}$", x))) return(FALSE)
  parsed <- as.Date(x, "%d/%m/%Y")
  !anyNA(parsed) && all(format(parsed, "%d/%m/%Y") == x)
}

mebane_check_control_config <- function(cfg) {
  controls <- cfg$official_controls
  if (is.null(controls)) return(invisible(NULL))
  turn_keys <- as.character(cfg$turns)
  metadata_keys <- c("status", "first_turn_url", "second_turn_url",
                     "first_turn_published", "second_turn_published",
                     "first_turn_last_updated", "second_turn_last_updated")
  if (!mebane_config_object(controls) ||
      !all(turn_keys %in% names(controls)) ||
      !all(names(controls) %in% c(turn_keys, metadata_keys))) {
    mebane_fail("Configuration has malformed official control turn mapping")
  }
  for (field in intersect(names(controls), metadata_keys)) {
    if (!mebane_config_string(controls[[field]])) {
      mebane_fail("Configuration has malformed official control metadata: ", field)
    }
  }
  total_fields <- c("sections", "aptos", "comparecimento", "abstencoes_reportadas",
                    "nominais", "brancos", "nulos")
  for (turn in turn_keys) {
    control <- controls[[turn]]
    if (!mebane_config_object(control) || !all(total_fields %in% names(control))) {
      mebane_fail("Configuration has incomplete or duplicate controls for turn ", turn)
    }
    candidate_fields <- setdiff(names(control), total_fields)
    if (any(!grepl("^candidate_[1-9][0-9]*$", candidate_fields))) {
      mebane_fail("Configuration has invalid candidate control name in turn ", turn)
    }
    candidates <- suppressWarnings(as.numeric(sub("^candidate_", "", candidate_fields)))
    if (anyNA(candidates) || any(!is.finite(candidates)) ||
        any(!candidates %in% cfg$eligible_candidates[[turn]])) {
      mebane_fail("Configuration has ineligible candidate control in turn ", turn)
    }
    for (field in names(control)) {
      if (!mebane_config_integer(control[[field]], 0)) {
        mebane_fail("Configuration requires scalar nonnegative integer control: ", turn, " ", field)
      }
    }
  }
  invisible(NULL)
}

mebane_config <- function(path) {
  if (!file.exists(path)) mebane_fail("Missing configuration: ", path)
  cfg <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  needed <- c("year", "turns", "cargo", "vote_file", "detail_file", "encoding",
              "eligible_candidates", "target_candidates", "pseudo_candidates",
              "small_section_threshold", "exterior_policy", "zero_vote_policy",
              "abstention_exception", "election_identity")
  if (!mebane_config_object(cfg) || !all(needed %in% names(cfg))) {
    mebane_fail("Configuration schema changed or duplicate object keys")
  }
  if (!mebane_config_integer(cfg$year, 1000) || cfg$year > 9999 ||
      !mebane_config_integer(cfg$cargo) ||
      !mebane_config_integer(cfg$small_section_threshold, 0)) {
    mebane_fail("Configuration requires scalar integer year, cargo and threshold")
  }
  cfg$turns <- mebane_config_array(cfg$turns, "turns")
  if (!all(cfg$turns %in% 1:2) || anyDuplicated(cfg$turns)) {
    mebane_fail("Configuration has invalid or duplicate turns")
  }
  turn_keys <- as.character(cfg$turns)
  for (field in c("eligible_candidates", "target_candidates", "election_identity")) {
    if (!mebane_config_object(cfg[[field]], turn_keys)) {
      mebane_fail("Configuration turn mapping is incomplete or duplicated: ", field)
    }
  }
  for (field in c("vote_file", "detail_file", "encoding", "exterior_policy",
                  "zero_vote_policy", "abstention_exception")) {
    if (!mebane_config_string(cfg[[field]])) mebane_fail("Configuration requires scalar text: ", field)
  }
  if (
      cfg$encoding != "Latin-1" || cfg$exterior_policy != "include_flagged" ||
      cfg$zero_vote_policy != "infer_only_after_complete_category_reconciliation" ||
      cfg$abstention_exception != "zero_turnout_zero_reported_abstentions_flagged_not_model_eligible") {
    mebane_fail("Unsupported configuration policy")
  }
  if (!mebane_config_object(cfg$pseudo_candidates, c("blank", "null")) ||
      !all(vapply(cfg$pseudo_candidates, mebane_config_integer, logical(1))) ||
      anyDuplicated(unlist(cfg$pseudo_candidates))) {
    mebane_fail("Configuration has malformed pseudo-candidate mapping")
  }
  for (turn in turn_keys) {
    eligible <- mebane_config_array(cfg$eligible_candidates[[turn]], paste0("eligible_candidates.", turn))
    target <- mebane_config_array(cfg$target_candidates[[turn]], paste0("target_candidates.", turn))
    if (anyDuplicated(eligible) || anyDuplicated(target) ||
        any(eligible %in% unlist(cfg$pseudo_candidates)) ||
        !all(target %in% eligible)) mebane_fail("Ineligible target in turn ", turn)
    cfg$eligible_candidates[[turn]] <- eligible
    cfg$target_candidates[[turn]] <- target
    identity <- cfg$election_identity[[turn]]
    if (!mebane_config_object(identity, mebane_identity_fields) ||
        !mebane_config_integer(identity$CD_ELEICAO) ||
        !mebane_config_integer(identity$CD_TIPO_ELEICAO) ||
        !mebane_config_string(identity$DT_ELEICAO) ||
        !mebane_valid_dates(identity$DT_ELEICAO) ||
        as.integer(format(as.Date(identity$DT_ELEICAO, "%d/%m/%Y"), "%Y")) != cfg$year) {
      mebane_fail("Configuration has malformed election identity for turn ", turn)
    }
  }
  identities <- cfg$election_identity[as.character(sort(cfg$turns))]
  codes <- vapply(identities, function(x) x$CD_ELEICAO, numeric(1))
  dates <- as.Date(vapply(identities, function(x) x$DT_ELEICAO, character(1)), "%d/%m/%Y")
  if (anyDuplicated(codes) || any(diff(dates) <= 0)) {
    mebane_fail("Configuration election codes must be unique and dates ordered by turn")
  }
  mebane_check_control_config(cfg)
  cfg$config_path <- path
  cfg
}

mebane_check_identity <- function(dt, cfg, label) {
  metadata <- unique(dt[, c("NR_TURNO", mebane_identity_fields), with = FALSE])
  for (turn in cfg$turns) {
    actual <- metadata[NR_TURNO == turn]
    expected <- cfg$election_identity[[as.character(turn)]]
    for (field in mebane_identity_fields) {
      if (nrow(actual) != 1L || any(actual[[field]] != expected[[field]])) {
        mebane_fail("Election identity mismatch: ", label, " turn ", turn, " ", field)
      }
    }
  }
}

mebane_new_output <- function(path) {
  if (dir.exists(path) || file.exists(path)) mebane_fail("Output path already exists: ", path)
  if (grepl("(^|/)data/processed(/|$)", path)) mebane_fail("Historical processed outputs are read-only")
  if (!dir.create(path, recursive = TRUE, showWarnings = FALSE)) mebane_fail("Cannot create output: ", path)
  path
}

mebane_integer <- function(dt, columns, label) {
  for (column in columns) {
    x <- dt[[column]]
    if (!is.numeric(x) || anyNA(x) || any(!is.finite(x)) ||
        any(x < 0) || any(x != floor(x))) {
      mebane_fail(label, ": invalid integer count/key in ", column)
    }
  }
}

mebane_unique <- function(dt, key, label) {
  if (anyNA(dt[, ..key]) || anyDuplicated(dt, by = key)) {
    mebane_fail(label, ": missing or duplicate key (including divergent duplicates)")
  }
}

mebane_read_csv <- function(path, columns) {
  if (!file.exists(path)) mebane_fail("Missing raw input: ", path)
  header <- names(data.table::fread(path, sep = ";", nrows = 0L,
                                    encoding = "Latin-1", showProgress = FALSE))
  if (anyDuplicated(header) || !all(columns %in% header)) {
    mebane_fail("Incompatible raw schema: ", path)
  }
  data.table::fread(path, sep = ";", dec = ",", encoding = "Latin-1",
                    select = columns, showProgress = FALSE)
}

mebane_validate <- function(v, d, cfg) {
  mebane_check_control_config(cfg)
  if (!all(c(mebane_key, mebane_detail_counts, mebane_meta,
             "NM_MUNICIPIO") %in% names(d)) ||
      !all(c(mebane_key, "NR_VOTAVEL", "QT_VOTOS", mebane_meta,
             "NM_MUNICIPIO", "NM_VOTAVEL") %in% names(v))) {
    mebane_fail("Incompatible in-memory schema")
  }
  for (column in c("NM_MUNICIPIO", "NM_VOTAVEL")) {
    if (column %in% names(v)) {
      converted <- iconv(v[[column]], from = "latin1", to = "UTF-8", sub = NA)
      if (anyNA(converted) || any(!nzchar(converted)) || !all(validUTF8(converted))) {
        mebane_fail("Invalid Latin-1 vote text: ", column)
      }
      data.table::set(v, j = column, value = converted)
    }
  }
  converted <- iconv(d$NM_MUNICIPIO, from = "latin1", to = "UTF-8", sub = NA)
  if (anyNA(converted) || any(!nzchar(converted)) || !all(validUTF8(converted))) {
    mebane_fail("Invalid Latin-1 detail text")
  }
  data.table::set(d, j = "NM_MUNICIPIO", value = converted)
  mebane_integer(d, c(mebane_key[mebane_key != "SG_UF"], mebane_detail_counts,
                      "CD_ELEICAO", "CD_TIPO_ELEICAO"), "detail")
  mebane_integer(v, c(mebane_key[mebane_key != "SG_UF"], "NR_VOTAVEL",
                      "QT_VOTOS", "CD_ELEICAO", "CD_TIPO_ELEICAO"), "vote")
  if (anyNA(d$SG_UF) || anyNA(v$SG_UF) || any(!nzchar(d$SG_UF)) ||
      any(!nzchar(v$SG_UF))) mebane_fail("Missing UF")
  if (!mebane_valid_dates(d$DT_GERACAO) || !mebane_valid_dates(v$DT_GERACAO) ||
      !mebane_valid_dates(d$DT_ELEICAO) || !mebane_valid_dates(v$DT_ELEICAO)) {
    mebane_fail("Invalid source dates")
  }
  d <- d[ANO_ELEICAO == cfg$year & NR_TURNO %in% cfg$turns & CD_CARGO == cfg$cargo]
  v <- v[ANO_ELEICAO == cfg$year & NR_TURNO %in% cfg$turns & CD_CARGO == cfg$cargo]
  if (!nrow(d) || !nrow(v) || !setequal(unique(d$NR_TURNO), cfg$turns) ||
      !setequal(unique(v$NR_TURNO), cfg$turns)) mebane_fail("Missing configured election or turn")
  mebane_check_identity(d, cfg, "detail")
  mebane_check_identity(v, cfg, "vote")
  mebane_unique(d, mebane_key, "detail")
  mebane_unique(v, c(mebane_key, "NR_VOTAVEL"), "vote")
  if (nrow(data.table::fsetdiff(unique(v[, ..mebane_key]),
                                unique(d[, ..mebane_key]))) > 0L) {
    mebane_fail("Vote row without matching detail section")
  }
  for (turn in cfg$turns) {
    allowed <- c(cfg$eligible_candidates[[as.character(turn)]],
                 unlist(cfg$pseudo_candidates, use.names = FALSE))
    if (any(!v[NR_TURNO == turn, NR_VOTAVEL] %in% allowed)) {
      mebane_fail("Candidate in wrong turn or unknown category: ", turn)
    }
  }
  blank <- cfg$pseudo_candidates$blank
  null <- cfg$pseudo_candidates$null
  sums <- v[, .(raw_nominais = sum(QT_VOTOS[!NR_VOTAVEL %in% c(blank, null)]),
                raw_brancos = sum(QT_VOTOS[NR_VOTAVEL == blank]),
                raw_nulos = sum(QT_VOTOS[NR_VOTAVEL == null])), by = mebane_key]
  joined <- merge(d, sums, by = mebane_key, all.x = TRUE, sort = FALSE)
  if (nrow(joined) != nrow(d)) mebane_fail("Non-1:1 section join")
  for (column in c("raw_nominais", "raw_brancos", "raw_nulos")) {
    data.table::set(joined, which(is.na(joined[[column]])), column, 0)
  }
  if (any(joined$raw_nominais != joined$QT_VOTOS_NOMINAIS) ||
      any(joined$raw_brancos != joined$QT_VOTOS_BRANCOS) ||
      any(joined$raw_nulos != joined$QT_VOTOS_NULOS)) {
    mebane_fail("Missing vote row cannot be distinguished from zero: category totals disagree")
  }
  if (any(joined$QT_COMPARECIMENTO > joined$QT_APTOS) ||
      any(joined$QT_COMPARECIMENTO != joined$QT_VOTOS_NOMINAIS +
          joined$QT_VOTOS_BRANCOS + joined$QT_VOTOS_NULOS +
          joined$QT_VOTOS_LEGENDA + joined$QT_VOTOS_ANULADOS_APU_SEP)) {
    mebane_fail("Impossible turnout or inconsistent ballot accounting")
  }
  bad <- joined[QT_APTOS != QT_COMPARECIMENTO + QT_ABSTENCOES]
  if (nrow(bad) && any(bad$QT_COMPARECIMENTO != 0 |
                       bad$QT_ABSTENCOES != 0)) {
    mebane_fail("Unrecognized aptos/abstention discrepancy")
  }
  for (turn in cfg$turns) {
    sub <- joined[NR_TURNO == turn]
    control <- cfg$official_controls[[as.character(turn)]]
    if (!is.null(control)) {
      observed <- c(sections = nrow(sub), aptos = sum(sub$QT_APTOS),
                    comparecimento = sum(sub$QT_COMPARECIMENTO),
                    abstencoes_reportadas = sum(sub$QT_ABSTENCOES),
                    nominais = sum(sub$QT_VOTOS_NOMINAIS),
                    brancos = sum(sub$QT_VOTOS_BRANCOS), nulos = sum(sub$QT_VOTOS_NULOS))
      for (field in names(observed)) {
        if (observed[[field]] != control[[field]]) mebane_fail("Official control disagreement: turn ", turn, " ", field)
      }
      for (field in grep("^candidate_", names(control), value = TRUE)) {
        candidate <- as.integer(sub("^candidate_", "", field))
        if (sum(v[NR_TURNO == turn & NR_VOTAVEL == candidate, QT_VOTOS]) != control[[field]]) {
          mebane_fail("Official candidate control disagreement: turn ", turn, " ", field)
        }
      }
    }
  }
  list(sections = joined, votes = v, abstention_exceptions = bad)
}

mebane_load <- function(cfg, out) {
  d <- mebane_read_csv(cfg$detail_file, c(mebane_meta, mebane_key,
                                          "NM_MUNICIPIO", mebane_detail_counts))
  v <- mebane_read_csv(cfg$vote_file, c(mebane_meta, mebane_key,
                                        "NM_MUNICIPIO", "NR_VOTAVEL",
                                        "NM_VOTAVEL", "QT_VOTOS"))
  checked <- mebane_validate(v, d, cfg)
  data.table::setorderv(checked$sections, mebane_key)
  data.table::setorderv(checked$votes, c(mebane_key, "NR_VOTAVEL"))
  arrow::write_parquet(checked$sections, file.path(out, "sections_validated.parquet"))
  arrow::write_parquet(checked$votes, file.path(out, "votes_validated.parquet"))
  data.table::fwrite(checked$abstention_exceptions,
                     file.path(out, "abstention_exceptions.csv"))
  metadata <- data.table::rbindlist(list(
    d[, .(source = "detail", rows = .N), by = c("NR_TURNO", mebane_meta)],
    v[, .(source = "vote", rows = .N), by = c("NR_TURNO", mebane_meta)]))
  data.table::setorderv(metadata, c("source", "NR_TURNO", "DT_GERACAO"))
  data.table::fwrite(metadata, file.path(out, "source_metadata.csv"))
  writeLines(digest::digest(file = cfg$config_path, algo = "sha256"),
             file.path(out, "load_config_sha256.txt"))
  message("Validated ", nrow(checked$sections), " sections, ",
          nrow(checked$votes), " vote rows; abstention exceptions: ",
          nrow(checked$abstention_exceptions))
  invisible(checked)
}

mebane_build <- function(cfg, out) {
  files <- c("sections_validated.parquet", "votes_validated.parquet",
             "load_config_sha256.txt")
  if (!all(file.exists(file.path(out, files)))) mebane_fail("Validated load missing")
  if (readLines(file.path(out, "load_config_sha256.txt"), warn = FALSE) !=
      digest::digest(file = cfg$config_path, algo = "sha256")) mebane_fail("Configuration changed after load")
  outputs <- c("model_counts.parquet", "uf_turn_reconciliation.csv",
               "candidate_turn_totals.csv", "rule_log.csv")
  if (any(file.exists(file.path(out, outputs)))) mebane_fail("Build output already exists")
  d <- data.table::as.data.table(arrow::read_parquet(file.path(out, files[[1L]])))
  v <- data.table::as.data.table(arrow::read_parquet(file.path(out, files[[2L]])))
  target <- data.table::rbindlist(lapply(cfg$turns, function(turn) {
    data.table::data.table(NR_TURNO = turn,
                           NR_VOTAVEL = cfg$target_candidates[[as.character(turn)]])
  }))
  model <- merge(d, target, by = "NR_TURNO", allow.cartesian = TRUE)
  vote_target <- v[NR_VOTAVEL %in% unique(target$NR_VOTAVEL),
                   c(mebane_key, "NR_VOTAVEL", "QT_VOTOS"), with = FALSE]
  model <- merge(model, vote_target, by = c(mebane_key, "NR_VOTAVEL"),
                 all.x = TRUE, sort = FALSE)
  if (nrow(model) != sum(vapply(cfg$turns, function(turn) {
    nrow(d[NR_TURNO == turn]) * length(cfg$target_candidates[[as.character(turn)]])
  }, integer(1)))) mebane_fail("Target join cardinality changed")
  model[is.na(QT_VOTOS), QT_VOTOS := 0L]
  model[, `:=`(N = QT_APTOS, a = QT_APTOS - QT_COMPARECIMENTO,
               w = QT_VOTOS, flag_exterior = SG_UF == "ZZ",
               flag_small = QT_APTOS < cfg$small_section_threshold,
               flag_zero_nominal = QT_VOTOS_NOMINAIS == 0,
               flag_zero_turnout = QT_COMPARECIMENTO == 0,
               abstention_discrepancy = QT_APTOS != QT_COMPARECIMENTO + QT_ABSTENCOES,
               model_eligible = QT_APTOS > 0 &
                 QT_APTOS == QT_COMPARECIMENTO + QT_ABSTENCOES)]
  if (any(model$w > model$N - model$a) || any(model$a < 0)) {
    mebane_fail("N/a/w physical bounds failed")
  }
  cand <- v[!NR_VOTAVEL %in% unlist(cfg$pseudo_candidates),
            .(QT_VOTOS = sum(QT_VOTOS)), by = .(NR_TURNO, NR_VOTAVEL)]
  data.table::setorderv(cand, c("NR_TURNO", "NR_VOTAVEL"))
  leaders <- cand[, .SD[QT_VOTOS == max(QT_VOTOS)], by = NR_TURNO]
  if (anyDuplicated(leaders, by = "NR_TURNO")) mebane_fail("National leader tie")
  model[, national_leader := leaders$NR_VOTAVEL[match(NR_TURNO, leaders$NR_TURNO)]]
  totals <- d[, .(sections = .N, aptos = sum(QT_APTOS),
                  comparecimento = sum(QT_COMPARECIMENTO),
                  abstencoes_reportadas = sum(QT_ABSTENCOES),
                  abstencoes_derivadas = sum(QT_APTOS - QT_COMPARECIMENTO),
                  nominais = sum(QT_VOTOS_NOMINAIS), brancos = sum(QT_VOTOS_BRANCOS),
                  nulos = sum(QT_VOTOS_NULOS),
                  nominal_zero_sections = sum(QT_VOTOS_NOMINAIS == 0)),
              by = .(SG_UF, NR_TURNO)]
  data.table::setorderv(totals, c("SG_UF", "NR_TURNO"))
  rules <- model[, .(sections = .N, exterior = sum(flag_exterior),
                     small = sum(flag_small), zero_nominal = sum(flag_zero_nominal),
                     zero_turnout = sum(flag_zero_turnout),
                     zero_target_votes = sum(w == 0),
                     model_ineligible_N_zero = sum(QT_APTOS == 0),
                     model_ineligible_abstention_discrepancy = sum(abstention_discrepancy),
                     excluded_from_count_file = 0L), by = .(NR_TURNO, NR_VOTAVEL)]
  data.table::setorderv(model, c(mebane_key, "NR_VOTAVEL"))
  data.table::fwrite(cand, file.path(out, "candidate_turn_totals.csv"))
  data.table::fwrite(totals, file.path(out, "uf_turn_reconciliation.csv"))
  data.table::fwrite(rules, file.path(out, "rule_log.csv"))
  arrow::write_parquet(model, file.path(out, "model_counts.parquet"))
  message("Built ", nrow(model), " count rows; national leaders: ",
          paste(leaders$NR_TURNO, leaders$NR_VOTAVEL, sep = "=", collapse = ", "))
  invisible(list(model = model, totals = totals, rules = rules))
}
