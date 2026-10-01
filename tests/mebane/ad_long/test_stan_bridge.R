# Deterministic shape and identity fixture; no empirical model is fitted here.
source("R/experimental/mebane_ad_long/stan_bridge.R")
args <- commandArgs(trailingOnly=TRUE)
stopifnot(length(args)==1L,!file.exists(args[1]))
n <- 143L
vnames <- c(paste0("pi[",1:3,"]"),paste0("alpha[",1:6,"]"),paste0("b0[",1:6,"]"),
            paste0("v[",1:6,"]"),unlist(lapply(1:6,function(b) paste0("mu[",1:n,",",b,"]"))),
            unlist(lapply(c("Z","pA","pW","pO"),function(b) paste0(b,"[",1:n,"]"))))
x <- array(seq_len(2000*4*length(vnames)),c(2000,4,length(vnames)),dimnames=list(NULL,NULL,vnames))
mapped <- ad_stan_common(x)
stopifnot(length(mapped)==4L,all(vapply(mapped,nrow,0L)==2000L),
          identical(as.numeric(mapped[[4]][,"mu.chi.s[143]"]),as.numeric(x[,4,"mu[143,6]"])),
          identical(as.numeric(mapped[[2]][,"beta.iota.s1"]),as.numeric(x[,2,"b0[4]"])),
          identical(as.numeric(mapped[[3]][,"p.o[7]"]),as.numeric(x[,3,"pO[7]"])),
          all(vapply(mapped,function(y) identical(as.numeric(attr(y,"mcpar")),c(2001,4000,1)),TRUE)))
stopifnot(inherits(try(ad_stan_common(x[-1,,,drop=FALSE]),silent=TRUE),"try-error"))
small <- array(0,c(2000,4,7*n+2),dimnames=list(NULL,NULL,c(
  paste0("Z[",1:n,"]"),unlist(lapply(1:6,function(b) paste0("mu[",1:n,",",b,"]"))),"M_total","S_total")))
small[,,paste0("Z[",1:n,"]")] <- 2
for (b in 1:6) small[,,paste0("mu[",1:n,",",b,"]")] <- b/10
small[,,"M_total"] <- 100*n*.9*.3
small[,,"S_total"] <- 100*n*.1*.8*.4
functional <- ad_stan_functional_checks(small,list(D=list(N=rep(100,n))))
stopifnot(functional$same_Z_reconstruction)
small[1,1,"M_total"] <- small[1,1,"M_total"]+1
stopifnot(inherits(try(ad_stan_functional_checks(small,list(D=list(N=rep(100,n)))),silent=TRUE),"try-error"))
set.seed(1001261)
internals <- c(unlist(lapply(1:6,function(b) paste0("z[",1:n,",",b,"]"))),"r[1]","r[2]")
continuous <- array(rnorm(2000*4*length(internals)),c(2000,4,length(internals)),
                    dimnames=list(NULL,NULL,internals))
sampler <- array(0,c(2000,4,3),dimnames=list(NULL,NULL,c("divergent__","treedepth__","energy__")))
sampler[,,"treedepth__"] <- 5
sampler[,,"energy__"] <- matrix(rnorm(8000),2000,4)
baseline <- ad_stan_sampler_checks(continuous,sampler)
stopifnot(baseline$pass,nrow(baseline$internal_diagnostics)==860L)
sampler[1,1,"divergent__"] <- 1
stopifnot(!ad_stan_sampler_checks(continuous,sampler)$pass)
sampler[1,1,"divergent__"] <- 0
sampler[1,1,"treedepth__"] <- 12
stopifnot(!ad_stan_sampler_checks(continuous,sampler)$pass)
sampler[1,1,"treedepth__"] <- 5
sampler[,1,"energy__"] <- 1
stopifnot(!ad_stan_sampler_checks(continuous,sampler)$pass)
sampler[,1,"energy__"] <- rnorm(2000)
continuous[,1,"z[1,1]"] <- continuous[,1,"z[1,1]"]+3
stopifnot(!ad_stan_sampler_checks(continuous,sampler)$pass)
ad_json(list(status="pass",checks=c("all_chains_shape","local_column_mapping","global_column_mapping", "probability_column_mapping","MCMC_iteration_metadata","wrong_shape_rejected","joint_GQ_reconstruction","wrong_joint_GQ_rejected", "HMC_NCP_valid_fixture","divergence_rejected","treedepth_rejected","undefined_EBFMI_rejected","NCP_chain_disagreement_rejected"),empirical_sampling=FALSE),args[1])
