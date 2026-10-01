# Independent executable review: synthetic coda payloads only, never JAGS sampling.
options(warn = 1)
root <- "/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud"
base <- "quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study"
out <- file.path(root, base, "review_preflight")
tree <- file.path(out, "common01_tree")
.libPaths(c(file.path(root, "renv/library/macos/R-4.4/aarch64-apple-darwin20"), .libPaths()))
stopifnot(!file.exists(file.path(out, "checks_common01.json")),
          !file.exists(file.path(out, "checks_common01.log")))
sink(file.path(out, "checks_common01.log"), split = TRUE)
setwd(tree)
source("R/experimental/mebane_ad/run_jags.R")
source("R/experimental/mebane_ad/diagnostics.R")
checks <- list()
check <- function(id, ok, detail = NULL) {
  checks[[length(checks) + 1L]] <<- list(id = id, pass = isTRUE(ok), detail = detail)
  cat(if (isTRUE(ok)) "PASS" else "FAIL", id, "\n")
  if (!isTRUE(ok)) stop(id)
}
error_of <- function(expr) tryCatch({force(expr); NULL}, error = function(e) conditionMessage(e))
contract_path <- file.path(base, "contract_v2.json")
data_path <- file.path(base, "data/run-20260930T235038Z-pid61600/dc2010_ad_data.rds")
payload <- readRDS(data_path)
contract <- jsonlite::read_json(contract_path, simplifyVector = TRUE)
archived <- load_dc2010(contract$case$source)
check("source-RDA-sha", ad_sha(contract$case$source) == contract$case$sha256)
check("literal-A-sha", ad_sha(contract$A$source) == contract$A$sha256)
check("G2-sha", ad_sha(contract$A$specification_contract) == contract$A$specification_sha256)
check("full-outgoing-payload-matches-archived-source", isTRUE(ad_check_payload(payload, contract)))
check("independent-row-mapping", identical(payload$precinct, as.character(archived$precinct)) &&
        identical(payload$A$N, archived$NVoters) && identical(payload$A$a, archived$a) &&
        identical(payload$A$w, archived$Votes) &&
        identical(unname(payload$D$observed[, 3]), archived$NValid - archived$Votes))
for (key in c("Xa", "Xw", "X.iota.m", "X.iota.s", "X.chi.m", "X.chi.s")) {
  x <- payload$A[[key]]
  check(paste0("design-", key), identical(dim(x), c(143L, 1L)) && all(x == 1) &&
          identical(rownames(x), payload$precinct))
}
for (kind in c("swap-A", "swap-D", "permute-ID", "permute-all-rows")) {
  bad <- payload
  if (kind == "swap-A") {bad$A$a <- payload$A$w; bad$A$w <- payload$A$a}
  if (kind == "swap-D") bad$D$observed <- bad$D$observed[, c(2, 1, 3)]
  if (kind == "permute-ID") bad$precinct <- rev(bad$precinct)
  if (kind == "permute-all-rows") bad <- build_dc2010_data(validate_dc2010(archived[143:1, ]))
  err <- error_of(ad_check_payload(bad, contract))
  check(paste0("reject-", kind), !is.null(err), err)
}
for (model in c("A", "D")) {
  inits <- ad_initial_values(model, payload, contract)
  for (chain in 1:4) {
    init <- inits[[chain]]
    check(paste(model, chain, "init-nodes"),
          length(init$Z) == 143 && all(init$Z == 1) &&
          init$.RNG.seed == contract$paired_design$chain_seeds[chain] &&
          all(unlist(init[ad_v_names]) == c(.1,.2,.3,.4)[chain]) &&
          all(unlist(init[paste0("beta.", ad_blocks, "1")]) == 0))
  }
}
check("rule-rhat-strict", !ad_metric_pass(c(1.01, 400, 400)))
check("rule-ESS-inclusive", ad_metric_pass(c(1.009, 400, 400)))
check("rule-bulk-below", !ad_metric_pass(c(1.009, 399, 400)))
check("rule-tail-below", !ad_metric_pass(c(1.009, 400, 399)))
check("rule-range-inclusive", ad_metric_pass(c(1.009, 400, 400), .05, .05))
check("rule-range-above", !ad_metric_pass(c(1.009, 400, 400), .05001, .05))
check("rule-NA", !ad_metric_pass(c(1.009, 400, NA)))
constant <- ad_diagnostic_row(matrix(0, 2000, 4), "constant", "fixture")
check("sample-constant-NA-inconclusive", !constant$diagnostic_pass && is.na(constant$rhat) &&
        ad_decision(constant, TRUE) == "computationally_inconclusive")
