# Read-only QA probe: no sourcing project scripts or estimation.
root <- normalizePath(".")
lib <- file.path(root, "renv/library/macos/R-4.4/aarch64-apple-darwin20")
.libPaths(c(lib, .libPaths()))

fit_path <- file.path(root, "quality_reports/results/05_eforensics_qbl_brasilia_fresh_v2_fit.rds")
fit <- readRDS(fit_path)
chains <- if (inherits(fit, "runjags")) fit$mcmc else fit
stopifnot(inherits(chains, "mcmc.list"))
cat("fit_class:", paste(class(fit), collapse = ","), "\n")
cat("chains:", length(chains), "draws:", paste(vapply(chains, nrow, integer(1)), collapse = ","), "\n")
cat("pi2_means:", paste(round(vapply(chains, function(x) mean(x[, "pi[2]"]), numeric(1)), 5), collapse = ","), "\n")
cat("pi2_rhat_classic:", coda::gelman.diag(chains[, "pi[2]"], autoburnin = FALSE)$psrf[1, 1], "\n")
cat("iota_rhat_classic:", coda::gelman.diag(chains[, "iota.s.alpha"], autoburnin = FALSE)$psrf[1, 1], "\n")

for (name in c("brasil_2022_secao.parquet", "brasil_2022_secao_clean.parquet",
               "brasil_2022_muni_clean.parquet", "nexojornal_muni_2022.parquet")) {
  path <- file.path(root, "data/processed", name)
  table <- arrow::read_parquet(path)
  cat("parquet:", name, "rows:", nrow(table), "columns:", ncol(table), "\n")
  rm(table)
}

desc <- read.dcf(file.path(find.package("eforensics"), "DESCRIPTION"))
frozen_desc <- read.dcf(file.path(root, "quality_reports/results/mebane_gates/G0/round1/eforensics_installed_DESCRIPTION"))
cat("eforensics_version:", desc[1, "Version"], "remote_sha:", desc[1, "RemoteSha"], "\n")
cat("description_identical:", identical(desc, frozen_desc), "\n")
model <- get("qbl", envir = asNamespace("eforensics"))()
frozen_model <- readChar(file.path(root, "quality_reports/results/mebane_gates/G0/round1/qbl_installed_3017de5.jags"),
                         file.info(file.path(root, "quality_reports/results/mebane_gates/G0/round1/qbl_installed_3017de5.jags"))$size)
cat("qbl_snapshot_equal:", identical(paste0(model, "\n"), frozen_model), "\n")

source_env <- new.env(parent = baseenv())
sys.source(file.path(root, "quality_reports/results/mebane_gates/G0/round1/ef_models_3017de5.R"), envir = source_env)
cat("qbl_commit_equal:", identical(model, source_env$qbl()), "\n")

lock <- jsonlite::fromJSON(file.path(root, "quality_reports/results/mebane_gates/G0/round1/final_state/renv.lock"),
                            simplifyVector = FALSE)
installed <- installed.packages()
roots <- c("eforensics", "rjags", "coda", "runjags", "cmdstanr", "posterior")
deps <- tools::package_dependencies(roots, db = installed,
                                    which = c("Depends", "Imports", "LinkingTo"), recursive = TRUE)
needed <- sort(unique(c(roots, unlist(deps, use.names = FALSE))))
needed <- setdiff(needed, c("R", rownames(installed.packages(priority = "base"))))
missing_lock <- setdiff(needed, names(lock$Packages))
version_mismatch <- needed[vapply(needed, function(name) {
  entry <- lock$Packages[[name]]
  is.null(entry) || !identical(entry$Version, packageDescription(name)[["Version"]])
}, logical(1))]
cat("closure_count:", length(needed), "missing_lock:", paste(missing_lock, collapse = ","),
    "version_mismatch:", paste(version_mismatch, collapse = ","), "\n")
cat("lock_R:", lock$R$Version, "runtime_R:", as.character(getRversion()), "\n")

extra_roots <- c("diptest", "spikes")
extra_deps <- tools::package_dependencies(extra_roots, db = installed,
                                          which = c("Depends", "Imports", "LinkingTo"), recursive = TRUE)
extra_needed <- sort(unique(c(extra_roots, unlist(extra_deps, use.names = FALSE))))
extra_needed <- setdiff(extra_needed, c("R", rownames(installed.packages(priority = "base"))))
cat("supplemental_missing_lock:", paste(setdiff(extra_needed, names(lock$Packages)), collapse = ","), "\n")
