"""Preserve the first QA attempt; normalize only all-NA CSV column storage types."""
import hashlib
import json
from pathlib import Path

OUT = Path('/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/review_results')
source = OUT/'check_results.R'
old = source.read_text()
old_eq = 'eq <- function(x,y,tol=1e-10) isTRUE(all.equal(unname(x),unname(y),tolerance=tol,check.attributes=FALSE))'
new_eq = '''eq <- function(x,y,tol=1e-10) {
  if(length(x)==length(y) && all(is.na(x)) && all(is.na(y))) return(TRUE)
  isTRUE(all.equal(unname(x),unname(y),tolerance=tol,check.attributes=FALSE))
}'''
assert old.count(old_eq)==1
new = old.replace(old_eq,new_eq).replace('checks_results.log','checks_results_attempt2.log')
with (OUT/'check_results_attempt2.R').open('x') as stream:
    stream.write(new)
with (OUT/'attempt1_explanation.json').open('x') as stream:
    json.dump(dict(status='review_fixture_storage_type_error_not_candidate_finding',
                   source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                   retained_log='checks_results.log',
                   failure='A common-table-identical-source-rows',
                   cause='range_limit is entirely NA among globals/scaled rows; read.csv inferred logical in comparison CSV, numeric in full diagnostics CSV. Values and missingness coincide.',
                   repair='Only treat equal-length entirely-NA columns as semantically equal; all nonmissing comparisons unchanged.',
                   new_source='check_results_attempt2.R',candidate_modified=False),stream,indent=2)
print('Preserved attempt 1; prepared all-NA type normalization only.')
