#!/usr/bin/env python3
"""Independent, read-only G7 freeze and ledger audit; outputs stay in review/."""
import copy
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[6]
REVIEW = Path(__file__).resolve().parent
ROUND = REVIEW.parent
sys.path.insert(0, str(ROOT / "scripts"))
import mebane_gates as gates


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


manifest_path = ROUND / "candidate_manifest.json"
manifest = load(manifest_path)
run = load(ROUND / "run.json")
contract = load(ROUND / "gate_contract.json")
snapshot = load(ROUND / "ledger_dag_snapshot.json")
ledger_path = ROOT / "quality_reports/plans/mebane_2022_2026_gates.json"
ledger = load(ledger_path)
file_results = []
for item in manifest["files"]:
    path = ROOT / item["path"]
    file_results.append({"path": item["path"], "ok": path.is_file() and
                         sha(path) == item["sha256"] and path.stat().st_size == item["bytes"]})
listed = [item["path"] for item in manifest["files"]]
declared = run["inputs"] + run["code"] + run["configuration"] + run["outputs"] + [str((ROUND / "run.json").relative_to(ROOT))]
round_files_at_freeze = {str(p.relative_to(ROOT)) for p in ROUND.rglob("*") if p.is_file()
                         and REVIEW not in p.parents and p.name != "candidate_manifest.json"}
postfreeze_allowed = {
    str((ROUND / "adjudication_encoding.R").relative_to(ROOT)),
    str((ROUND / "adjudication_encoding.json").relative_to(ROOT)),
}
g1 = ROOT / "quality_reports/results/mebane_gates/G1/round2"
expected_g1 = {
    "candidate_manifest.json": "517c17c724cca82a820519c476981d47c8892c7383dd2c3dded9373eba6d31e8",
    "review/review.json": "727f6b234e3a580c329cc5e898018bb68c02063717c292b6d91e4fbe12d86941",
    "adjudication.json": "fe21ce5ebaf107027b6cf64f72eb06f9f2549df8f65ccbbd3eeee2067807735e",
}
approval = load(g1 / "adjudication.json")
review = load(g1 / "review/review.json")
states = {g["id"]: g["status"] for g in ledger["gates"]}
snapshot_states = {g["id"]: g["status"] for g in snapshot["gates"]}
report = {
    "candidate_sha256": sha(manifest_path),
    "candidate_expected": "62f7a5c4907c9d39b75fe5cd88224bddb4796e015f69f004469e51df7ae493c8",
    "contract_sha256": hashlib.sha256(json.dumps(contract, sort_keys=True, ensure_ascii=False, separators=(",", ":")).encode()).hexdigest(),
    "file_count": len(file_results), "unique_paths": len(set(listed)),
    "bad_files": [x for x in file_results if not x["ok"]],
    "undeclared_manifest_files": sorted(set(listed) - set(declared)),
    "declared_unmanifested_files": sorted(set(declared) - set(listed)),
    "round_files_unmanifested": sorted(round_files_at_freeze - set(listed)),
    "postfreeze_coordinator_evidence": sorted((round_files_at_freeze - set(listed)) & postfreeze_allowed),
    "g1_hashes": {k: sha(g1 / k) for k in expected_g1},
    "g1_expected": expected_g1,
    "g1_review_status": review["status"],
    "g1_adjudication_status": approval["status"],
    "g1_adjudication_review_bound": approval["review_sha256"] == expected_g1["review/review.json"],
    "live_ledger_sha256": sha(ledger_path),
    "snapshot_sha256": sha(ROUND / "ledger_dag_snapshot.json"),
    "live_states": states, "snapshot_states": snapshot_states,
    "live_ledger_errors": gates.validate(ledger, ROOT),
    "snapshot_errors": gates.validate(snapshot, ROOT),
}

# The checker is exercised on copies only. No mock approval is counted as real evidence.
cases = []
for target, status, expected in [
    ("G8", "pass", "G8: prerequisite G6 has not passed"),
    ("G9", "pass", "G9: prerequisite G6 has not passed"),
    ("G9", "not_applicable", "G9: applicability_evidence requires independent official attestation"),
]:
    altered = copy.deepcopy(snapshot)
    next(g for g in altered["gates"] if g["id"] == target)["status"] = status
    errors = gates.validate(altered, ROOT)
    cases.append({"case": target + "_" + status, "expected_error": expected,
                  "matched": expected in errors, "errors": errors})
report["dag_probes"] = cases
inconclusive = copy.deepcopy(snapshot)
next(g for g in inconclusive["gates"] if g["id"] == "G9")["status"] = "inconclusive"
report["g9_inconclusive_without_predecessors_errors"] = gates.validate(inconclusive, ROOT)
report["g9_inconclusive_without_predecessors_accepted"] = not report["g9_inconclusive_without_predecessors_errors"]
without_status = lambda doc: {**doc, "gates": [{k: v for k, v in g.items() if k != "status"} for g in doc["gates"]]}
report["snapshot_matches_live_except_status"] = without_status(snapshot) == without_status(ledger)
report["manifest_complete"] = all(x["ok"] for x in file_results) and len(listed) == 275 and len(set(listed)) == 275 and set(declared) == set(listed) and (round_files_at_freeze - set(listed)) <= postfreeze_allowed
(REVIEW / "freeze_audit.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps({k: report[k] for k in ("candidate_sha256", "file_count", "bad_files", "undeclared_manifest_files", "declared_unmanifested_files", "round_files_unmanifested", "manifest_complete", "live_states", "live_ledger_errors", "snapshot_errors")}, ensure_ascii=False))
if not report["manifest_complete"] or report["candidate_sha256"] != report["candidate_expected"] or report["g1_hashes"] != expected_g1 or any(not x["matched"] for x in cases):
    raise SystemExit(1)
