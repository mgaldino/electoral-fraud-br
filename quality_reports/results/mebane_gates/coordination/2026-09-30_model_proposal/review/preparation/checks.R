# Independent deterministic fixtures, not a fitted or candidate production model.
args <- commandArgs(trailingOnly = TRUE)
out <- args[1]
stopifnot(length(args) == 1L, dir.exists(out))
tol <- 1e-12
checks <- list()
add <- function(id, condition, observed = NA_real_, expected = NA_real_, note = "") {
  checks[[length(checks) + 1L]] <<- data.frame(id = id, pass = isTRUE(condition),
    observed = observed, expected = expected, note = note)
}
close_to <- function(a, b) all(is.finite(c(a, b))) && max(abs(a - b)) <= tol
simplex <- function(tau, nu, m, s) {
  c(A = (1-tau)*(1-m), W = tau*nu + (1-tau)*m + tau*(1-nu)*s,
    O = tau*(1-nu)*(1-s))
}
literal_pw <- function(N, A, nu, m, s) {
  nu*((1-s)/(1-m))*(1-m-A/N) + (A/N)*((m-s)/(1-m)) + s
}
valid_probability <- function(p) all(is.finite(p) & p >= 0 & p <= 1)
literal_table <- function(N, tau, nu, m, s) {
  tab <- expand.grid(A = 0:N, W = 0:N)
  tab$pa <- (1-tau)*(1-m)
  tab$pw <- literal_pw(N, tab$A, nu, m, s)
  tab$valid_probability <- is.finite(tab$pw) & tab$pw >= 0 & tab$pw <= 1
  tab$physical <- tab$A + tab$W <= N
  tab$kernel <- 0
  ok <- tab$valid_probability
  tab$kernel[ok] <- dbinom(tab$A[ok], N, tab$pa[ok]) *
    dbinom(tab$W[ok], N, tab$pw[ok])
  tab
}
multinomial_mass <- function(N, A, W, p) {
  stopifnot(valid_probability(p), abs(sum(p)-1) <= tol)
  O <- N-A-W
  if (O < 0) return(0)
  counts <- c(A,W,O)
  factorial(N)/prod(factorial(counts))*prod(p^counts)
}
sequential_mass <- function(N, A, W, p) {
  if (A+W > N) return(0)
  if (p[["A"]] == 1) return(as.numeric(A == N && W == 0))
  dbinom(A,N,p[["A"]])*dbinom(W,N-A,p[["W"]]/(1-p[["A"]]))
}

pw_bad <- literal_pw(1,1,.5,.999,0)
add("F1_exact_value", close_to(pw_bad,499.5), pw_bad,499.5)
add("F1_invalid_strict", !valid_probability(pw_bad), pw_bad,499.5,
    "A=1 has positive binomial parent mass .0005; no call to dbinom with invalid p")
f2 <- literal_table(2,.5,.5,0,0)
bad_mass <- f2$kernel[f2$A == 1 & f2$W == 2]
add("F2_positive_nonphysical_mass",close_to(bad_mass,1/32),bad_mass,1/32)
normalizers <- do.call(rbind,lapply(c(.2,.5,.8),function(nu) {
  t <- literal_table(2,.5,nu,0,0)
  data.frame(nu=nu, rectangle=sum(t$kernel),triangle=sum(t$kernel[t$physical]),
    exact_triangle=1-.5*.5*nu^2/2)
}))
add("literal_normalizer_parameter_dependent",length(unique(normalizers$triangle)) == 3)
add("literal_triangle_formula",close_to(normalizers$triangle,normalizers$exact_triangle))
write.csv(normalizers,file.path(out,"literal_normalizers.csv"),row.names=FALSE)

