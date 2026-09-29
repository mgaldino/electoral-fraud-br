# Staging adapter for a deliberately narrow, section-by-candidate CSV contract.
# EA20 aggregates cannot be substituted for these section-level observations.
g7_fail <- function(message) stop(message, call. = FALSE)
g7_sha <- function(path) digest::digest(file = path, algo = "sha256")
g7_json <- function(path) jsonlite::fromJSON(path, simplifyVector = FALSE)
g7_policy_version <- "g7-intake-v2"
g7_policy_fingerprint <- function() {
  functions <- c("g7_fail", "g7_sha", "g7_json", "g7_policy_fingerprint",
                 "g7_scalar", "g7_int", "g7_doc_int", "g7_keys", "g7_read_config", "g7_election",
                 "g7_sections", "g7_read_votes", "g7_validate", "g7_controls",
                 "g7_stage", "g7_gate_route")
  digest::digest(list(version = g7_policy_version,
                      source_sha256 = g7_sha("R/lib/mebane_2026_intake.R"),
                      bodies = lapply(functions, function(name) body(get(name, mode = "function")))),
                 algo = "sha256")
}
g7_scalar <- function(x) length(x) == 1L && !is.na(x)
g7_int <- function(x, positive = FALSE) is.numeric(x) && g7_scalar(x) &&
  is.finite(x) && x == floor(x) && x >= if (positive) 1 else 0
g7_doc_int <- function(x, label, positive = TRUE) {
  if (!is.character(x) || !g7_scalar(x) || !grepl("^[0-9]+$", x))
    g7_fail(paste("Invalid documented code", label))
  value <- suppressWarnings(as.numeric(x))
  if (!is.finite(value) || value > .Machine$integer.max ||
      value < if (positive) 1 else 0) g7_fail(paste("Invalid documented code", label))
  as.integer(value)
}
g7_keys <- function(x, required) is.list(x) && !is.null(names(x)) &&
  !anyDuplicated(names(x)) && all(required %in% names(x))

g7_read_config <- function(path) {
  x <- g7_json(path)
  needed <- c("schema", "year", "cargo", "pleito_t1_documented",
              "election_t1_documented", "turns", "candidate_selection")
  if (!g7_keys(x, needed) || x$schema != "g7-intake-v1" ||
      !g7_int(x$year, TRUE) || !g7_int(x$cargo, TRUE) ||
      !g7_int(x$pleito_t1_documented, TRUE) ||
      !g7_int(x$election_t1_documented, TRUE) ||
      !identical(unlist(x$turns), c(1L, 2L))) g7_fail("Invalid intake configuration")
  x
}

g7_election <- function(path, cfg, turn) {
  x <- g7_json(path)
  if (!g7_keys(x, c("f", "pl")) || !x$f %in% c("s", "o") ||
      !is.list(x$pl)) g7_fail("Invalid EA11 schema or phase")
  matches <- list()
  for (p in x$pl) {
    if (!g7_keys(p, c("cd", "dt", "e")) || !is.list(p$e))
      g7_fail("Invalid EA11 pleito")
    pleito <- g7_doc_int(p$cd, "EA11 pl.cd")
    for (e in p$e) {
      if (!g7_keys(e, c("cd", "t", "abr")) || !is.list(e$abr))
        g7_fail("Invalid EA11 election")
      election <- g7_doc_int(e$cd, "EA11 e.cd")
      election_turn <- g7_doc_int(e$t, "EA11 e.t")
      if (!election_turn %in% 1:2) g7_fail("Invalid EA11 turn")
      cargo <- any(vapply(e$abr, function(a) {
        if (!g7_keys(a, c("cp")) || !is.list(a$cp)) g7_fail("Invalid EA11 cargo list")
        any(vapply(a$cp, function(cp) {
          if (!g7_keys(cp, "cd")) g7_fail("Invalid EA11 cargo")
          g7_doc_int(cp$cd, "EA11 cp.cd") == cfg$cargo
        }, logical(1)))
      }, logical(1)))
      if (election_turn == turn && cargo) matches[[length(matches) + 1L]] <-
        list(pleito = pleito, election = election, date = p$dt)
    }
  }
  if (length(matches) != 1L) g7_fail("EA11 election/cargo/turn not unique")
  m <- matches[[1L]]
  if (!is.character(m$date) || !g7_scalar(m$date) ||
      !grepl("^[0-9]{2}/[0-9]{2}/[0-9]{4}$", m$date) ||
      is.na(as.Date(m$date, "%d/%m/%Y")) ||
      as.integer(format(as.Date(m$date, "%d/%m/%Y"), "%Y")) != cfg$year)
    g7_fail("EA11 identity/date invalid")
  if (turn == 1L && (m$pleito != cfg$pleito_t1_documented ||
                     m$election != cfg$election_t1_documented))
    g7_fail("EA11 conflicts with documented T1 identifiers")
  c(m, list(phase = x$f))
}

