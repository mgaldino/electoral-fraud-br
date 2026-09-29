#!/usr/bin/env python3
"""Seal already completed bounded checks without rerunning the audit."""
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[5]


def record(path):
    data = path.read_bytes()
    return {"path": path.relative_to(ROOT).as_posix(), "bytes": len(data),
            "sha256": hashlib.sha256(data).hexdigest()}


review = json.loads((HERE / "review.json").read_text())
checks = json.loads((HERE / "checks.json").read_text())
assert checks["failed_checks"] == [] and len(checks["checks"]) == 20
assert review["status"] == "pass" and review["manifest_complete"] is True
assert review["findings"] == [] and len(checks["file_checks"]) == 186
assert all(item["passed"] for item in checks["file_checks"])
assert len((HERE / "review.md").read_text().split()) <= 250
candidate = record(HERE.parent / "candidate_manifest.json")
assert candidate["sha256"] == review["candidate_manifest_sha256"]
assert record(HERE.parent / "construction_input.json")["sha256"] == review["construction_input_sha256"]
assert record(HERE.parent / "run.json")["sha256"] == review["run_sha256"]
files = [record(p) for p in sorted(HERE.iterdir()) if p.is_file()]
seal = {
    "schema_version": "1.0", "gate_id": "G0", "round": "round4",
    "executor_id": review["executor_id"], "reviewer_id": review["reviewer_id"],
    "status": "pass", "contract_sha256": review["contract_sha256"],
    "candidate_manifest_sha256": review["candidate_manifest_sha256"],
    "review_sha256": record(HERE / "review.json")["sha256"],
    "files": files, "candidate_manifest": candidate,
    "reviewed_input_records": [item["actual"] for item in checks["file_checks"]],
    "self_excluded": "review_manifest.json",
    "scope": "QA seal only. Input records come from completed checks.json; no scientific test or new candidate audit performed by sealing."
}
with (HERE / "review_manifest.json").open("x", encoding="utf-8") as stream:
    json.dump(seal, stream, ensure_ascii=False, indent=2)
    stream.write("\n")
assert all(record(ROOT / item["path"]) == item for item in files)
print(json.dumps({"status": review["status"], "review": record(HERE / "review.json"),
                  "seal": record(HERE / "review_manifest.json"),
                  "markdown_words": len((HERE / "review.md").read_text().split())}, indent=2))
