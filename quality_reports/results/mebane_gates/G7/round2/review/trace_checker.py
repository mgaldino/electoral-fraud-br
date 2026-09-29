#!/usr/bin/env python3
"""Run the frozen-snapshot checker with a read audit and mutable-ledger prohibition."""
import json
import os
import runpy
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[6]
REVIEW = Path(__file__).resolve().parent
destination = Path(sys.argv[1]).resolve()
assert destination.is_relative_to(REVIEW) and not destination.exists()
mutable = str((ROOT / "quality_reports/plans/mebane_2022_2026_gates.json").resolve())
reads = set()
subprocesses = []


def audit(event, args):
    if event == "open" and isinstance(args[0], (str, bytes)):
        path = str(Path(os.fsdecode(args[0])).resolve())
        if path == mutable:
            raise RuntimeError("QA blocked a mutable-ledger read")
        if path.startswith(str(ROOT)):
            reads.add(path)
    if event == "subprocess.Popen":
        subprocesses.append(str(args[1]))


sys.addaudithook(audit)
result = 0
try:
    runpy.run_path(str(ROOT / "tests/mebane/2026/check_dag.py"), run_name="__main__")
except SystemExit as error:
    result = error.code or 0
finally:
    destination.write_text(json.dumps({"exit_code": result, "mutable_ledger_read": False,
        "project_reads": sorted(reads), "child_commands": subprocesses,
        "scope": "Python process opens; child render commands use explicit synthetic --ledger paths"}, indent=2) + "\n")
raise SystemExit(result)
