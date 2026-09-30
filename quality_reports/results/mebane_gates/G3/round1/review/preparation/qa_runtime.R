args <- commandArgs(trailingOnly=TRUE)
stopifnot(length(args)==4L)
protocol <- jsonlite::fromJSON(args[1],simplifyVector=FALSE)
out <- args[2]; source_path <- args[3]; index <- as.integer(args[4])
case <- protocol$runtime$cases[[index]]
stopifnot(identical(digest::digest(file=source_path,algo="sha256"),protocol$source_sha256))
stopifnot(as.character(rjags::jags.version())=="4.3.2")
`%or%` <- function(x,y)if(is.null(x))y else x
N <- case$N %or% 1
dat <- list(N=N,n=1,a=case$a %or% 1,w=case$w %or% 0,Z=case$Z,
  pi.aux1=1,pi.aux2=.4,pi.aux3=.6,
  N.iota.m=case$iota_m %or% 0,N.iota.s=0,N.chi.m=case$chi_m %or% 0,N.chi.s=0)
for(n in c("Xa","Xw","X.iota.m","X.iota.s","X.chi.m","X.chi.s"))dat[[n]]<-matrix(1,1,1)
for(n in c("dxa","dxw","dx.iota.m","dx.iota.s","dx.chi.m","dx.chi.s"))dat[[n]]<-1
for(n in c("tau","nu","iota.m","iota.s","chi.m","chi.s")) {
  dat[[paste0("beta.",n,"1")]] <- 0
  dat[[paste0(n,".alpha")]] <- 0
}
for(n in c("tb","nb","imb","isb","cmb","csb"))dat[[n]]<-.2
for(n in c("th","nh","imh","ish","cmh","csh"))dat[[n]]<-0
init <- list(.RNG.name="base::Wichmann-Hill",.RNG.seed=protocol$runtime$seed_base+index)
free <- case$free %or% character()
if(identical(free,"all_counts"))free<-c("N.iota.m","N.iota.s","N.chi.m","N.chi.s")
for(n in free) {
  dat[[n]] <- NULL
  init[[n]] <- case$init
}
omitted <- unlist(case$omit %or% character())
for(n in omitted)dat[[n]]<-NULL
if("a" %in% omitted)init$a<-0
if("w" %in% omitted)init$w<-0
saveRDS(dat,file.path(out,"data.rds")); saveRDS(init,file.path(out,"inits.rds"))
jsonlite::write_json(dat,file.path(out,"data.json"),pretty=TRUE,auto_unbox=TRUE)
jsonlite::write_json(init,file.path(out,"inits.json"),pretty=TRUE,auto_unbox=TRUE)
stage <- "compile_initialize"
warnings <- character()
result <- withCallingHandlers(tryCatch({
  model <- rjags::jags.model(file=source_path,data=dat,inits=init,n.chains=1,n.adapt=0,quiet=FALSE)
  stage <- "update"
  stats::update(model,n.iter=protocol$runtime$updates,progress.bar="none")
  stage <- "sample"
  monitors <- c("p.a","p.w","a","w","Z","N.iota.m","N.iota.s","N.chi.m","N.chi.s",
                "mu.tau","mu.nu","iota.m","iota.s","chi.m","chi.s")
  samples <- rjags::coda.samples(model,monitors,n.iter=protocol$runtime$updates,thin=1,progress.bar="none")
  saveRDS(samples,file.path(out,"samples.rds"))
  samples_matrix <- as.matrix(samples)
  write.csv(samples_matrix,file.path(out,"draws.csv"),row.names=FALSE)
  list(runtime_success=TRUE,phase="completed",error=NULL,
       physical_invalid_draws=sum(samples_matrix[,"a"]+samples_matrix[,"w"]>N),
       pW_range=range(samples_matrix[,"p.w"]),unique_Z=unique(samples_matrix[,"Z"]))
},error=function(e)list(runtime_success=FALSE,phase=stage,error=conditionMessage(e))),
warning=function(w) {warnings<<-c(warnings,conditionMessage(w));invokeRestart("muffleWarning")})
result$case <- case
result$warnings <- warnings
result$source_sha256 <- digest::digest(file=source_path,algo="sha256")
result$JAGS <- as.character(rjags::jags.version())
result$data_fixed_nodes <- names(dat)
result$free_latent_nodes <- free
result$missing_response_nodes <- omitted
result$init_nodes <- names(init)
result$scope <- "unchanged integral source, conditioned graph; no unconditional hierarchy validation; errors are preserved observations"
jsonlite::write_json(result,file.path(out,"runtime_result.json"),pretty=TRUE,auto_unbox=TRUE,digits=17,null="null")
print(result)
