"""Read-only negative dependency test against the project's real gate checker."""

import copy
import importlib.util
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "scripts"))
import mebane_gates  # noqa: E402

snapshot = ROOT / "quality_reports/results/mebane_gates/G7/round1/ledger_dag_snapshot.json"
base = json.loads(snapshot.read_text())
for target in ("G8", "G9"):
    plan = copy.deepcopy(base)
    by_id = {gate["id"]: gate for gate in plan["gates"]}
    by_id["G6"]["status"] = "queued"
    by_id["G7"]["status"] = "pass"
    by_id[target]["status"] = "pass"
    errors = mebane_gates.validate(plan, ROOT)
    expected = f"{target}: prerequisite G6 has not passed"
    if expected not in errors:
        raise AssertionError((expected, errors))
    print(expected)
print("G6 predecessor negative checks: PASS")

spec = importlib.util.spec_from_file_location("g7_frozen_checker_tests", ROOT / "tests/test_mebane_gates.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
module.GATES.LEDGER = snapshot
suite = unittest.defaultTestLoader.loadTestsFromModule(module)
result = unittest.TextTestRunner(verbosity=1).run(suite)
if not result.wasSuccessful():
    raise SystemExit(1)
print("Frozen-ledger checker suite: PASS")
