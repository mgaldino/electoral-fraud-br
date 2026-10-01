# Independent fixed-parent execution of frozen D. No unobserved stochastic node.
root <- "/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud"
base <- "quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study"
out <- file.path(root, base, "review_preflight")
.libPaths(c(file.path(root, "renv/library/macos/R-4.4/aarch64-apple-darwin20"), .libPaths()))
stopifnot(!file.exists(file.path(out, "checks_d_frozen.json")),
          !file.exists(file.path(out, "checks_d_frozen.log")))
sink(file.path(out, "checks_d_frozen.log"), split = TRUE)
setwd(file.path(out, "common01_tree"))
source("R/experimental/mebane_ad/run_jags.R")
source("R/experimental/mebane_ad/diagnostics.R")
source("R/experimental/mebane_ad/model_d.R")
checks <- list()
check <- function(id, ok, detail = NULL) {
  checks[[length(checks) + 1L]] <<- list(id = id, pass = isTRUE(ok), detail = detail)
  cat(if (isTRUE(ok)) "PASS" else "FAIL", id, "\n")
  if (!isTRUE(ok)) stop(id)
}
near <- function(x, y) max(abs(x - y)) < 1e-12
dat <- list(n = 4L, N = c(7L, 11L, 13L, 17L),
            observed = rbind(c(2L, 3L, 2L), c(5L, 4L, 2L),
                             c(1L, 9L, 3L), c(2L, 12L, 3L)),
            Z = c(1L, 2L, 3L, 2L), pi.aux1 = .8, pi.aux2 = .1, pi.aux3 = .3)
eta <- matrix(c(-1.8, -.9, .4, 1.4, .7, -.8, 1.1, -.2,
                -2, -.4, .6, 1, .3, -.7, 1.2, -.1,
                -.8, .9, -.6, .4, 1.5, -.3, .2, -.9), nrow = 4)
beta <- c(.27, -.19, .33, -.15, .22, -.31)
v <- c(.07, .13, .22, .35, .46, .59)
for (j in 1:6) {
  dat[[paste0(ad_blocks[j], ".alpha")]] <- -.3 + .1*j
  dat[[paste0("beta.", ad_blocks[j], "1")]] <- beta[j]
  dat[[ad_v_names[j]]] <- v[j]
  dat[[ad_h_names[j]]] <- eta[, j] - beta[j]
}
path <- "models/experimental/mebane_ad/d_multinomial.jags"
check("D-frozen-source-hash", ad_sha(path) ==
        "6ddb9624f60b15e196cc27ed9694852c40b6553a684a9962003168da4ecfaf5b")
jm <- rjags::jags.model(path, data = dat, n.chains = 4L, n.adapt = 0L, quiet = TRUE)
samplers <- rjags::list.samplers(jm)
check("all-stochastic-nodes-conditioned-no-samplers", length(samplers) == 0L)
raw <- rjags::coda.samples(jm, c(ad_monitors("D"), paste0(ad_blocks, ".beta")),
                           n.iter = 1L, thin = 1L, progress.bar = "none")
matrices <- lapply(raw, as.matrix)
check("native-coda-four-chains-one-deterministic-read", length(raw) == 4L &&
        all(vapply(raw, nrow, integer(1)) == 1L))
means <- plogis(eta)
means[, 3:4] <- .7 * means[, 3:4]
means[, 5:6] <- .7 + .3 * means[, 5:6]
for (j in 1:6) {
  node <- paste0("mu.", ad_blocks[j])
  got <- ad_array(matrices, node, 4L)
  check(paste0("native-extraction-", node), identical(dim(got), c(1L, 4L, 4L)) &&
          near(got, array(rep(means[, j], each = 4L), c(1L, 4L, 4L))))
  check(paste0("precision-is-inverse-variance-", ad_blocks[j]),
        near(ad_node(matrices, paste0(ad_blocks[j], ".beta")), 1/v[j]))
}
m <- c(0, means[2, 3], means[3, 5], means[4, 3])
s <- c(0, means[2, 4], means[3, 6], means[4, 4])
tau <- means[, 1]; nu <- means[, 2]
expected <- cbind((1-tau)*(1-m), tau*nu+(1-tau)*m+tau*(1-nu)*s,
                  tau*(1-nu)*(1-s))
for (j in 1:3) {
  got <- ad_array(matrices, c("p.a", "p.w", "p.o")[j], 4L)
  check(paste0("native-probability-", j), near(got, array(rep(expected[, j], each=4), c(1L,4L,4L))))
}
check("pi-partial-order-allows-third-above-second", near(ad_node(matrices, "pi", 3), .25) &&
        all(ad_node(matrices, "pi", 3) > ad_node(matrices, "pi", 2)))
for (i in 1:4) {
  check(paste0("R-loglik-independent-dmultinom-", i), near(
    ad_d_loglik_multinomial(setNames(dat$observed[i, ], c("A","W","O")), dat$N[i],
                           setNames(expected[i, ], c("A","W","O"))),
    dmultinom(dat$observed[i, ], prob = expected[i, ], log = TRUE)))
  q <- c(tau[i]*nu[i], (1-tau[i])*m[i], tau[i]*(1-nu[i])*s[i])/expected[i, 2]
  got <- ad_d_conditional_lms(dat$observed[i, 2], tau[i], nu[i], m[i], s[i])
  check(paste0("R-conditional-mean-covariance-", i),
        near(got$mean, dat$observed[i, 2]*q) &&
        near(got$covariance, dat$observed[i, 2]*(diag(q)-tcrossprod(q))))
}
ad_json(list(status = "pass", checks = checks, samplers = samplers,
             empirical_MCMC = FALSE, posterior_fit = FALSE,
             JAGS_scope = "four synthetic rows; all stochastic nodes fixed as data; one deterministic coda read per chain",
             created_utc = format(Sys.time(), tz="UTC", usetz=TRUE),
             reviewer_id = "01a0f4b8-962b-77a3-a418-6247c6219e8b",
             D_model_sha256 = ad_sha(path),
             D_helper_sha256 = ad_sha("R/experimental/mebane_ad/model_d.R")),
        file.path(out, "checks_d_frozen.json"))
cat("PASS", length(checks), "independent D checks; zero samplers; no empirical posterior\n")
sink()
