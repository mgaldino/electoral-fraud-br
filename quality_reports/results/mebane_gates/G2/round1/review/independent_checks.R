# Independent finite audit. No author algebra functions, package setup or MCMC.
args <- commandArgs(trailingOnly = TRUE)
out <- if (length(args)) args[1] else "quality_reports/results/mebane_gates/G2/round1/review"
stopifnot(dir.exists(out))
started <- Sys.time()
checks <- list(); measures <- list(); enumeration <- list()
record <- function(id, value, target, tolerance = 1e-10) {
  error <- max(abs(value - target))
  checks[[length(checks) + 1L]] <<- data.frame(
    id, passed = is.finite(error) && error <= tolerance, error, tolerance)
}
metric <- function(id, value) measures[[id]] <<- as.numeric(value)

source_path <- "quality_reports/results/mebane_gates/G0/round1/ef_models_3017de5.R"
expressions <- parse(source_path)
qbl_expression <- Filter(function(e) is.call(e) && identical(e[[1]],as.name("<-")) &&
                           identical(e[[2]],as.name("qbl")),as.list(expressions))
stopifnot(length(qbl_expression)==1)
isolated <- new.env(parent=baseenv())
eval(qbl_expression[[1]],isolated)
literal <- paste(readLines("quality_reports/results/mebane_gates/G0/round1/qbl_installed_3017de5.jags",warn=FALSE),collapse="\n")
record("qbl_literal_matches_fixed_commit",as.numeric(identical(trimws(isolated$qbl()),trimws(literal))),1)

# Forward transformation determinant is p1^3, verified against a numerical map.
uv_to_p <- function(uv) c(uv[1], uv[2]) / (1 + sum(uv))
for (uv in list(c(.1, .8), c(.25, .5), c(.99, .98))) {
  h <- 1e-5
  jac <- sapply(1:2, function(j) {
    delta <- numeric(2); delta[j] <- h
    (uv_to_p(uv + delta) - uv_to_p(uv - delta)) / (2 * h)
  })
  record(paste0("prior_forward_jacobian_", length(checks)), det(jac), (1 + sum(uv))^-3, 1e-9)
}
square_integral <- integrate(Vectorize(function(u) {
  integrate(function(v) 1 / (1 + u + v), 0, 1, rel.tol = 1e-11)$value
}), 0, 1, rel.tol = 1e-11)$value
record("prior_E_pi1_square_integral", square_integral, 3 * log(3) - 4 * log(2))
metric("E_pi1", square_integral)
# Integrate over pi2, then pi3; bounds encode pi1 >= pi2, pi3.
simplex_integral <- integrate(Vectorize(function(p2) {
  upper <- min(1 - 2 * p2, (1 - p2) / 2)
  integrate(function(p3) (1 - p2 - p3)^-3, 0, upper, rel.tol = 1e-11)$value
}), 0, 1/3, rel.tol = 1e-11)$value + integrate(Vectorize(function(p2) {
  integrate(function(p3) (1 - p2 - p3)^-3, 0, 1 - 2*p2, rel.tol = 1e-11)$value
}), 1/3, 1/2, rel.tol = 1e-11)$value
record("prior_simplex_normalization", simplex_integral, 1)
record("prior_largest_not_majority", integrate(function(u) 1-u, 0, 1)$value, .5)
record("prior_partial_not_total_order", as.numeric(uv_to_p(c(.2, .8))[2] > uv_to_p(c(.2, .8))[1]), 1)
record("prior_not_uniform_simplex", as.numeric(abs(.6^-3 - 6) > 1), 1)

exp_m1 <- integrate(function(v) v * 5 * exp(-5*v), 0, Inf, rel.tol=1e-12, abs.tol=1e-13)$value
exp_m2 <- integrate(function(v) v^2 * 5 * exp(-5*v), 0, Inf, rel.tol=1e-12, abs.tol=1e-13)$value
record("Exp5_mean", exp_m1, .2, 1e-9)
record("Exp5_variance", exp_m2 - exp_m1^2, .04, 1e-9)
sigma_density <- function(s) 10 * s * exp(-5*s*s)
record("sd_density_normalizes", integrate(sigma_density, 0, Inf)$value, 1, 1e-8)
record("sd_mean", integrate(function(s) s*sigma_density(s), 0, Inf)$value,
       sqrt(pi)/(2*sqrt(5)), 1e-8)
