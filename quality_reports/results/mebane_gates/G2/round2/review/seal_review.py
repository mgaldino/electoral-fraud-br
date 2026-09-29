"""Validate and seal this review without changing any candidate/dependency file."""
import csv
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[5]


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def entry(path):
    return {"path": str(path.relative_to(ROOT)), "sha256": sha(path), "bytes": path.stat().st_size}


review = read(HERE / "review.json")
initial = read(HERE / "integrity_initial.json")
final = read(HERE / "integrity_final.json")
checks = list(csv.DictReader((HERE / "independent_checks.csv").open()))
commands = read(HERE / "commands.json")
assert len(checks) == 59 and all(row["passed"] == "TRUE" for row in checks)
assert review["status"] == "inconclusive" and review["manifest_complete"] is False
assert review["candidate_manifest_complete"] is True
assert [row["exit_code"] for row in commands] == [0, 1, 0]
assert len(final["checks"]) == 720 and sum(x["pass"] for x in final["checks"]) == 719
assert len(initial["checks"]) == 719 and all(x["pass"] for x in initial["checks"])
assert sha(HERE.parent / "candidate_manifest.json") == review["candidate_manifest_sha256"]
assert sha(HERE.parent / "benchmark_contract.json") == review["benchmark_contract_sha256"]
assert sha(HERE.parent / "run.json") == review["run_sha256"]
assert review["executor_id"] != review["reviewer_id"]

expected = {item["path"]: item for item in initial["verified_inputs"]}
expected.update({item["path"]: item for item in final["verified_inputs"]})
inputs, mismatches = [], []
for name, old in sorted(expected.items()):
    path = ROOT / name
    actual = sha(path) if path.is_file() else None
    current = {**old, "available_at_seal": path.is_file(), "sha256_at_seal": actual,
               "matches_verified_hash": actual == old["sha256"]}
    inputs.append(current)
    if not current["matches_verified_hash"]:
        mismatches.append(current)
assert [x["path"] for x in mismatches] == ["ssrn-4073770.pdf.download/ssrn-4073770.pdf"], \
    "Dependency state changed again: update review before sealing"
assert mismatches[0]["sha256_at_seal"] is None

format_checks = []
for path in sorted(HERE.rglob("*")):
    if not path.is_file() or path.name == "review_manifest.json":
        continue
    if path.suffix == ".json":
        read(path)
    if path.suffix in (".py", ".R", ".md") and "snapshots" not in path.parts:
        text = path.read_text(encoding="utf-8")
        assert all(line.rstrip() == line for line in text.splitlines()), path
        format_checks.append(str(path.relative_to(ROOT)))
validation = {
    "status": "pass_for_accurate_inconclusive_review",
    "candidate_unchanged": True,
    "known_missing_dependency_count": 1,
    "json_syntax_checked": True,
    "own_text_files_whitespace_checked": format_checks,
    "independent_checks": 59,
    "reviewer_executor_distinct": True,
    "candidate_file_count": 163,
    "review_status_not_gate_approval": True,
}
(HERE / "qa_validation.json").write_text(json.dumps(validation, ensure_ascii=False, indent=2) + "\n")
artifacts = [entry(path) for path in sorted(HERE.rglob("*"))
             if path.is_file() and path.name != "review_manifest.json" and "__pycache__" not in path.parts]
manifest = {
    "schema_version": "1.0",
    "gate_id": "G2", "round": "round2", "reviewer_id": review["reviewer_id"],
    "executor_id": review["executor_id"], "contract_sha256": review["contract_sha256"],
    "candidate_manifest_sha256": review["candidate_manifest_sha256"],
    "review_json_sha256": sha(HERE / "review.json"),
    "review_md_sha256": sha(HERE / "review.md"),
    "sealed_at_utc": datetime.now(timezone.utc).isoformat(),
    "status": review["status"], "manifest_complete": False,
    "candidate_manifest_complete": True,
    "inputs": inputs,
    "artifacts": artifacts,
    "missing_dependency_inputs": mismatches,
    "self_hash_excluded": True,
    "scope_note": "Hashes of every verified input and all QA artifacts. One previously verified G0 input is now missing; its expected and current identities are explicit. No live ledger was consumed.",
}
(HERE / "review_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
sealed = read(HERE / "review_manifest.json")
assert all(sha(ROOT / item["path"]) == item["sha256"] for item in sealed["artifacts"])
print(json.dumps({"status": review["status"], "candidate_unchanged": True,
                  "input_records": len(inputs), "qa_artifacts": len(artifacts),
                  "known_missing_dependency_count": len(mismatches),
                  "review_json_sha256": sealed["review_json_sha256"],
                  "review_manifest_sha256": sha(HERE / "review_manifest.json")}, indent=2))
