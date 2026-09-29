"""Freeze G1 round2 using the reviewed static contract, with no live ledger input."""
import hashlib
import json
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

ROUND = Path(__file__).resolve().parent
ROOT = ROUND.parents[4]
PREFIX = str(ROUND.relative_to(ROOT))
OLD = "quality_reports/results/mebane_gates/G1/round1"
CONTRACT_SOURCE = f"{OLD}/gate_contract.json"
CONTRACT_FILE_SHA = "2364acc589da079d44687c79c9fb35561816cfe7fd34ad7431f7c18386c1ae4d"
CONTRACT_SHA = "f985ab97469aa66755b977a09781b30608afa6e245896d9d9788b4461190975d"
EXECUTOR = "01a0eaee-0164-7530-884d-adec564a8327"
DEPENDENCIES = {
    "quality_reports/results/mebane_gates/G0/round2/candidate_manifest.json": "f71333db477385fc78dad8a7a1a7ca78e48479226dcdbde80ce97d724409fec7",
    "quality_reports/results/mebane_gates/G0/round2/review/review.json": "ef624cb4b2d8ad098b87e196d87add358ce1eba93165d44fcc1939ff303f5376",
    "quality_reports/results/mebane_gates/G0/round2/adjudication.json": "ea1b4905fdfa14f6e3f36c41974ea948ba0c39d1f81f87d6eaf479782216267b",
}


def canonical_sha(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, ensure_ascii=False,
                                    separators=(",", ":")).encode("utf-8")).hexdigest()


def read_contract(path, file_sha=CONTRACT_FILE_SHA, contract_sha=CONTRACT_SHA):
    content = path.read_bytes()
    if hashlib.sha256(content).hexdigest() != file_sha:
        raise RuntimeError("Static contract file hash changed")
    contract = json.loads(content)
    if canonical_sha(contract) != contract_sha:
        raise RuntimeError("Static contract canonical hash changed")
    if any(key in contract for key in ("status", "records")) or any(
            any(key in todo for key in ("status", "evidence")) for todo in contract["todos"]):
        raise RuntimeError("Static contract contains mutable fields")
    return content, contract


def sha(path):
    with path.open("rb") as handle:
        return hashlib.file_digest(handle, "sha256").hexdigest()


def load(relative):
    return json.loads((ROOT / relative).read_text())


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def check_candidate():
    run = load(f"{PREFIX}/run.json")
    manifest = load(f"{PREFIX}/candidate_manifest.json")
    included = {item["path"] for item in manifest["files"]}
    read_contract(ROUND / "gate_contract.json")
    if run["contract_sha256"] != CONTRACT_SHA or manifest["contract_sha256"] != CONTRACT_SHA:
        raise RuntimeError("Candidate contract binding differs")
    if CONTRACT_SOURCE not in run["inputs"]:
        raise RuntimeError("Static contract input omitted")
    for field in ("inputs", "code", "configuration", "outputs"):
        if not set(run[field]).issubset(included):
            raise RuntimeError(f"Manifest omits declared {field}")
    for item in manifest["files"]:
        path = ROOT / item["path"]
        if sha(path) != item["sha256"] or path.stat().st_size != item["bytes"]:
            raise RuntimeError(f"Stale candidate file: {path}")
    print(f"PASS: {len(included)} file hashes/sizes, static contract and path closure verified.")
    print(f"candidate_manifest_sha256={sha(ROUND / 'candidate_manifest.json')}")


