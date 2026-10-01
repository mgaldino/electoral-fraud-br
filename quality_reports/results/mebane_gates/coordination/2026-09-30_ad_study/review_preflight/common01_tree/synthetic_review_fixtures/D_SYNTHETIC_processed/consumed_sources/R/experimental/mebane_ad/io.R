# Non-destructive artifact helpers shared by the experimental study.
ad_setup <- function() {
  local_lib <- "renv/library/macos/R-4.4/aarch64-apple-darwin20"
  if (dir.exists(local_lib)) .libPaths(c(local_lib, .libPaths()))
  for (package in c("jsonlite", "digest")) {
    if (!requireNamespace(package, quietly = TRUE)) {
      stop("Required existing package unavailable: ", package)
    }
  }
}

ad_sha <- function(path) {
  stopifnot(length(path) == 1L, file.exists(path), !dir.exists(path))
  digest::digest(file = path, algo = "sha256", serialize = FALSE)
}

ad_json <- function(value, path) {
  if (file.exists(path)) stop("Refusing to overwrite: ", path)
  jsonlite::write_json(value, path, pretty = TRUE, auto_unbox = TRUE,
                       na = "null", digits = NA)
}

ad_new_dir <- function(path) {
  if (file.exists(path) || dir.exists(path)) stop("Output already exists: ", path)
  if (!dir.create(path, recursive = TRUE, showWarnings = FALSE)) {
    stop("Cannot create output directory: ", path)
  }
  invisible(path)
}

ad_snapshot <- function(paths, out) {
  ad_new_dir(out)
  records <- lapply(unique(paths), function(path) {
    if (!file.exists(path) || dir.exists(path)) stop("Input missing: ", path)
    absolute <- normalizePath(path, mustWork = TRUE)
    root <- paste0(normalizePath(".", mustWork = TRUE), "/")
    if (!startsWith(absolute, root)) stop("Input outside project: ", path)
    relative <- substring(absolute, nchar(root) + 1L)
    target <- file.path(out, relative)
    dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
    if (file.exists(target) || !file.copy(path, target, overwrite = FALSE)) {
      stop("Cannot preserve source: ", path)
    }
    stopifnot(ad_sha(path) == ad_sha(target))
    list(path = relative, snapshot = target, bytes = unname(file.info(path)$size),
         sha256 = ad_sha(path))
  })
  ad_json(list(created_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
               files = records), file.path(out, "manifest.json"))
  records
}

ad_manifest <- function(out, inputs = character(), note = "") {
  paths <- sort(unique(c(inputs, list.files(out, recursive = TRUE,
                                           full.names = TRUE, all.files = TRUE))))
  paths <- paths[file.exists(paths) & !dir.exists(paths)]
  records <- lapply(paths, function(path) {
    list(path = path, bytes = unname(file.info(path)$size), sha256 = ad_sha(path))
  })
  ad_json(list(note = note, files = records,
               excluded = "This manifest itself; active outer process logs are sealed separately"),
           file.path(out, "manifest.json"))
}
