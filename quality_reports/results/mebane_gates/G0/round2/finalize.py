"""Freeze the repaired G0 candidate without binding mutable canonical paths."""

import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[5]
ROUND = Path(__file__).resolve().parent
ROUND1 = ROOT / "quality_reports/results/mebane_gates/G0/round1"
PREFIX = ROUND.relative_to(ROOT).as_posix()
PRIOR = ROUND1.relative_to(ROOT).as_posix()
EXECUTOR_ID = "01a0eaba-2cec-74f3-bca0-8c27b736567e"


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


old_run = read_json(ROUND1 / "run.json")
old_map = read_json(ROUND1 / "final_state_map.json")
current_map = read_json(ROUND / "final_state_map.json")
by_original = {item["original"]: item for item in current_map}
repaired = {item["original"] for item in current_map if item["origin_round"] == "round2"}
plan = read_json(ROOT / by_original["quality_reports/plans/mebane_2022_2026_gates.json"]["snapshot"])
gate = next(item for item in plan["gates"] if item["id"] == "G0")
contract = {key: value for key, value in gate.items() if key not in ("status", "records")}
contract["todos"] = [{key: value for key, value in todo.items() if key not in ("status", "evidence")}
                     for todo in gate["todos"]]
canonical = json.dumps(contract, sort_keys=True, ensure_ascii=False, separators=(",", ":"))
contract_sha = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
assert contract_sha == old_run["contract_sha256"]
write_json(ROUND / "gate_contract.json", contract)

prior_evidence = [
    "run.json", "candidate_manifest.json", "gate_contract.json",
    "inventory.json", "loads_environment.json", "sources.md", "claims.md",
    "final_state_map.json", "eforensics_commit_api.json",
    "review/review.json", "adjudication.json", "adjudication.md",
]
prior_evidence_paths = [f"{PRIOR}/{name}" for name in prior_evidence]
old_versions = [item["snapshot"] for item in old_map if item["original"] in repaired]
new_five = [item["snapshot"] for item in current_map
            if item["original"] == "research_note.md" or item["original"].startswith("output/tables/")]
assert len(new_five) == 5
inputs = sorted(set(old_run["inputs"] + prior_evidence_paths + old_versions + new_five))
code = sorted(set(old_run["code"] + [f"{PREFIX}/{name}" for name in
                                  ("reconcile_lock.R", "merge_lock.py", "verify_lock.R",
                                   "snapshot_repair.py", "finalize.py")]))
configuration = sorted({item["snapshot"] for item in current_map
                        if item["original"] in {entry["original"] for entry in old_map
                                                 if entry["snapshot"] in old_run["configuration"]}})
outputs = sorted(path.relative_to(ROOT).as_posix() for path in ROUND.rglob("*")
                 if path.is_file() and path.name not in ("run.json", "candidate_manifest.json")
                 and path.relative_to(ROOT).as_posix() not in code)
verification = read_json(ROUND / "lock_verification.json")
run = {
    "gate_id": "G0", "round": "round2", "contract_sha256": contract_sha,
    "executor_id": EXECUTOR_ID, "executor_role": "SOL-BASELINE",
    "goal_id": EXECUTOR_ID,
    "goal_objective": "Entregar candidato G0 round2 reparado para rechecagem independente",
    "requested_model": "gpt-6-sol", "requested_effort": "high",
    "effective_model": "not_exposed_by_runtime", "effective_effort": "not_exposed_by_runtime",
    "started_at_utc": datetime.fromtimestamp(1790646517, timezone.utc).isoformat(),
    "finished_at_utc": datetime.now(timezone.utc).isoformat(),
    "dependency_manifests": {}, "dependency_approvals": {},
    "repaired_from_manifest_sha256": sha256(ROUND1 / "candidate_manifest.json"),
    "binding_adjudication_sha256": sha256(ROUND1 / "adjudication.json"),
    "inputs": inputs, "code": code, "configuration": configuration, "outputs": outputs,
    "baseline_snapshots": current_map,
    "seeds": [],
    "versions": {"R": "4.4.2", "JAGS": "4.3.2", "CmdStan": "2.37.0",
                 "eforensics_RemoteSha": "3017de537450f97a01872d0157462a68bea348ee",
                 "supplemental_packages": verification["six_records"]},
    "commands": [
        {"command": "Rscript --vanilla quality_reports/results/mebane_gates/G0/round2/reconcile_lock.R",
         "exit_code": 0, "wall_seconds": 0.30, "effect": "13-package closure; six missing installed records"},
        {"command": "python3 quality_reports/results/mebane_gates/G0/round2/merge_lock.py",
         "exit_code": 0, "wall_seconds": 0.01, "effect": "append six; preserve 174"},
        {"command": "Rscript --vanilla quality_reports/results/mebane_gates/G0/round2/verify_lock.R",
         "exit_code": 0, "wall_seconds_last_run": 2.80,
         "effect": "180 entries; six literal versions; zero closure or direct script-root gaps"},
        {"command": "python3 quality_reports/results/mebane_gates/G0/round2/snapshot_repair.py",
         "exit_code": 0, "wall_seconds": 0.01, "effect": "five F1 sources plus four mutable files frozen"},
    ],
    "limits": [
        "No MCMC, G1 transformation, G2 audit, installation, or cold renv::restore was run.",
        "Historical ZIP acquisition URL/date are unknown; exact restoration elsewhere requires an intact copy with the recorded SHA-256.",
        "Round1 fit/data/PDF loads and integrity checks are historical inputs, not new round2 executions.",
    ],
}
write_json(ROUND / "run.json", run)

evidence = read_json(ROUND / "todo_evidence.json")
todo_paths = [item["path"] for todo in evidence["todos"] for item in todo["evidence"]]
paths = sorted(set(inputs + code + configuration + outputs + todo_paths + [f"{PREFIX}/run.json"]))
assert f"{PREFIX}/gate_contract.json" in paths
assert f"{PREFIX}/candidate_manifest.json" not in paths
files = []
for relative in paths:
    path = ROOT / relative
    assert path.is_file(), relative
    files.append({"path": relative, "sha256": sha256(path), "bytes": path.stat().st_size})
manifest = {"gate_id": "G0", "round": "round2", "contract_sha256": contract_sha,
            "files": files}
write_json(ROUND / "candidate_manifest.json", manifest)
print(f"contract_sha256={contract_sha} manifest_sha256={sha256(ROUND / 'candidate_manifest.json')} files={len(files)}")