def main():
    if len(sys.argv) == 2 and sys.argv[1] == "--check":
        check_candidate()
        return
    if len(sys.argv) != 1:
        raise SystemExit("Usage: freeze_candidate.py [--check]")
    if (ROUND / "run.json").exists() or (ROUND / "candidate_manifest.json").exists():
        raise RuntimeError("Candidate already frozen; refusing overwrite")
    started = datetime.now(timezone.utc).isoformat()
    t0 = time.monotonic()
    contract_bytes, contract = read_contract(ROOT / CONTRACT_SOURCE)
    (ROUND / "gate_contract.json").write_bytes(contract_bytes)
    old_manifest = load(f"{OLD}/candidate_manifest.json")
    if sha(ROOT / f"{OLD}/candidate_manifest.json") != "009e0fd39f8ab495e52fcb214476fcc7b6095f895381006a924df6a2ffbd7003":
        raise RuntimeError("Reviewed manifest changed")
    snapshot_map = load(f"{PREFIX}/previous_candidate_sources_map.json")
    before = load(f"{PREFIX}/round1_tree_before.json")
    preservation = load(f"{PREFIX}/checks/round1_preservation.json")
    if not preservation["previous_round_tree_unchanged"] or not preservation["reviewed_bytes_recoverable"]:
        raise RuntimeError("Preservation did not pass")
    snapshots = {item["original_path"]: item["snapshot_path"] for item in snapshot_map["files"]}
    inputs = {snapshots.get(item["path"], item["path"]) for item in old_manifest["files"]}
    inputs.update(item["path"] for item in before["files"])
    inputs.update(item["path"] for item in preservation["coordinator_additions_since_initial_snapshot"])
    inputs.update([CONTRACT_SOURCE, f"{OLD}/candidate_manifest.json",
                   f"{PREFIX}/previous_candidate_sources_map.json", f"{PREFIX}/round1_tree_before.json"])
    inputs.update(DEPENDENCIES)
    for path, expected in DEPENDENCIES.items():
        if sha(ROOT / path) != expected:
            raise RuntimeError(f"G0 dependency changed: {path}")
    code = ["R/01_load_tse.R", "R/02_build_vars.R", "R/lib/mebane_data.R",
            "tests/mebane/data/test_g1.R", "tests/mebane/data/check_official_histories.R",
            "tests/mebane/data/check_official_munzona.R", "tests/mebane/data/check_replay.R",
            "tests/mebane/data/test_round2_repairs.R", "tests/mebane/data/check_round2_identity_sources.R",
            "tests/mebane/data/check_round1_invariance.R", "tests/mebane/data/test_round2_freeze.py"]
    code.extend(str(path.relative_to(ROOT)) for path in sorted(ROUND.iterdir())
                if path.suffix in (".py", ".R") and path.is_file())
    configuration = ["config/mebane/2022.json", f"{PREFIX}/gate_contract.json"]
    records = [json.loads(path.read_text()) for path in sorted((ROUND / "logs").glob("*.json"))]
    if any(record["exit_code"] != 0 for record in records):
        raise RuntimeError("An executed check failed; candidate cannot be frozen as complete")
    runtime = load(f"{PREFIX}/checks/runtime.json")
    freeze_record = {
        "command": ["python3", f"{PREFIX}/freeze_candidate.py"],
        "scope": "Freeze candidate from the exact reviewed static contract and declared local artifacts",
        "started_at_utc": started, "validation_finished_at_utc": datetime.now(timezone.utc).isoformat(),
        "elapsed_validation_seconds": round(time.monotonic() - t0, 6),
        "contract_input": CONTRACT_SOURCE, "contract_file_sha256": CONTRACT_FILE_SHA,
        "contract_sha256": CONTRACT_SHA, "uses_mutable_ledger": False,
    }
    save(ROUND / "checks" / "freeze_record.json", freeze_record)
    outputs = [str(path.relative_to(ROOT)) for path in sorted(ROUND.rglob("*"))
               if path.is_file() and str(path.relative_to(ROOT)) not in set(code + configuration) | inputs
               and path.name not in ("run.json", "candidate_manifest.json")
               and "__pycache__" not in path.parts]
    fields = {"inputs": sorted(inputs), "code": sorted(code),
              "configuration": configuration, "outputs": outputs}
    all_paths = sorted(set(sum(fields.values(), [])))
    if any(path == "quality_reports/plans/mebane_2022_2026_gates.json" for path in all_paths):
        raise RuntimeError("Mutable ledger must not be a dependency")
    hashes = {path: sha(ROOT / path) for path in all_paths}
    run = {
        "gate_id": "G1", "round": "round2", "contract_sha256": CONTRACT_SHA,
        "executor_id": EXECUTOR, "goal_id": EXECUTOR,
        "goal_created_at_unix": 1790650105,
        "requested_model": contract["executor"]["model"],
        "requested_effort": contract["executor"]["effort"],
        "effective_model": None, "effective_effort": None,
        "findings_addressed": ["G1-R1-QAD-F01", "G1-R1-QAD-F02", "G1-R1-COORD-F03"],
        "dependency_manifests": {"G0": DEPENDENCIES["quality_reports/results/mebane_gates/G0/round2/candidate_manifest.json"]},
        "dependency_approvals": {"G0": {
            "review_sha256": DEPENDENCIES["quality_reports/results/mebane_gates/G0/round2/review/review.json"],
            "adjudication_sha256": DEPENDENCIES["quality_reports/results/mebane_gates/G0/round2/adjudication.json"],
        }},
        **fields,
        "component_sha256": {field: {path: hashes[path] for path in paths} for field, paths in fields.items()},
        "commands": sorted(records, key=lambda item: item["started_at_utc"]),
        "freeze": freeze_record, "runtime": runtime, "seeds": None,
        "scope": "Repair validation and provenance only; no data recoding, model estimation or 2026 configuration.",
        "previous_sources": f"{PREFIX}/previous_candidate_sources_map.json",
    }
    save(ROUND / "run.json", run)
    all_paths.append(f"{PREFIX}/run.json")
    hashes[f"{PREFIX}/run.json"] = sha(ROUND / "run.json")
    manifest = {
        "gate_id": "G1", "round": "round2", "contract_sha256": CONTRACT_SHA,
        "files": [{"path": path, "sha256": hashes[path], "bytes": (ROOT / path).stat().st_size}
                  for path in sorted(all_paths)],
    }
    save(ROUND / "candidate_manifest.json", manifest)
    print(f"Frozen G1 round2: {len(all_paths)} files; {len(records)} recorded successful commands.")
    print(f"candidate_manifest_sha256={sha(ROUND / 'candidate_manifest.json')}")


if __name__ == "__main__":
    main()
