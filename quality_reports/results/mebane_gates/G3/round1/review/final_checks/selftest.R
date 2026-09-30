args <- commandArgs(trailingOnly=TRUE)
source(args[1])
out <- args[2]
stopifnot(!dir.exists(out));dir.create(out,recursive=TRUE)
checks <- list()
record <- function(id,pass,value=NULL)checks[[length(checks)+1L]]<<-list(id=id,pass=isTRUE(pass),value=value)
x <- matrix(rep(rep(rep(c(0,1),20),each=50),4),ncol=4)
mcse <- qa_batch_mcse(x)$mcse
record("batch_mcse_closed_form",abs(mcse-sqrt(1/624))<=1e-12,mcse)
record("constant_MCSE_is_zero",qa_batch_mcse(matrix(0,2000,4))$mcse==0)
exact <- read.csv("quality_reports/results/mebane_gates/G3/round1/review/attempt_20260929T164404110482Z_math/v2_conditioned_exact_states.csv")
target <- qa_exact_targets(exact)
for(n in colnames(target)) {
  dist <- qa_exact_distribution(target[,n],exact$probability)
  checks[[length(checks)+1L]] <- list(id=paste0("exact_support_",n),pass=TRUE,distribution=dist)
}
S <- qa_exact_distribution(target[,"S"],exact$probability)
record("S_exact_constant",S$constant && identical(S$support,0))
M <- qa_exact_distribution(target[,"M"],exact$probability)
record("M_nonconstant_but_upper_quantile_indicator_constant",!M$constant && M$q95_indicator_constant)
record("invalid_count_rejected",inherits(try(qa_targets(matrix(c(1,2,0,0,0),nrow=1,
  dimnames=list(NULL,c("Z","N.iota.m","N.iota.s","N.chi.m","N.chi.s")))),silent=TRUE),"try-error"))
record("missing_count_rejected",inherits(try(qa_targets(matrix(1,1,1,dimnames=list(NULL,"Z"))),silent=TRUE),"try-error"))
jsonlite::write_json(checks,file.path(out,"selftest_checks.json"),pretty=TRUE,auto_unbox=TRUE,digits=17)
stopifnot(all(vapply(checks,function(x)x$pass,logical(1))))
