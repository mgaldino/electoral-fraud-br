args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) stop("Usage: Rscript --vanilla tests/mebane/ad_study/test_dc2010.R RUN_DIR")
run_dir <- normalizePath(args[[1L]], mustWork = TRUE)
file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
if (length(file_arg) != 1L) stop("Cannot locate test file")
test_path <- normalizePath(sub("^--file=", "", file_arg), mustWork = TRUE)
repo_root <- normalizePath(file.path(dirname(test_path), "../../.."), mustWork = TRUE)
script_path <- file.path(repo_root, "R/experimental/mebane_ad/prepare_dc2010.R")
source(script_path, local = TRUE)

assert <- function(condition, label) {
  if (!isTRUE(condition)) stop("FAIL: ", label)
}
rejects <- function(expression, label) {
  result <- tryCatch({ force(expression); FALSE }, error = function(e) TRUE)
  assert(result, label)
}

# The rows and A/W values are deliberately asymmetric, so a swap or sort fails.
fixture <- data.frame(
  precinct = factor(c("Z", "A", "M"), levels = c("M", "Z", "A")),
  NVoters = c(11L, 13L, 17L), NValid = c(7L, 5L, 13L),
  Votes = c(3L, 2L, 8L), a = c(4L, 8L, 4L)
)
small <- validate_dc2010(fixture, expected_n = 3L)
assert(identical(small$precinct, c("Z", "A", "M")), "source row order")
assert(identical(small$A, c(4L, 8L, 4L)), "A author mapping")
assert(identical(small$W, c(3L, 2L, 8L)), "W author mapping")
assert(identical(small$O, c(4L, 3L, 5L)), "O residual")
payload <- build_dc2010_data(small)
assert(identical(payload$A$a, small$A) && identical(payload$A$w, small$W),
       "JAGS a/w not swapped")
assert(identical(colnames(payload$D$observed), c("A", "W", "O")), "D count order")
assert(identical(unname(payload$D$observed[, "W"]), small$W), "D W values")
matrix_names <- c("Xa", "Xw", "X.iota.m", "X.iota.s", "X.chi.m", "X.chi.s")
for (name in matrix_names) {
  assert(is.matrix(payload$A[[name]]) && identical(dim(payload$A[[name]]), c(3L, 1L)) &&
           all(payload$A[[name]] == 1), paste("intercept matrix", name))
}

bad <- fixture
bad$Votes[1L] <- 3.5
rejects(validate_dc2010(bad, 3L), "noninteger storage/value")
bad <- fixture
bad$a[1L] <- NA_integer_
rejects(validate_dc2010(bad, 3L), "missing count")
bad <- fixture
bad$precinct[2L] <- "Z"
rejects(validate_dc2010(bad, 3L), "duplicate ID")
bad <- fixture
bad$precinct[2L] <- NA
rejects(validate_dc2010(bad, 3L), "missing ID")
bad <- fixture
bad$a[1L] <- 5L
rejects(validate_dc2010(bad, 3L), "author A identity")
bad <- fixture
bad$Votes[1L] <- 8L
rejects(validate_dc2010(bad, 3L), "physical A+W bound")
rejects(validate_dc2010(fixture, 143L), "expected 143 rows")

paths <- dc2010_paths(repo_root)
source_hash_before <- sha256_file(paths$input)
raw <- load_dc2010(paths$input)
actual <- validate_dc2010(raw)
assert(nrow(actual) == 143L, "frozen source row count")
assert(identical(actual$precinct, as.character(raw$precinct)), "frozen source order")
assert(identical(source_hash_before, sha256_file(paths$input)), "source unchanged by load")
assert(identical(source_hash_before,
                 "0386dcc86155e543382c2725e9eb61ebf365b2e6f96a2b037324dbee80005196"),
       "frozen input SHA-256")

csv <- read.csv(file.path(run_dir, "dc2010_common.csv"), stringsAsFactors = FALSE,
                check.names = FALSE)
assert(identical(csv, actual), "CSV exact rows, columns and integer values")
rds <- readRDS(file.path(run_dir, "dc2010_ad_data.rds"))
assert(identical(rds$precinct, actual$precinct), "RDS exact precinct order")
assert(identical(rds$A$a, actual$A) && identical(rds$A$w, actual$W), "RDS A observations")
assert(identical(unname(rds$D$observed), unname(cbind(A = actual$A, W = actual$W, O = actual$O))),
       "RDS D observations")
assert(identical(as.double(rowSums(rds$D$observed)), as.double(rds$D$N)),
       "D row totals")
assert(identical(as.double(rowSums(csv[c("A", "W", "O")])), as.double(csv$N)),
       "CSV row totals")

manifest_path <- file.path(run_dir, "manifest.json")
manifest <- jsonlite::read_json(manifest_path, simplifyVector = TRUE)
assert(identical(manifest$run_id, basename(run_dir)), "real run ID")
assert(identical(manifest$inputs$input$sha256, source_hash_before), "manifest input hash")
assert(identical(manifest$outputs$csv$sha256, sha256_file(file.path(run_dir, "dc2010_common.csv"))),
       "manifest CSV hash")
assert(identical(manifest$outputs$rds$sha256, sha256_file(file.path(run_dir, "dc2010_ad_data.rds"))),
       "manifest RDS hash")
assert(identical(manifest$outputs$log$sha256, sha256_file(file.path(run_dir, "prepare.log"))),
       "manifest log hash")
checksums <- readLines(file.path(run_dir, "SHA256SUMS"), warn = FALSE)
for (name in c("dc2010_common.csv", "dc2010_ad_data.rds", "prepare.log", "manifest.json")) {
  line <- paste(sha256_file(file.path(run_dir, name)), name)
  assert(line %in% checksums, paste("SHA256SUMS", name))
}
rejects(prepare_dc2010(repo_root, basename(run_dir)), "overwrite refusal")
assert(identical(source_hash_before, sha256_file(paths$input)), "source remains byte-identical")
cat("PASS: asymmetric mapping, invalid-data rejection, 143-row frozen input, output identity, hashes, overwrite refusal\n")
