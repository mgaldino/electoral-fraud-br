#!/usr/bin/env python3
"""Freeze and verify the bounded G0 round4 construction-input repair."""

import argparse
import datetime as dt
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import sys


HERE = Path(__file__).resolve().parent
ROOT = Path(__file__).resolve().parents[5]
R3 = Path("quality_reports/results/mebane_gates/G0/round3")
R4 = Path("quality_reports/results/mebane_gates/G0/round4")
COORD = Path("quality_reports/results/mebane_gates/coordination/2026-09-29_inventory_rebaseline")
BEFORE = COORD / "before/quality_reports/plans/mebane_2022_2026_gates.json"
BEFORE_SHA = "f32c2a1fbb40e29fe8a52944969222ce67a7581f516149c7a27cd57d5019eb66"
CHECKER = Path("quality_reports/results/mebane_gates/G0/round1/final_state/scripts/mebane_gates.py")
CHECKER_SHA = "15601b30477b940bda011a7370d3a2edc269c7ffd89fe92e09d8dd9d34a93480"
DECISION = COORD / "decision.md"
DECISION_SHA = "fe62bfd30ffd6e985a6070fb6f575770e5097f6c96de543eed145df3df75007a"
REVIEW = R3 / "review/review.json"
REVIEW_SHA = "058f951892a72fd8b76b6d811c22c614aa12fc57d01ce923f2aeae95d6e0dcc7"
OLD_MANIFEST_SHA = "42406b1ecb8ee843c95ef75a902ab15e6468c7bb7900b5ac8717d6476afd08bf"
ABSENT = "ssrn-4073770.pdf.download/ssrn-4073770.pdf"
INFO = "ssrn-4073770.pdf.download/Info.plist"
EXECUTOR = "01a0edcd-cd1f-70f0-b9f5-95fb470b6c40"
GENERATED = ("gate_contract.json", "inventory_current.json", "tombstone.json",
             "todo_evidence.json", "implementation.md", "run.json", "candidate_manifest.json")


def checked_path(value):
    path = Path(value)
    if path.is_absolute() or not path.parts or ".." in path.parts:
        raise ValueError(f"unsafe path: {value}")
    file = ROOT / path
    if not file.resolve().is_relative_to(ROOT) or not file.is_file() or file.is_symlink():
        raise ValueError(f"missing or unsafe file: {value}")
    return file


def file_record(value):
    hash_ = hashlib.sha256()
    size = 0
    with checked_path(value).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            hash_.update(block)
            size += len(block)
    return {"path": str(value), "sha256": hash_.hexdigest(), "bytes": size}


def read_json(value):
    return json.loads(checked_path(value).read_text(encoding="utf-8"))


def write_json(name, value):
    (HERE / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def checker_module():
    if file_record(CHECKER)["sha256"] != CHECKER_SHA:
        raise ValueError("archived checker changed")
    spec = importlib.util.spec_from_file_location("mebane_gates_frozen_g0r4", checked_path(CHECKER))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def static_gate(gate):
    static = {key: value for key, value in gate.items() if key not in {"status", "records"}}
    static["todos"] = [
        {key: value for key, value in todo.items() if key not in {"status", "evidence"}}
        for todo in gate["todos"]
    ]
    return static


def canonical_sha(value):
    encoded = json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(",", ":"))
    return hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def source_preflight():
    for path, expected in ((BEFORE, BEFORE_SHA), (DECISION, DECISION_SHA), (REVIEW, REVIEW_SHA)):
        if file_record(path)["sha256"] != expected:
            raise ValueError(f"source changed: {path}")
    if file_record(R3 / "candidate_manifest.json")["sha256"] != OLD_MANIFEST_SHA:
        raise ValueError("round3 manifest changed")
    review = read_json(REVIEW)
    adjud = read_json(COORD / "adjudication_build_input.json")
    if [item["id"] for item in review["findings"]] != ["G0-R3-QA-F01"]:
        raise ValueError("unexpected round3 review findings")
    if adjud["adjudication"]["verdict"] != "READY_FOR_IMPLEMENTATION":
        raise ValueError("round3 construction-input repair not adjudicated")
    if (ROOT / ABSENT).exists() or (ROOT / INFO).exists():
        raise ValueError("authorized absent files were restored unexpectedly")


