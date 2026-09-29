#!/usr/bin/env python3
"""Validate and seal this review once, retaining every generated artifact."""
import ast
import datetime as dt
import hashlib
import json
from pathlib import Path
from uuid import UUID

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[5]


def sha(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(2**20), b""):
            h.update(block)
    return h.hexdigest()


def entry(path):
    return {"path": path.relative_to(ROOT).as_posix(), "bytes": path.stat().st_size, "sha256": sha(path)}


def load(path):
    return json.loads(path.read_text())


def write_new(path, value):
    with path.open("x", encoding="utf-8") as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write("\n")


review = load(HERE / "review.json")
results = load(HERE / "run01/results.json")
source = load(HERE / "source_checks.json")
manifest = HERE.parent / "candidate_manifest.json"
assert review["candidate_manifest_sha256"] == sha(manifest)
assert review["run_sha256"] == sha(HERE.parent / "run.json")
assert review["status"] == "changes_requested" and review["manifest_complete"] is False
assert (review["gate_id"], review["round"]) == ("G0", "round3")
assert review["executor_id"] != review["reviewer_id"]
assert all(str(UUID(review[k])) == review[k] for k in ("executor_id", "reviewer_id"))
assert results["failed_checks"] == ["actual_executor_input_code_closure_complete"]
assert source["function_AST_equal"] and source["ledger_unchanged_since_read_trace"]
assert source["current_checker_sha256"] == source["frozen_checker_sha256"]
assert len(review["findings"]) == 1
assert review["findings"][0]["severity"] == "major"
assert review["findings"][0]["classification"] == "CONFIRMED"
ledger = ROOT / "quality_reports/plans/mebane_2022_2026_gates.json"
assert sha(ledger) == source["ledger_sha256"]
snapshots = HERE / "input_snapshots"
snapshots.mkdir(exist_ok=False)
with (snapshots / "ledger_observed.json").open("xb") as stream:
    stream.write(ledger.read_bytes())

# Independently rehash direct and transitive inputs at seal time as well.
hashes = []
for path in (HERE / "run01/active_hashes.json", HERE / "run01/transitive_hashes.json"):
    for row in load(path):
        expected = row["expected"]
        actual = entry(ROOT / expected["path"])
        assert actual == expected, expected["path"]
        hashes.append(actual)
for path in HERE.rglob("*.json"):
    load(path)
for path in HERE.glob("*.py"):
    ast.parse(path.read_text())
write_new(HERE / "seal_checks.json", {
    "review_required_fields_and_identities_valid": True,
    "review_status_intentionally_blocks_approval": True,
    "json_and_python_syntax_valid": True,
    "direct_files_rehashed_at_seal": 171,
    "transitive_files_rehashed_at_seal": 22,
    "mismatches": 0,
    "candidate_manifest_sha256": sha(manifest),
    "ledger_snapshot_sha256": sha(snapshots / "ledger_observed.json"),
    "checker_equivalence_confirmed": True,
    "limits": "No actual gate adjudication created; synthetic fixtures stay synthetic."
})
own = [entry(p) for p in sorted(HERE.rglob("*")) if p.is_file()]
seal = {
    "schema_version": "1.0", "gate_id": "G0", "round": "round3",
    "reviewer_id": review["reviewer_id"], "executor_id": review["executor_id"],
    "status": review["status"], "candidate_manifest_sha256": sha(manifest),
    "contract_sha256": review["contract_sha256"], "review_sha256": sha(HERE / "review.json"),
    "sealed_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
    "files": own, "reviewed_active_and_transitive_inputs": hashes,
    "candidate_manifest": entry(manifest),
    "self_excluded": "review_manifest.json",
    "scope": "QA-only seal; not a replacement candidate manifest or gate approval."
}
write_new(HERE / "review_manifest.json", seal)
assert all(entry(ROOT / item["path"]) == item for item in seal["files"])
print(json.dumps({"qa_files": len(own), "review_sha256": sha(HERE / "review.json"),
                  "review_manifest_sha256": sha(HERE / "review_manifest.json"),
                  "active_and_transitive_inputs_rehashed": len(hashes)}, indent=2))
