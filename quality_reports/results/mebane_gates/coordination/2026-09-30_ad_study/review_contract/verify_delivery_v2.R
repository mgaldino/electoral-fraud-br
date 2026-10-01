# Delivery validation only; no model or diagnostic sampling.
root <- normalizePath(commandArgs(trailingOnly = TRUE)[[1]], mustWork = TRUE)
base <- "quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study"
out_rel <- file.path(base, "review_contract")
out <- file.path(root, out_rel)
.libPaths(c(file.path(root, "renv/library/macos/R-4.4/aarch64-apple-darwin20"), .libPaths()))
stopifnot(!file.exists(file.path(out, "delivery_manifest_v2.json")))
read <- function(p) jsonlite::fromJSON(file.path(out, p), simplifyVector = FALSE)
sha <- function(p) digest::digest(file = file.path(root, p), algo = "sha256")
r <- read("review_v2.json"); d <- read("delta_checks_v2.json")
stopifnot(r$status == "pass", length(r$findings) == 0,
          r$contract_sha256 == d$contract_sha256,
          sha(file.path(base, "contract_v2.json")) == r$contract_sha256,
          r$reviewer_id == Sys.getenv("CODEX_THREAD_ID"),
          !r$authorization_boundary$empirical_MCMC_authorized_by_this_review)
for (x in d$source_hashes) stopifnot(sha(x$path) == x$sha256)
old <- read("delivery_manifest.json")
for (x in old$files) stopifnot(sha(x$path) == x$sha256)
count <- 0L
for (x in c(list(r$prior_finding_assessment), r$verified_delta)) {
  for (e in x[["evidence"]]) {
    n <- length(readLines(file.path(root, e$path), warn = FALSE))
    stopifnot(e$line_start >= 1, e$line_end >= e$line_start, e$line_end <= n)
    count <- count + 1L
  }
}
md <- paste(readLines(file.path(out, "review_v2.md"), warn = FALSE), collapse = "\n")
stopifnot(grepl(r$contract_sha256, md, fixed = TRUE))
links <- regmatches(md, gregexpr("\\]\\(/Users/[^)]+\\)", md))[[1]]
for (link in links) {
  path <- sub("^\\]\\(", "", sub("\\)$", "", link))
  stopifnot(file.exists(sub(":[0-9]+$", "", path)))
}
files <- c("check_delta_v2.R", "delta_checks_v2.json", "delta_checks_v2.log",
           "review_v2.json", "review_v2.md", "verify_delivery_v2.R")
manifest <- list(status = "pass_delivery_integrity", checked_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
                 reviewer_id = r$reviewer_id, executor_id = r$executor_id,
                 contract_sha256 = r$contract_sha256, evidence_ranges_checked = count,
                 links_checked = length(links), previous_manifest_files_intact = length(old$files),
                 command = paste("env LC_ALL=C LANG=C Rscript --vanilla", file.path(out_rel, "verify_delivery_v2.R"), root),
                 validator_note = "An initial ad-hoc validator failed because R $ partially matched evidence_file to evidence. Exact [[ indexing fixes the validator; candidate and review contents were not changed.",
                 files = lapply(files, function(p) list(path = file.path(out_rel, p), sha256 = sha(file.path(out_rel, p)))),
                 MCMC = FALSE, self_hash_excluded = TRUE)
jsonlite::write_json(manifest, file.path(out, "delivery_manifest_v2.json"), pretty = TRUE, auto_unbox = TRUE)
cat("PASS delivery integrity;", count, "evidence ranges,", length(links),
    "links and eight old files verified; no empirical MCMC authorization.\n")
