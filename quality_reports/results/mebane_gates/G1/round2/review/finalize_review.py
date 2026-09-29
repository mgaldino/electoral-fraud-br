"""Validate QA evidence and emit its execution index and hash manifest."""
import csv
import hashlib
import json
import uuid
from datetime import datetime, timezone
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[5]
R2 = OUT.parent

def read(path):
    return json.loads(path.read_text())

def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()

def entry(path):
    return {"path": str(path.relative_to(ROOT)), "sha256": sha(path),
            "bytes": path.stat().st_size}

def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")

review = read(OUT / "review.json")
assert review["status"] == "pass" and review["manifest_complete"] is True
assert not review["findings"]
assert review["executor_id"] != review["reviewer_id"]
for key in ("executor_id", "reviewer_id"):
    assert str(uuid.UUID(review[key])) == review[key]
assert sha(R2 / "candidate_manifest.json") == review["candidate_manifest_sha256"]
assert {x["id"] for x in review["resolved_prior_findings"]} == {
    "G1-R1-QAD-F01", "G1-R1-QAD-F02", "G1-R1-COORD-F03"}
assert all(x["prior_status"] == "CONFIRMED" and x["resolved"]
           for x in review["resolved_prior_findings"])
assert all(x["status"] == "pass" for x in review["todos_covered"])
assert next(x for x in review["resolved_prior_findings"]
            if x["id"] == "G1-R1-COORD-F03")["source_review"] == "COORD-G1-R1"

csv_counts = {}
for file, flag, count in [
    ("adversarial_results.csv", "passed", 43),
    ("independent_controls.csv", "pass", 8),
    ("round1_column_invariance.csv", "identical", 70),
    ("replay_hashes.csv", "identical", 9),
]:
    with (OUT / file).open() as handle:
        rows = list(csv.DictReader(handle))
    assert len(rows) == count and all(x[flag] == "TRUE" for x in rows), file
    csv_counts[file] = count
records = [read(path) for path in sorted((OUT / "logs").glob("*.json"))]
required = {"integrity", "integrity_final", "adversarial_final", "existing_fixtures",
            "repair_fixtures", "static_contract_fixtures", "load_clean", "build_clean",
            "load_replay", "build_replay", "independent_data", "runtime"}
available = {p.stem for p in (OUT / "logs").glob("*.json")}
assert required.issubset(available)
for path in (OUT / "logs").glob("*.json"):
    record = read(path)
    if path.stem == "adversarial":
        assert record["exit_code"] == 1
    else:
        assert record["exit_code"] == 0, path
now = datetime.now(timezone.utc).isoformat()
write(OUT / "qa_run.json", {
    "gate_id": "G1", "round": "round2", "reviewer_id": review["reviewer_id"],
    "executor_id": review["executor_id"],
    "goal_created_at_unix": review["goal_created_at_unix"],
    "candidate_manifest_sha256": review["candidate_manifest_sha256"],
    "contract_sha256": review["contract_sha256"],
    "completed_at_utc": now,
    "review_elapsed_seconds_to_freeze": round(datetime.now(timezone.utc).timestamp() -
                                              review["goal_created_at_unix"]),
    "required_commands_passed": True,
    "superseded_qa_failure": "logs/adversarial.json: reviewer-only table-printing error; corrected and rerun in adversarial_final",
    "commands": sorted(records, key=lambda x: x["started_at_utc"]),
    "csv_validation_counts": csv_counts,
    "runtime": {"R": "4.4.2", "data.table": "1.17.0", "arrow": "22.0.0",
                "jsonlite": "2.0.0", "digest": "0.6.37"},
    "runtime_evidence": "logs/runtime.txt",
    "source_read_audit": "source_audit.md",
    "network_installation_mcmc": False,
})
candidate = read(R2 / "candidate_manifest.json")
inputs = list(candidate["files"])
for item in inputs:
    assert sha(ROOT / item["path"]) == item["sha256"], item["path"]
inputs.extend(entry(path) for path in [
    R2 / "candidate_manifest.json", ROOT / "CLAUDE.md",
    ROOT / "quality_reports/plans/mebane_gate_agent_prompts.md"])
files = [entry(path) for path in sorted(OUT.rglob("*")) if path.is_file()
         and path.name != "qa_manifest.json" and "tmp" not in path.relative_to(OUT).parts
         and "__pycache__" not in path.parts]
write(OUT / "qa_manifest.json", {
    "schema_version": "1.0", "gate_id": "G1", "round": "round2",
    "reviewer_id": review["reviewer_id"], "executor_id": review["executor_id"],
    "candidate_manifest_sha256": review["candidate_manifest_sha256"],
    "contract_sha256": review["contract_sha256"], "created_at_utc": now,
    "inputs": inputs, "files": files,
    "self_excluded": True, "temporary_runtime_files_excluded": True,
})
for name in ("review.json", "review.md", "qa_run.json", "qa_manifest.json"):
    print(name, sha(OUT / name))
print(f"QA manifest: {len(inputs)} input entries and {len(files)} reviewer artifacts.")
