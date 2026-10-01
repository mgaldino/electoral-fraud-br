"""Verify the completed review against its evidence and seal the delivered review files."""
import hashlib
import json
from pathlib import Path

ROOT = Path.cwd().resolve()
NEW = Path("quality_reports/results/mebane_gates/coordination/2026-10-01_ad_long_stan")
SCOPE = NEW / "review_stan_results"
assert Path(__file__).resolve().parent == ROOT / SCOPE


def read(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def sha(path):
    h = hashlib.sha256()
    with (ROOT / path).open("rb") as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


review = read(SCOPE / "review.json")
evidence = read(SCOPE / "final_evidence.json")
summary = read(SCOPE / "attempt02/recomputed_summary.json")
assert review["status"] == evidence["status"] == "pass"
assert review["requested_review_scope_completed"] and not review["findings"]
assert review["candidate"]["sha256"] == evidence["candidate_sha256"] == sha(NEW / "results_candidate_manifest.json")
for path, expected in review["candidate"]["input_hashes_relative_to_NEW"].items():
    assert sha(NEW / path) == expected, path
assert sha(SCOPE / review["evidence"]["manifest"]) == review["evidence"]["manifest_sha256"]
for entry in evidence["evidence"]:
    assert sha(Path(entry["path"])) == entry["sha256"], entry["path"]
for left, right in (("global_failed", "global_failed_count"), ("NCP_failed", "internal_failed"),
                    ("common_failed", "common_failed"), ("common_undefined_subset_failed", "common_undefined_subset_failed"),
                    ("status_confirmed", "status_confirmed"), ("HMC_pass", "HMC_pass")):
    assert review["checks"][left] == summary[right], left
assert review["checks"]["global_failed_names"] == summary["global_failed"]
assert review["checks"]["numerical_assertions_passed"] == evidence["numerical_assertions"]
assert review["checks"]["delivery_named_checks_passed"] == evidence["delivery_named_checks"]
assert review["timing"]["Stan_productive_total_seconds"] == evidence["productive_Stan_total_seconds"]
assert review["timing"]["failed_diagnostic01_seconds_excluded_and_disclosed"] == evidence["failed_diagnostic_seconds_excluded"]
visual = read(SCOPE / "visual_checks01/visual_review.json")
assert visual["status"] == "pass" and visual["pages_inspected"] == [1, 2, 3, 4]
files = [SCOPE / name for name in ("review.json", "review.md", "README.md", "final_evidence.json", "verify_review.py")]
record = {"status": "pass", "reviewer_id": review["reviewer_id"],
          "review_consistency_verified": True, "requested_scope_completed": True,
          "files": [{"path": str(path), "sha256": sha(path)} for path in files]}
with (ROOT / SCOPE / "review_delivery_manifest.json").open("x", encoding="utf-8") as stream:
    json.dump(record, stream, ensure_ascii=False, indent=2)
    stream.write("\n")
print(json.dumps(record, indent=2))
