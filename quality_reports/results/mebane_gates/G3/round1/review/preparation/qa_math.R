args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 2L)
protocol <- jsonlite::fromJSON(args[1], simplifyVector = FALSE)
out <- args[2]
tol <- protocol$tolerances$absolute
checks <- list()
check <- function(id, ok, observed = NULL) {
  checks[[length(checks) + 1L]] <<- list(id = id, pass = isTRUE(ok), observed = observed)
}
close_num <- function(x, y) abs(x-y) <= tol + protocol$tolerances$relative * abs(y)
literal <- function(x, m, s, nu) {
  nu * ((1-s)/(1-m)) * (1-m-x) + x * ((m-s)/(1-m)) + s
}
affine <- function(x, m, s, nu) nu*(1-s)+s+x*((m-s)-nu*(1-s))/(1-m)
manufactured <- function(r, N) ifelse(r == N, 0.999, r/N)
pmf <- function(x, N, p) {
  ans <- rep(0, length(p))
  valid <- is.finite(p) & p >= 0 & p <= 1
  ans[valid] <- dbinom(x, N, p[valid])
  ans
}

check("F1_pW", close_num(literal(1, .999, 0, .5), 499.5), literal(1,.999,0,.5))
check("F2_mass", close_num(dbinom(1,2,.5)*dbinom(2,2,.25), 1/32), 1/32)
outputs <- list()
joint_marginals <- list()
normalizers <- list()
for (j in seq_along(protocol$math$parameter_sets)) {
  par <- protocol$math$parameter_sets[[j]]
  q <- unlist(par$q); pi <- unlist(par$pi)
  for (N in unlist(protocol$math$N)) {
    g <- expand.grid(rm=0:N, rs=0:N, cm=0:N, cs=0:N, Z=1:3)
    g$prior <- pi[g$Z] * dbinom(g$rm,N,q[1]) * dbinom(g$rs,N,q[2]) *
      dbinom(g$cm,N,q[3]) * dbinom(g$cs,N,q[4])
    g$m <- ifelse(g$Z == 1, 0, ifelse(g$Z == 2, manufactured(g$rm,N), manufactured(g$cm,N)))
    g$s <- ifelse(g$Z == 1, 0, ifelse(g$Z == 2, g$rs/N, g$cs/N))
    g$M <- N*g$m*(1-par$tau)
    g$S <- N*g$s*par$tau*(1-par$nu)
    check(sprintf("prior_mass_%s_%s",j,N), close_num(sum(g$prior),1))
    for (A in 0:N) for (W in 0:N) {
      pA <- (1-par$tau)*(1-g$m)
      pW <- (g$Z==1)*par$nu*(1-A/N) +
        (g$Z==2)*literal(A/N,manufactured(g$rm,N),g$rs/N,par$nu) +
        (g$Z==3)*literal(A/N,manufactured(g$cm,N),g$cs/N,par$nu)
      check(sprintf("literal_affine_%s_%s_%s_%s",j,N,A,W), all(close_num(pW,affine(A/N,g$m,g$s,par$nu))))
      weight <- g$prior*dbinom(A,N,pA)*pmf(W,N,pW)
      K <- sum(weight)
      active <- expand.grid(mr=0:N,sr=0:N)
      active$m <- manufactured(active$mr,N); active$s <- active$sr/N
      reduced <- pi[1]*dbinom(A,N,1-par$tau)*dbinom(W,N,par$nu*(1-A/N))
      for (z in 2:3) {
        ii <- if (z==2) 1:2 else 3:4
        reduced <- reduced + pi[z]*sum(dbinom(active$mr,N,q[ii[1]])*
          dbinom(active$sr,N,q[ii[2]])*dbinom(A,N,(1-par$tau)*(1-active$m))*
          pmf(W,N,literal(A/N,active$m,active$s,par$nu)))
      }
      check(sprintf("full_reduced_%s_%s_%s_%s",j,N,A,W), close_num(K,reduced))
      outputs[[length(outputs)+1L]] <- data.frame(parameter_set=j,N=N,A=A,W=W,
        kernel_zero_invalid=K,physical_valid=A+W<=N,
        invalid_parent_prior_mass=sum(g$prior[!is.finite(pW)|pW<0|pW>1]))
      if (K > 0) {
        p <- weight/K
        if(j==3 && N==1 && A==0 && W==0) {
          exact <- g
          exact$probability <- p
          exact$margin_lower_algebraic <- 1-exact$M-2*exact$S
          exact$margin_upper_algebraic <- 1-exact$M-exact$S
          exact$Dobs_compatible_with_observed_W <- FALSE
          write.csv(exact,file.path(out,"v2_conditioned_exact_states.csv"),row.names=FALSE)
        }
        joint_marginals[[length(joint_marginals)+1L]] <- data.frame(parameter_set=j,N=N,A=A,W=W,
          Z1=sum(p[g$Z==1]),Z2=sum(p[g$Z==2]),Z3=sum(p[g$Z==3]),
          M=sum(p*g$M),S=sum(p*g$S),M2=sum(p*g$M^2),S2=sum(p*g$S^2),MS=sum(p*g$M*g$S))
      }
    }
  }
}
cells <- do.call(rbind, outputs)
for (j in seq_along(protocol$math$parameter_sets)) for (N in 1:3) {
  z <- cells[cells$parameter_set==j & cells$N==N,]
  normalizers[[length(normalizers)+1L]] <- data.frame(parameter_set=j,N=N,
    total_diagnostic_mass=sum(z$kernel_zero_invalid),
    physical_invalid_mass=sum(z$kernel_zero_invalid[!z$physical_valid]))
}
norms <- do.call(rbind,normalizers)
check("diagnostic_mass_not_one",all(norms$total_diagnostic_mass < 1-tol),norms)
check("diagnostic_mass_parameter_dependent",all(abs(norms$total_diagnostic_mass[1:3]-norms$total_diagnostic_mass[4:6])>tol))
check("physical_invalid_mass_positive_N2_N3",all(norms$physical_invalid_mass[norms$N>1]>0))