g7_sections <- function(path, pleito, phase) {
  x <- g7_json(path)
  if (!g7_keys(x, c("f", "cdp", "abr")) || !identical(x$f, phase) ||
      !is.list(x$abr))
    g7_fail("EA16 pleito/phase/schema mismatch")
  if (g7_doc_int(x$cdp, "EA16 cdp") != pleito)
    g7_fail("EA16 pleito/phase/schema mismatch")
  rows <- list()
  for (a in x$abr) {
    if (!g7_keys(a, c("cd", "mu")) || !is.list(a$mu) ||
        !is.character(a$cd) || !g7_scalar(a$cd) ||
        !grepl("^[a-z]{2}$", a$cd)) g7_fail("Invalid EA16 UF")
    for (m in a$mu) {
      if (!g7_keys(m, c("cd", "zon")) || !is.list(m$zon) ||
          !is.character(m$cd) || !g7_scalar(m$cd) ||
          !grepl("^[0-9]{5}$", m$cd)) g7_fail("Invalid EA16 municipality")
      for (z in m$zon) {
        if (!g7_keys(z, c("cd", "sec")) || !is.list(z$sec) ||
            !is.character(z$cd) || !g7_scalar(z$cd) ||
            !grepl("^[0-9]{4}$", z$cd)) g7_fail("Invalid EA16 zone")
        for (s in z$sec) {
          if (!g7_keys(s, "ns") || !is.character(s$ns) || !g7_scalar(s$ns) ||
              !grepl("^[0-9]{4}$", s$ns) ||
              (!is.null(s$nsp) && (!is.character(s$nsp) || !g7_scalar(s$nsp) ||
                                    !grepl("^[0-9]{4}$", s$nsp))))
            g7_fail("Invalid EA16 section")
          # Only principal sections carry a separate ballot; aggregated sections
          # have nsp and must not inflate the expected result denominator.
          if (is.null(s$nsp) || !nzchar(s$nsp)) rows[[length(rows) + 1L]] <-
            c(toupper(a$cd), m$cd, z$cd, s$ns)
        }
      }
    }
  }
  if (!length(rows)) g7_fail("Empty EA16 reference")
  out <- unique(vapply(rows, paste, collapse = ":", FUN.VALUE = character(1)))
  if (length(out) != length(rows)) g7_fail("Duplicate EA16 section")
  out
}

