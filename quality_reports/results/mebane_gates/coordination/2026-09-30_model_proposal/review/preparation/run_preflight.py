"""Read-only external preflight and small deterministic R checks; QA-only writes."""
import csv
import datetime
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path("/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud")
BASE = ROOT / "quality_reports/results/mebane_gates/coordination/2026-09-30_model_proposal"
QA = BASE / "review"
OUT = QA / sys.argv[1]
assert OUT.is_relative_to(QA) and not OUT.exists()
OUT.mkdir(parents=True)
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
read = lambda p: json.loads(p.read_text())


def write_new(name, obj):
    with (OUT / name).open("x", encoding="utf-8") as stream:
        json.dump(obj, stream, indent=2, ensure_ascii=False, allow_nan=False)
        stream.write("\n")


protocol = read(QA / "preparation/protocol.json")
bindings = protocol["fixed_bindings"]
g3 = ROOT / "quality_reports/results/mebane_gates/G3/round1"
external = {
    "G3_revision3_manifest": g3 / "revision3/candidate_manifest.json",
    "G3_final_review": g3 / "review/review.json",
    "G3_QA_manifest": g3 / "review/review_manifest.json",
    "qbl_source": ROOT / "quality_reports/results/mebane_gates/G0/round1/qbl_installed_3017de5.jags",
    "raw_RDS": g3 / "revision2/raw_chains.rds",
    "benchmark_contract": ROOT / "quality_reports/results/mebane_gates/G2/round2/benchmark_contract.json",
}
declared = {}
for key, path in external.items():
    declared[key] = {"path": str(path.relative_to(ROOT)), "sha256": sha(path),
                     "expected_sha256": bindings[key], "valid": sha(path) == bindings[key]}
write_new("binding_checks.json", declared)
assert all(row["valid"] for row in declared.values())
entries = []
for key in ("G3_revision3_manifest", "G3_QA_manifest"):
    for row in read(external[key])["files"]:
        path = ROOT / row["path"]
        ok = path.is_file() and sha(path) == row["sha256"] and path.stat().st_size == row["bytes"]
        entries.append({"manifest": key, "path": row["path"], "sha256": row["sha256"], "valid": ok})
write_new("prior_inventory_checks.json", entries)

adjudication_path = BASE / "provenance_adjudication.json"
adjudication = read(adjudication_path)
assert adjudication["source"]["sha256"] == bindings["G3_revision3_manifest"]
assert adjudication["review_sources"][0]["sha256"] == bindings["G3_final_review"]
assert adjudication["findings"][0]["finding_id"] == "G3-QA-R2-INPUT-01"
assert adjudication["adjudication"]["verdict"] == "READY_FOR_IMPLEMENTATION"
closure_path = g3 / "review/input_closure_revision2.json"
missing = read(closure_path)["historical_preservation"]["missing_effective_code_versions"]
assert len(missing) == len({r["sha256"] for r in missing}) == 7
write_new("expected_seven_sources.json", missing)

inputs = list(external.values()) + [adjudication_path, closure_path,
    g3 / "review/history_audit.json", g3 / "review/executor_event_sequence.json",
    ROOT / "appendices/mebane_model_contract.md", ROOT / "CLAUDE.md",
    ROOT / "quality_reports/plans/mebane_2022_2026_gates.json",
    QA / "preparation/protocol.json", QA / "preparation/checks.R", Path(__file__)]
write_new("freeze.json", {"frozen_at_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "before_deterministic_tests": True, "no_proposal_received": True,
    "inputs": [{"path": str(p.relative_to(ROOT)), "sha256": sha(p), "bytes": p.stat().st_size} for p in inputs]})
ledger = read(ROOT / "quality_reports/plans/mebane_2022_2026_gates.json")
gate = next(g for g in ledger["gates"] if g["id"] == "G3")
command = ["timeout", "110", "Rscript", "--vanilla", str(QA / "preparation/checks.R"), str(OUT)]
write_new("invocation.json", {"argv": command, "cwd": str(ROOT), "no_RNG": True, "no_estimation": True})
start = time.monotonic()
with (OUT / "stdout.log").open("x") as stdout, (OUT / "stderr.log").open("x") as stderr:
    done = subprocess.run(command, cwd=ROOT, stdout=stdout, stderr=stderr, timeout=115, check=False)
elapsed = time.monotonic()-start
rows = list(csv.DictReader((OUT / "checks.csv").open())) if (OUT / "checks.csv").is_file() else []
result = {"stage": "preparation_only_not_a_proposal_review", "proposal_received": False,
    "provenance_package_reviewed": False, "G3_ledger_status_observed": gate["status"],
    "G3_review_status": read(external["G3_final_review"])["status"],
    "G3_candidate_entries_verified": sum(e["valid"] for e in entries if e["manifest"] == "G3_revision3_manifest"),
    "G3_QA_entries_verified": sum(e["valid"] for e in entries if e["manifest"] == "G3_QA_manifest"),
    "inventory_errors": [e for e in entries if not e["valid"]],
    "source_versions_expected": len(missing), "R_exit_code": done.returncode,
    "R_elapsed_seconds": elapsed, "deterministic_checks": len(rows),
    "failed_checks": [r for r in rows if r["pass"] != "TRUE"],
    "no_estimation": True, "no_new_chains": True, "production_approved": False,
    "next_step": "Await frozen provenance package and proposal paths/SHA; do not infer approval of unseen documents."}
write_new("preflight_result.json", result)
print(json.dumps(result, ensure_ascii=False))
assert done.returncode == 0 and not result["failed_checks"] and not result["inventory_errors"]
