# Validate delivery structure and frozen sources; no statistical computation.
args <- commandArgs(trailingOnly = TRUE)
root <- normalizePath(if (length(args)) args[[1]] else ".", mustWork = TRUE)
rel <- "quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/review_contract"
out <- file.path(root, rel)
.libPaths(c(file.path(root, "renv/library/macos/R-4.4/aarch64-apple-darwin20"), .libPaths()))
stopifnot(!file.exists(file.path(out, "delivery_manifest.json")))
review <- jsonlite::fromJSON(file.path(out, "review.json"), simplifyVector = FALSE)
checks <- jsonlite::fromJSON(file.path(out, "checks.json"), simplifyVector = FALSE)
sha <- function(p) digest::digest(file = file.path(root, p), algo = "sha256")
stopifnot(review$status == "changes_requested", length(review$findings) == 1,
          review$reviewer_id == Sys.getenv("CODEX_THREAD_ID"),
          review$reviewer_id != review$executor_id,
          identical(review$contract_sha256, checks$contract_sha256),
          identical(sha(review$contract_path), review$contract_sha256),
          !review$G3_approved, !review$G10_approved, !review$production_approval,
          !review$executed_verification$new_MCMC,
          checks$computational_checks_status == "pass")
for (s in checks$source_hashes) stopifnot(sha(s$path) == s$actual)
evidence_count <- 0L
for (item in c(review$findings, review$accepted_checks)) {
  for (e in item$evidence) {
    lines <- readLines(file.path(root, e$path), warn = FALSE)
    stopifnot(e$line_start >= 1, e$line_end >= e$line_start,
              e$line_end <= length(lines), any(nzchar(lines[e$line_start:e$line_end])))
    evidence_count <- evidence_count + 1L
  }
}
md <- paste(readLines(file.path(out, "review.md"), warn = FALSE), collapse = "\n")
stopifnot(grepl(review$contract_sha256, md, fixed = TRUE),
          grepl(review$reviewer_id, md, fixed = TRUE),
          grepl("AD-CONTRACT-QA-01", md, fixed = TRUE))
links <- regmatches(md, gregexpr("\\]\\(/Users/[^)]+\\)", md))[[1]]
for (link in links) {
  path <- sub("^\\]\\(", "", sub("\\)$", "", link))
  path <- sub(":[0-9]+$", "", path)
  stopifnot(file.exists(path))
}
files <- list.files(out, full.names = FALSE)
artifacts <- lapply(files, function(p) list(path = file.path(rel, p),
                                         sha256 = sha(file.path(rel, p)),
                                         bytes = unname(file.info(file.path(out, p))$size)))
manifest <- list(schema_version = "1.0-independent-review-delivery",
                 created_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
                 executor_id = review$executor_id, reviewer_id = review$reviewer_id,
                 contract_sha256 = review$contract_sha256,
                 validation = "pass_delivery_integrity_not_scientific_approval",
                 evidence_ranges_checked = evidence_count, markdown_links_checked = length(links),
                 candidate_and_reference_hashes_unchanged = TRUE,
                 command = paste("env LC_ALL=C LANG=C Rscript --vanilla", file.path(rel, "verify_delivery.R"), root),
                 files = artifacts, self_hash_excluded = TRUE)
jsonlite::write_json(manifest, file.path(out, "delivery_manifest.json"), pretty = TRUE, auto_unbox = TRUE)
cat("PASS delivery integrity;", evidence_count, "line ranges;", length(links),
    "file links; nine frozen hashes unchanged. Contract status remains changes_requested.\n")
