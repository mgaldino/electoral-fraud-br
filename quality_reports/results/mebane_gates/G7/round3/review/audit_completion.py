#!/usr/bin/env python3
"""Read-only completion check of the four delivered reviews and preserved G0 history."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[6]
BASE = ROOT / "quality_reports/results/mebane_gates"
results = []


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


for gate, round_id, expected_status in (("G0", "round3", "changes_requested"), ("G0", "round4", "pass"),
                                        ("G1", "round3", "pass"), ("G2", "round3", "pass"), ("G7", "round3", "pass")):
    directory = BASE / gate / round_id
    review = json.loads((directory / "review/review.json").read_text())
    manifest = json.loads((directory / "review/review_manifest.json").read_text())
    assert review["gate_id"] == gate and review["round"] == round_id and review["status"] == expected_status
    assert review["reviewer_id"] == "01a0edd1-ae42-7973-8cf9-2fda610d33cf" != review["executor_id"]
    assert review["manifest_complete"] is (expected_status == "pass")
    assert review["candidate_manifest_sha256"] == sha(directory / "candidate_manifest.json")
    assert manifest["review_sha256"] == sha(directory / "review/review.json")
    assert manifest["candidate_manifest_sha256"] == review["candidate_manifest_sha256"]
    assert (directory / "review/review.md").is_file()
    for item in manifest["files"] + manifest.get("supporting_qa_code", []):
        path = ROOT / item["path"]
        assert path.is_file() and path.stat().st_size == item["bytes"] and sha(path) == item["sha256"], item["path"]
    if expected_status == "pass":
        assert review["findings"] == []
    results.append({"gate_id": gate, "round": round_id, "status": expected_status,
                    "review_sha256": sha(directory / "review/review.json"),
                    "review_manifest_sha256": sha(directory / "review/review_manifest.json")})
print(json.dumps({"four_gates_delivered_and_seals_valid": True, "historical_G0_round3_preserved": True,
                  "new_science_or_gate_state_change": False, "reviews": results}, indent=2))