finite_row <- constant; finite_row$diagnostic_pass <- TRUE
check("adaptation-fails-closed", ad_decision(finite_row, FALSE) == "computationally_inconclusive")
check("completion-fails-closed", ad_decision(finite_row, TRUE, FALSE) == "computationally_inconclusive")

N <- payload$A$N; A <- payload$A$a; W <- payload$A$w; n <- length(N)
iteration <- seq_len(2000)
blocks <- c("tau", "nu", "iota.m", "iota.s", "chi.m", "chi.s")
fixture_root <- "synthetic_review_fixtures"
ad_new_dir(fixture_root)
make_payload <- function(model) {
  expected_M <- expected_S <- expected_CM <- expected_CS <- matrix(0, 2000, 4)
  draws <- lapply(1:4, function(chain) {
    signal <- qnorm((((iteration * 613L + chain * 277L) %% 2000) + .5) / 2000)
    zoffset <- c(-2, 2, -2, 2)[chain]
    values <- list()
    values[["pi[1]"]] <- .6 + .02 * sin(iteration * .91 + chain)
    values[["pi[2]"]] <- .2 + .01 * cos(iteration * .57 + chain)
    values[["pi[3]"]] <- 1 - values[["pi[1]"]] - values[["pi[2]"]]
    for (b in seq_along(blocks)) {
      values[[paste0(blocks[b], ".alpha")]] <- signal + zoffset + b/10
      beta <- paste0("beta.", blocks[b], "1", if (model == "A") "[1]" else "")
      values[[beta]] <- .005 * sin(iteration * .71 + b + chain)
      values[[ad_v_names[b]]] <- .1 + .01 * cos(iteration * .33 + b + chain)
    }
    for (i in seq_len(n)) {
      wave <- sin(iteration * .73 + i + chain)
      tau <- .3 + .04 * wave + .005 * zoffset
      nu <- .6 + .04 * cos(iteration * .31 + i + chain)
      mus <- list(.08 + .015 * wave, .2 + .025 * wave,
                  .78 + .025 * wave, .92 + .025 * wave)
      Z <- as.integer((iteration + i + chain) %% 3 + 1)
      values[[paste0("Z[", i, "]")]] <- Z
      values[[paste0("mu.tau[", i, "]")]] <- tau
      values[[paste0("mu.nu[", i, "]")]] <- nu
      for (b in 1:4) values[[paste0("mu.", blocks[b+2], "[", i, "]")]] <- mus[[b]]
      fractions <- mus
      if (model == "A") {
        counts <- lapply(mus, function(x) floor(N[i] * x))
        # Legal endpoint sentinel: s=1 keeps A's active pW finite at m=.999.
        endpoint <- iteration %% 7 == 0
        for (b in 1:4) counts[[b]][endpoint] <- N[i]
        for (b in 1:4) values[[paste0("N.", blocks[b+2], "[", i, "]")]] <- counts[[b]]
        fractions <- lapply(counts, function(x) x / N[i])
        for (b in c(1, 3)) fractions[[b]][fractions[[b]] == 1] <- .999
      }
      m <- ifelse(Z == 1, 0, ifelse(Z == 2, fractions[[1]], fractions[[3]]))
      s <- ifelse(Z == 1, 0, ifelse(Z == 2, fractions[[2]], fractions[[4]]))
      pa <- (1-tau)*(1-m)
      pw <- if (model == "D") tau*nu + (1-tau)*m + tau*(1-nu)*s else
        nu*(1-s)/(1-m)*(1-m-A[i]/N[i]) + (A[i]/N[i])*(m-s)/(1-m) + s
      values[[paste0("p.a[", i, "]")]] <- pa
      values[[paste0("p.w[", i, "]")]] <- pw
      if (model == "D") values[[paste0("p.o[", i, "]")]] <- tau*(1-nu)*(1-s)
      expected_M[, chain] <<- expected_M[, chain] + N[i]*(1-tau)*m
      expected_S[, chain] <<- expected_S[, chain] + N[i]*tau*(1-nu)*s
      if (model == "D") {
        expected_CM[, chain] <<- expected_CM[, chain] + W[i]*(1-tau)*m/pw
        expected_CS[, chain] <<- expected_CS[, chain] + W[i]*tau*(1-nu)*s/pw
      }
    }
    m <- do.call(cbind, values)
    coda::mcmc(m[, order(colnames(m))], start = 6001, thin = 1)
  })
  list(raw = list(model = model, draws = do.call(coda::mcmc.list, draws),
                  contract_sha256 = ad_sha(contract_path), seeds = contract$paired_design$chain_seeds,
                  adaptation_adequate = TRUE, phases = list(), SYNTHETIC_NOT_MCMC = TRUE),
       expected = list(M = expected_M, S = expected_S, CM = expected_CM, CS = expected_CS))
}
audit_outputs <- function(model, synthetic, run_dir, processed) {
  diag <- read.csv(file.path(processed, "diagnostics.csv"), check.names = FALSE)
  joint <- read.csv(file.path(processed, "joint_functionals.csv"))
  result <- jsonlite::read_json(file.path(processed, "diagnostic_result.json"), simplifyVector = TRUE)
  check(paste(model, "actual-mandatory-target-count"), sum(diag$mandatory) == if (model == "A") 2171 else 1742)
  check(paste(model, "no-duplicate-diagnostic-targets"), !anyDuplicated(diag$target))
  check(paste(model, "shape-iteration-chain"), identical(joint$iteration, rep(1:2000, 4)) &&
          identical(joint$chain, rep(1:4, each = 2000)))
  check(paste(model, "joint-M-exact"), max(abs(joint$M - as.vector(synthetic$expected$M))) < 1e-8)
  check(paste(model, "joint-S-exact"), max(abs(joint$S - as.vector(synthetic$expected$S))) < 1e-8)
  check(paste(model, "fixed-denominator"), max(abs(joint$M_fraction_N - joint$M/sum(N))) < 1e-12)
  matrices <- lapply(synthetic$raw$draws, as.matrix)
  # Verify every directly extracted target by name and chain mean independently.
  direct <- diag$group %in% c("global", "local_continuous", "A_auxiliary") &
    !diag$target %in% c("M_total", "S_total")
  errors <- vapply(which(direct), function(j) {
    name <- diag$target[j]
    if (!name %in% colnames(matrices[[1]])) name <- paste0(name, "[1]")
    target <- vapply(matrices, function(m) mean(m[, name]), numeric(1))
    max(abs(target - as.numeric(diag[j, paste0("chain", 1:4)])))
  }, numeric(1))
  check(paste(model, "all-direct-extractions-chain-means"), max(errors) < 1e-9, length(errors))
  tau_row <- diag[diag$target == "tau.alpha", ]
  tm <- do.call(cbind, lapply(matrices, function(m) m[, "tau.alpha"]))
  check(paste(model, "actual-Rhat-preserves-chains"), abs(tau_row$rhat - posterior::rhat(tm)) < 1e-12 &&
          tau_row$rhat > 1.1 && posterior::rhat(matrix(as.vector(tm), ncol=1)) < 1.01)
  classes <- read.csv(file.path(processed, "class_probabilities.csv"), stringsAsFactors = FALSE)
  ranges <- numeric()
  for (k in 1:3) {
    counts <- matrix(0, 2000, 4)
    for (i in seq_len(n)) {
      ind <- do.call(cbind, lapply(matrices, function(m) as.numeric(m[, paste0("Z[", i, "]")] == k)))
      counts <- counts + ind
      row <- classes[classes$precinct == payload$precinct[i] & classes$class == k, ]
      stopifnot(nrow(row) == 1, max(abs(as.numeric(row[paste0("chain",1:4)]) - colMeans(ind))) < 1e-12)
    }
    dr <- diag[diag$target == paste0("class_count[", k, "]"), ]
    ranges[k] <- abs(dr$chain_mean_range - diff(range(colMeans(counts)))/n)
  }
  check(paste(model, "all-class-probabilities-rowmapping"), TRUE)
  check(paste(model, "class-count-range-divided-by-n"), max(ranges) < 1e-12)
  check(paste(model, "ties-preserved"), all(classes$modal == (ave(classes$probability, classes$precinct,
                                                               FUN=function(x) x == max(x)) == 1)))
  expected_pass <- with(diag, is.finite(rhat) & is.finite(ess_bulk) & is.finite(ess_tail) &
                        rhat < 1.01 & ess_bulk >= 400 & ess_tail >= 400 &
                        (is.na(range_limit) | chain_mean_range <= range_limit))
  check(paste(model, "every-row-v2-decision"), identical(diag$diagnostic_pass, expected_pass))
  check(paste(model, "synthetic-inconclusive-not-pair-release"), result$status == "computationally_inconclusive" &&
          result$paired_verdict == "not_assigned_by_per_model_processor" && !any(diag$analytic_constant))
  if (model == "D") {
    check("D-conditional-means-exact", max(abs(joint$M_count_conditional_mean - as.vector(synthetic$expected$CM)),
                                          abs(joint$S_count_conditional_mean - as.vector(synthetic$expected$CS))) < 1e-8)
    ct <- readRDS(file.path(processed, "secondary_counts_by_unit.rds"))
    check("D-count-array-and-capacities", identical(dim(ct$M), c(2000L,4L,143L)) &&
            all(ct$M == floor(ct$M)) && all(ct$S == floor(ct$S)) &&
            all(ct$M >= 0) && all(ct$S >= 0) && all(sweep(ct$M+ct$S,3,W,"<=")))
    check("D-count-joint-aggregation", all(joint$M_count == as.vector(apply(ct$M,c(1,2),sum))) &&
            all(joint$S_count == as.vector(apply(ct$S,c(1,2),sum))))
    set.seed(contract$paired_design$postprocess_seed)
    count_error <- 0
    for (i in seq_len(n)) for (chain in 1:4) for (j in 1:2000) {
      mx <- matrices[[chain]]; z <- mx[j,paste0("Z[",i,"]")]
      t <- mx[j,paste0("mu.tau[",i,"]")]; u <- mx[j,paste0("mu.nu[",i,"]")]
      m <- if(z==1) 0 else mx[j,paste0("mu.",if(z==2) "iota.m" else "chi.m","[",i,"]")]
      s <- if(z==1) 0 else mx[j,paste0("mu.",if(z==2) "iota.s" else "chi.s","[",i,"]")]
      q <- c(t*u,(1-t)*m,t*(1-u)*s)
      sample <- as.vector(rmultinom(1,W[i],q))
      count_error <- max(count_error, abs(ct$M[j,chain,i]-sample[2]), abs(ct$S[j,chain,i]-sample[3]))
    }
    check("D-all-conditional-draws-same-Z-and-seed", count_error == 0)
  }
  manifest <- jsonlite::read_json(file.path(processed, "manifest.json"), simplifyVector = FALSE)
  check(paste(model, "postprocess-manifest-all-hashes"), all(vapply(manifest$files,
                function(x) ad_sha(x$path) == x$sha256, logical(1))))
  err <- error_of(ad_process_draws(run_dir, data_path, contract_path, processed))
  check(paste(model, "process-refuses-overwrite"), !is.null(err), err)
}
for (model in c("A", "D")) {
  cat("SYNTHETIC MODEL FORMAT", model, "no JAGS/MCMC\n")
  synthetic <- make_payload(model)
  run_dir <- file.path(fixture_root, paste0(model, "_SYNTHETIC"))
  ad_new_dir(run_dir)
  saveRDS(synthetic$raw, file.path(run_dir, "raw_chains.rds"))
  saveRDS(synthetic$expected, file.path(run_dir, "independent_expected.rds"))
  ad_json(list(model=model, data_sha256=ad_sha(data_path), contract_sha256=ad_sha(contract_path),
               SYNTHETIC_NOT_MCMC=TRUE), file.path(run_dir, "sampling_metadata.json"))
  ad_json(list(model=model, raw_sha256=ad_sha(file.path(run_dir,"raw_chains.rds")),
               elapsed_seconds=1, status="sampled_not_diagnosed", SYNTHETIC_NOT_MCMC=TRUE),
          file.path(run_dir, "run_result.json"))
  processed <- paste0(run_dir, "_processed")
  ad_process_draws(run_dir, data_path, contract_path, processed)
  audit_outputs(model, synthetic, run_dir, processed)
}
result <- list(status="pass_common_synthetic_checks", checks=checks,
               reviewer_id=Sys.getenv("CODEX_THREAD_ID"), executor_id="019d795a-acfa-72c2-a210-d55a46c606c2",
               created_utc=format(Sys.time(),tz="UTC",usetz=TRUE), MCMC=FALSE,
               D_source_read=FALSE, payload_scope="synthetic real-format coda matrices, actual 143-row common input",
               candidate_manifest_sha256=ad_sha(file.path(base,"preflight_common01/candidate_manifest.json")))
jsonlite::write_json(result,file.path(out,"checks_common01.json"),pretty=TRUE,auto_unbox=TRUE)
cat("PASS",length(checks),"independent executable checks; synthetic payloads only\n")
print(sessionInfo())
sink()
