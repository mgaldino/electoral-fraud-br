# Build a read-only proposal from installed packages. Never restore or install.
root <- normalizePath(".")
round_dir <- file.path(root, "quality_reports/results/mebane_gates/G0/round1")
project_lib <- file.path(root, "renv/library/macos/R-4.4/aarch64-apple-darwin20")
.libPaths(c(project_lib, .libPaths()))
stopifnot(requireNamespace("renv", quietly = TRUE), requireNamespace("jsonlite", quietly = TRUE))

roots <- c("eforensics", "rjags", "coda", "runjags", "cmdstanr", "posterior")
installed <- installed.packages()
dependencies <- tools::package_dependencies(roots, db = installed,
  which = c("Depends", "Imports", "LinkingTo"), recursive = TRUE)
needed <- sort(unique(c(roots, unlist(dependencies, use.names = FALSE))))
needed <- setdiff(needed, c("R", rownames(installed.packages(priority = "base"))))
old <- jsonlite::fromJSON("renv.lock", simplifyVector = FALSE)
missing <- setdiff(needed, names(old$Packages))
proposal_path <- file.path(round_dir, "installed_records.lock")
renv::snapshot(project = root, library = .libPaths(), lockfile = proposal_path,
               packages = needed, type = "all", prompt = FALSE, force = TRUE)
proposal <- jsonlite::fromJSON(proposal_path, simplifyVector = FALSE)
available <- intersect(missing, names(proposal$Packages))
unavailable <- setdiff(missing, available)
report <- list(roots = roots, needed_count = length(needed), missing_count = length(missing),
               missing = missing, proposal_entries_available = available,
               proposal_entries_unavailable = unavailable,
               preserved_original_entries = length(old$Packages))
jsonlite::write_json(report, file.path(round_dir, "lock_reconciliation.json"),
                     auto_unbox = TRUE, pretty = TRUE)
cat("Missing", length(missing), "lock records; proposed", length(available), "entries\n")
