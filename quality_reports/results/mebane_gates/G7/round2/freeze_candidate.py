"""Freeze a tested G7 round2 candidate; never read the mutable gate ledger."""
import datetime as dt
import difflib
import hashlib
import json
import os
from pathlib import Path
from uuid import UUID

from audit_integrity import audit

ROOT = Path(__file__).resolve().parents[5]
ROUND = Path(__file__).resolve().parent
PREFIX = str(ROUND.relative_to(ROOT)) + "/"

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def read(path):
    return json.loads(path.read_text(encoding="utf-8"))

def dump(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

def relative(path):
    return str(path.relative_to(ROOT))

assert not (ROUND / "run.json").exists() and not (ROUND / "candidate_manifest.json").exists()
executor = os.environ["CODEX_THREAD_ID"]
assert str(UUID(executor)) == executor
checks = audit()
execution = read(ROUND / "executions/final1/execution.json")
diff = []
for change in checks["source_changes"]:
    name = change["path"]
    before = (ROUND / "previous_sources" / name).read_text().splitlines(keepends=True)
    after = (ROOT / name).read_text().splitlines(keepends=True)
    diff.extend(difflib.unified_diff(before, after, fromfile="round1/" + name, tofile="round2/" + name))
(ROUND / "source_changes.patch").write_text("".join(diff), encoding="utf-8")

inputs = [relative(path) for path in (ROUND / "previous_sources").rglob("*") if path.is_file()]
inputs += [
    "quality_reports/results/mebane_gates/G7/round1/candidate_manifest.json",
    "quality_reports/results/mebane_gates/G7/round1/adjudication.json",
    "quality_reports/results/mebane_gates/G7/round1/adjudication.md",
    "quality_reports/results/mebane_gates/G7/round1/review/review.json",
    "quality_reports/results/mebane_gates/G7/round1/review/review_manifest.json",
    "quality_reports/results/mebane_gates/G1/round2/candidate_manifest.json",
    "quality_reports/results/mebane_gates/G1/round2/review/review.json",
    "quality_reports/results/mebane_gates/G1/round2/adjudication.json",
    "quality_reports/results/mebane_gates/G1/round2/gate_contract.json",
    "quality_reports/results/mebane_gates/coordination/tse2026_source_preflight.md",
    "config/mebane/2022.json", PREFIX + "ledger_dag_snapshot.json",
]
inputs += [relative(path) for path in (ROOT / "tests/mebane/2026/fixtures").glob("*")
           if path.is_file() and path.name != "config2022.json"]
code = [
    "R/lib/mebane_2026_intake.R", "R/lib/mebane_data.R",
    "tests/mebane/2026/run_tests.R", "tests/mebane/2026/test_round2.R", "tests/mebane/2026/check_dag.py",
    "tests/mebane/data/test_g1.R", "scripts/mebane_gates.py", "tests/test_mebane_gates.py",
    PREFIX + "prepare_round.py", PREFIX + "run_suite.py", PREFIX + "audit_integrity.py",
    PREFIX + "freeze_candidate.py",
]
configuration = ["config/mebane/2026/intake.json", "tests/mebane/2026/fixtures/config2022.json",
                 PREFIX + "gate_contract.json"]
reserved = set(inputs + code + configuration + [PREFIX + "run.json", PREFIX + "candidate_manifest.json"])
outputs = sorted(relative(path) for path in ROUND.rglob("*")
                 if path.is_file() and relative(path) not in reserved)
inventory = inputs + code + configuration + outputs
assert len(inventory) == len(set(inventory))
assert all((ROOT / path).is_file() for path in inventory)
assert set(execution["code_input_sha256"]).issubset(inventory)
assert all(e["path"] in inventory for todo in read(ROUND / "todo_evidence.json")["todos"]
           for e in todo["evidence"])
run = {
    "gate_id": "G7", "round": "round2", "contract_sha256": checks["contract_sha256"],
    "executor_id": executor, "goal_id": executor,
    "goal_objective": "Finite repair of the three confirmed G7 round1 findings and delivery of round2 candidate",
    "goal_status_at_freeze": "active; complete after verified delivery",
    "candidate_status": "submitted_for_independent_review",
    "created_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
    "dependency_manifests": {"G1": checks["dependency_hashes"]["candidate_manifest.json"]},
    "dependency_approvals": {"G1": {
        "review_sha256": checks["dependency_hashes"]["review/review.json"],
        "adjudication_sha256": checks["dependency_hashes"]["adjudication.json"]}},
    "previous_candidate_manifest_sha256": "62f7a5c4907c9d39b75fe5cd88224bddb4796e015f69f004469e51df7ae493c8",
    "repair_adjudication_sha256": "882d1b4081df7d4443983e5b5709942076030b34f0edf1f18b68d45a6edc122a",
    "repair_findings": ["G7-R1-COORD-F03", "G7-R1-QA-F01", "G7-R1-QA-F02"],
    "repair_status": "implemented and executor-tested; independent verification pending",
    "recovery_map": PREFIX + "recovery_map.json",
    "inputs": sorted(inputs), "code": sorted(code), "configuration": sorted(configuration), "outputs": outputs,
    "commands": [read(ROUND / "preparation_log.json"), *execution["commands"], read(ROUND / "integrity_final.json")],
    "test_execution": PREFIX + "executions/final1/execution.json",
    "exploratory_execution": PREFIX + "executions/trial1/execution.json",
    "executed_code_input_sha256": execution["code_input_sha256"],
    "seeds": "none; deterministic synthetic fixtures",
    "effective_locales": checks["locales"],
    "versions": {"R": "4.4.2", "jsonlite": "2.0.0", "digest": "0.6.37"},
    "limits": [
        "No real 2026 votes or audited raw-file converter; normalized section/candidate CSV only.",
        "Serial ingestion or external lock required; no concurrency guarantee.",
        "Reference-relative completeness only; all data_ready, inference_ready and national_coverage_attested flags false.",
        "T2 calendar date is conditional; candidates remain null and T2 election code is not inferred.",
        "No MCMC, package install, download, polling or national-scale performance test.",
        "Independent QA and adjudication of round2 are pending; this candidate does not approve G7.",
    ],
}
dump(ROUND / "run.json", run)
paths = sorted(inventory + [PREFIX + "run.json"])
manifest = {"gate_id": "G7", "round": "round2", "contract_sha256": checks["contract_sha256"],
            "files": [{"path": path, "sha256": sha(ROOT / path), "bytes": (ROOT / path).stat().st_size}
                      for path in paths]}
dump(ROUND / "candidate_manifest.json", manifest)
print(json.dumps({"manifest_sha256": sha(ROUND / "candidate_manifest.json"), "files": len(paths),
                  "run_sha256": sha(ROUND / "run.json"), "recovery_map_sha256": sha(ROUND / "recovery_map.json"),
                  "contract_sha256": checks["contract_sha256"]}))