g7_read_votes <- function(path) {
  fields <- c("year", "turn", "pleito", "election", "cargo", "uf", "municipio",
              "zona", "secao", "candidate_code", "candidate_name", "votes",
              "aptos", "turnout", "blank", "null")
  header <- names(read.csv(path, nrows = 0L, check.names = FALSE))
  if (!identical(header, fields)) g7_fail("Unknown normalized CSV schema")
  v <- read.csv(path, colClasses = "character", check.names = FALSE,
                na.strings = character(), fileEncoding = "UTF-8")
  if (!nrow(v) || anyNA(v) || any(!nzchar(as.matrix(v)))) g7_fail("Empty/missing vote values")
  number <- c("year", "turn", "pleito", "election", "cargo", "candidate_code",
              "votes", "aptos", "turnout", "blank", "null")
  for (field in number) {
    if (any(!grepl("^(0|[1-9][0-9]*)$", v[[field]]))) g7_fail(paste("Invalid integer", field))
    v[[field]] <- as.numeric(v[[field]])
    if (any(!is.finite(v[[field]]))) g7_fail(paste("Invalid integer", field))
  }
  if (any(!grepl("^[A-Z]{2}$", v$uf)) ||
      any(!grepl("^[0-9]{5}$", v$municipio)) ||
      any(!grepl("^[0-9]{4}$", v$zona)) ||
      any(!grepl("^[0-9]{4}$", v$secao))) g7_fail("Invalid section key")
  v
}

g7_validate <- function(v, cfg, election, expected, turn) {
  for (field in c("year", "turn", "pleito", "election", "cargo")) {
    target <- switch(field, year = cfg$year, turn = turn, pleito = election$pleito,
                     election = election$election, cargo = cfg$cargo)
    if (any(v[[field]] != target)) g7_fail(paste("Election scope mismatch", field))
  }
  selection <- cfg$candidate_selection[[as.character(turn)]]
  if (is.null(selection) || !g7_keys(selection, c("code", "name")) ||
      !g7_int(selection$code, TRUE) || !is.character(selection$name) ||
      !g7_scalar(selection$name) || !nzchar(selection$name))
    g7_fail("Candidate selection unresolved for turn")
  if (any(v$candidate_code != selection$code) ||
      any(v$candidate_name != selection$name)) g7_fail("Candidate code/name conflict")
  key <- paste(v$uf, v$municipio, v$zona, v$secao, sep = ":")
  if (anyDuplicated(key)) g7_fail("Duplicate section/candidate row")
  if (any(!key %in% expected)) g7_fail("Unexpected section outside independent EA16")
  if (any(v$turnout > v$aptos) || any(v$votes + v$blank + v$null > v$turnout))
    g7_fail("Impossible section totals")
  missing <- setdiff(expected, key)
  list(complete = !length(missing), expected_sections = length(expected),
       observed_sections = length(key), missing_sections = missing,
       totals = list(aptos = sum(v$aptos), turnout = sum(v$turnout),
                     candidate_votes = sum(v$votes), blank = sum(v$blank), null = sum(v$null)))
}

g7_controls <- function(path, cfg, election, turn, result) {
  x <- g7_json(path)
  needed <- c("year", "turn", "pleito", "election", "sections", "aptos",
              "turnout", "candidate_votes", "blank", "null")
  if (!g7_keys(x, needed) || !all(vapply(x[needed], g7_int, logical(1))) ||
      x$year != cfg$year || x$turn != turn || x$pleito != election$pleito ||
      x$election != election$election || x$sections != result$expected_sections)
    g7_fail("Independent controls schema/scope mismatch")
  if (!result$complete) return(FALSE)
  all(vapply(c("aptos", "turnout", "candidate_votes", "blank", "null"),
             function(field) identical(as.numeric(x[[field]]), as.numeric(result$totals[[field]])),
             logical(1)))
}

