#!/usr/bin/env python3
"""Seal the completed documentary review; no analysis rerun or overwrite."""
import hashlib
import json
from pathlib import Path
from uuid import UUID

ROOT = Path(__file__).resolve().parents[6]


def record(path):
    data = path.read_bytes()
    return {"path": path.relative_to(ROOT).as_posix(), "bytes": len(data),
            "sha256": hashlib.sha256(data).hexdigest()}


def seal(here, supporting=()):
    review = json.loads((here / "review.json").read_text())
    checks = json.loads((here / "checks.json").read_text())
    assert checks["failed_checks"] == []
    assert all(c["passed"] for c in checks["checks"])
    assert review["status"] == "pass" and review["manifest_complete"] is True and review["findings"] == []
    assert review["executor_id"] != review["reviewer_id"]
    assert all(str(UUID(review[k])) == review[k] for k in ("executor_id", "reviewer_id"))
    assert record(here.parent / "candidate_manifest.json")["sha256"] == review["candidate_manifest_sha256"]
    assert record(here.parent / "run.json")["sha256"] == review["run_sha256"]
    files = [record(p) for p in sorted(here.iterdir()) if p.is_file()]
    result = {"schema_version": "1.0", "gate_id": review["gate_id"], "round": "round3",
              "reviewer_id": review["reviewer_id"], "executor_id": review["executor_id"],
              "contract_sha256": review["contract_sha256"],
              "candidate_manifest_sha256": review["candidate_manifest_sha256"],
              "review_sha256": record(here / "review.json")["sha256"], "status": review["status"],
              "files": files, "supporting_qa_code": [record(p) for p in supporting],
              "candidate_manifest": record(here.parent / "candidate_manifest.json"),
              "reviewed_input_records": [x["actual"] for x in checks["file_checks"]],
              "reviewed_active_dependency_records": [x["actual"] for x in checks["active_dependency_file_checks"]],
              "self_excluded": "review_manifest.json", "scope": "QA seal only; input checks already executed, no new scientific analysis."}
    with (here / "review_manifest.json").open("x", encoding="utf-8") as stream:
        json.dump(result, stream, ensure_ascii=False, indent=2)
        stream.write("\n")
    assert all(record(ROOT / x["path"]) == x for x in files)
    print(json.dumps({"review": record(here / "review.json"), "seal": record(here / "review_manifest.json")}, indent=2))


if __name__ == "__main__":
    seal(Path(__file__).resolve().parent)
