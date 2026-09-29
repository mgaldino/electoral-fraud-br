#!/usr/bin/env python3
"""Independent synthetic approval-record probes; never touches the real ledger."""
import copy
import datetime as dt
import importlib.util
import json
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[6]
REVIEW = Path(__file__).resolve().parent
OUT = REVIEW / "dag_probes"
OUT.mkdir(exist_ok=False)
start = time.monotonic()
spec = importlib.util.spec_from_file_location("qa_gates", ROOT / "scripts/mebane_gates.py")
gates = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gates)
plan = json.loads((REVIEW.parent / "ledger_dag_snapshot.json").read_text())
for gate in plan["gates"]:
    gate["status"] = "queued"
    gate["records"] = None
    for todo in gate["todos"]:
        todo["status"] = "todo"
        todo["evidence"] = []
by_id = {g["id"]: g for g in plan["gates"]}
executor = "11111111-1111-4111-8111-111111111111"
reviewer = "22222222-2222-4222-8222-222222222222"


def dump(name, value):
    (OUT / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def external(key, requirement, turn, applicability=False):
    snapshot = key + "-synthetic-snapshot.txt"
    (OUT / snapshot).write_text("SYNTHETIC QA fixture; not evidence of any real election or authorization.\n")
    evidence = {"gate_id": key, "requirement": requirement,
                "election_year": 2026, "turn": turn,
                "source_url": "https://www.tse.jus.br/qa-synthetic",
                "publication_date": dt.date.today().isoformat(),
                "checked_at": dt.datetime.now(dt.timezone.utc).isoformat(),
                "reviewer_id": reviewer, "snapshot_path": snapshot,
                "snapshot_sha256": gates.sha256(OUT / snapshot)}
    evidence.update({"occurrence": "not_held"} if applicability else {"coverage_pass": True})
    name = key + "-synthetic-attestation.json"
    dump(name, evidence)
    return name, snapshot


for key in ("G0", "G1", "G2", "G3", "G4", "G5", "G6", "G7", "G8"):
    gate = by_id[key]
    evidence = []
    extras = []
    if gate["external_prerequisites"]:
        for requirement in gate["external_prerequisites"]:
            attestation, snapshot = external(key, requirement, gate["election_scope"]["turn"])
            evidence.append(attestation)
            extras.extend((attestation, snapshot))
    (OUT / (key + "-input.txt")).write_text("synthetic input\n")
    (OUT / (key + "-output.txt")).write_text("synthetic output\n")
    record = {"executor_id": executor, "reviewer_id": reviewer,
              "run": key + "-run.json", "candidate_manifest": key + "-manifest.json",
              "review": key + "-review.json", "adjudication": key + "-adjudication.json",
              "external_evidence": evidence}
    run = {"gate_id": key, "round": "round1", "contract_sha256": gates.contract_sha256(gate),
           "executor_id": executor, "inputs": [key + "-input.txt"], "code": [],
           "configuration": [], "outputs": [key + "-output.txt"],
           "dependency_manifests": {p: gates.sha256(OUT / by_id[p]["records"]["candidate_manifest"])
                                    for p in gate["depends_on"]},
           "dependency_approvals": {p: {f + "_sha256": gates.sha256(OUT / by_id[p]["records"][f])
                                         for f in ("review", "adjudication")} for p in gate["depends_on"]}}
    dump(record["run"], run)
    paths = [key + "-input.txt", key + "-output.txt", record["run"], *extras]
    dump(record["candidate_manifest"], {"gate_id": key, "round": "round1",
         "contract_sha256": gates.contract_sha256(gate),
         "files": [{"path": p, "sha256": gates.sha256(OUT / p)} for p in paths]})
    common = {"gate_id": key, "round": "round1", "contract_sha256": gates.contract_sha256(gate),
              "candidate_manifest_sha256": gates.sha256(OUT / record["candidate_manifest"]),
              "status": "pass", "findings": []}
    dump(record["review"], dict(common, executor_id=executor, reviewer_id=reviewer, manifest_complete=True))
    dump(record["adjudication"], dict(common, review_sha256=gates.sha256(OUT / record["review"]), unresolved_material_findings=0))
    gate["status"] = "pass"
    gate["records"] = record
    for todo in gate["todos"]:
        todo["status"] = "done"
        todo["evidence"] = [{"path": key + "-output.txt", "basis": "executed"}]

cases = []


def check(label, doc, expected=None):
    errors = gates.validate(doc, OUT)
    cases.append({"id": label, "errors": errors, "expected_error": expected,
                  "passed": not errors if expected is None else expected in errors})


by_id["G9"]["status"] = "waiting_external"
check("G8_pass_G9_waiting_coherent_records", plan)
by_id["G9"]["status"] = "inconclusive"
check("G8_pass_G9_inconclusive_coherent_records", plan)
for predecessor in ("G6", "G7"):
    bad = copy.deepcopy(plan)
    next(g for g in bad["gates"] if g["id"] == predecessor)["status"] = "queued"
    check("G8_missing_" + predecessor, bad, f"G8: prerequisite {predecessor} has not passed")
bad = copy.deepcopy(plan)
next(g for g in bad["gates"] if g["id"] == "G8")["records"] = None
check("G8_boolean_labels_not_approval", bad, "G8: pass requires approval records")
bad = copy.deepcopy(plan)
g9 = next(g for g in bad["gates"] if g["id"] == "G9")
g9["status"] = "not_applicable"
check("G9_no_attestation", bad, "G9: applicability_evidence requires independent official attestation")
attestation, snapshot = external("G9", "turn_not_held", 2, applicability=True)
g9["records"] = {"executor_id": executor, "reviewer_id": reviewer, "applicability_evidence": [attestation]}
check("G9_structural_nonoccurrence_attestation", bad)
wrong = json.loads((OUT / attestation).read_text())
wrong["occurrence"] = "unknown"
dump(attestation, wrong)
check("G9_unknown_occurrence_rejected", bad,
      "G9: invalid external evidence: non-occurrence attestation requires occurrence=not_held without coverage_pass")
wrong["occurrence"] = "not_held"
dump(attestation, wrong)
dump("synthetic_plan.json", plan)
report = {"synthetic_only": True, "real_gate_authorized": False,
          "status": "PASS" if all(x["passed"] for x in cases) else "FAIL", "cases": cases,
          "wall_seconds": time.monotonic() - start,
          "command": "python3 -B quality_reports/results/mebane_gates/G7/round2/review/probe_dag.py"}
dump("results.json", report)
print(json.dumps(report))
if report["status"] != "PASS":
    raise SystemExit(1)
