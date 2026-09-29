# Read frozen scripts and installed DESCRIPTION records; no project activation.
root <- normalizePath(".")
round_dir <- file.path(root, "quality_reports/results/mebane_gates/G0/round2")
.libPaths(c(file.path(root, "renv/library/macos/R-4.4/aarch64-apple-darwin20"), .libPaths()))
run <- jsonlite::fromJSON(file.path(round_dir, "run.json"), simplifyVector = FALSE)
lock <- jsonlite::fromJSON(file.path(round_dir, "final_state/renv.lock"), simplifyVector = FALSE)
paths <- unlist(run$code, use.names = FALSE)
paths <- paths[grepl("/final_state/R/[^/]+[.]R$", paths)]
roots <- character()
walk <- function(expr) {
  if (missing(expr)) return(invisible(NULL))
  if (!is.call(expr)) return(invisible(NULL))
  op <- if (is.symbol(expr[[1]])) as.character(expr[[1]]) else ""
  if (op %in% c("library", "require", "requireNamespace", "::", ":::")) {
    arg <- expr[[2]]
    if (is.character(arg) || (is.symbol(arg) && op != "requireNamespace")) {
      roots <<- union(roots, as.character(arg))
    }
  }
  for (arg in as.list(expr)[-1]) walk(arg)
  invisible(NULL)
}
for (path in paths) for (expr in parse(file.path(root, path), keep.source = FALSE)) walk(expr)
base <- rownames(installed.packages(priority = "base"))
roots <- sort(setdiff(roots, c("R", base)))
installed <- installed.packages()
stopifnot(all(roots %in% rownames(installed)))
deps <- tools::package_dependencies(roots, db = installed,
                                    which = c("Depends", "Imports", "LinkingTo"), recursive = TRUE)
closure <- sort(setdiff(unique(c(roots, unlist(deps, use.names = FALSE))), c("R", base)))
missing <- setdiff(closure, names(lock$Packages))
mismatches <- closure[vapply(closure, function(pkg) {
  is.null(lock$Packages[[pkg]]) ||
    !identical(lock$Packages[[pkg]]$Version, packageDescription(pkg)[["Version"]])
}, logical(1))]
six <- c("bbmle", "bdsmatrix", "diptest", "emdbook", "plyr", "spikes")
records <- lapply(six, function(pkg) {
  record <- lock$Packages[[pkg]]
  desc <- packageDescription(pkg)
  list(package = pkg, observed_version = desc[["Version"]],
       locked_version = record$Version, source = record$Source,
       repository = record$Repository, remote_sha = record$RemoteSha,
       version_equal = identical(desc[["Version"]], record$Version))
})
result <- list(frozen_scripts = paths, script_count = length(paths), roots = roots,
               closure_count = length(closure), missing = missing, version_mismatches = mismatches,
               six_records = records, r_version = R.version.string,
               method = "Parse frozen R expressions; recursive installed Depends/Imports/LinkingTo; literal DESCRIPTION versions")
jsonlite::write_json(result, file.path(round_dir, "review/dependencies_results.json"),
                     auto_unbox = TRUE, pretty = TRUE, null = "null")
cat("scripts", length(paths), "roots", length(roots), "closure", length(closure),
    "missing", paste(missing, collapse = ","), "version_mismatches", paste(mismatches, collapse = ","), "\n")
print(records)
stopifnot(length(missing) == 0L, length(mismatches) == 0L,
          all(vapply(records, function(item) item$version_equal, logical(1))))