record("precision_density_normalizes", integrate(function(l) 5/l^2 * exp(-5/l), 0, Inf)$value, 1, 1e-8)
record("paper_sd_Exp5_implies_variance_008", exp_m2, .08, 1e-9)
for (x in c(0, .4, 1.2)) {
  marginal <- integrate(function(v) dnorm(x, 0, sqrt(v)) * dexp(v, 5), 0, Inf,
                        subdivisions = 1000, rel.tol = 1e-8)$value
  record(paste0("laplace_marginal_x", x), marginal, sqrt(5/2)*exp(-sqrt(10)*abs(x)), 1e-7)
}
var0 <- solve(diag(c(10000, 1, 1)))
record("intercept_precision_inverse", diag(var0), c(.0001, 1, 1))
record("collapsed_intercept_variance", 1+var0[1, 1], 1.0001)
# Gaussian convolution, independently checking the reduced prior density.
conv <- integrate(function(b) dnorm(.8-b) * dnorm(b, 0, .01), -.2, .2)$value
record("collapsed_intercept_density", conv, dnorm(.8, 0, sqrt(1.0001)), 1e-9)
record("noncentered_density_jacobian",dnorm(.3+sqrt(.17)*.8,.3,sqrt(.17))*sqrt(.17),dnorm(.8))
X <- rbind(c(1,0,0), c(1,1,0), c(1,0,1))
Sigma <- X %*% diag(c(1.0001,1,1)) %*% t(X)
contrast <- rbind(c(-1,1,0), c(0,1,-1))
record("reference_contrast_variance", diag(contrast %*% Sigma %*% t(contrast)), c(1,2))
for (bounds in list(c(0,1), c(0,.7), c(.7,1))) {
  lo <- bounds[1]; hi <- bounds[2]
  density <- function(p) dnorm(qlogis((p-lo)/(hi-lo)), .4, .8) *
    (hi-lo)/((p-lo)*(hi-p))
  record(paste0("logistic_jacobian_", lo, "_", hi),
         integrate(density, lo, hi, rel.tol = 1e-9)$value, 1, 1e-8)
}

# Literal from frozen JAGS lines 191-193, independent of executor helpers.
source_pw <- function(q, nu, m, s) {
  nu*((1-s)/(1-m))*(1-m-q) + q*((m-s)/(1-m)) + s
}
# Derivation via the reconstructed turnout t*, used only in the reduced route.
derived_pw <- function(q, nu, m, s) {
  tt <- 1-q/(1-m)
  nu*tt + m*(1-tt) + s*tt*(1-nu)
}
stan_pw <- function(q, nu, m, s) {
  denominator <- max(1e-9, 1-m)
  raw <- nu*(1-s)*(1-m-q)/denominator + q*(m-s)/denominator+s
  min(1-1e-9, max(1e-9, raw))
}
grid <- expand.grid(q = c(0, .07, .4, .91, 1), nu = c(0, .23, .5, 1),
                    m = c(0, .13, .65, .85, .999), s = c(0, .19, .8, 1))
pw <- with(grid, source_pw(q, nu, m, s))
record("pw_literal_vs_turnout_reconstruction", pw,
       with(grid, derived_pw(q,nu,m,s)), 1e-10)
record("pw_nonnegative_400_cases", as.numeric(all(pw >= -1e-11)), 1)
cvals <- with(grid, nu+(1-nu)*s)
record("physical_mean_identity", pw+grid$q, cvals+(1-cvals)*grid$q/(1-grid$m), 1e-10)
record("all_q_support_iff", as.numeric(pmax(cvals,grid$m*(1-cvals)/(1-grid$m)) <= 1+1e-10),
       as.numeric(grid$m*(2-cvals) <= 1+1e-10))
