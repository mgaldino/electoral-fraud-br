#!/usr/bin/env Rscript
# Independent synthetic fixtures, exact-error probes and receipt round trips.
args <- commandArgs(trailingOnly = TRUE)
prefix <- "quality_reports/results/mebane_gates/G7/round2/review/"
stopifnot(length(args) == 1L, startsWith(args[[1]], prefix), !dir.exists(args[[1]]))
out <- args[[1]]
dir.create(out, recursive = TRUE)
locale_before <- Sys.getlocale()
source("R/lib/mebane_2026_intake.R")
records <- list()
check <- function(id, expr, expected_error = NULL) {
  warnings <- character()
  error <- withCallingHandlers(tryCatch({force(expr); NULL}, error = conditionMessage),
    warning = function(w) {warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning")})
  records[[length(records) + 1L]] <<- list(id = id, expected_error = expected_error,
    observed_error = error, warnings = as.list(warnings),
    passed = if (is.null(expected_error)) is.null(error) else identical(error, expected_error))
}
jwrite <- function(x, path) jsonlite::write_json(x, path, auto_unbox = TRUE, pretty = TRUE, null = "null")
csv_write <- function(v, path) {
  quote <- function(x) paste0('"', gsub('"', '""', as.character(x), fixed = TRUE), '"')
  lines <- c(paste(names(v), collapse = ","), apply(v, 1L, function(x) paste(quote(x), collapse = ",")))
  writeBin(charToRaw(enc2utf8(paste0(paste(lines, collapse = "\n"), "\n"))), path)
}
make_case <- function(id, year = 2022L, turn = 1L, ufs = c("SP", "AM"), nsec = 2L,
                      name = "CANDIDATO QA") {
  dir <- file.path(out, id)
  dir.create(dir)
  dates <- if (year == 2022L) c("02/10/2022", "30/10/2022") else c("04/10/2026", "25/10/2026")
  pleitos <- if (year == 2022L) c(901L, 902L) else c(3220L, 99001L)
  elections <- if (year == 2022L) c(1901L, 2777L) else c(6257L, 88002L)
  cfg <- list(schema = "g7-intake-v2", year = year, cargo = 1L,
              pleito_t1_documented = pleitos[1], election_t1_documented = elections[1],
              turns = list(1L, 2L), election_dates = setNames(as.list(dates), c("1", "2")),
              territorial_scope = list(universe = "Independent synthetic reference, not national attestation",
                                       expected_ufs = as.list(ufs)),
              candidate_selection = list("1" = list(code = 22L, name = name),
                                         "2" = list(code = 22L, name = name)))
  ea11 <- list(f = "s", pl = lapply(1:2, function(t) list(cd = as.character(pleitos[t]), dt = dates[t],
    e = list(list(cd = as.character(elections[t]), t = as.character(t), abr = list(list(cp = list(list(cd = "1")))))))))
  ea16 <- list(f = "s", cdp = as.character(pleitos[turn]), abr = lapply(ufs, function(uf)
    list(cd = tolower(uf), mu = list(list(cd = "00009", zon = list(list(cd = "0003",
      sec = lapply(seq_len(nsec), function(s) list(ns = sprintf("%04d", s))))))))))
  v <- do.call(rbind, lapply(ufs, function(uf) data.frame(year = year, turn = turn,
    pleito = pleitos[turn], election = elections[turn], cargo = 1L, uf = uf,
    municipio = "00009", zona = "0003", secao = sprintf("%04d", seq_len(nsec)),
    candidate_code = 22L, candidate_name = name, votes = 3L, aptos = 12L,
    turnout = 7L, blank = 1L, null = 1L, stringsAsFactors = FALSE)))
  controls <- list(year = year, turn = turn, pleito = pleitos[turn], election = elections[turn],
    sections = nrow(v), aptos = sum(v$aptos), turnout = sum(v$turnout),
    candidate_votes = sum(v$votes), blank = sum(v$blank), null = sum(v$null))
  list(dir = dir, cfg = cfg, ea11 = ea11, ea16 = ea16, votes = v, controls = controls, turn = turn)
}
save_case <- function(x) {
  jwrite(x$cfg, file.path(x$dir, "config.json"))
  jwrite(x$ea11, file.path(x$dir, "ea11.json"))
  jwrite(x$ea16, file.path(x$dir, "ea16.json"))
  jwrite(x$controls, file.path(x$dir, "controls.json"))
  csv_write(x$votes, file.path(x$dir, "votes.csv"))
  invisible(x)
}
stage <- function(x, provenance = "fixture") {
  g7_stage(file.path(x$dir, "votes.csv"), file.path(x$dir, "ea11.json"),
    file.path(x$dir, "ea16.json"), file.path(x$dir, "controls.json"), file.path(x$dir, "config.json"),
    file.path(x$dir, "store"), x$turn, provenance,
    if (provenance == "official") "https://resultados.tse.jus.br/qa-synthetic" else NULL)
}
receipt_path <- function(x, r) file.path(x$dir, "store", as.character(r$year), paste0("turn", r$turn), r$version, "receipt.json")
case_probe <- function(id, mutate = identity, error = NULL, year = 2022L, turn = 1L) {
  x <- mutate(make_case(id, year, turn))
  save_case(x)
  check(id, stage(x), error)
  invisible(x)
}
baseline <- make_case("ascii")
save_case(baseline)
check("F03_ASCII_e2e", {
  r <- stage(baseline)
  stopifnot(r$validation$status == "staging_validated", r$validation$reference_complete,
    identical(r$candidate$name, "CANDIDATO QA"), !r$data_ready, !r$inference_ready,
    !r$validation$national_coverage_attested)
})
names_utf8 <- c("JOS\u00c9 DA CONCEI\u00c7\u00c3O", "JOSE\u0301 DA CONCEIC\u0327A\u0303O",
                "\u00c1LVARO D'\u00c1VILA, J\u00daNIOR")
for (i in seq_along(names_utf8)) {
  x <- make_case(paste0("utf8_", i), name = names_utf8[i])
  save_case(x)
  check(paste0("F03_UTF8_exact_e2e_", i), {
    v <- g7_read_votes(file.path(x$dir, "votes.csv"))
    r <- stage(x)
    receipt <- g7_json(receipt_path(x, r))
    cfg2 <- g7_json(file.path(dirname(receipt_path(x, r)), "config.snapshot"))
    stopifnot(all(vapply(v$candidate_name, function(s) identical(charToRaw(s), charToRaw(names_utf8[i])), logical(1))),
      identical(charToRaw(r$candidate$name), charToRaw(names_utf8[i])),
      identical(charToRaw(receipt$candidate$name), charToRaw(names_utf8[i])),
      identical(charToRaw(cfg2$candidate_selection[["1"]]$name), charToRaw(names_utf8[i])),
      g7_sha(file.path(x$dir, "votes.csv")) == g7_sha(file.path(dirname(receipt_path(x, r)), "votes.snapshot")),
      identical(stage(x)$version, r$version), !r$data_ready, !r$inference_ready)
  })
}
case_probe("F03_unicode_identity_mismatch", function(x) {
  x$cfg$candidate_selection[["1"]]$name <- names_utf8[1]
  x$votes$candidate_name <- names_utf8[2]
  x
}, "Candidate code/name conflict")
for (kind in c("invalid_ff", "truncated", "overlong", "nul")) {
  x <- make_case(paste0("F03_", kind))
  save_case(x)
  path <- file.path(x$dir, "votes.csv")
  bytes <- readBin(path, "raw", n = file.info(path)$size)
  addition <- switch(kind, invalid_ff = as.raw(255), truncated = as.raw(195),
                     overlong = as.raw(c(192, 175)), nul = as.raw(0))
  writeBin(c(bytes, addition), path)
  check(paste0("F03_", kind), stage(x),
        if (kind == "nul") "Invalid UTF-8 CSV: embedded NUL" else "Invalid UTF-8 CSV bytes")
}
for (t in 1:2) {
  x <- make_case(paste0("date_ok_", t), turn = as.integer(t))
  save_case(x)
  check(paste0("F01_date_correct_T", t), stopifnot(stage(x)$election_date == x$cfg$election_dates[[as.character(t)]]))
  case_probe(paste0("F01_wrong_same_year_T", t), function(z) {
    z$ea11$pl[[t]]$dt <- if (t == 1L) "03/10/2022" else "29/10/2022"; z
  }, "EA11 date differs from configured turn date", turn = as.integer(t))
}
date_changes <- list(missing = function(x) {x$cfg$election_dates[["2"]] <- NULL; x},
  impossible = function(x) {x$cfg$election_dates[["2"]] <- "31/11/2022"; x},
  reverse = function(x) {x$cfg$election_dates <- rev(x$cfg$election_dates); names(x$cfg$election_dates) <- c("1", "2"); x},
  numeric = function(x) {x$cfg$election_dates[["1"]] <- 20221002L; x},
  vector = function(x) {x$cfg$election_dates[["1"]] <- list("02/10/2022", "03/10/2022"); x},
  extra_turn = function(x) {x$cfg$election_dates[["3"]] <- "31/10/2022"; x})
for (id in names(date_changes)) case_probe(paste0("F01_config_", id), date_changes[[id]], "Invalid configured election dates")
case_probe("schema_v1_rejected", function(x) {x$cfg$schema <- "g7-intake-v1"; x}, "Invalid intake configuration")
case_probe("F01_EA11_wrong_year", function(x) {x$ea11$pl[[1]]$dt <- "02/10/2026"; x}, "EA11 identity/date invalid")

cfg2026 <- g7_json("config/mebane/2026/intake.json")
ufs2026 <- unlist(cfg2026$territorial_scope$expected_ufs, use.names = FALSE)
check("F01_2026_anchor_metadata", stopifnot(cfg2026$election_dates[["1"]] == "04/10/2026",
  cfg2026$election_dates[["2"]] == "25/10/2026", cfg2026$calendar_source$turn_2_date_is_conditional,
  is.null(cfg2026$candidate_selection[["1"]]), is.null(cfg2026$candidate_selection[["2"]]),
  is.null(cfg2026$election_t2_documented), is.null(cfg2026$pleito_t2_documented)))
for (t in 1:2) {
  x <- make_case(paste0("null2026_", t), year = 2026L, turn = as.integer(t), ufs = ufs2026, nsec = 1L)
  x$cfg <- cfg2026
  save_case(x)
  check(paste0("F01_null2026_coherent_T", t), stage(x), "Candidate selection unresolved for turn")
}
x <- make_case("all_UFs_not_attestation", year = 2026L, ufs = ufs2026, nsec = 1L, name = names_utf8[1])
x$cfg$territorial_scope$universe <- cfg2026$territorial_scope$universe
x$ea11$f <- "o"; x$ea16$f <- "o"
save_case(x)
check("F02_all28_UFs_not_national_attestation", {
  r <- stage(x, "official")
  stopifnot(r$validation$reference_complete, r$validation$expected_sections == 28L,
    length(r$validation$by_uf) == 28L, !r$validation$national_coverage_attested,
    !r$data_ready, !r$inference_ready, is.null(r$validation$complete))
})
x <- make_case("conditional_T2_absent", year = 2026L)
x$cfg <- cfg2026; x$ea11$pl <- x$ea11$pl[1]
save_case(x)
check("F01_T2_absent_does_not_imply_not_held",
  g7_election(file.path(x$dir, "ea11.json"), cfg2026, 2L), "EA11 election/cargo/turn not unique")
for (election2 in c(88002L, 77777L)) {
  x <- make_case(paste0("conditional_T2_", election2), year = 2026L, turn = 2L)
  x$ea11$pl[[2]]$e[[1]]$cd <- as.character(election2)
  x$votes$election <- election2; x$controls$election <- election2
  save_case(x)
  check(paste0("F01_T2_received_code_", election2), stopifnot(stage(x)$turn == 2L))
}
case_probe("F02_missing_reference_UF", function(x) {x$cfg$territorial_scope$expected_ufs <- list("SP", "AM", "AC"); x}, "EA16 missing configured UFs")
case_probe("F02_extra_reference_UF", function(x) {x$cfg$territorial_scope$expected_ufs <- list("SP"); x}, "EA16 unexpected UFs")
case_probe("F02_extra_vote_UF", function(x) {x$votes$uf[1] <- "AC"; x}, "Unexpected section outside independent EA16")
x <- make_case("partial_by_UF"); x$votes <- x$votes[x$votes$uf == "SP", ]; save_case(x)
check("F02_partial_counts_by_UF", {
  v <- stage(x)$validation
  am <- v$by_uf[[which(vapply(v$by_uf, function(y) y$uf == "AM", logical(1)))]]
  sp <- v$by_uf[[which(vapply(v$by_uf, function(y) y$uf == "SP", logical(1)))]]
  stopifnot(v$status == "incomplete_coverage", !v$reference_complete,
    am$reference_sections == 2L, am$observed_sections == 0L, am$missing_sections == 2L,
    sp$observed_sections == 2L, sp$missing_sections == 0L)
})
x <- make_case("one_section", ufs = "SP", nsec = 1L); save_case(x)
check("F02_one_section_relative_complete", {
  v <- stage(x)$validation
  stopifnot(v$reference_complete, v$expected_sections == 1L, !v$national_coverage_attested,
    v$territorial_scope$coverage_basis == "supplied_EA16_principal_sections")
})
case_probe("F02_scope_duplicate_UF", function(x) {x$cfg$territorial_scope$expected_ufs <- list("SP", "SP"); x}, "Invalid configured territorial scope")
case_probe("F02_scope_scalar_UF", function(x) {x$cfg$territorial_scope$expected_ufs <- "SP"; x}, "Invalid configured territorial scope")
case_probe("F02_scope_missing", function(x) {x$cfg$territorial_scope <- NULL; x}, "Invalid intake configuration")
check("quoted_codes_and_padded_keys", {
  v <- g7_read_votes(file.path(baseline$dir, "votes.csv"))
  stopifnot(all(v$municipio == "00009"), all(v$zona == "0003"),
    identical(unique(v$secao), c("0001", "0002")),
    g7_election(file.path(baseline$dir, "ea11.json"), baseline$cfg, 1L)$election == 1901L)
})
case_probe("unquoted_EA11_code", function(x) {x$ea11$pl[[1]]$cd <- 901L; x}, "Invalid documented code EA11 pl.cd")
case_probe("unquoted_EA11_turn", function(x) {x$ea11$pl[[1]]$e[[1]]$t <- 1L; x}, "Invalid documented code EA11 e.t")
case_probe("unquoted_EA16_code", function(x) {x$ea16$cdp <- 901L; x}, "Invalid documented code EA16 cdp")
case_probe("unpadded_section", function(x) {x$votes$secao[1] <- "1"; x}, "Invalid section key")
case_probe("duplicate_rows", function(x) {x$votes <- rbind(x$votes, x$votes[1, ]); x}, "Duplicate section/candidate row")
case_probe("fractional_votes", function(x) {x$votes$votes[1] <- 2.5; x}, "Invalid integer votes")
case_probe("candidate_wrong_code", function(x) {x$votes$candidate_code[1] <- 13; x}, "Candidate code/name conflict")
x <- case_probe("divergent_controls", function(x) {x$controls$candidate_votes <- 999L; x})
check("divergent_controls_status", stopifnot(stage(x)$validation$status == "control_mismatch"))
case_probe("wrong_csv_schema", function(x) {names(x$votes)[1] <- "year2"; x}, "Unknown normalized CSV schema")

x <- make_case("idempotence_and_policy"); save_case(x)
first <- stage(x)
first_hash <- g7_sha(receipt_path(x, first))
check("same_inputs_same_version", stopifnot(stage(x)$version == first$version))
old_policy <- g7_policy_version
g7_policy_version <- paste0(old_policy, "-qa-probe")
check("policy_changes_version", stopifnot(stage(x)$version != first$version))
g7_policy_version <- old_policy
original_date <- g7_date
g7_date <- function(x, year) original_date(x, year)
check("function_body_changes_version", stopifnot(stage(x)$version != first$version))
g7_date <- original_date
check("restored_policy_keeps_prior_bytes", stopifnot(stage(x)$version == first$version,
  g7_sha(receipt_path(x, first)) == first_hash))
x$votes$votes[1] <- 2L; x$controls$candidate_votes <- x$controls$candidate_votes - 1L
save_case(x)
check("revision_new_namespace_preserves_old", stopifnot(stage(x)$version != first$version,
  g7_sha(receipt_path(x, first)) == first_hash))
tamper <- list(date = function(r) {r$election_date <- "03/10/2022"; r},
  candidate = function(r) {r$candidate$name <- "FORGED"; r},
  territory = function(r) {r$validation$territorial_scope$universe <- "FORGED"; r},
  by_uf = function(r) {r$validation$by_uf[[1]]$observed_sections <- 999L; r},
  reference = function(r) {r$validation$reference_complete <- FALSE; r},
  national = function(r) {r$validation$national_coverage_attested <- TRUE; r},
  data = function(r) {r$data_ready <- TRUE; r}, inference = function(r) {r$inference_ready <- TRUE; r})
for (field in names(tamper)) {
  z <- make_case(paste0("tamper_", field)); save_case(z)
  r <- stage(z); p <- receipt_path(z, r)
  original <- readBin(p, "raw", n = file.info(p)$size)
  changed <- tamper[[field]](g7_json(p))
  stopifnot(identical(changed$input_hashes, r$input_hashes))
  Sys.chmod(p, "0644"); jwrite(changed, p)
  check(paste0("receipt_tamper_", field), stage(z), "Staged receipt differs from recomputed validation or policy")
  writeBin(original, p); Sys.chmod(p, "0444")
}
z <- make_case("snapshot_tamper"); save_case(z); r <- stage(z)
p <- file.path(dirname(receipt_path(z, r)), "votes.snapshot")
Sys.chmod(p, "0644"); writeBin(charToRaw("changed"), p)
check("snapshot_tamper_rejected", stage(z), "Previously staged snapshot changed")
for (g9 in c("waiting_external", "inconclusive")) check(paste0("route_", g9), {
  r <- g7_gate_route("pass", "pass", "pass", g9)
  stopifnot(r$example_only, !r$records_verified)
})
check("route_G6_guard", g7_gate_route("queued", "pass", "pass", "waiting_external"), "Invalid gate route")
check("route_G7_guard", g7_gate_route("pass", "queued", "pass", "inconclusive"), "Invalid gate route")
check("route_G8_guard", g7_gate_route("pass", "pass", "queued", "waiting_external"), "Invalid gate route")
check("route_not_applicable_guard", g7_gate_route("pass", "pass", "pass", "not_applicable"),
      "T2 not_applicable requires independent official non-occurrence attestation")
check("route_not_applicable_example_only", {
  r <- g7_gate_route("pass", "pass", "pass", "not_applicable", "not_held", TRUE)
  stopifnot(r$example_only, !r$records_verified)
})
check("helper_preserves_locale", stopifnot(identical(locale_before, Sys.getlocale())))
report <- list(status = if (all(vapply(records, function(x) x$passed, logical(1)))) "PASS" else "FAIL",
  locale_before = locale_before, locale_after = Sys.getlocale(), locale_ctype = Sys.getlocale("LC_CTYPE"),
  count = length(records), passed = sum(vapply(records, function(x) x$passed, logical(1))),
  cases = records, R = R.version.string, source_sha256 = g7_sha("R/lib/mebane_2026_intake.R"))
jwrite(report, file.path(out, "results.json"))
cat(report$status, report$passed, "/", report$count, "LC_CTYPE", report$locale_ctype, "\n")
if (report$status != "PASS") {
  print(records[!vapply(records, function(x) x$passed, logical(1))])
  quit(status = 1L)
}
