"""Validate final QA claims against preserved evidence, not gate acceptance."""
import csv
import hashlib
import json
from pathlib import Path

ROOT = Path("/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud")
BASE = ROOT / "quality_reports/results/mebane_gates/G3/round1"
QA = BASE / "review"
read = lambda p: json.loads(p.read_text())
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
report = read(QA / "review.json")
candidate = ROOT / report["candidate_manifest_path"]
assert sha(candidate) == report["candidate_manifest_sha256"]
assert sha(candidate.parent / "run.json") == report["run_sha256"]
manifest = read(candidate)
assert len(manifest["files"]) == report["input_closure"]["active_entries_verified"] == 350
assert sum(row["bytes"] for row in manifest["files"]) == report["input_closure"]["active_bytes_verified"]
for row in manifest["files"]:
    p = ROOT / row["path"]
    assert sha(p) == row["sha256"] and p.stat().st_size == row["bytes"]
assert sha(ROOT / report["source_path"]) == report["source_sha256"]
assert sha(BASE / "revision2/raw_chains.rds") == report["raw_draws_sha256"]
assert sha(QA / "review_revision2.json") == report["inherited_source_review"]["sha256"]
assert sha(QA / "review_manifest_revision2.json") == report["inherited_source_review"]["evidence_manifest_sha256"]
numeric = read(QA / "revision3_checks_02/checks.json")
documentary = read(QA / "revision3_documentary_01/checks.json")
assert numeric["failed"] == documentary["failed"] == 0
assert numeric["total"] == report["verification"]["revision3_numeric_checks_passed"] == 55
assert len(documentary["checks"]) == report["verification"]["revision3_documentary_checks_passed"] == 338
assert documentary["historical_gap_count"] == report["input_closure"]["missing_historical_source_versions"] == 7
assert report["manifest_complete"] is False and report["inputs_closed"] is False
assert report["status"] == "inconclusive" and report["production_validated"] is False
assert [f["id"] for f in report["findings"]] == ["G3-QA-R2-INPUT-01"]
assert all(x["resolved"] for x in report["resolved_findings"])
assert report["protocol_and_execution"]["new_MCMC_revision3"] == 0
with (BASE / "revision3/postprocess/conditional_comparison.csv").open() as f:
    rows = list(csv.DictReader(f))
assert sum(r["mean_pass"] == "TRUE" for r in rows) == 12
assert sum(r["ess_tail"] == "NA" and r["constant"] == "FALSE" for r in rows) == 9
assert sum(r["diagnostic_pass"] == "FALSE" for r in rows) == 9
out = {"status": "pass_consistency_only", "candidate_manifest_sha256": sha(candidate),
       "review_sha256": sha(QA / "review.json"), "review_status": report["status"],
       "candidate_entries_rehashed": 350, "numeric_checks": 55, "documentary_checks": 338,
       "manifest_complete": False, "production_validated": False,
       "open_findings": ["G3-QA-R2-INPUT-01"], "no_files_changed_outside_review": True}
with (QA / "final_consistency_checks.json").open("x", encoding="utf-8") as f:
    json.dump(out, f, ensure_ascii=False, indent=2)
    f.write("\n")
print(json.dumps(out))