g7_stage <- function(vote_path, ea11_path, ea16_paths, controls_path, config_path, store,
                     turn, provenance = "fixture", source_url = NULL) {
  if (is.null(source_url)) source_url <- ""
  if (!identical(turn, as.integer(turn)) || !turn %in% 1:2 ||
      !provenance %in% c("fixture", "official") ||
      !is.character(ea16_paths) || !length(ea16_paths)) g7_fail("Invalid turn/provenance/EA16 list")
  paths <- c(vote_path, ea11_path, ea16_paths, controls_path, config_path)
  if (any(!file.exists(paths)) || anyDuplicated(normalizePath(paths)))
    g7_fail("Missing or reused reference/input file")
  cfg <- g7_read_config(config_path)
  election <- g7_election(ea11_path, cfg, turn)
  rosters <- lapply(ea16_paths, g7_sections, pleito = election$pleito, phase = election$phase)
  expected <- unlist(rosters, use.names = FALSE)
  if (anyDuplicated(expected)) g7_fail("Duplicate section across EA16 references")
  v <- g7_read_votes(vote_path)
  result <- g7_validate(v, cfg, election, expected, turn)
  result$controls_pass <- g7_controls(controls_path, cfg, election, turn, result)
  result$status <- if (!result$complete) "incomplete_coverage" else
    if (!result$controls_pass) "control_mismatch" else "staging_validated"
  if (provenance == "official" && (election$phase != "o" ||
      !is.character(source_url) || length(source_url) != 1L ||
      !grepl("^https://([A-Za-z0-9-]+\\.)*tse\\.jus\\.br/", source_url)))
    g7_fail("Official provenance requires official phase and TSE source")
  hashes <- vapply(paths, g7_sha, character(1))
  names(hashes) <- c("votes", "ea11", paste0("ea16_", seq_along(ea16_paths)),
                     "controls", "config")
  policy_sha256 <- g7_policy_fingerprint()
  version <- digest::digest(paste(c(hashes, provenance, source_url, policy_sha256), collapse = ":"),
                            algo = "sha256", serialize = FALSE)
  root <- file.path(store, as.character(cfg$year), paste0("turn", turn), version)
  receipt <- list(year = cfg$year, turn = turn, version = version,
                  policy_sha256 = policy_sha256, input_hashes = as.list(hashes),
                  provenance = provenance, phase = election$phase, source_url = source_url,
                  validation = result,
                  data_ready = FALSE, inference_ready = FALSE,
                  release_condition = "independent official-source and coverage attestation; G6 pass for inference")
  if (dir.exists(root)) {
    prior <- g7_json(file.path(root, "receipt.json"))
    normalized <- function(x) jsonlite::toJSON(x, auto_unbox = TRUE, null = "null")
    if (!identical(normalized(prior), normalized(receipt)))
      g7_fail("Staged receipt differs from recomputed validation or policy")
    for (name in names(hashes)) if (g7_sha(file.path(root, paste0(name, ".snapshot"))) != hashes[[name]])
      g7_fail("Previously staged snapshot changed")
    return(receipt)
  }
  if (!dir.create(root, recursive = TRUE, showWarnings = FALSE)) g7_fail("Cannot create version")
  for (i in seq_along(paths)) {
    dest <- file.path(root, paste0(names(hashes)[[i]], ".snapshot"))
    if (!file.copy(paths[[i]], dest) || g7_sha(dest) != hashes[[i]]) g7_fail("Snapshot copy failed")
    Sys.chmod(dest, "0444")
  }
  jsonlite::write_json(receipt, file.path(root, "receipt.json"), auto_unbox = TRUE, pretty = TRUE)
  Sys.chmod(file.path(root, "receipt.json"), "0444")
  receipt
}

g7_gate_route <- function(g6, g7, g8, g9, t2_occurrence = "unknown",
                          nonoccurrence_attested = FALSE) {
  # Scenario validator only: strings/booleans are not approval records.
  if (g6 != "pass" || g7 != "pass" || g8 != "pass" ||
      !g9 %in% c("waiting_external", "inconclusive", "not_applicable"))
    g7_fail("Invalid gate route")
  if (g9 == "not_applicable" && (t2_occurrence != "not_held" ||
                                   !identical(nonoccurrence_attested, TRUE)))
    g7_fail("T2 not_applicable requires independent official non-occurrence attestation")
  list(g6 = g6, g7 = g7, g8 = g8, g9 = g9,
       example_only = TRUE, records_verified = FALSE,
       t2_applicability = if (g9 == "not_applicable") "officially_not_held" else "unresolved")
}
