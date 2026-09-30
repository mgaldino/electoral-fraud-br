path <- "quality_reports/results/mebane_gates/G0/round1/qbl_installed_3017de5.jags"
q <- paste(readLines(path, warn = FALSE), collapse = "\n")
has <- function(s) grepl(s, q, fixed = TRUE)
blocks <- c("tau", "nu", "iota.m", "iota.s", "chi.m", "chi.s")
checks <- c(
  pi_partial = has("pi.aux2 ~ dunif(0,pi.aux1)") &&
    has("pi.aux3 ~ dunif(0,pi.aux1)"),
  four_counts = all(vapply(c("iota.s", "iota.m", "chi.s", "chi.m"),
    function(x) has(paste0("N.",x,"[j]")) && has(paste0("mu.",x,"[j]")),logical(1))),
  endpoint = has(".999, N.iota.m[j]/N[j]") && has(".999, N.chi.m[j]/N[j]"),
  two_observations = has("a[j] ~ dbin(p.a[j],N[j])") &&
    has("w[j] ~ dbin(p.w[j],N[j])"),
  fixed_intercept_precision = all(vapply(blocks, function(x)
    has(paste0("sigma.beta.",x,"[i,j]")), logical(1))),
  alpha_and_beta0 = all(vapply(blocks, function(x)
    has(paste0(x,".alpha ~ dnorm(0,1)")) &&
    has(paste0("beta.",x,"1")), logical(1))),
  six_exp5_variances = all(vapply(c("tb","nb","imb","isb","cmb","csb"),
    function(x) has(paste0(x," ~ dexp(5)")), logical(1))),
  six_observation_effects = all(vapply(c("th","nh","imh","ish","cmh","csh"),
    function(x) has(paste0(x,"[j] ~ dnorm(")), logical(1))),
  distinct_intercepts = has("omt[j] <- inprod(Xa[j,], beta.tau1)") &&
    has("mu.tau[j] <- ilogit(th[j] + omt[j])") &&
    has("omn[j] <- inprod(Xw[j,], beta.nu1)") &&
    has("mu.nu[j]  <- ilogit(nh[j] + omn[j])"),
  weighted_pw = has("(Z[j] == 1) * ( mu.nu[j]") &&
    has("(Z[j] == 2) * ( mu.nu[j]") &&
    has("(Z[j] == 3) * ( mu.nu[j]")
)
out <- "quality_reports/results/mebane_gates/G3/round1/source_checks.csv"
write.csv(data.frame(check=names(checks),pass=unname(checks)),out,row.names=FALSE)
stopifnot(all(checks))
cat("source contract PASS:",length(checks),"checks\n")
