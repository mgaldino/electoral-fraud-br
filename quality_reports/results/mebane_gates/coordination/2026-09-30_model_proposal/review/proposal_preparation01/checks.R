# Independent ordered-microstate and literal-kernel checks. No candidate code.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 1L, dir.exists(args[1]))
out <- args[1]
tol <- 1e-12
checks <- list()
check <- function(id, ok, value = NA_real_) {
  checks[[length(checks) + 1L]] <<- data.frame(id, pass = isTRUE(ok), value)
}
pmf <- function(n, p) {
  stopifnot(all(is.finite(p)), all(p >= 0), all(p <= 1),
            abs(sum(p) - 1) < tol, all(n >= 0), all(n == as.integer(n)))
  if (any(p == 0 & n > 0)) return(0)
  exp(lgamma(sum(n) + 1) - sum(lgamma(n + 1)) +
        sum(n[p > 0] * log(p[p > 0])))
}
cells <- function(t, v, m, s) c((1-t)*(1-m), t*v, (1-t)*m,
                                t*(1-v)*s, t*(1-v)*(1-s))
grid <- expand.grid(t = c(0, .37, 1), v = c(0, .61, 1),
                    m = c(0, .23, 1), s = c(0, .41, 1))
grid <- rbind(grid, c(.6,.4,.2,.3), c(.5,.5,.999,0), c(.6,.5,.25,1/3))
metrics <- list()
for (N in 1:4) {
  micro <- as.matrix(expand.grid(rep(list(1:5), N)))
  A <- rowSums(micro == 1)
  L <- rowSums(micro == 2)
  M <- rowSums(micro == 3)
  S <- rowSums(micro == 4)
  O <- rowSums(micro == 5)
  W <- L+M+S
  check(paste0("reservoirs_N", N), all(A+W+O == N & M <= A+M &
        S <= O+S & M+S <= W))
  for (g in seq_len(nrow(grid))) {
    q <- do.call(cells, as.list(grid[g,]))
    stopifnot(all(is.finite(q)), all(q >= 0), all(q <= 1), abs(sum(q)-1) < tol)
    p <- c(q[1], sum(q[2:4]), q[5])
    mass <- apply(matrix(q[micro], ncol=N), 1, prod)
    errs <- c(observed=0, sequential=0, conditional_joint=0,
              joint_functional=0, marginal_A=0, marginal_W=0)
    for (a in 0:N) for (w in 0:(N-a)) {
      observed <- pmf(c(a,w,N-a-w), p)
      mask <- A == a & W == w
      rec <- sum(mass[mask])
      errs["observed"] <- max(errs["observed"], abs(rec-observed))
      seqmass <- if (p[2]+p[3] == 0) as.numeric(a == N && w == 0) else
        dbinom(a,N,p[1])*dbinom(w,N-a,p[2]/(p[2]+p[3]))
      errs["sequential"] <- max(errs["sequential"],abs(seqmass-observed))
      if (observed > 0 && p[2] > 0) {
        for (m in 0:w) for (s in 0:(w-m)) {
          split <- pmf(c(w-m-s,m,s), q[2:4]/p[2])
          conditional <- sum(mass[mask & M == m & S == s])/rec
          errs["conditional_joint"] <- max(errs["conditional_joint"],abs(split-conditional))
        }
        for (f in 0:w) {
          functional <- sum(mass[mask & M+S == f])/rec
          errs["joint_functional"] <- max(errs["joint_functional"],
            abs(functional-dbinom(f,w,sum(q[3:4])/p[2])))
        }
      }
    }
    for (x in 0:N) {
      errs["marginal_A"] <- max(errs["marginal_A"],abs(sum(mass[A == x])-dbinom(x,N,p[1])))
      errs["marginal_W"] <- max(errs["marginal_W"],abs(sum(mass[W == x])-dbinom(x,N,p[2])))
    }
    covariance <- sum(mass*A*W)-sum(mass*A)*sum(mass*W)
    metrics[[length(metrics)+1L]] <- data.frame(N=N,grid=g,grid[g,],
      total=sum(mass),t(errs),covariance_error=abs(covariance+N*p[1]*p[2]))
  }
}
metrics <- do.call(rbind, metrics)
write.csv(metrics,file.path(out,"microstate_metrics.csv"),row.names=FALSE)
check("336_distributions",nrow(metrics) == 336,nrow(metrics))
check("mass_normalized",max(abs(metrics$total-1)) < tol,max(abs(metrics$total-1)))
for (name in names(metrics)[8:ncol(metrics)])
  check(paste0("microstate_",name),max(metrics[[name]]) < tol,max(metrics[[name]]))

