args<-commandArgs(trailingOnly=TRUE);out<-args[1]
stopifnot(!dir.exists(out));dir.create(out,recursive=TRUE)
base<-"quality_reports/results/mebane_gates/G3/round1"
source(file.path(base,"review/final_checks/diagnostic_helpers.R"))
p<-readRDS(file.path(base,"revision2/raw_chains.rds"))
draws<-lapply(p$draws,qa_targets)
published<-read.csv(file.path(base,"revision2/conditional_comparison.csv"))
names_map<-c(r_im="N.iota.m",r_is="N.iota.s",r_cm="N.chi.m",r_cs="N.chi.s")
rows<-list();shapes<-list()
for(i in seq_len(nrow(published))) {
  key<-published$target[i]
  if(key %in% names(names_map))key<-unname(names_map[key])
  x<-vapply(draws,function(m)m[,key],numeric(2000))
  wrapped<-posterior::as_draws_array(array(x,c(2000,4,1),dimnames=list(NULL,NULL,key)))
  split<-get(".split_chains",asNamespace("posterior"))
  shapes[[key]]<-list(matrix_dim=dim(x),draws_array_dim=dim(wrapped),coerced_array_dim=dim(as.matrix(wrapped)),
    correct_split_dim=dim(split(x)),candidate_split_dim=dim(split(wrapped)))
  if(published$constant[i])next
  calc<-function(z)c(rhat=posterior::rhat(z),bulk=posterior::ess_bulk(z),tail=posterior::ess_tail(z))
  wrong<-calc(wrapped);right<-calc(x)
  old<-unlist(published[i,c("rhat","ess_bulk","ess_tail")],use.names=FALSE)
  matched<-all((is.na(wrong)&is.na(old))|(!is.na(wrong)&!is.na(old)&abs(wrong-old)<1e-8))
  q<-quantile(x,c(.05,.95));i05<-x<=q[1];i95<-x<=q[2]
  rows[[length(rows)+1L]]<-data.frame(target=key,published_matches_pooled=matched,
    correct_rhat=right[1],pooled_rhat=wrong[1],correct_bulk=right[2],pooled_bulk=wrong[2],
    correct_tail=right[3],pooled_tail=wrong[3],
    lower_tail_indicator_constant=length(unique(as.vector(i05)))==1L,
    upper_tail_indicator_constant=length(unique(as.vector(i95)))==1L)
}
tab<-do.call(rbind,rows)
write.csv(tab,file.path(out,"shape_counterexample.csv"),row.names=FALSE)
jsonlite::write_json(list(shapes=shapes,all_published_diagnostics_match_pooled=all(tab$published_matches_pooled),
  all_correct_rhat_below_1_01=all(tab$correct_rhat<1.01),
  all_correct_bulk_above_400=all(tab$correct_bulk>=400),
  correct_tail_NA=sum(is.na(tab$correct_tail)),
  all_NA_have_constant_tail_indicator=all((tab$lower_tail_indicator_constant|tab$upper_tail_indicator_constant)[is.na(tab$correct_tail)]),
  threshold_not_relaxed=TRUE,no_new_sampling=TRUE,
  finding="rhat/ess defaults call as.matrix on draws_array, collapsing four chains into one before splitting",
  qa_note="Structural indicator constancy replaces equality-to-one floating mass in explanatory flags only; candidate data and criteria unchanged"),
  file.path(out,"counterexample.json"),pretty=TRUE,auto_unbox=TRUE,digits=17,na="null")
for(n in c("rhat.default","ess_bulk.default","ess_tail.default",".ess_quantile",".split_chains"))
  writeLines(deparse(get(n,asNamespace("posterior"))),file.path(out,paste0(n,".R")))
stopifnot(all(tab$published_matches_pooled),sum(is.na(tab$correct_tail))==9L,
  all((tab$lower_tail_indicator_constant|tab$upper_tail_indicator_constant)[is.na(tab$correct_tail)]))
