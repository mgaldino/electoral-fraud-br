# Deterministic data preparation only. No model is fitted here.
dc2010_paths <- function(repo_root) {
  discovery <- file.path(repo_root, "quality_reports/results/mebane_gates/coordination/authors_replication_discovery")
  list(
    input = file.path(discovery, "archive/UMeforensics-eforensics_public-3017de5/data/dc2010.rda"),
    discovery = file.path(discovery, "discovery.md"),
    contract = file.path(discovery, "replication_contract.json"),
    model_a = file.path(repo_root, "quality_reports/results/mebane_gates/G0/round1/qbl_installed_3017de5.jags"),
    script = file.path(repo_root, "R/experimental/mebane_ad/prepare_dc2010.R"),
    test = file.path(repo_root, "tests/mebane/ad_study/test_dc2010.R"),
    output_root = file.path(repo_root, "quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/data")
  )
}

sha256_file <- function(path) {
  if (!file.exists(path) || dir.exists(path)) stop("Missing regular file: ", path)
  result <- suppressWarnings(system2(
    "shasum", c("-a", "256", shQuote(normalizePath(path))),
    stdout = TRUE, stderr = TRUE, env = "LC_ALL=C"
  ))
  if (!is.null(attr(result, "status")) || length(result) != 1L ||
      !grepl("^[0-9a-f]{64}  ", result)) {
    stop("SHA-256 calculation failed for: ", path)
  }
  substr(result, 1L, 64L)
}

load_dc2010 <- function(path) {
  isolated <- new.env(parent = emptyenv())
  loaded <- load(path, envir = isolated)
  if (!identical(loaded, "dc2010")) stop("RDA must contain only dc2010")
  isolated$dc2010
}

validate_dc2010 <- function(data, expected_n = 143L) {
  required <- c("precinct", "NVoters", "NValid", "Votes", "a")
  if (!is.data.frame(data) || !identical(names(data), required)) {
    stop("Unexpected dc2010 table or column schema")
  }
  if (nrow(data) != expected_n) stop("Unexpected precinct count")
  if (!is.factor(data$precinct) && !is.character(data$precinct)) {
    stop("precinct must be a factor or character identifier")
  }
  id <- as.character(data$precinct)
  if (anyNA(id) || any(!nzchar(id)) || anyDuplicated(id)) {
    stop("Missing, empty or duplicate precinct identifier")
  }
  for (column in required[-1L]) {
    value <- data[[column]]
    if (!is.integer(value) || anyNA(value) || any(!is.finite(value))) {
      stop(column, " must contain finite, nonmissing R integers")
    }
  }
  N <- data$NVoters
  valid <- data$NValid
  A <- data$a
  W <- data$Votes
  if (any(N < 1L) || any(valid < 0L | valid > N) ||
      any(A < 0L | A > N) || any(W < 0L | W > N)) {
    stop("Counts outside physical bounds")
  }
  if (any(as.double(A) != as.double(N) - valid)) {
    stop("Author mapping a = NVoters - NValid does not hold")
  }
  O_double <- as.double(N) - A - W
  if (any(O_double < 0) || any(O_double > .Machine$integer.max)) {
    stop("A + W exceeds N or residual overflows")
  }
  O <- as.integer(O_double)
  if (any(as.double(A) + W + O != N)) stop("A + W + O != N")
  data.frame(precinct = id, N = N, A = A, W = W, O = O,
             stringsAsFactors = FALSE, check.names = FALSE)
}

build_dc2010_data <- function(common) {
  n <- nrow(common)
  id <- common$precinct
  design <- function() {
    matrix(1, nrow = n, ncol = 1L,
           dimnames = list(id, "(Intercept)"))
  }
  X <- list(Xa = design(), Xw = design(),
            X.iota.m = design(), X.iota.s = design(),
            X.chi.m = design(), X.chi.s = design())
  a_data <- c(list(n = as.integer(n), N = common$N,
                   a = common$A, w = common$W,
                   dxa = 1L, dxw = 1L,
                   dx.iota.m = 1L, dx.iota.s = 1L,
                   dx.chi.m = 1L, dx.chi.s = 1L), X)
  observed <- cbind(A = common$A, W = common$W, O = common$O)
  rownames(observed) <- id
  list(
    case_id = "dc2010", precinct = id,
    A = a_data,
    D = list(n = as.integer(n), N = common$N, observed = observed),
    mapping = list(N = "NVoters", A = "a = NVoters - NValid",
                   W = "Votes", O = "NVoters - a - Votes")
  )
}

dc2010_summary <- function(common) {
  totals <- colSums(common[c("N", "A", "W", "O")])
  names(totals) <- c("N", "A", "W", "O")
  columns <- lapply(common[c("N", "A", "W", "O")], function(x) {
    list(min = unname(min(x)), median = unname(median(x)),
         mean = unname(mean(x)), max = unname(max(x)))
  })
  list(
    precincts = nrow(common),
    totals = as.list(totals),
    fractions_of_registered_N = list(A = unname(totals["A"] / totals["N"]),
                                     W = unname(totals["W"] / totals["N"]),
                                     O = unname(totals["O"] / totals["N"])),
    count_by_precinct = columns,
    denominator_note = "Fractions use sum(NVoters) = sum(N) across all 143 precincts; count summaries use 143 precincts, not voters."
  )
}

