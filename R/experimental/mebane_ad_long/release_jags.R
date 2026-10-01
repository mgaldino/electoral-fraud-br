# Bind the independent delta review to exactly the candidate the supervisor uses.
source("R/experimental/mebane_ad/io.R")
ad_setup()
root <- "quality_reports/results/mebane_gates/coordination/2026-10-01_ad_long_stan"
candidate_path <- file.path(root,"jags_candidate/manifest.json")
review_path <- file.path(root,"review/JAGS_preflight.json")
candidate <- jsonlite::read_json(candidate_path,simplifyVector=FALSE)
review <- jsonlite::read_json(review_path,simplifyVector=FALSE)
stopifnot(review$status=="pass",review$blocking_findings==0L,
          review$executor_id!=review$reviewer_id,
          review$candidate_manifest_sha256==ad_sha(candidate_path))
for (f in candidate$files) stopifnot(ad_sha(f$path)==f$sha256,ad_sha(f$snapshot)==f$sha256)
adjudication_path <- file.path(root,"jags_adjudication.json")
ad_json(list(status="accepted_scoped_preflight",review_sha256=ad_sha(review_path),
             candidate_manifest_sha256=ad_sha(candidate_path),
             findings_received=0L,blocking_findings=0L,
             decision="One new A/D JAGS round, 20k retained per chain, authorized by the user",
             evidence="Source delta, frozen hash inventory, prospective settings and independently repeated fixture evidence inspected",
             runtime_and_precision_not_yet_observed=TRUE,Stan_approved=FALSE,
             production_approved=FALSE),adjudication_path)
extra <- c(candidate_path,review_path,adjudication_path)
files <- c(lapply(candidate$files,function(f) list(path=f$path,sha256=f$sha256)),
           lapply(extra,function(p) list(path=p,sha256=ad_sha(p))))
ad_json(list(status="approved_for_JAGS20k",files=files,
             contract_path=file.path(root,"contract.json"),
             data_path="quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/data/run-20260930T235038Z-pid61600/dc2010_ad_data.rds",
             retries=0L,old_study_unchanged=TRUE),file.path(root,"jags_release.json"))