def prepare_input():
    if (HERE / "construction_input.json").exists() or any((HERE / name).exists() for name in GENERATED):
        raise ValueError("round4 input/candidate already exists; refusing overwrite")
    source_preflight()
    ledger = read_json(BEFORE)
    gate = next(item for item in ledger["gates"] if item["id"] == "G0")
    static = static_gate(gate)
    contract = checker_module().contract_sha256(gate)
    if static != read_json(R3 / "gate_contract.json"):
        raise ValueError("G0 static contract differs from round3")
    if contract != read_json(R3 / "candidate_manifest.json")["contract_sha256"]:
        raise ValueError("G0 canonical static hash differs from round3")
    dynamic = {
        "status": gate["status"],
        "todos": [{"id": item["id"], "status": item["status"], "evidence": item["evidence"]}
                  for item in gate["todos"]],
    }
    snapshot = {
        "schema_version": "1.0", "gate_id": "G0", "round": "round4",
        "source_before": file_record(BEFORE),
        "checker_snapshot": file_record(CHECKER),
        "static_contract": static, "contract_sha256": contract,
        "consumed_dynamic": dynamic,
        "consumed_dynamic_sha256": canonical_sha(dynamic),
    }
    write_json("construction_input.json", snapshot)
    print(f"FROZEN construction input SHA-256 {file_record(R4 / 'construction_input.json')['sha256']}")


def frozen_input():
    snapshot_path = R4 / "construction_input.json"
    value = read_json(snapshot_path)
    if value.get("gate_id") != "G0" or value.get("round") != "round4":
        raise ValueError("construction input belongs to another gate/round")
    if value["source_before"] != file_record(BEFORE) or value["source_before"]["sha256"] != BEFORE_SHA:
        raise ValueError("before-ledger source drift")
    if value["checker_snapshot"] != file_record(CHECKER):
        raise ValueError("checker source drift")
    if canonical_sha(value["consumed_dynamic"]) != value["consumed_dynamic_sha256"]:
        raise ValueError("dynamic construction metadata drift")
    if value["static_contract"] != read_json(R3 / "gate_contract.json"):
        raise ValueError("static contract snapshot drift")
    # Only the archived checker computes the contract; the live checker and ledger are never imported.
    gate = dict(value["static_contract"])
    gate["status"] = value["consumed_dynamic"]["status"]
    by_id = {todo["id"]: todo for todo in value["consumed_dynamic"]["todos"]}
    gate["todos"] = [dict(todo, status=by_id[todo["id"]]["status"],
                          evidence=by_id[todo["id"]]["evidence"]) for todo in gate["todos"]]
    if checker_module().contract_sha256(gate) != value["contract_sha256"]:
        raise ValueError("frozen input contract mismatch")
    return value


def old_files():
    manifest = read_json(R3 / "candidate_manifest.json")
    if file_record(R3 / "candidate_manifest.json")["sha256"] != OLD_MANIFEST_SHA:
        raise ValueError("round3 manifest drift")
    seen = set()
    total = 0
    for item in manifest["files"]:
        if item["path"] in seen or file_record(item["path"]) != item:
            raise ValueError(f"round3 item stale or duplicate: {item['path']}")
        seen.add(item["path"])
        total += item["bytes"]
    if len(seen) != 171 or ABSENT in seen or INFO in seen:
        raise ValueError("round3 active set changed")
    if read_json(R3 / "inventory_current.json")["active_file_count"] != 157:
        raise ValueError("round3 retained count changed")
    return manifest, total