record("all_component_pa_probabilities",(1-.57)*(1-c(0,.31,.88)),c(.43,.2967,.0516))
record("paper_identity_at_mean_abstention",source_pw((1-.61)*(1-.23),.38,.23,.41),
       .61*.38+.23*(1-.61)+.41*.61*(1-.38))
record("invalid_positive_mass_parent", source_pw(1,.5,.999,0), 499.5, 1e-9)
metric("invalid_positive_mass_parent", source_pw(1,.5,.999,0))
record("continuous_incremental_raw_invalid", source_pw(.9,.1,.6,.05), 1.16875)
record("stan_clamp_changes_target", stan_pw(.9,.1,.6,.05), 1-1e-9)
record("stan_zero_becomes_positive", stan_pw(1,.5,0,0), 1e-9)
record("stan_clamp_can_hide_denominator_floor_change",
       as.numeric(abs(stan_pw(.4,.3,1-1e-12,.9) -
                        min(1-1e-9,max(1e-9,source_pw(.4,.3,1-1e-12,.9)))) > 0), 0)
# A difference before clamping is sufficient: saturated outputs may coincide.
mnear <- 1-1e-12; qnear <- (1-mnear)/2
record("stan_floor_changes_unsaturated_probability", as.numeric(
  abs(stan_pw(qnear,.3,mnear,.9)-source_pw(qnear,.3,mnear,.9)) > .01), 1)

mf <- function(r,N) ifelse(r==N,.999,r/N)
for (N in c(1,2,4,999,1000,1001)) {
  u <- .81; weights <- dbinom(0:N,N,u); val <- mf(0:N,N)
  record(paste0("atom_mean_N",N), sum(weights*val), u-.001*u^N,1e-9)
  record(paste0("atom_second_N",N), sum(weights*val^2), u^2+u*(1-u)/N-.001999*u^N,1e-9)
}
record("atom_collision_N1000", mf(999,1000), mf(1000,1000))
record("atom_decreases_N1001", as.numeric(mf(1000,1001)>mf(1001,1001)),1)

# Independent combinatorial PMF for reduced sums; full sums use R dbinom.
bern_count <- function(x,N,p) {
  if (p == 0) return(as.numeric(x==0))
  if (p == 1) return(as.numeric(x==N))
  if (!is.finite(p) || p<0 || p>1) return(0)
  factorial(N)/(factorial(x)*factorial(N-x))*p^x*(1-p)^(N-x)
}
kernel <- function(N,A,W,tau,nu,m,s, literal = FALSE) {
  pA <- (1-tau)*(1-m)
  pW <- if (literal) source_pw(A/N,nu,m,s) else derived_pw(A/N,nu,m,s)
  if (pW < -1e-10 || pW > 1+1e-10) return(0)
  # Only round numerical noise at mathematical endpoints, not invalid states.
  pW <- min(1,max(0,pW))
  if (literal) return(dbinom(A,N,pA)*dbinom(W,N,pW))
  bern_count(A,N,pA)*bern_count(W,N,pW)
}
pair <- function(N,A,W,tau,nu,mu) {
  total <- 0
  for (r in 0:N) for (s in 0:N) {
    total <- total + bern_count(r,N,mu[1])*bern_count(s,N,mu[2]) *
      kernel(N,A,W,tau,nu,mf(r,N),s/N)
  }
  total
}
full <- function(N,A,W,tau,nu,mu,mixing) {
  latents <- expand.grid(im=0:N,is=0:N,em=0:N,es=0:N)
  total <- 0
  for (row in seq_len(nrow(latents))) {
    rr <- as.numeric(latents[row,])
    weight <- prod(dbinom(rr,N,mu))
    for (z in 1:3) {
      m <- if (z==1) 0 else mf(rr[c(1,3)[z-1]],N)
      s <- if (z==1) 0 else rr[c(2,4)[z-1]]/N
      total <- total+weight*mixing[z]*kernel(N,A,W,tau,nu,m,s,literal=TRUE)
    }
  }
  total
}
configurations <- list(
  list(tau=.57,nu=.31,mu=c(.13,.62,.78,.96),pi=c(.51,.29,.20)),
  list(tau=.83,nu=.89,mu=c(.69,.03,.99,.71),pi=c(.35,.32,.33)),
  list(tau=.05,nu=.02,mu=c(.01,.67,.71,.99),pi=c(.7,.1,.2)))