# Four-count literal kernel, including inactive factors, at fixed parameters.
N <- 2
t <- .6
v <- .4
mus <- c(.2,.3,.8,.9)
weights <- c(.6,.25,.15)
rs <- as.matrix(expand.grid(rep(list(0:N),4)))
base <- apply(rs,1,function(r) prod(dbinom(r,N,mus)))
obs <- subset(expand.grid(a=0:N,w=0:N), a+w <= N)
K <- array(0,dim=c(nrow(obs),nrow(rs),3))
invalid <- 0L
for (z in 1:3) for (r in seq_len(nrow(rs))) {
  m <- if (z == 1) 0 else rs[r,2*z-3]/N
  s <- if (z == 1) 0 else rs[r,2*z-2]/N
  if (m == 1) m <- .999 # Exact transformation in the source, not a QA clamp.
  for (i in seq_len(nrow(obs))) {
    a <- obs$a[i]
    w <- obs$w[i]
    pa <- (1-t)*(1-m)
    pw <- if (z == 1) v*(1-a/N) else
      v*((1-s)/(1-m))*(1-m-a/N)+(a/N)*((m-s)/(1-m))+s
    valid <- is.finite(pa) && is.finite(pw) && pa >= 0 && pa <= 1 && pw >= 0 && pw <= 1
    if (!valid) { invalid <- invalid+1L; next }
    K[i,r,z] <- base[r]*dbinom(a,N,pa)*dbinom(w,N,pw)
  }
}
C <- apply(K,3,sum)
Rprior <- apply(K,c(2,3),sum)
Rprior <- sweep(Rprior,2,C,"/")
conditional_C <- sweep(apply(K,c(2,3),sum),1,base,"/")
check("literal_positive_C",all(C > 0 & C <= 1))
check("strict_invalid_states_zeroed",invalid > 0,invalid)
check("active_R_prior_changed",max(abs(Rprior[,2]-base)) > 1e-3,
      max(abs(Rprior[,2]-base)))
check("inactive_R_keeps_marginal",max(abs(vapply(0:N,function(x)
  sum(Rprior[rs[,3] == x,2]),numeric(1))-dbinom(0:N,N,mus[3]))) < tol)
norm_component <- sweep(K,3,C,"/")
global_class <- weights*C/sum(weights*C)
check("component_pi_preserved",max(abs(weights*apply(norm_component,3,sum)-weights)) < tol)
check("global_pi_changed",max(abs(global_class-weights)) > 1e-3,max(abs(global_class-weights)))
per_R <- K
for (z in 1:3) for (r in seq_len(nrow(rs)))
  per_R[,r,z] <- if (conditional_C[r,z] > 0) K[,r,z]/conditional_C[r,z] else 0
check("per_R_normalization_retains_base",max(abs(apply(per_R,c(2,3),sum)-base)) < tol)
check("per_R_distinct_from_component",max(abs(per_R-norm_component)) > 1e-3,
      max(abs(per_R-norm_component)))
write.csv(data.frame(z=1:3,C=C,pi=weights,pi_global=global_class),
          file.path(out,"literal_normalization.csv"),row.names=FALSE)
write.csv(data.frame(rs,prior=base,induced_z1=Rprior[,1],induced_z2=Rprior[,2],
                    induced_z3=Rprior[,3],C_z2_given_R=conditional_C[,2]),
          file.path(out,"induced_R.csv"),row.names=FALSE)

# Posterior class probabilities must incorporate the observed likelihood.
pars <- rbind(c(.6,.4,0,0),c(.6,.4,.2,.3),c(.6,.4,.8,.9))
lik <- apply(pars,1,function(x) {q <- do.call(cells,as.list(x)); pmf(c(0,2,0),c(q[1],sum(q[2:4]),q[5]))})
posterior <- weights*lik/sum(weights*lik)
check("posterior_class_not_prior",max(abs(posterior-weights)) > .1,max(abs(posterior-weights)))
write.csv(data.frame(z=1:3,prior=weights,likelihood=lik,posterior=posterior),
          file.path(out,"posterior_classes.csv"),row.names=FALSE)

q <- cells(.6,.4,.2,.3)
p <- c(q[1],sum(q[2:4]),q[5])
q0 <- cells(1-p[1],p[2]/(1-p[1]),0,0)
check("same_observables_different_transfers",max(abs(p-c(q0[1],q0[2],q0[5]))) < tol && sum(q[3:4]) > 0)
check("boundary_cancellation_not_valid_probability",.2/(1-.8) > 1)
check("stable_positive_sum",.2/(.2+0) == 1)
rows <- do.call(rbind,checks)
write.csv(rows,file.path(out,"checks.csv"),row.names=FALSE)
writeLines(capture.output(sessionInfo()),file.path(out,"sessionInfo.txt"))
print(rows)
stopifnot(all(rows$pass))
