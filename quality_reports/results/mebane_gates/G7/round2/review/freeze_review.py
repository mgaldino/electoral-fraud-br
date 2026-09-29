#!/usr/bin/env python3
"""Close the QA package after a final read-only candidate/recovery audit."""
import datetime as dt
import hashlib
import json
import os
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[6]
REVIEW = Path(__file__).resolve().parent
manifest_path = REVIEW / "review_manifest.json"
assert not manifest_path.exists()
review = json.loads((REVIEW / "review.json").read_text())
assert review["status"] == "pass" and review["manifest_complete"] and not review["findings"]
assert len(review["resolved_prior_findings"]) == 3 and all(x["resolved"] and x["closed"] for x in review["resolved_prior_findings"])
before = time.monotonic()
command = [sys.executable, "-B", str(REVIEW / "audit_inputs.py"), str(REVIEW / "final_integrity.json")]
result = subprocess.run(command, cwd=ROOT, env=dict(os.environ, PYTHONDONTWRITEBYTECODE="1"), capture_output=True)
(REVIEW / "final_integrity.log").write_bytes(result.stdout + result.stderr)
assert result.returncode == 0
final = json.loads((REVIEW / "final_integrity.json").read_text())
baseline = json.loads((REVIEW / "run01/integrity_before.json").read_text())
assert final["ledger_sha256"] == baseline["ledger_sha256"] and final["ledger_states"] == baseline["ledger_states"]
execution = json.loads((REVIEW / "run01/execution.json").read_text())
dag = json.loads((REVIEW / "dag_probes/results.json").read_text())
trace = json.loads((REVIEW / "integrity_read_trace_final.json").read_text())
qa_run = {
    "reviewer_id": review["reviewer_id"], "candidate_manifest_sha256": review["candidate_manifest_sha256"],
    "goal_started_at_utc": dt.datetime.fromtimestamp(1790656136, dt.timezone.utc).isoformat(),
    "closed_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
    "execution": execution,
    "supplemental_commands": [
        {"command": dag["command"], "status": dag["status"], "wall_seconds": dag["wall_seconds"], "log": "dag_probes/results.json"},
        {"command": "python3 -B quality_reports/results/mebane_gates/G7/round2/review/trace_integrity.py", "status": trace["status"],
         "wall_seconds": trace["wall_seconds"], "log": "integrity_read_trace_final.json"},
        {"command": "python3 -B quality_reports/results/mebane_gates/G7/round2/review/verify_outputs.py", "status": "PASS", "log": "verification.json"},
        {"command": command, "status": "PASS", "wall_seconds": time.monotonic() - before, "log": "final_integrity.log"}
    ],
    "superseded_qa_diagnostic": {"log": "integrity_read_trace.json", "status": "FAIL", "reason": "Absent cache open attempt was counted as a read; corrected in final trace with both records preserved."},
    "inspected_only": ["freeze_candidate.py and prepare_round.py source; neither writing entrypoint rerun",
                       "official archived calendar note/URL; no new source retrieval",
                       "concurrency and large-file memory limit declarations"],
    "not_executed": ["real 2026 ingestion", "raw official converter", "MCMC", "installation", "downloads", "national-scale performance", "new concurrency stress"],
    "final_ledger_sha256": final["ledger_sha256"], "final_ledger_states": final["ledger_states"]
}
(REVIEW / "qa_run.json").write_text(json.dumps(qa_run, ensure_ascii=False, indent=2) + "\n")
files = sorted(p for p in REVIEW.rglob("*") if p.is_file() and p != manifest_path)
manifest = {"gate_id": "G7", "round": "round2", "reviewer_id": review["reviewer_id"],
            "contract_sha256": review["contract_sha256"], "candidate_manifest_sha256": review["candidate_manifest_sha256"],
            "excluded_self": str(manifest_path.relative_to(ROOT)),
            "files": [{"path": str(p.relative_to(ROOT)), "sha256": hashlib.sha256(p.read_bytes()).hexdigest(),
                       "bytes": p.stat().st_size} for p in files]}
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
assert len(files) == len({x["path"] for x in manifest["files"]})
for entry in manifest["files"]:
    p = ROOT / entry["path"]
    assert hashlib.sha256(p.read_bytes()).hexdigest() == entry["sha256"] and p.stat().st_size == entry["bytes"]
print(json.dumps({"QA_files": len(files), "hashes": {name: hashlib.sha256((REVIEW / name).read_bytes()).hexdigest()
                  for name in ("review.json", "review.md", "review_manifest.json", "qa_run.json")}}, indent=2))
