"""Round2 packaging only. Mathematical computations live in separate R scripts."""
import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[5]
HERE = Path(__file__).resolve().parent
OLD = HERE.parent / "round1"
APPENDIX = "appendices/mebane_model_contract.md"
EXECUTOR = "01a0eaee-01df-7773-bd63-d321db26a47c"
G0_HASHES = {
    "candidate_manifest.json": "f71333db477385fc78dad8a7a1a7ca78e48479226dcdbde80ce97d724409fec7",
    "review/review.json": "ef624cb4b2d8ad098b87e196d87add358ce1eba93165d44fcc1939ff303f5376",
    "adjudication.json": "ea1b4905fdfa14f6e3f36c41974ea948ba0c39d1f81f87d6eaf479782216267b",
}


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def write(path, value):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def now():
    return datetime.now(timezone.utc).isoformat()


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def relative(path):
    return str(Path(path).relative_to(ROOT))


def canonical(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, ensure_ascii=False,
                                    separators=(",", ":")).encode("utf-8")).hexdigest()


def entry(path):
    path = Path(path)
    return {"path": relative(path), "sha256": sha(path), "bytes": path.stat().st_size}


def assert_entry(item, path=None):
    path = Path(path) if path else ROOT / item["path"]
    assert sha(path) == item["sha256"], f"Hash mismatch: {path}"
    if "bytes" in item:
        assert path.stat().st_size == item["bytes"], f"Size mismatch: {path}"


def prepare():
    assert not (HERE / "round1_recovery_map.json").exists(), "Preparation already frozen"
    ledger = read(ROOT / "quality_reports/plans/mebane_2022_2026_gates.json")
    gates = {gate["id"]: gate for gate in ledger["gates"]}
    assert gates["G0"]["status"] == "pass"
    g0 = ROOT / "quality_reports/results/mebane_gates/G0/round2"
    for path, expected in G0_HASHES.items():
        assert sha(g0 / path) == expected
    assert gates["G0"]["records"]["candidate_manifest"] == relative(g0 / "candidate_manifest.json")
    for key, path in (("review", "review/review.json"), ("adjudication", "adjudication.json")):
        assert gates["G0"]["records"][key] == relative(g0 / path)
        assert read(g0 / path)["status"] == "pass"
    contract = copy.deepcopy(gates["G2"])
    for key in ("status", "records"):
        contract.pop(key, None)
    for todo in contract["todos"]:
        for key in ("status", "evidence"):
            todo.pop(key, None)
    assert contract == read(OLD / "gate_contract.json"), "G2 static contract changed"
    candidates = [OLD / "candidate_manifest.json", OLD / "review/review_manifest.json"]
    for manifest in candidates:
        for item in read(manifest)["files"]:
            assert_entry(item)
    snapshot = HERE / "inherited/appendix_round1.md"
    snapshot.parent.mkdir(parents=True, exist_ok=True)
    assert not snapshot.exists()
    shutil.copyfile(ROOT / APPENDIX, snapshot)
    assert sha(snapshot) == sha(ROOT / APPENDIX)
    mapping = {
        "created_at_utc": now(), "gate_id": "G2", "round": "round2",
        "purpose": "Read-only path substitution for historical verification; never rewrite old manifests or restore over the current appendix automatically.",
        "original_manifest_files": [entry(p) for p in candidates],
        "old_adjudication": entry(OLD / "adjudication.json"),
        "replacements": [{"original_path": APPENDIX, "snapshot_path": relative(snapshot),
                          "sha256": sha(snapshot), "bytes": snapshot.stat().st_size}],
        "recovery": "Resolve original_path to snapshot_path only when verifying round1; the original appendix bytes are the snapshot. Any actual restoration is a separate authorized operation.",
    }
    write(HERE / "round1_recovery_map.json", mapping)
    inherited = {}
    for manifest in candidates:
        for item in read(manifest)["files"]:
            path = snapshot if item["path"] == APPENDIX else ROOT / item["path"]
            inherited[relative(path)] = entry(path)
    for path in candidates + sorted(OLD.glob("adjudication*")):
        if path.is_file():
            inherited[relative(path)] = entry(path)
    write(HERE / "inherited_evidence.json", {
        "basis": "historical; hashes rechecked in round2; prior tests not rerun",
        "files": sorted(inherited.values(), key=lambda item: item["path"]),
    })
    write(HERE / "protected_round1_inventory.json", {
        "files": [entry(path) for path in sorted(OLD.rglob("*")) if path.is_file()]
    })
    shutil.copyfile(OLD / "gate_contract.json", HERE / "gate_contract.json")
    write(HERE / "results/contract_projection_check.json", {
        "matches_current_static_projection": True, "contract_sha256": canonical(contract),
        "mutable_ledger_excluded": True, "checked_at_utc": now(),
        "dependency_manifests": {"G0": G0_HASHES["candidate_manifest.json"]},
        "dependency_approvals": {"G0": {
            "review_sha256": G0_HASHES["review/review.json"],
            "adjudication_sha256": G0_HASHES["adjudication.json"]}},
    })
    check_inheritance(save=True)


