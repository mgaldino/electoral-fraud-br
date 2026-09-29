#!/usr/bin/env python3
"""Freeze the G7 round1 candidate without reading the mutable gate ledger."""

import datetime as dt
import hashlib
import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[5]
ROUND = Path(__file__).resolve().parent
PREFIX = "quality_reports/results/mebane_gates/G7/round1/"
EXECUTOR = os.environ.get("CODEX_THREAD_ID")
EXPECTED_EXECUTOR = "01a0eb3a-6ea4-7f61-a66d-2805e495d1d0"
G7_CONTRACT = "fc071a8664d04ba6a0a4ca91298d333ee1ca89868a26b23e705946fef1c2f94d"
G1_CONTRACT = "f985ab97469aa66755b977a09781b30608afa6e245896d9d9788b4461190975d"
G1_FILES = {
    "candidate_manifest.json": "517c17c724cca82a820519c476981d47c8892c7383dd2c3dded9373eba6d31e8",
    "review/review.json": "727f6b234e3a580c329cc5e898018bb68c02063717c292b6d91e4fbe12d86941",
    "adjudication.json": "fe21ce5ebaf107027b6cf64f72eb06f9f2549df8f65ccbbd3eeee2067807735e",
}


def sha(path):
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def canonical(value):
    return json.dumps(value, sort_keys=True, ensure_ascii=False,
                      separators=(",", ":")).encode("utf-8")


def relative(path):
    path = path.resolve()
    return str(path.relative_to(ROOT))


if EXECUTOR != EXPECTED_EXECUTOR:
    raise SystemExit("Wrong executor identity")
if (ROUND / "run.json").exists() or (ROUND / "candidate_manifest.json").exists():
    raise SystemExit("Round already frozen; do not overwrite")
contract_path = ROUND / "gate_contract.json"
contract = json.loads(contract_path.read_text(encoding="utf-8"))
if "status" in contract or "records" in contract or any(
    "status" in todo or "evidence" in todo for todo in contract["todos"]
):
    raise SystemExit("Contract is not static")
contract_hash = hashlib.sha256(canonical(contract)).hexdigest()
if contract_hash != G7_CONTRACT:
    raise SystemExit("G7 canonical contract changed")

g1_base = ROOT / "quality_reports/results/mebane_gates/G1/round2"
for path, expected in G1_FILES.items():
    if sha(g1_base / path) != expected:
        raise SystemExit(f"G1 approval changed: {path}")
g1_contract = json.loads((g1_base / "gate_contract.json").read_text(encoding="utf-8"))
if hashlib.sha256(canonical(g1_contract)).hexdigest() != G1_CONTRACT:
    raise SystemExit("G1 canonical contract changed")

inputs = [
    "quality_reports/plans/mebane_gate_agent_prompts.md",
    "quality_reports/results/mebane_gates/coordination/tse2026_source_preflight.md",
    "quality_reports/results/mebane_gates/G1/round2/gate_contract.json",
    *["quality_reports/results/mebane_gates/G1/round2/" + item for item in G1_FILES],
    "config/mebane/2022.json",
    PREFIX + "ledger_dag_snapshot.json",
]
inputs += sorted(relative(path) for path in
                 (ROOT / "quality_reports/results/mebane_gates/coordination").glob("tse-*.pdf"))
inputs += sorted(relative(path) for path in
                 (ROOT / "tests/mebane/2026/fixtures").glob("*") if path.name != "config2022.json")
code = [
    "R/lib/mebane_2026_intake.R",
    "R/lib/mebane_data.R",
    "tests/mebane/2026/run_tests.R",
    "tests/mebane/2026/check_dag.py",
    "tests/mebane/data/test_g1.R",
    "tests/test_mebane_gates.py",
    "scripts/mebane_gates.py",
    PREFIX + "freeze_candidate.py",
]
configuration = [
    "config/mebane/2026/intake.json",
    "tests/mebane/2026/fixtures/config2022.json",
    PREFIX + "gate_contract.json",
]
reserved = set(inputs + code + configuration + [PREFIX + "run.json", PREFIX + "candidate_manifest.json"])
outputs = sorted(relative(path) for path in ROUND.rglob("*")
                 if path.is_file() and relative(path) not in reserved)