def build():
    if any((HERE / name).exists() for name in GENERATED):
        raise ValueError("round4 candidate already exists; refusing overwrite")
    source_preflight()
    consumed = frozen_input()
    old, total = old_files()
    for name in ("gate_contract.json", "inventory_current.json", "tombstone.json"):
        shutil.copyfile(checked_path(R3 / name), HERE / name)
        if file_record(R4 / name)["sha256"] != file_record(R3 / name)["sha256"]:
            raise ValueError(f"round3 documentary artifact not copied exactly: {name}")
    todos = []
    listed = {item["path"] for item in old["files"]}
    for todo in consumed["consumed_dynamic"]["todos"]:
        evidence = []
        for item in todo["evidence"]:
            if item["path"] not in listed:
                raise ValueError(f"historical todo evidence outside round3: {item['path']}")
            evidence.append({
                "path": item["path"], "basis": "historical",
                "locator": item.get("locator", "") + "; bytes reverified; calculation not rerun",
            })
        if todo["id"] == "G0-T1":
            evidence.extend([
                {"path": str(R4 / "inventory_current.json"), "basis": "executed",
                 "locator": "157 active direct entries retained from verified round3 inventory"},
                {"path": str(R4 / "tombstone.json"), "basis": "inspected",
                 "locator": "authorized absence remains explicit; actor/cause unknown"},
                {"path": str(R4 / "construction_input.json"), "basis": "inspected",
                 "locator": "status and todo evidence consumed from frozen before-ledger projection"},
            ])
        todos.append({"id": todo["id"], "status": todo["status"], "evidence": evidence})
    write_json("todo_evidence.json", {"todos": todos})
    context = [
        R3 / "candidate_manifest.json", R4 / "construction_input.json", BEFORE,
        DECISION, REVIEW, R3 / "review/source_checks.json",
        R3 / "review/run01/ledger_counterexample.json",
        COORD / "adjudication_build_input.json", COORD / "review_finding_map.md",
    ]
    inputs = list(dict.fromkeys([item["path"] for item in old["files"]] + [str(path) for path in context]))
    code = [str(R4 / "build_candidate.py"), str(CHECKER)]
    configuration = [str(R4 / "gate_contract.json")]
    outputs = [str(R4 / name) for name in ("inventory_current.json", "tombstone.json",
                                            "todo_evidence.json", "implementation.md")]
    run = {
        "gate_id": "G0", "round": "round4", "contract_sha256": consumed["contract_sha256"],
        "executor_id": EXECUTOR, "goal_id": EXECUTOR,
        "created_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "dependency_manifests": {}, "dependency_approvals": {},
        "construction_input": str(R4 / "construction_input.json"),
        "construction_input_sha256": file_record(R4 / "construction_input.json")["sha256"],
        "source_before_sha256": BEFORE_SHA, "checker_snapshot_sha256": CHECKER_SHA,
        "repaired_from_manifest_sha256": OLD_MANIFEST_SHA,
        "round3_entries_verified": len(old["files"]), "round3_bytes_verified": total,
        "inputs": inputs, "code": code, "configuration": configuration, "outputs": outputs,
        "commands": [f"python3 -B {R4 / 'build_candidate.py'} prepare-input",
                     f"python3 -B {R4 / 'build_candidate.py'} build",
                     f"python3 -B {R4 / 'build_candidate.py'} verify"],
        "seeds": None, "scientific_execution": False, "MCMC": False,
        "software": {"python": sys.version.split()[0], "hash": "hashlib.sha256"},
        "limits": ["Only documentary hashes, byte counts and construction metadata were checked.",
                   "Previous R, fit/data loads, MCMC and scientific tests were not rerun.",
                   "The canonical live ledger and checker were not read by this build.",
                   "This candidate requires independent QA and adjudication; no PASS is claimed."],
    }
    write_json("run.json", run)
    (HERE / "implementation.md").write_text(
        "# G0 round4: reparo de proveniência do input de construção\n\n"
        "O único achado material de round3 foi G0-R3-QA-F01, equivalente a G0-R3-COORD-F01. "
        "Este candidato preserva integralmente os 171 arquivos do manifesto round3, inclusive os 157 "
        "arquivos ativos inventariados; o PDF incompleto e Info.plist continuam ausentes. "
        "Nenhum arquivo histórico foi alterado, excluído ou restaurado.\n\n"
        "construction_input.json fixa contrato, status, IDs e evidence dos quatro todos da projeção "
        "G0 do ledger before da coordenação. O build lê esse arquivo, identificado em run.json por "
        f"SHA-256 {run['construction_input_sha256']}; o ledger canônico não é lido. "
        "O checker importado é o snapshot arquivado, SHA-256 " + CHECKER_SHA + ". "
        "O contrato estático é byte-idêntico ao de round3; o hash estático sozinho não é "
        "apresentado como fechamento dos metadados dinâmicos.\n\n"
        "O review formal round3 e a adjudicação delimitada entram como histórico de reparo, "
        "não como aprovação deste candidato. Hashes e tamanhos dos 171 arquivos foram conferidos "
        "agora; cálculos e testes científicos anteriores não foram reexecutados. "
        f"Verificação: python3 -B {R4 / 'build_candidate.py'} verify.\n",
        encoding="utf-8",
    )
    paths = list(dict.fromkeys([item["path"] for item in old["files"]] + inputs + code +
                               configuration + outputs + [str(R4 / "run.json")]))
    if ABSENT in paths or INFO in paths or any(path in paths for path in
        ("README.md", "CLAUDE.md", "quality_reports/plans/mebane_2022_2026_gates.json")):
        raise ValueError("absent or mutable canonical path entered active manifest")
    manifest = {"gate_id": "G0", "round": "round4",
                "contract_sha256": consumed["contract_sha256"],
                "files": [file_record(path) for path in paths]}
    write_json("candidate_manifest.json", manifest)
    verify()
    print(f"BUILT G0 round4 manifest SHA-256 {file_record(R4 / 'candidate_manifest.json')['sha256']}")


