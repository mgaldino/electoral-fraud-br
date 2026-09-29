# Read installed package metadata; do not activate renv, install, or restore.
root <- normalizePath(".")
round_dir <- file.path(root, "quality_reports/results/mebane_gates/G0/round2")
project_lib <- file.path(root, "renv/library/macos/R-4.4/aarch64-apple-darwin20")
.libPaths(c(project_lib, .libPaths()))
stopifnot(requireNamespace("renv", quietly = TRUE),
          requireNamespace("jsonlite", quietly = TRUE))

scripts <- c("R/05_dip_test_diagnostics.R", "R/08_spikes_rozenas.R")
roots <- c("diptest", "spikes")
for (i in seq_along(scripts)) {
  source_text <- paste(readLines(scripts[[i]], warn = FALSE), collapse = "\n")
  stopifnot(grepl(paste0("library\\(", roots[[i]], "\\)"), source_text))
}
installed <- installed.packages()
deps <- tools::package_dependencies(roots, db = installed,
                                    which = c("Depends", "Imports", "LinkingTo"),
                                    recursive = TRUE)
closure <- setdiff(sort(unique(c(roots, unlist(deps, use.names = FALSE)))),
                   c("R", rownames(installed.packages(priority = "base"))))
old <- jsonlite::fromJSON("renv.lock", simplifyVector = FALSE)
stopifnot(length(old$Packages) == 174L)
missing <- setdiff(closure, names(old$Packages))
expected <- c("bbmle", "bdsmatrix", "diptest", "emdbook", "plyr", "spikes")
stopifnot(setequal(missing, expected))
proposal_path <- file.path(round_dir, "installed_supplement.lock")
renv::snapshot(project = root, library = .libPaths(), lockfile = proposal_path,
               packages = closure, prompt = FALSE, force = TRUE)
proposal <- jsonlite::fromJSON(proposal_path, simplifyVector = FALSE)
stopifnot(all(missing %in% names(proposal$Packages)))

records <- lapply(missing, function(pkg) {
  d <- packageDescription(pkg)
  list(package = pkg, version = d[["Version"]], source = d[["Repository"]],
       remote_sha = d[["RemoteSha"]], in_prior_lock = FALSE,
       proposed_version = proposal$Packages[[pkg]]$Version)
})
names(records) <- missing
stopifnot(all(vapply(records, function(x) identical(x$version, x$proposed_version), logical(1))))
report <- list(roots = roots, root_scripts = scripts, closure = closure,
               closure_count = length(closure), old_lock_count = length(old$Packages),
               missing = missing, installed_records = records,
               method = "installed DESCRIPTION$Version and renv snapshot; no install or restore")
jsonlite::write_json(report, file.path(round_dir, "lock_reconciliation.json"),
                     auto_unbox = TRUE, pretty = TRUE, null = "null")
cat("closure", length(closure), "missing", paste(missing, collapse = ","), "\n")