def check_inheritance(save=False):
    mapping = read(HERE / "round1_recovery_map.json")
    replacement = {item["original_path"]: ROOT / item["snapshot_path"] for item in mapping["replacements"]}
    reports = []
    for manifest in mapping["original_manifest_files"]:
        assert_entry(manifest)
        entries = read(ROOT / manifest["path"])["files"]
        for item in entries:
            assert_entry(item, replacement.get(item["path"], ROOT / item["path"]))
        reports.append({"manifest": manifest["path"], "sha256": manifest["sha256"],
                        "files_verified": len(entries), "pass": True})
    for name in ("inherited_evidence.json", "protected_round1_inventory.json"):
        for item in read(HERE / name)["files"]:
            assert_entry(item)
    assert_entry(mapping["old_adjudication"])
    result = {"checked_at_utc": now(), "status": "pass", "scope": "byte integrity only, not gate approval",
              "manifests": reports, "appendix_resolved_to_snapshot": True,
              "protected_round1_files": len(read(HERE / "protected_round1_inventory.json")["files"])}
    if save:
        write(HERE / "results/inheritance_check.json", result)
    print(json.dumps(result, ensure_ascii=False))
    return result


def run_command(argv):
    assert argv, "Missing command"
    assert not (HERE / "candidate_manifest.json").exists(), "Candidate is sealed"
    commands_path = HERE / "commands.json"
    commands = read(commands_path) if commands_path.exists() else []
    output = HERE / f"results/command_{len(commands) + 1:02}.log"
    output.parent.mkdir(exist_ok=True)
    started = now()
    timer = time.monotonic()
    result = subprocess.run(argv, cwd=ROOT, env={**os.environ, "LC_ALL": "C"},
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    output.write_bytes(result.stdout)
    commands.append({"argv": argv, "started_at_utc": started,
                     "elapsed_seconds": time.monotonic() - timer,
                     "exit_code": result.returncode, "environment_override": {"LC_ALL": "C"},
                     "log": relative(output)})
    write(commands_path, commands)
    sys.stdout.buffer.write(result.stdout)
    assert result.returncode == 0, f"Command failed: {argv}"


def freeze_interface():
    discovery = ROOT / "quality_reports/results/mebane_gates/coordination/authors_replication_discovery"
    manifest = read(discovery / "source_manifest.json")
    selected = next(item for item in manifest["pertinent_extracted_members"] if item["path"].endswith("/R/ef_main.R"))
    primary = discovery / selected["path"]
    assert sha(primary) == selected["sha256"] == "ee626c0c939f84567c0ee74a100954229567911711193716a46837e1d6e3ce8b"
    sources = HERE / "sources"
    sources.mkdir(exist_ok=True)
    for original, name in ((primary, "ef_main_3017de5.R"), (discovery / "source_manifest.json", "discovery_source_manifest.json")):
        target = sources / name
        assert not target.exists(), "Interface source already frozen"
        shutil.copyfile(original, target)
    baseline = ROOT / "quality_reports/results/mebane_gates/G0/round1/final_state/R"
    paths = [baseline / name for name in ("05_eforensics_umeforensics_qbl.R", "07_brasil_full_qbl.R", "05_eforensics_qbl_fresh_diagnostic.R", "05_jags_qbl_zone_fe.R")]
    # Only G0 snapshots are retained as script evidence, never a mutable production input.
    old_files = {item["path"]: item for item in read(ROOT / "quality_reports/results/mebane_gates/G0/round1/candidate_manifest.json")["files"]}
    for path in paths:
        assert_entry(old_files[relative(path)])
    write(HERE / "interface_sources.json", {
        "basis": "primary archived source and G0 script snapshots inspected in round2; no fitting code executed",
        "primary_origin": entry(primary),
        "discovery_manifest_origin": entry(discovery / "source_manifest.json"),
        "source_manifest_note": "Full source-manifest snapshot retained only for provenance of ef_main.R; other discovered applications are not evidence adopted by G2.",
        "files": [entry(primary)] + [entry(path) for path in paths] + [entry(path) for path in sorted(sources.iterdir())],
    })
    print(json.dumps({"primary_sha256": sha(primary), "snapshot": relative(sources / "ef_main_3017de5.R")}, indent=2))


def seal():
    assert not (HERE / "candidate_manifest.json").exists(), "Refuse to overwrite sealed manifest"
    check_inheritance(save=True)
    benchmark = read(HERE / "benchmark_contract.json")
    projection = read(HERE / "results/contract_projection_check.json")
    assert benchmark["inferential_approval"] is False
    for source in (benchmark["baseline"]["qbl"], benchmark["baseline"]["qbl_R_source"]):
        assert_entry(source)
    assert sha(ROOT / benchmark["wrapper_interface"]["primary_source"]) == benchmark["wrapper_interface"]["primary_sha256"]
    assert all(todo["status"] == "done" for todo in read(HERE / "todo_evidence.json")["todos"])
    current = next(g for g in read(ROOT / "quality_reports/plans/mebane_2022_2026_gates.json")["gates"] if g["id"] == "G2")
    current = copy.deepcopy(current)
    for key in ("status", "records"):
        current.pop(key, None)
    for todo in current["todos"]:
        for key in ("status", "evidence"):
            todo.pop(key, None)
    assert canonical(current) == projection["contract_sha256"], "Live G2 static contract changed during round2"
    write(HERE / "results/final_contract_check.json", {
        "checked_at_utc": now(), "matches_current_static_projection": True,
        "contract_sha256": canonical(current), "ledger_included_in_manifest": False,
        "consumed_baseline_and_interface_hashes_verified": True,
        "todos_complete_candidate_only": True,
    })
    import csv
    with (HERE / "results/round2_checks.csv").open() as stream:
        checks = list(csv.DictReader(stream))
    assert checks and all(item["pass"] == "TRUE" for item in checks)
    files = {item["path"]: item for item in read(HERE / "inherited_evidence.json")["files"]}
    for item in read(HERE / "interface_sources.json")["files"]:
        assert_entry(item)
        files[item["path"]] = item
    files[APPENDIX] = entry(ROOT / APPENDIX)
    test = ROOT / "tests/mebane/algebra/test_benchmark_round2.R"
    files[relative(test)] = entry(test)
    for path in HERE.rglob("*"):
        if path.is_file() and path.name not in ("candidate_manifest.json", "run.json") and "__pycache__" not in path.parts:
            files[relative(path)] = entry(path)
    inherited_paths = read(HERE / "inherited_evidence.json")["files"] + read(HERE / "interface_sources.json")["files"]
    code = [p for p in files if p.endswith((".R", ".py", ".lua", ".jags", ".stan"))]
    config = [relative(HERE / name) for name in ("gate_contract.json", "benchmark_contract.json", "round1_recovery_map.json")]
    inputs = sorted({item["path"] for item in inherited_paths if item["path"] not in code})
    outputs = [p for p in files if p not in code + config + inputs]
    run = {
        "gate_id": "G2", "round": "round2", "contract_sha256": projection["contract_sha256"],
        "executor_id": EXECUTOR, "executor_role": "METODO-PRINCIPAL", "goal_id": EXECUTOR,
        "goal_created_at_unix": 1790685977, "goal_scope": "finite candidate delivery, not gate approval",
        "requested_model": "inherit", "requested_effort": "xhigh",
        "effective_model": "unknown_not_exposed_by_runtime", "effective_effort": "unknown_not_exposed_by_runtime",
        "candidate_created_at_utc": now(), "outcome": "decisions_authorized_candidate_pending_independent_QA",
        "gate_approved": False, "inferential_approval": False, "independent_review_obtained_for_round2": False,
        "historical_round1_independent_rederivation_obtained": True,
        "dependency_manifests": projection["dependency_manifests"],
        "dependency_approvals": projection["dependency_approvals"],
        "inputs": sorted(inputs), "code": sorted(code), "configuration": config, "outputs": sorted(outputs),
        "benchmark_contract_canonical_sha256": canonical(benchmark),
        "benchmark_contract_file_sha256": sha(HERE / "benchmark_contract.json"),
        "literal_benchmark_input": entry(ROOT / benchmark["baseline"]["qbl"]["path"]),
        "commands": read(HERE / "commands.json"), "rng": "none; deterministic fixtures", "seeds": [],
        "tests": {"round2_passed": len(checks), "round2_total": len(checks),
                  "round1_evidence": "inherited by direct hashes, not reexecuted"},
        "executed_code": [relative(test), "tests/mebane/algebra/qbl_algebra.R", relative(HERE / "candidate_tools.py")],
        "production_code_execution": "none", "MCMC": "not run", "engine_version": "JAGS 4.3.2 required; runtime not probed in round2",
        "PDF": "no new PDF, per updated user instruction; consolidated PDF assigned to coordinator",
        "write_scope_used": [APPENDIX, relative(test), relative(HERE) + "/"],
        "pending": ["independent round2 review and coordinator adjudication", "G3 JAGS invalid-parent runtime tests", "G4 production geography decision before G6", "G10 author replication by separate assigned agent before G4"],
    }
    write(HERE / "run.json", run)
    files[relative(HERE / "run.json")] = entry(HERE / "run.json")
    manifest = {"gate_id": "G2", "round": "round2", "contract_sha256": projection["contract_sha256"],
                "executor_id": EXECUTOR, "files": sorted(files.values(), key=lambda x: x["path"])}
    write(HERE / "candidate_manifest.json", manifest)
    verify()


def verify():
    manifest = read(HERE / "candidate_manifest.json")
    run = read(HERE / "run.json")
    for item in manifest["files"]:
        assert_entry(item)
    assert canonical(read(HERE / "gate_contract.json")) == manifest["contract_sha256"] == run["contract_sha256"]
    paths = {item["path"] for item in manifest["files"]}
    assert len(paths) == len(manifest["files"])
    for key in ("inputs", "code", "configuration", "outputs"):
        assert set(run[key]) <= paths
    assert not any("mebane_2022_2026_gates.json" in p for p in paths)
    assert run["benchmark_contract_canonical_sha256"] == canonical(read(HERE / "benchmark_contract.json"))
    assert run["benchmark_contract_file_sha256"] == sha(HERE / "benchmark_contract.json")
    for path, expected in G0_HASHES.items():
        assert sha(ROOT / "quality_reports/results/mebane_gates/G0/round2" / path) == expected
    check_inheritance(save=False)
    print(json.dumps({"status": "pass", "scope": "candidate integrity, not QA or gate approval",
                      "files": len(paths), "candidate_manifest_sha256": sha(HERE / "candidate_manifest.json"),
                      "run_sha256": sha(HERE / "run.json"),
                      "benchmark_contract_sha256": sha(HERE / "benchmark_contract.json")}, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=("prepare", "freeze-interface", "check-inheritance", "run", "seal", "verify"))
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if args.action == "run":
        run_command(args.command[1:] if args.command[:1] == ["--"] else args.command)
    elif args.action == "check-inheritance":
        check_inheritance(save=not (HERE / "candidate_manifest.json").exists())
    else:
        {"prepare": prepare, "freeze-interface": freeze_interface, "seal": seal, "verify": verify}[args.action]()
