out <- commandArgs(trailingOnly=TRUE)[1]
base <- "quality_reports/results/mebane_gates/G3/round1/review"
old <- file.path(base,"attempt_20260929T164413891477Z_wrapper")
sentinel <- jsonlite::fromJSON(file.path(base,"preparation/protocol.json"))$wrapper$sentinel
checks <- list()
for(i in 1:3) {
  payload <- readRDS(file.path(old,paste0("wrapper_payload_",i,".rds")))
  ordered <- identical(as.numeric(payload$data$a),as.numeric(sentinel$a)) &&
    identical(as.numeric(payload$data$w),as.numeric(sentinel$w))
  design <- if(i==3) identical(as.numeric(payload$data$Xw),c(1,1,-1,2)) &&
    identical(as.numeric(payload$data$Xa),c(1,1,3,-2)) &&
    identical(dim(payload$data$Xw),c(2L,2L)) && identical(dim(payload$data$Xa),c(2L,2L)) else
    all(vapply(payload$data[c("Xa","Xw","X.iota.m","X.iota.s","X.chi.m","X.chi.s")],
      function(x)identical(dim(x),c(2L,1L)) && identical(as.numeric(x),c(1,1)),logical(1)))
  checks[[length(checks)+1L]] <- list(case=i,pass=identical(ordered,i!=2) && design,
    response_order_correct=ordered,design_correct=design,source_attempt=old)
}
e <- new.env(parent=asNamespace("eforensics"))
sys.source("quality_reports/results/mebane_gates/G2/round2/sources/ef_main_3017de5.R",envir=e)
for(n in c("eforensics","eforensics_main_par","getRegMatrix")) {
  installed <- get(n,asNamespace("eforensics")); saved <- get(n,e)
  left <- deparse(body(installed)); right <- deparse(body(saved))
  writeLines(c(paste0("# Installed AST: ",n),left),file.path(out,paste0(n,"_installed_ast.R")))
  writeLines(c(paste0("# Archived AST: ",n),right),file.path(out,paste0(n,"_archived_ast.R")))
  checks[[length(checks)+1L]] <- list(case=paste0("source_body_",n),pass=identical(left,right) &&
    identical(deparse(formals(installed)),deparse(formals(saved))))
}
direct <- readRDS(file.path(old,"direct_data.rds"))
actual <- readRDS(file.path(old,"wrapper_payload_1.rds"))$data
checks[[length(checks)+1L]] <- list(case="direct_data",pass=all(vapply(names(direct),function(n)
  identical(as.numeric(direct[[n]]),as.numeric(actual[[n]])) && identical(dim(direct[[n]]),dim(actual[[n]])),logical(1))))
jsonlite::write_json(checks,file.path(out,"wrapper_checks.json"),pretty=TRUE,auto_unbox=TRUE)
left <- integrate(function(b)1.5/(1-b)^2,0,1/3,abs.tol=1e-12,rel.tol=1e-12)
right <- integrate(function(b).5/b^2-.5/(1-b)^2,1/3,.5,abs.tol=1e-12,rel.tol=1e-12)
integral <- left$value+right$value
math_checks <- list(left_mass=left$value,right_mass=right$value,total=integral,
  exact_left=3/4,exact_right=1/4,
  pass=abs(left$value-3/4)<=1e-12 && abs(right$value-1/4)<=1e-12 && abs(integral-1)<=1e-12,
  error_bound_reported=left$abs.error+right$abs.error)
exact <- read.csv(file.path(base,"attempt_20260929T164404110482Z_math/v2_conditioned_exact_states.csv"))
math_checks$S_support_exact <- sort(unique(exact$S[exact$probability>0]))
math_checks$S_is_analytically_constant <- all(exact$S[exact$probability>0]==0)
math_checks$proof <- "A=0 implies pW=(1+s)/2; active s=1 implies pW=1 and hence likelihood W=0 is zero; Z=1 always S=0"
jsonlite::write_json(math_checks,file.path(out,"repaired_math_checks.json"),pretty=TRUE,auto_unbox=TRUE,digits=17)
stopifnot(all(vapply(checks,function(x)x$pass,logical(1))),math_checks$pass,math_checks$S_is_analytically_constant)
