#!/usr/bin/env python3
"""Resolve the coordinator's narrow checker-equivalence question."""
import ast
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[5]
PREFIX = "quality_reports/results/mebane_gates/G0/"


def read(path):
    return json.loads((ROOT / path).read_text())


def sha(path):
    return hashlib.sha256((ROOT / path).read_bytes()).hexdigest()


def function(path):
    tree = ast.parse((ROOT / path).read_text())
    node = next(x for x in tree.body if isinstance(x, ast.FunctionDef) and x.name == "contract_sha256")
    return ast.dump(node, include_attributes=False)


live = "scripts/mebane_gates.py"
frozen = PREFIX + "round1/final_state/scripts/mebane_gates.py"
ledger = "quality_reports/plans/mebane_2022_2026_gates.json"
gate = next(g for g in read(ledger)["gates"] if g["id"] == "G0")


def consumed_todos(g):
    return [{"id": t["id"], "status": t["status"],
             "evidence": [{"path": e["path"], "locator": e.get("locator", "")} for e in t["evidence"]]}
            for t in g["todos"]]


comparisons = []
for version in ("round1", "round2"):
    path = PREFIX + version + "/final_state/" + ledger
    snapshot_gate = next(g for g in read(path)["gates"] if g["id"] == "G0")
    comparisons.append({"path": path, "sha256": sha(path),
                        "consumed_todo_projection_equals_live": consumed_todos(snapshot_gate) == consumed_todos(gate)})
old_todos = read(PREFIX + "round2/todo_evidence.json")
prior_projection_equal = consumed_todos(old_todos) == consumed_todos(gate)
trace = read(PREFIX + "round3/review/run01/executor_reads.json")
traced_ledger = next(x for x in trace["effective_project_reads"] if x["path"] == ledger)
result = {
    "gate_id": "G0", "round": "round3",
    "function_consumed": "contract_sha256",
    "current_checker_sha256": sha(live), "frozen_checker_sha256": sha(frozen),
    "function_AST_equal": function(live) == function(frozen),
    "checker_equivalence_interpretation": "No defect in the consumed hash function was demonstrated; identical AST is counterevidence against such a claim. The live import remains unbound operationally, but is not a separate material finding.",
    "ledger_sha256": sha(ledger), "ledger_unchanged_since_read_trace": sha(ledger) == traced_ledger["sha256"],
    "consumed_live_todo_projection": consumed_todos(gate),
    "prior_frozen_ledger_comparisons": comparisons,
    "round2_todo_evidence_consumed_projection_equals_live": prior_projection_equal,
    "static_contract_excludes_todo_status_and_evidence": True,
    "narrow_finding": "The static hash cannot bind todo status/evidence actually consumed by build; the counterexample changes output while passing check_contract. This is provenance, not invalid scientific data or mathematics.",
}
with (HERE / "source_checks.json").open("x", encoding="utf-8") as stream:
    json.dump(result, stream, ensure_ascii=False, indent=2)
    stream.write("\n")
print(json.dumps({k: v for k, v in result.items() if k != "consumed_live_todo_projection"}, indent=2))