if len(outputs) < 3 or PREFIX + "implementation.md" not in outputs or \
        PREFIX + "todo_evidence.json" not in outputs or \
        PREFIX + "rehearsal_v6/test_summary.json" not in outputs:
    raise SystemExit("Required outputs absent")
all_paths = inputs + code + configuration + outputs
if len(all_paths) != len(set(all_paths)) or any(not (ROOT / path).is_file() for path in all_paths):
    raise SystemExit("Duplicate or missing inventory path")

run = {
    "gate_id": "G7", "round": "round1", "contract_sha256": contract_hash,
    "executor_id": EXECUTOR, "goal_id": EXECUTOR,
    "goal_status": "active_at_freeze; complete only after candidate delivery",
    "candidate_status": "submitted_for_independent_review_not_gate_pass",
    "created_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
    "dependency_manifests": {"G1": G1_FILES["candidate_manifest.json"]},
    "dependency_approvals": {"G1": {
        "review_sha256": G1_FILES["review/review.json"],
        "adjudication_sha256": G1_FILES["adjudication.json"],
    }},
    "inputs": sorted(inputs), "code": sorted(code),
    "configuration": sorted(configuration), "outputs": outputs,
    "seeds": "none; deterministic fixtures",
    "versions": {"R": "4.4.2", "jsonlite": "2.0.0", "digest": "0.6.37",
                 "data.table": "1.17.0", "python": "python3; checker stdlib"},
    "commands": [
        {"cmd": "LC_ALL=C Rscript tests/mebane/2026/run_tests.R quality_reports/results/mebane_gates/G7/round1/rehearsal_v6",
         "exit_code": 0, "wall_seconds": 0.161801292, "basis": "executed; synthetic 2022-derived fixture"},
        {"cmd": "python3 tests/mebane/2026/check_dag.py",
         "exit_code": 0, "wall_seconds": 8.466982708,
         "basis": "executed; frozen ledger snapshot, 26 checker tests and G6-negative cases"},
        {"cmd": "LC_ALL=C Rscript tests/mebane/data/test_g1.R",
         "exit_code": 0, "wall_seconds": 0.101018042,
         "basis": "executed; existing G1 synthetic fixture"},
    ],
    "exploratory_commands": [
        {"cmd": "LC_ALL=C Rscript tests/mebane/2026/run_tests.R quality_reports/results/mebane_gates/G7/round1/rehearsal",
         "exit_code": 1, "wall_seconds": None, "note": "NULL source_url serialization; old code"},
        {"cmd": "LC_ALL=C Rscript tests/mebane/2026/run_tests.R quality_reports/results/mebane_gates/G7/round1/rehearsal_v2",
         "exit_code": 0, "wall_seconds": 0.083529792, "note": "superseded code/tests"},
        {"cmd": "LC_ALL=C Rscript tests/mebane/2026/run_tests.R quality_reports/results/mebane_gates/G7/round1/rehearsal_v3",
         "exit_code": 0, "wall_seconds": 0.069624458, "note": "superseded code/tests"},
        {"cmd": "LC_ALL=C Rscript tests/mebane/2026/run_tests.R quality_reports/results/mebane_gates/G7/round1/rehearsal_v4",
         "exit_code": 1, "wall_seconds": None, "note": "multi-UF synthetic control mismatch; old code/tests"},
        {"cmd": "LC_ALL=C Rscript tests/mebane/2026/run_tests.R quality_reports/results/mebane_gates/G7/round1/rehearsal_v5",
         "exit_code": 0, "wall_seconds": 0.128390292, "note": "superseded before quoted-code repair"},
    ],
    "limits": [
        "No real 2026 voting file, candidate identity, official section adapter or external attestation was tested.",
        "All receipts remain data_ready=false and inference_ready=false.",
        "G2 engine choice and G6 inference approval are outside G7.",
        "No network download, polling, package install/update or MCMC was performed.",
    ],
}
run_path = ROUND / "run.json"
run_path.write_text(json.dumps(run, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
paths = sorted(set(all_paths + [relative(run_path)]))
manifest = {
    "gate_id": "G7", "round": "round1", "contract_sha256": contract_hash,
    "files": [{"path": path, "sha256": sha(ROOT / path), "bytes": (ROOT / path).stat().st_size}
              for path in paths],
}
(ROUND / "candidate_manifest.json").write_text(
    json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"G7 manifest: {sha(ROUND / 'candidate_manifest.json')} ({len(paths)} files)")