for (cfg in seq_along(configurations)) {
  t <- configurations[[cfg]]
  for (N in 1:4) for (A in 0:N) for (W in 0:N) {
    components <- c(kernel(N,A,W,t$tau,t$nu,0,0),
                    pair(N,A,W,t$tau,t$nu,t$mu[1:2]),
                    pair(N,A,W,t$tau,t$nu,t$mu[3:4]))
    reduced <- sum(t$pi*components)
    brute <- full(N,A,W,t$tau,t$nu,t$mu,t$pi)
    enumeration[[length(enumeration)+1L]] <- data.frame(cfg,N,A,W,reduced,brute,error=abs(reduced-brute))
  }
}
enum <- do.call(rbind,enumeration)
record("T5_four_latents_vs_active_pair_162_cases", max(enum$error),0,1e-12)
metric("T5_max_abs_error",max(enum$error))

normalizer <- function(N,tau,nu,mu,physical) {
  total <- 0
  for (r in 0:N) for (s in 0:N) for (A in 0:N) {
    m <- mf(r,N); wprob <- derived_pw(A/N,nu,m,s/N)
    if (wprob < -1e-10 || wprob > 1+1e-10) next
    wprob <- min(1,max(0,wprob))
    total <- total + bern_count(r,N,mu[1])*bern_count(s,N,mu[2]) *
      bern_count(A,N,(1-tau)*(1-m)) * if (physical) pbinom(N-A,N,wprob) else 1
  }
  total
}
for (physical in c(FALSE,TRUE)) for (N in 1:4) {
  explicit <- 0
  for (A in 0:N) for (W in 0:N) if (!physical || A+W<=N)
    explicit <- explicit + pair(N,A,W,.61,.37,c(.81,.93))
  record(paste0("T5_CDF_normalizer_N",N,"_physical_",physical),
         normalizer(N,.61,.37,c(.81,.93),physical),explicit)
}
metric("executor_example_exact",pair(2,1,1,.6,.4,c(.2,.3)))
metric("executor_example_plugin",kernel(2,1,1,.6,.4,.2,.3))
record("executor_example_exact_value",pair(2,1,1,.6,.4,c(.2,.3)),.171900319424,1e-12)
record("plugin_not_marginalization",as.numeric(abs(pair(2,1,1,.6,.4,c(.2,.3))-
                                                  kernel(2,1,1,.6,.4,.2,.3))>.02),1)
# Stronger counterexample: m=0, so no .999/clamp/invalid-probability confounder.
stolen_exact <- sum(vapply(0:2,function(s) dbinom(s,2,.3)*dbinom(0,2,0)*
                            dbinom(1,2,.4+.6*s/2),numeric(1)))
stolen_plugin <- dbinom(1,2,.4+.6*.3)
record("plugin_failure_without_invalid_or_atom",stolen_plugin-stolen_exact,2*.6^2*.3*.7/2)
metric("clean_plugin_exact",stolen_exact); metric("clean_plugin_value",stolen_plugin)

paper_mass <- sum(vapply(0:1,function(A)sum(vapply(0:(1-A),function(W)
  dbinom(A,1,.5)*dbinom(W,1,.25),numeric(1))),numeric(1)))
jags_mass <- sum(vapply(0:2,function(A)sum(vapply(0:(2-A),function(W)
  kernel(2,A,W,.5,.5,0,0),numeric(1))),numeric(1)))
record("paper_physical_mass",paper_mass,.875)
record("JAGS_no_fraud_physical_mass",jags_mass,.96875)
record("source_invalid_normalizer_depends_on_tau",
       c(sum(vapply(0:1,function(W)kernel(1,0,W,.5,.5,.999,0),numeric(1))),
         sum(vapply(0:1,function(W)kernel(1,0,W,.8,.5,.999,0),numeric(1)))),c(.9995,.9998))