def verify():
    consumed = frozen_input()
    old, _ = old_files()
    manifest = read_json(R4 / "candidate_manifest.json")
    run = read_json(R4 / "run.json")
    todos = read_json(R4 / "todo_evidence.json")
    if run["construction_input_sha256"] != file_record(R4 / "construction_input.json")["sha256"]:
        raise ValueError("construction input hash drift")
    if (manifest["gate_id"], manifest["round"], manifest["contract_sha256"]) != (
            "G0", "round4", consumed["contract_sha256"]):
        raise ValueError("manifest binding drift")
    files = {}
    for item in manifest["files"]:
        if item["path"] in files or file_record(item["path"]) != item:
            raise ValueError(f"stale or duplicate candidate item: {item['path']}")
        files[item["path"]] = item
    for item in old["files"]:
        if files.get(item["path"]) != item:
            raise ValueError(f"round3 item omitted or changed: {item['path']}")
    for name in ("gate_contract.json", "inventory_current.json", "tombstone.json"):
        if file_record(R4 / name)["sha256"] != file_record(R3 / name)["sha256"]:
            raise ValueError(f"round3 document drift: {name}")
    for field in ("inputs", "code", "configuration", "outputs"):
        if any(path not in files for path in run[field]):
            raise ValueError(f"run.{field} file omitted from manifest")
    if str(R4 / "run.json") not in files:
        raise ValueError("run missing from manifest")
    expected_ids = [todo["id"] for todo in consumed["consumed_dynamic"]["todos"]]
    if [todo["id"] for todo in todos["todos"]] != expected_ids:
        raise ValueError("todo IDs differ from frozen input")
    for todo in todos["todos"]:
        if any(item["path"] not in files for item in todo["evidence"]):
            raise ValueError(f"todo evidence omitted: {todo['id']}")
    if ABSENT in files or INFO in files:
        raise ValueError("authorized absent file became active")
    print(f"PASS G0 round4: {len(old['files'])} round3 files preserved; "
          f"{len(files)} candidate files verified; manifest SHA-256 "
          f"{file_record(R4 / 'candidate_manifest.json')['sha256']}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("prepare-input", "build", "verify"))
    args = parser.parse_args()
    try:
        {"prepare-input": prepare_input, "build": build, "verify": verify}[args.command]()
    except (OSError, ValueError, KeyError, TypeError, StopIteration, json.JSONDecodeError) as error:
        raise SystemExit(f"FAIL: {error}")
