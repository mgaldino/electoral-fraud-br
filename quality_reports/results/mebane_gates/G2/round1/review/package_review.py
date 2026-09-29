"""Validate and render the independent review; never writes outside review/."""
import csv
import hashlib
import json
import os
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from uuid import UUID

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[5]
PY = "/Users/manoelgaldino/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, data):
    assert path.resolve().is_relative_to(HERE)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")


review = json.loads((HERE / "review.json").read_text())
assert review["gate_id"] == "G2" and review["round"] == "round1"
assert review["status"] == "changes_requested" and review["manifest_complete"] is True
assert review["reviewer_id"] != review["executor_id"]
for field in ("reviewer_id", "executor_id"):
    assert str(UUID(review[field])) == review[field]
assert len({f["id"] for f in review["findings"]}) == len(review["findings"])
assert all(f["severity"] in {"critical", "major", "minor"} for f in review["findings"])
assert all(not f["resolved"] and not f["contract_derivation_defect"] for f in review["findings"])
assert all(f["classification"] == "CONFIRMED" for f in review["executor_findings"])

records = []


def run(argv, name):
    start = time.monotonic()
    timestamp = datetime.now(timezone.utc).isoformat()
    env = os.environ.copy()
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    result = subprocess.run(argv, cwd=ROOT, capture_output=True, text=True, env=env)
    log = HERE / f"{name}.log"
    log.write_text(result.stdout + result.stderr)
    records.append({"argv": argv, "started_at_utc": timestamp,
                    "elapsed_seconds": time.monotonic() - start,
                    "exit_code": result.returncode, "log": str(log.relative_to(ROOT))})
    write(HERE / "review_run.json", {"reviewer_id": review["reviewer_id"], "commands": records})
    if result.returncode:
        raise RuntimeError(f"Command failed: {argv}; see {log}")


run([sys.executable, str(HERE / "verify_evidence.py")], "verify_evidence")
integrity = json.loads((HERE / "integrity.json").read_text())
assert integrity["candidate_manifest_sha256"] == review["candidate_manifest_sha256"]
assert integrity["contract_sha256"] == review["contract_sha256"]
run(["Rscript", "--vanilla", str(HERE / "independent_checks.R")], "independent_execution")
rows = list(csv.DictReader((HERE / "independent_checks.csv").open()))
assert len(rows) == review["tests"]["total"] and all(r["passed"] == "TRUE" for r in rows)
run(["pandoc", str(HERE / "review.md"), "--standalone", "--pdf-engine=pdflatex",
     f"--lua-filter={HERE / 'review_code.lua'}", "-o", str(HERE / "review.pdf")], "render_review")
run(["pdftotext", "-layout", str(HERE / "review.pdf"), str(HERE / "review_pdf.txt")], "extract_review")
run([PY, str(HERE / "inspect_review_pdf.py")], "inspect_review_pdf")
versions = {}
for argv in (["pandoc", "--version"], ["pdflatex", "--version"], ["pdftoppm", "-v"],
             [PY, "--version"]):
    result = subprocess.run(argv, capture_output=True, text=True)
    versions[argv[0]] = (result.stdout + result.stderr).splitlines()[:2]
run_record = {"reviewer_id": review["reviewer_id"], "gate_id": "G2", "round": "round1",
              "candidate_manifest_sha256": review["candidate_manifest_sha256"],
              "commands": records, "versions": versions, "mcmc": False, "rng": "none",
              "writes_confined_to": str(HERE.relative_to(ROOT)),
              "finalized_at_utc": datetime.now(timezone.utc).isoformat()}
write(HERE / "review_run.json", run_record)
files = [p for p in HERE.rglob("*") if p.is_file() and p.name != "review_manifest.json"
         and "__pycache__" not in p.parts]
write(HERE / "review_manifest.json", {
    "gate_id": "G2", "round": "round1", "reviewer_id": review["reviewer_id"],
    "candidate_manifest_sha256": review["candidate_manifest_sha256"],
    "review_json_sha256": sha(HERE / "review.json"),
    "files": [{"path": str(p.relative_to(ROOT)), "sha256": sha(p), "bytes": p.stat().st_size}
              for p in sorted(files)]})
print(json.dumps({"status": review["status"], "checks": len(rows),
                  "review_json_sha256": sha(HERE / "review.json"),
                  "review_pdf_sha256": sha(HERE / "review.pdf"),
                  "review_manifest_files": len(files)}))
