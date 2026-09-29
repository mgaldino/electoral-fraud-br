# Read-only package and artifact probe. Avoid project .Rprofile / renv bootstrap.
root <- normalizePath(".")
round_dir <- file.path(root, "quality_reports/results/mebane_gates/G0/round1")
project_lib <- file.path(root, "renv/library/macos/R-4.4/aarch64-apple-darwin20")
.libPaths(c(project_lib, .libPaths()))
stopifnot(requireNamespace("jsonlite", quietly = TRUE))

packages <- c("renv", "eforensics", "rjags", "coda", "runjags", "cmdstanr",
              "posterior", "arrow", "data.table", "dplyr", "here", "readxl")
package_info <- lapply(packages, function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) return(list(installed = FALSE))
  description <- packageDescription(pkg)
  list(installed = TRUE, version = description[["Version"]],
       library = find.package(pkg), remote_sha = description[["RemoteSha"]],
       remote_repo = description[["RemoteRepo"]],
       remote_username = description[["RemoteUsername"]],
       built = description[["Built"]])
})
names(package_info) <- packages

lock <- jsonlite::fromJSON("renv.lock", simplifyVector = FALSE)
lock_gaps <- lapply(packages, function(pkg) {
  entry <- lock$Packages[[pkg]]
  list(package = pkg, locked = !is.null(entry),
       locked_version = if (!is.null(entry)) entry$Version else NULL,
       effective_version = package_info[[pkg]]$version,
       version_equal = !is.null(entry) && identical(entry$Version, package_info[[pkg]]$version))
})

fit_path <- "quality_reports/results/05_eforensics_qbl_brasilia_fresh_v2_fit.rds"
fit <- readRDS(fit_path)
fit_info <- list(path = fit_path, class = class(fit), length = length(fit),
                 names = names(fit), object_bytes = as.numeric(object.size(fit)))
chains <- if (inherits(fit, "runjags")) fit$mcmc else fit
if (inherits(chains, "mcmc.list")) {
  fit_info$chains <- length(chains)
  fit_info$draws_per_chain <- vapply(chains, nrow, integer(1))
  fit_info$parameters <- colnames(chains[[1]])
  fit_info$pi2_chain_means <- vapply(chains, function(chain) mean(chain[, "pi[2]"]), numeric(1))
  for (parameter in c("tau.alpha", "nu.alpha", "pi[1]", "pi[2]", "iota.s.alpha")) {
    key <- gsub("[^A-Za-z0-9]", "_", parameter)
    fit_info[[paste0("rhat_", key)]] <- as.numeric(coda::gelman.diag(chains[, parameter], autoburnin = FALSE)$psrf[1, 1])
  }
}

data_path <- "data/processed/brasil_2022_secao_clean.parquet"
table <- arrow::read_parquet(data_path)
data_info <- list(path = data_path, class = class(table), rows = nrow(table),
                  columns = ncol(table), names = names(table))
rm(table, fit, chains)
invisible(gc())

model_text <- get("qbl", envir = asNamespace("eforensics"))()
writeLines(model_text, file.path(round_dir, "qbl_installed_3017de5.jags"), useBytes = TRUE)
stopifnot(file.copy(file.path(find.package("eforensics"), "DESCRIPTION"),
                    file.path(round_dir, "eforensics_installed_DESCRIPTION"),
                    overwrite = TRUE))
reference <- new.env(parent = baseenv())
sys.source(file.path(round_dir, "ef_models_3017de5.R"), envir = reference)
qbl_reference_equal <- identical(reference$qbl(), model_text)

cmdstan <- tryCatch(list(path = cmdstanr::cmdstan_path(),
                         version = as.character(cmdstanr::cmdstan_version())),
                    error = function(e) list(error = conditionMessage(e)))
jags_banner <- tryCatch(system2("jags", input = "exit", stdout = TRUE, stderr = TRUE),
                        error = function(e) conditionMessage(e))
result <- list(r_version = R.version.string, platform = R.version$platform,
               library_paths = .libPaths(), package_info = package_info,
               lock_r_version = lock$R$Version, lock_gaps = lock_gaps,
               cmdstan = cmdstan, jags_banner = jags_banner, fit = fit_info, data = data_info,
               qbl_model_snapshot = "quality_reports/results/mebane_gates/G0/round1/qbl_installed_3017de5.jags",
               qbl_reference_equal = qbl_reference_equal,
               rhat_method = "coda::gelman.diag point estimate, autoburnin=FALSE; not rank-normalized")
jsonlite::write_json(result, file.path(round_dir, "loads_environment.json"),
                     auto_unbox = TRUE, pretty = TRUE, null = "null")
cat("Loaded fit", paste(fit_info$class, collapse = "/"), "and parquet", data_info$rows, "rows\n")