# Same-Z dependence cannot be replaced by two independent mixtures.
pi <- c(.5,.2,.3); m <- c(0,.5,.999); s <- c(0,.5,1)
la <- dbinom(1,2,(1-.5)*(1-m)); lw <- pmf(0,2,literal(.5,m,s,.5))
check("independent_mixtures_negative_control",abs(sum(pi*la*lw)-sum(pi*la)*sum(pi*lw))>tol,
      list(joint=sum(pi*la*lw),wrong=sum(pi*la)*sum(pi*lw)))

M <- matrix(c(0,0,.5,.5),nrow=2,byrow=TRUE)
S <- matrix(c(0,0,.25,.25),nrow=2,byrow=TRUE)
totals <- data.frame(draw=1:2,M=rowSums(M),S=rowSums(S))
totals$margin_lower <- 1-totals$M-2*totals$S
totals$margin_upper <- 1-totals$M-totals$S
totals$runner_up_capacity <- 0
totals$lower_bound_attainable <- totals$S <= totals$runner_up_capacity
check("joint_aggregation",identical(totals$M,c(0,1)) && identical(totals$S,c(0,.5)))
check("conditional_means_lose_joint_spread",var(totals$M)>0 && var(rep(sum(colMeans(M)),2))==0)
check("margin_identity",all(close_num(totals$margin_lower,totals$margin_upper-totals$S)))
check("infeasible_bound_flagged_not_clipped",!totals$lower_bound_attainable[2] && totals$margin_lower[2]==-1)
check("partial_order_allows_pi3_gt_pi2",.3>.2 && .5>=max(.2,.3))
integral <- integrate(function(p2) vapply(p2, function(b) {
  hi <- 1-b
  # pi1 is integrated first, constrained by pi1>=pi2 and pi1>=pi3.
  lower <- max(b,(1-b)/2)
  if (lower>=hi) 0 else (lower^(-2)-hi^(-2))/2
}, numeric(1)),lower=0,upper=.5,subdivisions=1000,abs.tol=1e-12)$value
check("partial_pi_density_normalizes",close_num(integral,1),integral)
write.csv(cells,file.path(out,"kernel_cells.csv"),row.names=FALSE)
write.csv(do.call(rbind,joint_marginals),file.path(out,"diagnostic_conditional_marginals.csv"),row.names=FALSE)
write.csv(norms,file.path(out,"diagnostic_mass.csv"),row.names=FALSE)
write.csv(totals,file.path(out,"joint_functionals_fixture.csv"),row.names=FALSE)
jsonlite::write_json(list(target="zero-invalid diagnostic kernel, not normalized JAGS likelihood",
  checks=checks,failed=sum(!vapply(checks,function(x)x$pass,logical(1)))),
  file.path(out,"math_checks.json"),pretty=TRUE,auto_unbox=TRUE,digits=17)
stopifnot(all(vapply(checks,function(x)x$pass,logical(1))))
