#!/usr/bin/env python3
"""Audit the freezer's read-only dependency function and resolve prior inputs."""
import hashlib
import importlib.util
import json
import os
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[6]
REVIEW = Path(__file__).resolve().parent
ROUND = REVIEW.parent
target = REVIEW / "integrity_read_trace_final.json"
assert not target.exists()
mutable = (ROOT / "quality_reports/plans/mebane_2022_2026_gates.json").resolve()
seen = set()
enabled = True


def hook(event, args):
    if enabled and event == "open" and isinstance(args[0], (str, bytes)):
        path = Path(os.fsdecode(args[0])).resolve()
        if path == mutable:
            raise RuntimeError("Mutable-ledger read forbidden in the freezer dependency audit")
        if path.is_relative_to(ROOT):
            seen.add(path)


sys.addaudithook(hook)
start = time.monotonic()
spec = importlib.util.spec_from_file_location("candidate_integrity", ROUND / "audit_integrity.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
result = module.audit()
enabled = False
manifest = json.loads((ROUND / "candidate_manifest.json").read_text())
included = {(ROOT / x["path"]).resolve() for x in manifest["files"]}
mapping = {str((ROOT / x["original_path"]).resolve()): x for x in
           json.loads((ROUND / "recovery_map.json").read_text())["files"]}
recovered = []
uncovered = []
attempted_missing = sorted(path for path in seen if not path.is_file())
successful = {path for path in seen if path.is_file()}
for path in sorted(successful - included):
    entry = mapping.get(str(path))
    if (entry and hashlib.sha256(path.read_bytes()).hexdigest() == entry["sha256"] and
            (ROOT / entry["snapshot_path"]).resolve() in included):
        recovered.append(str(path.relative_to(ROOT)))
    else:
        uncovered.append(str(path.relative_to(ROOT)))
report = {"status": "PASS" if not uncovered else "FAIL", "mutable_ledger_read": False,
          "project_read_count": len(successful), "read_paths": [str(p.relative_to(ROOT)) for p in sorted(successful)],
          "unsuccessful_open_attempts": [str(p.relative_to(ROOT)) for p in attempted_missing],
          "reads_resolved_via_recovery_map": recovered, "uncovered_reads": uncovered,
          "candidate_integrity_return": result, "wall_seconds": time.monotonic() - start,
          "scope": "Executed audit_integrity.audit, the freezer dependency; freeze_candidate itself inspected, not rerun"}
target.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
print(json.dumps({k: report[k] for k in ("status", "mutable_ledger_read", "project_read_count", "uncovered_reads")}))
if uncovered:
    raise SystemExit(1)
