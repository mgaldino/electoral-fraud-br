# Map the same augmented D posterior into the already reviewed common diagnostics.
source("R/experimental/mebane_ad/io.R")
ad_setup()
source("R/experimental/mebane_ad_long/diagnostics_stan.R")

ad_stan_common <- function(draws) {
  stopifnot(length(dim(draws))==3L, identical(as.integer(dim(draws)[1:2]),c(2000L,4L)))
  blocks <- c("tau","nu","iota.m","iota.s","chi.m","chi.s")
  vars <- c("tb","nb","imb","isb","cmb","csb")
  names <- dimnames(draws)[[3]]
  n <- sum(grepl("^Z\\[[0-9]+\\]$",names))
  stopifnot(n==143L, !anyDuplicated(names))
  source <- c(paste0("pi[",1:3,"]"),paste0("alpha[",1:6,"]"),
              paste0("b0[",1:6,"]"),paste0("v[",1:6,"]"))
  target <- c(paste0("pi[",1:3,"]"),paste0(blocks,".alpha"),paste0("beta.",blocks,"1"),vars)
  for (b in 1:6) {
    source <- c(source,paste0("mu[",1:n,",",b,"]"))
    target <- c(target,paste0("mu.",blocks[b],"[",1:n,"]"))
  }
  for (p in c("Z","pA","pW","pO")) {
    source <- c(source,paste0(p,"[",1:n,"]"))
    tp <- switch(p,Z="Z",pA="p.a",pW="p.w",pO="p.o")
    target <- c(target,paste0(tp,"[",1:n,"]"))
  }
  stopifnot(!anyDuplicated(source),!anyDuplicated(target),all(source %in% names))
  chains <- lapply(1:4,function(k) {
    x <- unclass(draws[,k,source,drop=FALSE])
    dim(x) <- c(2000L,length(source));dimnames(x) <- list(NULL,target)
    coda::mcmc(x,start=2001,end=4000,thin=1)
  })
  coda::mcmc.list(chains)
}

ad_stan_sampler_checks <- function(draws, sampler) {
  stopifnot(identical(as.integer(dim(sampler)[1:2]),c(2000L,4L)))
  needed <- c("divergent__","treedepth__","energy__")
  stopifnot(all(needed %in% dimnames(sampler)[[3]]))
  records <- do.call(rbind,lapply(1:4,function(k) {
    energy <- sampler[,k,"energy__"]
    ebfmi <- if (var(energy)>0) mean(diff(energy)^2)/var(energy) else NA_real_
    data.frame(chain=k,divergences=sum(sampler[,k,"divergent__"]),
               treedepth_hits=sum(sampler[,k,"treedepth__"]>=12),ebfmi=ebfmi)
  }))
  internal_names <- grep("^(z\\[|r\\[)",dimnames(draws)[[3]],value=TRUE)
  stopifnot(length(internal_names)==6*143+2)
  internal <- do.call(rbind,lapply(internal_names,function(name)
    ad_diagnostic_row(as.matrix(draws[,,name]),name,"Stan_internal")))
  ok <- all(records$divergences==0 & records$treedepth_hits==0 &
              is.finite(records$ebfmi) & records$ebfmi>=.3) && all(internal$diagnostic_pass)
  list(chain_diagnostics=records,internal_diagnostics=internal,pass=isTRUE(ok))
}

ad_stan_functional_checks <- function(draws, payload) {
  n <- length(payload$D$N)
  z <- draws[,,paste0("Z[",seq_len(n),"]"),drop=FALSE]
  stopifnot(all(z %in% 1:3))
  mu <- lapply(1:6,function(b) draws[,,paste0("mu[",seq_len(n),",",b,"]"),drop=FALSE])
  m <- (z==2)*mu[[3]]+(z==3)*mu[[5]]
  s <- (z==2)*mu[[4]]+(z==3)*mu[[6]]
  M <- apply(sweep((1-mu[[1]])*m,3,payload$D$N,"*"),c(1,2),sum)
  S <- apply(sweep(mu[[1]]*(1-mu[[2]])*s,3,payload$D$N,"*"),c(1,2),sum)
  errors <- c(M=max(abs(M-draws[,,"M_total"])),S=max(abs(S-draws[,,"S_total"])))
  stopifnot(all(errors<1e-7))
  list(max_absolute_error=as.list(errors),same_Z_reconstruction=TRUE)
}
