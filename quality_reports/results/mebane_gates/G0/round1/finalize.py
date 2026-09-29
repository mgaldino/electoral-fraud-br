"""Freeze the static G0 contract, run declaration, and candidate manifest."""

import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[5]
ROUND = Path(__file__).resolve().parent
PREFIX = ROUND.relative_to(ROOT).as_posix()
EXECUTOR_ID = "01a0eaba-2cec-74f3-bca0-8c27b736567e"


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


final_state_map = json.loads((ROUND / "final_state_map.json").read_text(encoding="utf-8"))
snapshots = {item["original"]: item["snapshot"] for item in final_state_map}
plan = json.loads((ROOT / snapshots["quality_reports/plans/mebane_2022_2026_gates.json"]).read_text(encoding="utf-8"))
gate = next(gate for gate in plan["gates"] if gate["id"] == "G0")
contract = {key: value for key, value in gate.items() if key not in ("status", "records")}
contract["todos"] = [{key: value for key, value in todo.items() if key not in ("status", "evidence")}
                     for todo in gate["todos"]]
canonical = json.dumps(contract, sort_keys=True, ensure_ascii=False, separators=(",", ":"))
contract_sha = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
write_json(ROUND / "gate_contract.json", contract)

inventory = json.loads((ROUND / "inventory.json").read_text(encoding="utf-8"))
by_category = {}
for item in inventory["items"]:
    by_category.setdefault(item["category"], []).append(item["path"])
inputs = sorted(sum((by_category.get(category, []) for category in
                    ("raw", "processed", "stan_chains", "fits", "logs", "pdf")), []))
inputs += [
    "quality_reports/results/mebane_gates/coordination/pm23_2023-07-02.pdf",
    "quality_reports/results/mebane_gates/coordination/measfrauds_2022-03-06.pdf",
    snapshots["quality_reports/results/mebane_gates/coordination/method_sources_download.md"],
]
inputs.sort()
code = sorted([snapshots[path] for path in by_category.get("code", [])] + [
    snapshots["scripts/mebane_gates.py"],
    *[f"{PREFIX}/{name}" for name in
      ("inventory.py", "check_loads.R", "propose_lock.R", "merge_lock.py",
       "snapshot_sources.py", "snapshot_final.py", "finalize.py", "ef_models_3017de5.R")],
])
configuration_original = (set(by_category.get("configuration", [])) - {"scripts/mebane_gates.py"}) | {
    "quality_reports/results/2026-09-28_gate_design/implementation_checker_round2.md",
    "quality_reports/results/2026-09-28_gate_design/implementation_checker_round3.md",
}
configuration = sorted(snapshots[path] for path in configuration_original)
outputs = sorted(path.relative_to(ROOT).as_posix() for path in ROUND.rglob("*")
                 if path.is_file() and path.name not in ("run.json", "candidate_manifest.json")
                 and path.relative_to(ROOT).as_posix() not in code)