prepare_dc2010 <- function(repo_root, run_id = NULL) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Existing jsonlite package is required; no installation is attempted")
  }
  paths <- dc2010_paths(repo_root)
  if (is.null(run_id)) {
    run_id <- paste0("run-", format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC"),
                     "-pid", Sys.getpid())
  }
  if (length(run_id) != 1L || is.na(run_id) ||
      !grepl("^run-[0-9]{8}T[0-9]{6}Z-pid[0-9]+$", run_id)) {
    stop("Invalid run_id")
  }
  run_dir <- file.path(paths$output_root, run_id)
  if (file.exists(run_dir) || dir.exists(run_dir)) {
    stop("Refusing to overwrite existing run: ", run_dir)
  }
  input_hashes <- lapply(paths[c("input", "discovery", "contract", "model_a", "script", "test")], sha256_file)
  common <- validate_dc2010(load_dc2010(paths$input))
  payload <- build_dc2010_data(common)
  summary <- dc2010_summary(common)
  if (!dir.create(run_dir, recursive = TRUE, showWarnings = FALSE)) {
    stop("Could not create new run directory: ", run_dir)
  }
  csv_path <- file.path(run_dir, "dc2010_common.csv")
  rds_path <- file.path(run_dir, "dc2010_ad_data.rds")
  log_path <- file.path(run_dir, "prepare.log")
  manifest_path <- file.path(run_dir, "manifest.json")
  checksums_path <- file.path(run_dir, "SHA256SUMS")
  now <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  write.csv(common, csv_path, row.names = FALSE, na = "")
  saveRDS(payload, rds_path, version = 3L)
  log_lines <- c(
    paste("run_id:", run_id), paste("created_at_utc:", now),
    "status: PREPARED_NOT_ESTIMATED_NOT_APPROVED",
    "command: Rscript --vanilla R/experimental/mebane_ad/prepare_dc2010.R",
    paste("input:", paths$input), paste("input_sha256:", input_hashes$input),
    "checks: schema, integer/finite/NA, 143 rows, unique IDs, count bounds, author a mapping, A+W+O=N: PASS",
    paste("sum_N:", summary$totals$N), paste("sum_A:", summary$totals$A),
    paste("sum_W:", summary$totals$W), paste("sum_O:", summary$totals$O),
    "estimation: NONE"
  )
  writeLines(log_lines, log_path, useBytes = TRUE)
  output_hashes <- lapply(list(csv = csv_path, rds = rds_path, log = log_path), sha256_file)
  manifest <- list(
    schema_version = "1.0", run_id = run_id, status = "PREPARED_NOT_ESTIMATED_NOT_APPROVED",
    created_at_utc = now,
    source = list(case_id = "dc2010", package = "UMeforensics/eforensics_public 0.0.4",
                  commit = "3017de537450f97a01872d0157462a68bea348ee",
                  vignette_date = "2019-08-16", package_commit_date = "2019-10-27",
                  local_archive_download_date = "2026-09-29", accessed_at_utc = now,
                  election_description = "Washington, D.C. 2010 mayoral example as described in the archived authors' vignette"),
    inputs = Map(function(path, hash) list(path = path, sha256 = hash),
                 paths[c("input", "discovery", "contract", "model_a", "script", "test")], input_hashes),
    outputs = list(csv = list(file = basename(csv_path), sha256 = output_hashes$csv),
                   rds = list(file = basename(rds_path), sha256 = output_hashes$rds),
                   log = list(file = basename(log_path), sha256 = output_hashes$log)),
    data = list(row_order = "Exact source RDA row order; no sorting or filtering",
                csv_columns = names(common), summary = summary,
                model_a = "Original qbl JAGS observed a=A, w=W, N=NVoters; six intercept-only matrices; model file is not modified",
                model_d = "Candidate multinomial observed matrix columns A,W,O with N; no likelihood, prior or estimator is implemented",
                dc_brazil_mapping_note = paste(
                  "In this author-packaged D.C. example A is defined as NVoters-NValid.",
                  "Do not relabel NValid as Brazilian turnout or transfer that definition to Brazilian data.",
                  "O is an arithmetic residual, not necessarily votes for an opponent.")),
    environment = list(R = R.version.string, platform = R.version$platform,
                       jsonlite = as.character(utils::packageVersion("jsonlite")),
                       sha256_command = "shasum -a 256"),
    commands = list(prepare = "Rscript --vanilla R/experimental/mebane_ad/prepare_dc2010.R",
                    test = paste("Rscript --vanilla tests/mebane/ad_study/test_dc2010.R", run_dir)),
    limits = c("No model estimation or MCMC", "No G10 numeric author reference or gate approval",
               "Source RDA integrity checks do not establish original electoral provenance")
  )
  jsonlite::write_json(manifest, manifest_path, pretty = TRUE, auto_unbox = TRUE,
                       null = "null", digits = 10)
  checksum_files <- c(csv_path, rds_path, log_path, manifest_path)
  checksum_lines <- vapply(checksum_files, function(path) {
    paste0(sha256_file(path), "  ", basename(path))
  }, character(1))
  writeLines(checksum_lines, checksums_path, useBytes = TRUE)
  cat(run_dir, "\n", sep = "")
  invisible(run_dir)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 0L) stop("Usage: Rscript --vanilla R/experimental/mebane_ad/prepare_dc2010.R")
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(file_arg) != 1L) stop("Cannot locate script file")
  script_path <- normalizePath(sub("^--file=", "", file_arg), mustWork = TRUE)
  repo_root <- normalizePath(file.path(dirname(script_path), "../../.."), mustWork = TRUE)
  prepare_dc2010(repo_root)
}
