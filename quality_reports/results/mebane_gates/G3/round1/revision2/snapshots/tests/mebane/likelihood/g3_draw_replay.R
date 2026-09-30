# One conditioned qbl/JAGS replay. No probes, grid or downstream summaries here.
.libPaths(c("renv/library/macos/R-4.4/aarch64-apple-darwin20", .libPaths()))
stopifnot(requireNamespace("rjags", quietly = TRUE),
          requireNamespace("coda", quietly = TRUE),
          requireNamespace("jsonlite", quietly = TRUE))
outdir <- "quality_reports/results/mebane_gates/G3/round1/revision2"
model <- "quality_reports/results/mebane_gates/G0/round1/qbl_installed_3017de5.jags"
protocol <- "quality_reports/results/mebane_gates/G3/round1/protocol_v2.json"
rds_path <- file.path(outdir, "raw_chains.rds")
metadata_path <- file.path(outdir, "sampling_metadata.json")
stopifnot(dir.exists(outdir), !file.exists(rds_path), !file.exists(metadata_path))
sha <- function(path) strsplit(system2("shasum", c("-a", "256", path),
                                       stdout = TRUE), " ")[[1]][1]
stopifnot(sha(model) == "f8360126424b7a463f76a1c99efc89a8a5cb81339213bd4931559f14595fbab6",
          as.character(rjags::jags.version()) == "4.3.2")
p <- jsonlite::read_json(protocol, simplifyVector = TRUE)
stopifnot(identical(as.integer(p$seeds$jags_chains), 31102:31105),
          p$jags$chains == 4, p$jags$adapt == 200,
          p$jags$burnin == 500, p$jags$sample_iterations_per_chain == 2000)

data <- list(n = 1L, N = 1L, a = 0L, w = 0L,
             "pi.aux1" = 1, "pi.aux2" = .5, "pi.aux3" = .25)
for (nm in c("tau", "nu", "iota.m", "iota.s", "chi.m", "chi.s")) {
  name <- if (nm == "tau") "a" else if (nm == "nu") "w" else paste0(".", nm)
  data[[paste0("X", name)]] <- matrix(1, 1, 1)
  data[[paste0("dx", name)]] <- 1L
  h <- switch(nm, tau = "th", nu = "nh", "iota.m" = "imh",
              "iota.s" = "ish", "chi.m" = "cmh", "chi.s" = "csh")
  data[[h]] <- 0
  data[[paste0("beta.", nm, "1")]] <- 0
}
# Z and all four counts remain stochastic; all continuous effects are conditioned.
seeds <- 31102:31105
inits <- lapply(seeds, function(s) list(.RNG.name = "base::Mersenne-Twister",
                                        .RNG.seed = as.integer(s)))
started <- Sys.time()
jm <- rjags::jags.model(model, data = data, inits = inits,
                       n.chains = 4L, n.adapt = 200L, quiet = TRUE)
stats::update(jm, 500L, progress.bar = "none")
nodes <- c("Z", "N.iota.m", "N.iota.s", "N.chi.m", "N.chi.s")
fit <- rjags::coda.samples(jm, nodes, n.iter = 2000L,
                           progress.bar = "none")
ended <- Sys.time()
stopifnot(length(fit) == 4L,
          all(vapply(fit, nrow, integer(1)) == 2000L),
          all(vapply(fit, ncol, integer(1)) == 5L))
payload <- list(schema_version = "1.0", repair_id = "G3-COORD-DRAW-01",
  new_draws_not_recovery = TRUE, model_path = model, model_sha256 = sha(model),
  protocol_path = protocol, protocol_sha256 = sha(protocol),
  data = data, inits = inits, monitored_nodes = nodes,
  adapt = 200L, burnin = 500L, post_iterations_per_chain = 2000L,
  thin = 1L, chains = 4L, seeds = seeds,
  r_version = R.version.string, jags_version = as.character(rjags::jags.version()),
  rjags_version = as.character(utils::packageVersion("rjags")),
  coda_version = as.character(utils::packageVersion("coda")),
  started_at = format(started, tz = "UTC", usetz = TRUE),
  ended_at = format(ended, tz = "UTC", usetz = TRUE),
  elapsed_seconds = as.numeric(difftime(ended, started, units = "secs")),
  draws = fit)
saveRDS(payload, rds_path, version = 3)
# This metadata records the persisted object; summaries are computed by a separate reopen.
metadata <- payload[names(payload) != "draws"]
metadata$raw_rds_path <- rds_path
metadata$raw_rds_sha256 <- sha(rds_path)
metadata$draw_rows_per_chain <- vapply(fit, nrow, integer(1))
metadata$draw_columns <- colnames(as.matrix(fit[[1]]))
jsonlite::write_json(metadata, metadata_path, auto_unbox = TRUE,
                     pretty = TRUE, na = "null")
cat("persisted", length(fit), "chains x", nrow(fit[[1]]), "draws, SHA-256",
    metadata$raw_rds_sha256, "\n")