t0 <- literal_table(2,.5,.5,0,0)
t1 <- literal_table(2,.5,.5,.5,0)
C0 <- sum(t0$kernel[t0$physical]); C1 <- sum(t1$kernel[t1$physical])
Cmix <- (C0+C1)/2
global <- .5*(t0$kernel+t1$kernel)*t0$physical/Cmix
component <- .5*(t0$kernel/C0+t1$kernel/C1)*t0$physical
index <- which(t0$A == 2 & t0$W == 0)
add("component_normalizers",close_to(c(C0,C1),c(31/32,55/64)))
add("mixture_normalizer",close_to(Cmix,117/128),Cmix,117/128)
add("mixture_reweights_class_prior",close_to(.5*C0/Cmix,62/117),.5*C0/Cmix,62/117)
add("global_mixture_cell",close_to(global[index],17/117),global[index],17/117)
add("component_normalized_cell",close_to(component[index],471/3410),component[index],471/3410)
add("normalization_order_changes_model",max(abs(global-component)) > 1e-3,
    max(abs(global-component)),1e-3)
write.csv(data.frame(A=t0$A,W=t0$W,global=global,component=component),
          file.path(out,"normalization_order.csv"),row.names=FALSE)

p <- simplex(.5,.5,0,0)
paper_bad <- dbinom(1,1,p[["A"]])*dbinom(1,1,p[["W"]])
paper_triangle <- 1-paper_bad
add("paper_simplex",close_to(sum(p),1) && valid_probability(p))
add("independent_binomials_nonphysical",close_to(paper_bad,1/8),paper_bad,1/8)
conditioned_cell <- dbinom(0,1,p[["A"]])*dbinom(0,1,p[["W"]])/paper_triangle
mult_cell <- multinomial_mass(1,0,0,p)
add("conditioned_independent_is_not_multinomial",close_to(conditioned_cell,3/7) &&
      close_to(mult_cell,1/4),conditioned_cell,3/7)

grid <- expand.grid(N=1:3,tau=c(.2,.5,.8),nu=c(.2,.5,.8),
                    m=c(0,.2,.6,.999),s=c(0,.3,.8))
metrics <- vector("list",nrow(grid))
for (j in seq_len(nrow(grid))) {
  g <- grid[j,]; p <- simplex(g$tau,g$nu,g$m,g$s)
  tab <- literal_table(g$N,g$tau,g$nu,g$m,g$s)
  independent <- dbinom(tab$A,g$N,p[["A"]])*dbinom(tab$W,g$N,p[["W"]])
  multi <- mapply(function(A,W)multinomial_mass(g$N,A,W,p),tab$A,tab$W)
  seqp <- mapply(function(A,W)sequential_mass(g$N,A,W,p),tab$A,tab$W)
  C <- sum(tab$kernel[tab$physical])
  normalized <- if (is.finite(C) && C > 0) tab$kernel*tab$physical/C else rep(NA_real_,nrow(tab))
  metrics[[j]] <- data.frame(g,probabilities_valid=valid_probability(p),simplex_error=abs(sum(p)-1),
    independent_mass=sum(independent),independent_nonphysical=sum(independent[!tab$physical]),
    multinomial_mass=sum(multi),multinomial_nonphysical=sum(multi[!tab$physical]),
    sequential_max_error=max(abs(multi-seqp)),
    literal_invalid_parent_rows=sum(!tab$valid_probability),
    diagnostic_rectangle_mass=sum(tab$kernel),diagnostic_triangle_mass=C,
    normalized_mass=sum(normalized),normalized_nonphysical=sum(normalized[!tab$physical]))
}
metrics <- do.call(rbind,metrics)
add("grid_probability_support",all(metrics$probabilities_valid))
add("grid_simplex",all(metrics$simplex_error <= tol),max(metrics$simplex_error),0)
add("grid_independent_rectangle_normalized",close_to(metrics$independent_mass,rep(1,nrow(grid))))
add("grid_multinomial_triangle_normalized",close_to(metrics$multinomial_mass,rep(1,nrow(grid))))
add("grid_multinomial_physical",all(metrics$multinomial_nonphysical == 0))
add("grid_sequential_equivalence",all(metrics$sequential_max_error <= tol),max(metrics$sequential_max_error),0)
add("grid_triangle_constant_positive",all(metrics$diagnostic_triangle_mass > 0))
add("grid_normalized_kernel_sum",close_to(metrics$normalized_mass,rep(1,nrow(grid))))
add("grid_normalized_kernel_physical",all(metrics$normalized_nonphysical == 0))
write.csv(metrics,file.path(out,"grid_metrics.csv"),row.names=FALSE)

