"""Seal one QA delivery without changing candidate files or previous reviews."""
import datetime
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path("/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud")
QA = ROOT / "quality_reports/results/mebane_gates/G3/round1/review"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def path_in_root(value):
    p = (ROOT / value).resolve()
    assert p.is_relative_to(ROOT), value
    return p


def entry(path, role):
    return {"path": str(path.relative_to(ROOT)), "sha256": digest(path),
            "bytes": path.stat().st_size, "role": role}


def write_new(path, payload):
    assert path.is_relative_to(QA)
    with path.open("x", encoding="utf-8") as stream:
        json.dump(payload, stream, ensure_ascii=False, indent=2, allow_nan=False)
        stream.write("\n")


report_path = path_in_root(sys.argv[1])
assert report_path.parent == QA
report = json.loads(report_path.read_text())
manifest_path = QA / report["review_manifest"]
validation_path = manifest_path.with_name(manifest_path.stem + "_validation.json")
assert not manifest_path.exists() and not validation_path.exists()
candidate_path = path_in_root(report["candidate_manifest_path"])
assert digest(candidate_path) == report["candidate_manifest_sha256"]
candidate = json.loads(candidate_path.read_text())
assert report["status"] in {"pass", "changes_requested", "inconclusive"}
assert report["gate_id"] == "G3" and report["round"] == "round1"
assert report["contract_sha256"] == candidate["contract_sha256"]
assert report["reviewer_id"] != report["executor_id"]
assert not report["participated_in_implementation"]
assert not report["production_validated"]

inputs = {candidate_path: "candidate_identity"}
by_hash = {}
for item in candidate["files"]:
    p = path_in_root(item["path"])
    if p.is_file():
        by_hash.setdefault((digest(p), p.stat().st_size), []).append(p)
candidate_preservation = []
for item in candidate["files"]:
    p = path_in_root(item["path"])
    intact = p.is_file() and digest(p) == item["sha256"] and p.stat().st_size == item["bytes"]
    matches = [p] if intact else by_hash.get((item["sha256"], item["bytes"]), [])
    assert matches, f"No preserved bytes for {item['path']}"
    preserved = matches[0]
    inputs[preserved] = "candidate_frozen_input_or_output"
    candidate_preservation.append({"declared_path": item["path"],
        "expected_sha256": item["sha256"], "original_path_intact": intact,
        "verified_path": str(preserved.relative_to(ROOT))})

coord = ROOT / "quality_reports/results/mebane_gates/coordination/2026-09-29_g3_runtime"
for name in ("diagnostic_shape_adjudication.json", "diagnostic_shape_adjudication.md"):
    p = coord / name
    if p.is_file():
        inputs[p] = "coordination_scope_not_independent_evidence"
for p in QA.rglob("*"):
    if p.is_file() and p not in {manifest_path, validation_path}:
        inputs[p] = "independent_qa_artifact"
inputs[report_path] = "primary_qa_review"
md_path = report_path.with_suffix(".md")
assert md_path.is_file()
inputs[md_path] = "primary_qa_review"

files = [entry(p, role) for p, role in sorted(inputs.items(), key=lambda it: str(it[0]))]
result = {"schema_version": "1.0", "gate_id": "G3", "round": "round1",
    "candidate_revision": report["candidate_revision"], "review_id": report["review_id"],
    "reviewer_id": report["reviewer_id"], "executor_id": report["executor_id"],
    "candidate_manifest_sha256": report["candidate_manifest_sha256"],
    "contract_sha256": report["contract_sha256"],
    "review_path": str(report_path.relative_to(ROOT)), "review_sha256": digest(report_path),
    "candidate_manifest_complete": report["manifest_complete"],
    "candidate_preservation": candidate_preservation,
    "qa_evidence_inventory_complete_for_this_delivery": True,
    "self_reference_policy": "This manifest and its subsequent validation receipt are excluded. All other QA artifacts existing at seal time are inventoried. QA authorship is not attributed to the candidate executor.",
    "sealed_at_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "files": files}
write_new(manifest_path, result)
for item in files:
    p = path_in_root(item["path"])
    assert digest(p) == item["sha256"] and p.stat().st_size == item["bytes"]
write_new(validation_path, {"status": "pass_inventory_validation_only",
    "manifest_sha256": digest(manifest_path), "review_sha256": digest(report_path),
    "files_verified": len(files), "candidate_entries_preserved": len(candidate_preservation),
    "candidate_remapped_entries": sum(not x["original_path_intact"] for x in candidate_preservation),
    "review_status": report["status"], "candidate_manifest_complete": report["manifest_complete"],
    "production_validated": False})
print(json.dumps({"manifest": str(manifest_path.relative_to(ROOT)),
    "sha256": digest(manifest_path), "files_verified": len(files),
    "review_sha256": digest(report_path), "review_status": report["status"]}))
