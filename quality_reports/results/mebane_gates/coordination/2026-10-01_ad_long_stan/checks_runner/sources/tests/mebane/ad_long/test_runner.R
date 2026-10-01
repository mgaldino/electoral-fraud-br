source("R/experimental/mebane_ad_long/run_jags.R")
source("R/experimental/mebane_ad_long/diagnostics.R")
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 3L)
contract_path <- args[1]
data_path <- args[2]
out <- args[3]
ad_new_dir(out)
ad_snapshot(c(contract_path, data_path, "R/experimental/mebane_ad/io.R",
              "R/experimental/mebane_ad_long/run_jags.R", "R/experimental/mebane_ad_long/diagnostics.R",
              "R/experimental/mebane_ad/prepare_dc2010.R",
              "tests/mebane/ad_long/test_runner.R"), file.path(out, "sources"))
checks <- list()
check <- function(label, value) {
  checks[[length(checks) + 1L]] <<- data.frame(check = label, pass = isTRUE(value))
  if (!isTRUE(value)) stop("FAIL: ", label)
}
rejects <- function(code) inherits(tryCatch({force(code); NULL}, error = identity), "error")
contract <- jsonlite::read_json(contract_path, simplifyVector = TRUE)
payload <- readRDS(data_path)
check("actual common data match source", ad_check_payload(payload, contract))
wrong <- payload
wrong$A$a <- payload$A$w
wrong$A$w <- payload$A$a
check("swapped A responses rejected by actual runner", rejects(ad_check_payload(wrong, contract)))
wrong <- payload
wrong$D$observed <- wrong$D$observed[, c(2, 1, 3)]
check("swapped D observed columns rejected", rejects(ad_check_payload(wrong, contract)))
wrong <- payload
wrong$precinct <- rev(wrong$precinct)
check("unit permutation rejected", rejects(ad_check_payload(wrong, contract)))
check("A exact outgoing payload", identical(ad_model_data("A", payload), payload$A))
check("D exact outgoing payload", identical(ad_model_data("D", payload), payload$D))
for (model in c("A", "D")) {
  inits <- ad_initial_values(model, payload, contract)
  check(paste(model, "four initial states"), length(inits) == 4L)
  for (chain in 1:4) {
    x <- inits[[chain]]
    check(paste(model, chain, "class and RNG"),
          all(x$Z == 1L) && x$.RNG.seed == contract$paired_design$chain_seeds[chain])
    check(paste(model, chain, "six nonzero variances"), all(unlist(x[ad_v_names]) == c(.1,.2,.3,.4)[chain]))
    check(paste(model, chain, "partial pi ordering"),
          x[["pi.aux1"]] >= max(x[["pi.aux2"]], x[["pi.aux3"]]))
    tau <- plogis(x$th + x[["beta.tau1"]])
    nu <- plogis(x$nh + x[["beta.nu1"]])
    N <- payload$A$N; A <- payload$A$a; W <- payload$A$w
    lp <- if (model == "A") dbinom(A, N, 1-tau, log=TRUE) +
      dbinom(W, N, nu*(1-A/N), log=TRUE) else
      vapply(seq_along(N), function(i)
        dmultinom(c(A[i],W[i],N[i]-A[i]-W[i]),
                   prob=c(1-tau[i],tau[i]*nu[i],tau[i]*(1-nu[i])),log=TRUE), numeric(1))
    check(paste(model, chain, "finite starting observation masses"), all(is.finite(lp)))
    if (model == "A") {
      for (b in 3:6) {
        mu <- if (b < 5) .7*plogis(x[[ad_h_names[b]]]) else
          .7+.3*plogis(x[[ad_h_names[b]]])
        check(paste(model, chain, ad_blocks[b], "counts exact"),
              identical(as.numeric(x[[paste0("N.",ad_blocks[b])]]), floor(N*mu)))
      }
    }
  }
}

set.seed(930270)
balanced <- matrix(rnorm(80000), nrow=20000, ncol=4)
separated <- sweep(balanced, 2, c(-3,-1,1,3), "+")
row <- ad_diagnostic_row(separated,"separated","fixture")
check("between-chain separation detected", row$rhat > 1.1 && !row$diagnostic_pass)
sample_constant <- ad_diagnostic_row(matrix(0,20000,4),"sample_constant","fixture")
check("sample-only constant stays inconclusive", !sample_constant$diagnostic_pass &&
        sample_constant$precision_label == "inconclusive")
known_constant <- ad_diagnostic_row(matrix(0,20000,4),"analytic","fixture",analytic_constant=TRUE)
check("analytic fixture labelled separately", known_constant$precision_label == "exact_not_MC")
check("empirical contract permits no analytic exemptions", length(contract$diagnostics$analytic_exemptions_in_empirical_pilot)==0L)
check("range alone can fail finite good metrics", !ad_metric_pass(c(1,1000,1000),.051,.05))
check("range boundary inclusive", ad_metric_pass(c(1,1000,1000),.05,.05))
check("required NA cannot pass", !ad_metric_pass(c(1,1000,NA),0,.05))
check("bad adaptation is inconclusive", ad_decision(known_constant,FALSE)=="computationally_inconclusive")
check("missing run is inconclusive", ad_decision(known_constant,TRUE,FALSE)=="computationally_inconclusive")
matrices <- lapply(1:4,function(k)cbind(x=balanced[,k],`v[1]`=separated[,k]))
check("scalar node preserves chains", identical(ad_node(matrices,"x"),balanced))
check("indexed node preserves chains", identical(ad_node(matrices,"v",1),separated))
check("wrong draw shape rejected", rejects(ad_diagnostic_row(matrix(1,80000,1),"pooled","fixture")))
check("absent node rejected", rejects(ad_node(matrices,"absent")))

result <- do.call(rbind,checks)
write.csv(result,file.path(out,"checks.csv"),row.names=FALSE)
ad_json(list(status="deterministic_checks_pass",checks=nrow(result),new_MCMC=FALSE,
              contract_sha256=ad_sha(contract_path),
              executor_id="019d795a-acfa-72c2-a210-d55a46c606c2"),file.path(out,"result.json"))
ad_manifest(out,note="Runner/interface/decision fixtures; no empirical fitting")
cat("PASS",nrow(result),"runner and diagnostic checks; no MCMC\n")