corner_parameters <- list(c(0,.5,0,0),c(1,1,0,0),c(1,0,0,0))
for (j in seq_along(corner_parameters)) {
  a <- corner_parameters[[j]]; p <- simplex(a[1],a[2],a[3],a[4])
  cells <- expand.grid(A=0:3,W=0:3)
  lhs <- mapply(function(A,W)multinomial_mass(3,A,W,p),cells$A,cells$W)
  rhs <- mapply(function(A,W)sequential_mass(3,A,W,p),cells$A,cells$W)
  add(paste0("corner_",j),close_to(lhs,rhs) && close_to(sum(lhs),1))
}

five_prob <- c(.4*.75,.4*.25,.6*.5,.6*.5/3,.6*.5*2/3)
three_prob <- simplex(.6,.5,.25,1/3)
transfer_metrics <- list()
for (N in 1:3) {
  x <- expand.grid(rep(list(0:N),5)); x <- as.matrix(x[rowSums(x)==N,])
  mass <- apply(x,1,function(count)factorial(N)/prod(factorial(count))*prod(five_prob^count))
  A <- x[,1]; M <- x[,2]; W <- rowSums(x[,2:4,drop=FALSE]); S <- x[,4]; O <- x[,5]
  obs <- expand.grid(A=0:N,W=0:N)
  observed <- mapply(function(a,w)sum(mass[A==a & W==w]),obs$A,obs$W)
  target <- mapply(function(a,w)multinomial_mass(N,a,w,three_prob),obs$A,obs$W)
  add(paste0("transfer_marginalizes_",N),close_to(observed,target))
  add(paste0("transfer_capacity_",N),all(M+S<=W) && all(A+W+O==N))
  add(paste0("transfer_expectations_",N),close_to(c(sum(mass*M),sum(mass*S)),c(.1*N,.1*N)))
  covAW <- sum(mass*A*W)-sum(mass*A)*sum(mass*W)
  add(paste0("multinomial_covariance_",N),close_to(covAW,-N*three_prob[1]*three_prob[2]),
      covAW,-N*three_prob[1]*three_prob[2])
  transfer_metrics[[N]] <- data.frame(N=N,total_mass=sum(mass),mean_M=sum(mass*M),
    mean_S=sum(mass*S),cov_A_W=covAW,max_marginal_error=max(abs(observed-target)))
}
write.csv(do.call(rbind,transfer_metrics),file.path(out,"transfer_metrics.csv"),row.names=FALSE)

p0 <- simplex(.7,5/7,0,0); p1 <- simplex(.6,.5,.25,1/3)
add("same_observable_probabilities_different_transfers",close_to(p0,p1) &&
      close_to(p0,c(.3,.5,.2)))
for (N in 1:3) {
  obs <- expand.grid(A=0:N,W=0:N)
  lhs <- mapply(function(A,W)multinomial_mass(N,A,W,p0),obs$A,obs$W)
  rhs <- mapply(function(A,W)multinomial_mass(N,A,W,p1),obs$A,obs$W)
  add(paste0("observational_equivalence_",N),close_to(lhs,rhs),max(abs(lhs-rhs)),0)
}
write.csv(data.frame(case=c("no_transfer","positive_transfer"),tau=c(.7,.6),nu=c(5/7,.5),
  m=c(0,.25),s=c(0,1/3),pA=c(p0[1],p1[1]),pW=c(p0[2],p1[2]),pO=c(p0[3],p1[3]),
  expected_M_per_N=c(0,.1),expected_S_per_N=c(0,.1)),
  file.path(out,"identification_counterexample.csv"),row.names=FALSE)
result <- do.call(rbind,checks)
write.csv(result,file.path(out,"checks.csv"),row.names=FALSE)
writeLines(capture.output(sessionInfo()),file.path(out,"session.txt"))
stopifnot(all(result$pass))
cat(nrow(result),"deterministic checks passed across",nrow(grid),"fixed-parameter grid cases. No RNG or estimation.\n")
