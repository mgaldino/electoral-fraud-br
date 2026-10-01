# Adjudicate the independent preflight without changing any frozen sources.
source("R/experimental/mebane_ad/io.R")
ad_setup()
root <- "quality_reports/results/mebane_gates/coordination/2026-10-01_ad_long_stan"
review_path <- file.path(root,"review/stan/review.json")
r <- jsonlite::read_json(review_path,simplifyVector=FALSE)
stopifnot(r$status=="PASS",length(r$findings)==0L,r$blocking_findings_count==0L,
          r$reviewer_id!=r$candidate_executor_id,r$reviewer_id!=r$coordinator_id,
          ad_sha(r$preparation_manifest)==r$preparation_manifest_sha256,
          ad_sha(r$adapter_manifest)==r$adapter_manifest_sha256)
for(path in c(r$preparation_manifest,r$adapter_manifest)) {
  manifest <- jsonlite::read_json(path,simplifyVector=FALSE)
  for(f in manifest$files) {
    stopifnot(ad_sha(f$path)==f$sha256)
    if(!is.null(f$snapshot)) stopifnot(ad_sha(f$snapshot)==f$sha256)
  }
}
for(f in r$evidence)stopifnot(ad_sha(file.path(dirname(review_path),f$path))==f$sha256)
ad_json(list(status="approved_for_one_Stan_D_2k_round",review_path=review_path,
             review_sha256=ad_sha(review_path),reviewer_id=r$reviewer_id,
             preparation_manifest_sha256=r$preparation_manifest_sha256,
             adapter_manifest_sha256=r$adapter_manifest_sha256,
             findings_received=0L,blocking_findings=0L,
             own_checker_issue="Independent near() assertion rejected expected NA; scoped recheck confirmed correct candidate output and unchanged thresholds",
             posterior_precision_not_yet_observed=TRUE,production_approved=FALSE,
             authorization="User request for JAGS20k and exact D Stan2k, same approved case; no new authorization required for this bounded sampling phase",
             retries=0L),file.path(root,"stan_adjudication.json"))
