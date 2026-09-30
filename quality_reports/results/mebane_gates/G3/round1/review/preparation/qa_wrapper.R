args <- commandArgs(trailingOnly=TRUE)
stopifnot(length(args)==3L)
protocol <- jsonlite::fromJSON(args[1],simplifyVector=FALSE)
out <- args[2]; source_path <- args[3]
sentinel <- protocol$wrapper$sentinel
dat <- data.frame(N=unlist(sentinel$N),a=unlist(sentinel$a),w=unlist(sentinel$w),xw=c(-1,2),xa=c(3,-2))
capture_path <- NULL
trace("run.jags",where=asNamespace("runjags"),print=FALSE,tracer=quote({
  saveRDS(list(data=data,model=model,monitor=monitor),get("capture_path",envir=.GlobalEnv))
  stop("QA_CAPTURE_NO_SAMPLING")
}))
results <- list()
for (i in 1:3) {
  capture_path <- file.path(out,paste0("wrapper_payload_",i,".rds"))
  f1 <- if(i==2) a~1 else if(i==3) w~xw else w~1
  f2 <- if(i==2) w~1 else if(i==3) a~xa else a~1
  error <- tryCatch({eforensics::eforensics(formula1=f1,formula2=f2,data=dat,
    eligible.voters="N",mcmc=list(n.chains=1,n.iter=1,burn.in=0,n.adapt=0),
    parameters="pi",autoConv=FALSE,parComp=FALSE,get.dic=0);NA_character_},error=conditionMessage)
  ok <- file.exists(capture_path)
  payload <- if(ok)readRDS(capture_path) else NULL
  ordered <- ok && identical(as.numeric(payload$data$a),dat$a) && identical(as.numeric(payload$data$w),dat$w)
  if(ok) jsonlite::write_json(payload$data,file.path(out,paste0("wrapper_data_",i,".json")),pretty=TRUE,auto_unbox=TRUE)
  design_ok <- if(!ok)FALSE else if(i==3) {
    isTRUE(all.equal(unname(payload$data$Xw),unname(model.matrix(~xw,dat)))) &&
      isTRUE(all.equal(unname(payload$data$Xa),unname(model.matrix(~xa,dat))))
  } else all(vapply(payload$data[c("Xw","Xa","X.iota.m","X.iota.s","X.chi.m","X.chi.s")],
                    function(x)identical(dim(x),c(2L,1L)) && all(x==1),logical(1)))
  results[[i]] <- list(case=i,captured_engine_boundary=ok,error=error,response_order_correct=ordered,
    expected_negative_control=i==2,design_correct=design_ok,
    pass=ok && design_ok && identical(ordered,i!=2) && identical(error,"QA_CAPTURE_NO_SAMPLING"))
}
source_env <- new.env(parent=asNamespace("eforensics"))
sys.source(source_path,envir=source_env)
for(n in c("eforensics","eforensics_main_par","getRegMatrix")) {
  installed <- get(n,asNamespace("eforensics"))
  saved <- get(n,source_env)
  results[[length(results)+1L]] <- list(case=paste0("source_body_",n),
    pass=identical(body(installed),body(saved)) && identical(formals(installed),formals(saved)))
}
direct <- list(w=dat$w,a=dat$a,N=dat$N,n=2L)
for(n in c("Xa","Xw","X.iota.m","X.iota.s","X.chi.m","X.chi.s"))direct[[n]]<-matrix(1,2,1)
for(n in c("dxa","dxw","dx.iota.m","dx.iota.s","dx.chi.m","dx.chi.s"))direct[[n]]<-1L
positive <- readRDS(file.path(out,"wrapper_payload_1.rds"))$data
equal <- all(vapply(names(direct),function(n)isTRUE(all.equal(unname(direct[[n]]),unname(positive[[n]]))),logical(1)))
results[[length(results)+1L]] <- list(case="independent_direct_list",pass=equal,
  scope="independent fixture; candidate adapter not yet reviewed")
saveRDS(direct,file.path(out,"direct_data.rds"))
jsonlite::write_json(results,file.path(out,"wrapper_checks.json"),pretty=TRUE,auto_unbox=TRUE)
stopifnot(all(vapply(results,function(x)x$pass,logical(1))))