environment = json.loads((ROUND / "loads_environment.json").read_text(encoding="utf-8"))
run = {
    "gate_id": "G0", "round": "round1", "contract_sha256": contract_sha,
    "executor_id": EXECUTOR_ID, "executor_role": "SOL-BASELINE",
    "goal_id": EXECUTOR_ID,
    "goal_objective": "Entregar candidato verificavel G0 para revisao independente",
    "requested_model": "gpt-6-sol", "requested_effort": "high",
    "effective_model": "not_exposed_by_runtime", "effective_effort": "not_exposed_by_runtime",
    "started_at_utc": datetime.fromtimestamp(1790644477, timezone.utc).isoformat(),
    "finished_at_utc": datetime.now(timezone.utc).isoformat(),
    "dependency_manifests": {}, "dependency_approvals": {},
    "inputs": inputs, "code": code, "configuration": configuration, "outputs": outputs,
    "baseline_snapshots": final_state_map,
    "seeds": [],
    "versions": {
        "R": environment["r_version"], "JAGS": "4.3.2 (CLI welcome banner)",
        "eforensics": "0.0.4", "eforensics_RemoteSha": "3017de537450f97a01872d0157462a68bea348ee",
        "rjags": environment["package_info"]["rjags"]["version"],
        "cmdstanr": environment["package_info"]["cmdstanr"]["version"],
        "CmdStan": environment["cmdstan"]["version"],
    },
    "commands": [
        {"command": "python3 quality_reports/results/mebane_gates/G0/round1/inventory.py", "exit_code": 0, "wall_seconds_last_run": 11.75, "effect": "inventory, ZIP/PDF checks and hashes"},
        {"command": "Rscript --vanilla quality_reports/results/mebane_gates/G0/round1/propose_lock.R", "exit_code": 0, "wall_seconds": 0.68, "effect": "installed_records.lock and gap report; no install"},
        {"command": "python3 quality_reports/results/mebane_gates/G0/round1/merge_lock.py", "exit_code": 0, "wall_seconds": 0.01, "effect": "append 49 missing records to renv.lock"},
        {"command": "python3 quality_reports/results/mebane_gates/G0/round1/snapshot_sources.py", "exit_code": 0, "wall_seconds": 0.01, "effect": "14 pre-edit canonical snapshots"},
        {"command": "Rscript --vanilla quality_reports/results/mebane_gates/G0/round1/check_loads.R", "exit_code": 0, "wall_seconds_last_run": 1.03, "effect": "readRDS, read_parquet, package probe, qbl comparison"},
        {"command": "Rscript --vanilla -e '<installed Depends/Imports/LinkingTo closure versus lock>'", "exit_code": 0, "wall_seconds": 0.08, "effect": "110 required packages, zero missing lock entries"},
        {"command": "pdfinfo ssrn-4073770.pdf.download/ssrn-4073770.pdf", "exit_code": 1, "wall_seconds": 0.01, "effect": "partial PDF rejected"},
        {"command": "curl -IL https://websites.umich.edu/~wmebane/pm23.pdf", "exit_code": 0, "http_status": 403, "wall_seconds": 5.4, "effect": "primary PDF bytes inaccessible; no SHA assigned"},
        {"command": "curl -fsSL https://api.github.com/repos/UMeforensics/eforensics_public/commits/3017de537450f97a01872d0157462a68bea348ee -o <round>/eforensics_commit_api.json", "exit_code": 0, "wall_seconds": 3.4},
        {"command": "curl -fsSL https://raw.githubusercontent.com/UMeforensics/eforensics_public/3017de537450f97a01872d0157462a68bea348ee/R/ef_models.R -o <round>/ef_models_3017de5.R", "exit_code": 0, "wall_seconds": 3.9},
        {"command": "pdfinfo <coordination>/pm23_2023-07-02.pdf; pdfinfo <coordination>/measfrauds_2022-03-06.pdf", "exit_codes": [0, 0], "effect": "105 and 75 pages; PDF structure valid"},
        {"command": "pdftotext -f 1 -l 1 <coordination>/<each primary PDF> -", "exit_codes": [0, 0], "effect": "first-page titles and version dates checked"},
        {"command": "shasum -a 256 <coordination>/<both primary PDFs>", "exit_code": 0, "effect": "coordinator hashes independently matched"},
    ],
    "limits": [
        "No MCMC, G1 full-data transformation, rank-normalized diagnostics, or cold renv::restore was run.",
        "Initial Michigan host returned HTTP 403/challenge; primary PDFs were later downloaded from public.websites.umich.edu and pinned by local SHA-256.",
        "One .download PDF is incomplete and excluded as a valid source.",
        "JAGS and CmdStan are external system dependencies not restored by renv.lock.",
        "Only first-page metadata and PDF integrity were checked for the two primary papers; substantive mathematical review belongs to G2.",
    ],
}
write_json(ROUND / "run.json", run)

paths = sorted(set(inputs + code + configuration + outputs + [f"{PREFIX}/run.json"]))
assert f"{PREFIX}/gate_contract.json" in paths
assert f"{PREFIX}/candidate_manifest.json" not in paths
files = []
for relative in paths:
    path = ROOT / relative
    assert path.is_file(), relative
    files.append({"path": relative, "sha256": sha256(path), "bytes": path.stat().st_size})
manifest = {"gate_id": "G0", "round": "round1", "contract_sha256": contract_sha,
            "files": files}
write_json(ROUND / "candidate_manifest.json", manifest)
print(f"contract_sha256={contract_sha} manifest_sha256={sha256(ROUND / 'candidate_manifest.json')} files={len(files)}")
