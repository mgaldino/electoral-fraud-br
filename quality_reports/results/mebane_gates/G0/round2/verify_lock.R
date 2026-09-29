# Verify literal versions and dependency closure after the bounded lock merge.
root <- normalizePath(".")
round_dir <- file.path(root, "quality_reports/results/mebane_gates/G0/round2")
.libPaths(c(file.path(root, "renv/library/macos/R-4.4/aarch64-apple-darwin20"),
            .libPaths()))
lock <- jsonlite::fromJSON("renv.lock", simplifyVector = FALSE)
before <- jsonlite::fromJSON(file.path(round_dir, "renv_before.lock"),
                             simplifyVector = FALSE)
report <- jsonlite::fromJSON(file.path(round_dir, "lock_reconciliation.json"),
                             simplifyVector = FALSE)
stopifnot(length(before$Packages) == 174L, length(lock$Packages) == 180L,
          identical(before$R, lock$R),
          all(vapply(names(before$Packages), function(pkg)
            identical(before$Packages[[pkg]], lock$Packages[[pkg]]), logical(1))))
closure <- unlist(report$closure, use.names = FALSE)
missing <- setdiff(closure, names(lock$Packages))
versions <- lapply(unlist(report$missing, use.names = FALSE), function(pkg) {
  observed <- packageDescription(pkg)[["Version"]]
  locked <- lock$Packages[[pkg]]$Version
  list(package = pkg, observed = observed, locked = locked,
       equal = identical(observed, locked), source = lock$Packages[[pkg]]$Source)
})
stopifnot(length(missing) == 0L,
          all(vapply(versions, function(item) item$equal, logical(1))))
names(versions) <- unlist(report$missing, use.names = FALSE)
scripts <- list.files("R", pattern = "\\.R$", full.names = TRUE)
used <- unique(unlist(lapply(scripts, function(path) {
  source_text <- paste(readLines(path, warn = FALSE), collapse = "\n")
  matches <- regmatches(source_text,
                        gregexpr("library\\([A-Za-z0-9.]+\\)|[A-Za-z0-9.]+::",
                                 source_text, perl = TRUE))[[1]]
  sub("::$", "", sub("^library\\(([A-Za-z0-9.]+)\\)$", "\\1", matches))
}), use.names = FALSE))
used <- sort(setdiff(used, c("stats", "utils")))
missing_direct <- setdiff(used, names(lock$Packages))
stopifnot(length(missing_direct) == 0L)
jsonlite::write_json(list(prior_records_preserved = 174L, final_records = 180L,
                          roots = unlist(report$roots, use.names = FALSE),
                          closure_count = length(closure),
                          missing_after_merge = missing,
                          scanned_R_scripts = basename(scripts),
                          direct_roots = used,
                          missing_direct_roots = missing_direct,
                          six_records = versions),
                     file.path(round_dir, "lock_verification.json"),
                     auto_unbox = TRUE, pretty = TRUE)
cat("Preserved 174; final 180; closure missing 0; direct roots missing 0; six literal versions matched\n")