stan_square <- stan_triangle <- 0
for (A in 0:3) for (W in 0:3) {
  val <- dbinom(A,3,(1-.5)*(1-.6))*dbinom(W,3,stan_pw(A/3,.1,.6,.05))
  stan_square <- stan_square+val
  if (A+W<=3) stan_triangle <- stan_triangle+val
}
record("Stan_rectangle_mass",stan_square,1)
record("Stan_not_physical_generator",as.numeric(stan_triangle<1),1)
metric("Stan_triangle_mass_N3",stan_triangle)
Cvec <- c(1,normalizer(3,.61,.37,c(.2,.3),FALSE),normalizer(3,.61,.37,c(.81,.93),FALSE))
mix <- c(.55,.3,.15)
parts <- c(kernel(3,1,1,.61,.37,0,0),pair(3,1,1,.61,.37,c(.2,.3)),pair(3,1,1,.61,.37,c(.81,.93)))
global <- sum(mix*parts)/sum(mix*Cvec)
component <- sum(mix*parts/Cvec)
record("global_vs_component_normalization_different",as.numeric(abs(global-component)>1e-8),1)
metric("globally_normalized_likelihood",global); metric("component_normalized_likelihood",component)

# Full posterior variance: finite exact distribution, no random samples.
theta_weight <- c(.4,.6); prob <- c(.2,.8); amount <- c(10,30)
Etheta <- prob*amount
posterior_mean <- sum(theta_weight*Etheta)
between <- sum(theta_weight*(Etheta-posterior_mean)^2)
within <- sum(theta_weight*prob*(1-prob)*amount^2)
joint_weight <- c(theta_weight*(1-prob),theta_weight*prob)
joint_value <- c(0,0,amount)
full_variance <- sum(joint_weight*(joint_value-posterior_mean)^2)
record("total_variance_identity",between+within,full_variance)
metric("RB_variance",between); metric("full_variance",full_variance); metric("omitted_class_variance",within)
joint <- rbind(c(0,100),c(100,0))
record("joint_totals_not_sum_of_quantiles",as.numeric(sum(apply(joint,2,quantile,.975))!=quantile(rowSums(joint),.975)),1)
rho <- c(0,.2,1); M <- 8; S <- 3; W <- 50; R <- 30
D0 <- (W-M-S)-(R+rho*S)
record("T1_T2_fixed_opponent_bounds",range(D0),c(6,9))
record("T2_residual_blank_null_counterexample",as.numeric(D0[1]!=D0[3]),1)
invalid_origin <- c(0,1,3)
valid_obs <- 90
majority_margin0 <- W-M-S - (valid_obs-M-invalid_origin)/2
record("T1_majority_margin_bounds",range(majority_margin0),
       c(W-valid_obs/2-M/2-S,W-valid_obs/2-(M+S)/2))

write.csv(do.call(rbind,checks),file.path(out,"independent_checks.csv"),row.names=FALSE)
write.csv(data.frame(metric=names(measures),value=unlist(measures)),file.path(out,"independent_metrics.csv"),row.names=FALSE)
write.csv(enum,file.path(out,"independent_enumeration.csv"),row.names=FALSE)
writeLines(c(paste("Start UTC:",format(started,tz="UTC",usetz=TRUE)),
             paste("End UTC:",format(Sys.time(),tz="UTC",usetz=TRUE)),
             paste("Elapsed seconds:",as.numeric(difftime(Sys.time(),started,units="secs"))),
             "RNG: none. No MCMC. No author algebra code sourced.",capture.output(sessionInfo())),
           file.path(out,"independent_session.txt"))
ans <- do.call(rbind,checks)
print(ans,row.names=FALSE)
cat(sprintf("\n%d/%d checks passed; %d full/reduced enumeration cases\n",sum(ans$passed),nrow(ans),nrow(enum)))
if (!all(ans$passed)) quit(status=1)
