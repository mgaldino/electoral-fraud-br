#!/usr/bin/env python3
"""Documentary round3 rebinding; audit is read-only and build is approval-gated."""

import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path
import shutil
import sys
from uuid import UUID


HERE = Path(__file__).resolve().parent
ROOT = Path(__file__).resolve().parents[5]
GATE = HERE.parent.name
PARENT = {"G1": "G0", "G2": "G0", "G7": "G1"}
APPROVED_ROUND = {"G0": "round4", "G1": "round3"}
if GATE not in PARENT:
    raise SystemExit("unsupported gate")
ROUND2 = Path("quality_reports/results/mebane_gates") / GATE / "round2"
ROUND3 = Path("quality_reports/results/mebane_gates") / GATE / "round3"
DECISION = Path(
    "quality_reports/results/mebane_gates/coordination/"
    "2026-09-29_inventory_rebaseline/decision.md"
)
DECISION_SHA256 = "fe62bfd30ffd6e985a6070fb6f575770e5097f6c96de543eed145df3df75007a"
EXECUTOR_ID = "01a0edcd-cd1f-70f0-b9f5-95fb470b6c40"
GENERATED = (
    "ledger_input_snapshot.json", "gate_contract.json", "inherited_map.json",
    "todo_evidence.json", "implementation.md", "run.json", "candidate_manifest.json"
)
MUTABLE_DOCUMENTS = {
    "README.md", "CLAUDE.md", "quality_reports/plans/mebane_2022_2026_gates.json",
    "scripts/mebane_gates.py"
}
SOURCE_PREFIXES = ("R/", "config/", "tests/", "appendices/", "scripts/")
SCOPE = {
    "G1": "Documentary revalidation of the existing 2022 TSE data pipeline; no data rebuild.",
    "G2": "Literal qbl/JAGS software benchmark contract only; no inferential approval.",
    "G7": "Normalized-CSV staging rehearsal only; not an official-raw converter or 2026 inference.",
}


def unique(values):
    return list(dict.fromkeys(values))


def checked_path(value):
    path = Path(value)
    if path.is_absolute() or not path.parts or ".." in path.parts:
        raise ValueError(f"unsafe path: {value}")
    file = ROOT / path
    if not file.resolve().is_relative_to(ROOT) or not file.is_file() or file.is_symlink():
        raise ValueError(f"missing, symlinked or out-of-root file: {value}")
    return file


def file_record(value):
    file = checked_path(value)
    hash_ = hashlib.sha256()
    size = 0
    with file.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            hash_.update(block)
            size += len(block)
    return {"path": str(value), "sha256": hash_.hexdigest(), "bytes": size}


def read_json(value):
    return json.loads(checked_path(value).read_text(encoding="utf-8"))


def write_json(name, data):
    (HERE / name).write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


def canonical_hash(gate):
    static = {key: value for key, value in gate.items() if key not in {"status", "records"}}
    static["todos"] = [
        {key: value for key, value in todo.items() if key not in {"status", "evidence"}}
        for todo in gate["todos"]
    ]
    encoded = json.dumps(static, sort_keys=True, ensure_ascii=False, separators=(",", ":"))
    return static, hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def audit_round2():
    path = ROUND2 / "candidate_manifest.json"
    manifest = read_json(path)
    if manifest.get("gate_id") != GATE or manifest.get("round") != "round2":
        raise ValueError("round2 manifest belongs to another gate or round")
    seen = set()
    bytes_total = 0
    for expected in manifest["files"]:
        value = expected["path"]
        if value in seen:
            raise ValueError(f"duplicate round2 entry: {value}")
        seen.add(value)
        actual = file_record(value)
        if actual != expected:
            raise ValueError(f"round2 entry drift: {value}; actual={actual}")
        bytes_total += actual["bytes"]
    old_contract = read_json(ROUND2 / "gate_contract.json")
    if canonical_hash(old_contract)[1] != manifest["contract_sha256"]:
        raise ValueError("round2 static contract hash mismatch")
    if file_record(DECISION)["sha256"] != DECISION_SHA256:
        raise ValueError("coordinator decision changed")
    if GATE == "G2":
        benchmark = read_json(ROUND2 / "benchmark_contract.json")
        if benchmark.get("target_kind") != "literal_software_benchmark_not_certified_data_generator":
            raise ValueError("G2 benchmark target changed")
        if benchmark.get("inferential_approval") is not False:
            raise ValueError("G2 contract incorrectly claims inferential approval")
    return manifest, file_record(path), old_contract, bytes_total


def gate_chain(gates, gate_id):
    order = []
    seen = set()

    def visit(current):
        for parent in gates[current]["depends_on"]:
            if parent not in gates:
                raise ValueError(f"missing predecessor {parent}")
            if parent not in seen:
                visit(parent)
                seen.add(parent)
                order.append(parent)

    visit(gate_id)
    return order


def canonical_uuid(value):
    try:
        return isinstance(value, str) and str(UUID(value)) == value
    except (ValueError, AttributeError):
        return False


def approved_chain(gates, target_id):
    approved = {}
    for parent_id in gate_chain(gates, target_id):
        gate = gates[parent_id]
        if gate.get("status") != "pass":
            raise ValueError(f"{parent_id} has not passed")
        record = gate.get("records")
        if not isinstance(record, dict):
            raise ValueError(f"{parent_id} has no approval records")
        executor = record.get("executor_id")
        reviewer = record.get("reviewer_id")
        if not canonical_uuid(executor) or not canonical_uuid(reviewer) or executor == reviewer:
            raise ValueError(f"{parent_id} approval identities are invalid")
        paths = {key: record.get(key) for key in ("run", "candidate_manifest", "review", "adjudication")}
        expected_round = APPROVED_ROUND.get(parent_id)
        if expected_round is None:
            raise ValueError(f"no expected approved round configured for {parent_id}")
        expected_manifest = (
            f"quality_reports/results/mebane_gates/{parent_id}/{expected_round}/candidate_manifest.json"
        )
        if paths["candidate_manifest"] != expected_manifest:
            raise ValueError(f"{parent_id} is not approved on {expected_round}")
        prefix = f"quality_reports/results/mebane_gates/{parent_id}/{expected_round}/"
        if not all(isinstance(path, str) and path.startswith(prefix) for path in paths.values()):
            raise ValueError(f"{parent_id} records escape {expected_round}")
        records = {key: file_record(path) for key, path in paths.items()}
        manifest = read_json(paths["candidate_manifest"])
        run = read_json(paths["run"])
        review = read_json(paths["review"])
        adjudication = read_json(paths["adjudication"])
        contract = canonical_hash(gate)[1]
        if any((doc.get("gate_id"), doc.get("round"), doc.get("contract_sha256"))
               != (parent_id, expected_round, contract)
               for doc in (manifest, run, review, adjudication)):
            raise ValueError(f"{parent_id} approval binds another contract or round")
        if run.get("executor_id") != executor:
            raise ValueError(f"{parent_id} run executor mismatch")
        if review.get("status") != "pass" or review.get("manifest_complete") is not True:
            raise ValueError(f"{parent_id} independent review is not passing")
        if review.get("executor_id") != executor or review.get("reviewer_id") != reviewer:
            raise ValueError(f"{parent_id} review identities mismatch")
        if adjudication.get("status") != "pass" or adjudication.get("unresolved_material_findings") != 0:
            raise ValueError(f"{parent_id} adjudication is not passing")
        if review.get("candidate_manifest_sha256") != records["candidate_manifest"]["sha256"]:
            raise ValueError(f"{parent_id} review is stale")
        if adjudication.get("candidate_manifest_sha256") != records["candidate_manifest"]["sha256"]:
            raise ValueError(f"{parent_id} adjudication is stale")
        if adjudication.get("review_sha256") != records["review"]["sha256"]:
            raise ValueError(f"{parent_id} adjudication review binding is stale")
        expected_deps = gate["depends_on"]
        expected_manifests = {
            dep: approved[dep]["records"]["candidate_manifest"]["sha256"] for dep in expected_deps
        }
        expected_approvals = {
            dep: {
                "review_sha256": approved[dep]["records"]["review"]["sha256"],
                "adjudication_sha256": approved[dep]["records"]["adjudication"]["sha256"],
            }
            for dep in expected_deps
        }
        if run.get("dependency_manifests") != expected_manifests:
            raise ValueError(f"{parent_id} has stale dependency manifests")
        if run.get("dependency_approvals") != expected_approvals:
            raise ValueError(f"{parent_id} has stale dependency approvals")
        manifest_paths = set()
        for item in manifest["files"]:
            if item["path"] in manifest_paths or file_record(item["path"]) != item:
                raise ValueError(f"{parent_id} predecessor manifest has a stale entry: {item['path']}")
            manifest_paths.add(item["path"])
        if paths["run"] not in manifest_paths:
            raise ValueError(f"{parent_id} predecessor run is outside its manifest")
        approved[parent_id] = {
            "round": expected_round, "records": records, "contract_sha256": contract
        }
    return approved


def ledger_snapshot(old_contract, source_manifest):
    ledger_path = Path("quality_reports/plans/mebane_2022_2026_gates.json")
    ledger_bytes = checked_path(ledger_path).read_bytes()
    ledger = json.loads(ledger_bytes)
    by_id = {gate["id"]: gate for gate in ledger["gates"]}
    chain = gate_chain(by_id, GATE)
    target = by_id[GATE]
    if canonical_hash(target)[0] != old_contract:
        raise ValueError(f"{GATE} static contract changed in live ledger")
    gates = {key: by_id[key] for key in chain + [GATE]}
    approvals = approved_chain(gates, GATE)
    return {
        "schema_version": "1.0",
        "target_gate_id": GATE,
        "captured_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "source_ledger_path": str(ledger_path),
        "source_ledger_sha256": hashlib.sha256(ledger_bytes).hexdigest(),
        "source_decision": file_record(DECISION),
        "source_round2_manifest": source_manifest,
        "gates": gates,
        "approved_predecessors": approvals,
    }


def snapshot_source(value):
    if value.startswith(SOURCE_PREFIXES):
        return True
    return value.startswith("quality_reports/results/") and not value.startswith(
        "quality_reports/results/mebane_gates/"
    )


def old_context_paths():
    values = [
        ROUND2 / "candidate_manifest.json", ROUND2 / "run.json",
        ROUND2 / "gate_contract.json", ROUND2 / "todo_evidence.json",
        ROUND2 / "review/review.json",
    ]
    for name in ("adjudication.json", "adjudication_initial.json"):
        path = ROUND2 / name
        if (ROOT / path).is_file():
            values.append(path)
    return [str(path) for path in values]


def build():
    if any((HERE / name).exists() for name in GENERATED):
        raise ValueError("round3 already materialized; refusing to overwrite frozen files")
    old, source_manifest, old_contract, total_bytes = audit_round2()
    captured = ledger_snapshot(old_contract, source_manifest)
    write_json("ledger_input_snapshot.json", captured)
    snapshot_path = ROUND3 / "ledger_input_snapshot.json"
    snapshot = read_json(snapshot_path)
    if snapshot != captured:
        raise ValueError("ledger input snapshot was not read back unchanged")
    if file_record(snapshot["source_ledger_path"])["sha256"] != snapshot["source_ledger_sha256"]:
        raise ValueError("live ledger changed during capture")
    if canonical_hash(snapshot["gates"][GATE])[0] != old_contract:
        raise ValueError("frozen target static contract mismatch")
    if approved_chain(snapshot["gates"], GATE) != snapshot["approved_predecessors"]:
        raise ValueError("frozen predecessor approvals mismatch")
    snapshot_hash = file_record(snapshot_path)["sha256"]

    (HERE / "gate_contract.json").write_bytes(
        checked_path(ROUND2 / "gate_contract.json").read_bytes()
    )
    remap = {}
    active = []
    for item in old["files"]:
        original = item["path"]
        if snapshot_source(original):
            replacement = str(ROUND3 / "snapshots" / original)
            destination = HERE / "snapshots" / original
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(checked_path(original), destination)
            if file_record(replacement)["sha256"] != item["sha256"]:
                raise ValueError(f"snapshot differs from round2: {original}")
            remap[original] = replacement
            active.append({"path": replacement, "sha256": item["sha256"], "bytes": item["bytes"]})
        else:
            active.append(item)
    inherited = {
        "gate_id": GATE, "round": "round3",
        "source_manifest": source_manifest,
        "round2_entries_verified": len(old["files"]),
        "round2_bytes_verified": total_bytes,
        "remapped": [
            {"original": original, "snapshot": replacement,
             "sha256": next(item["sha256"] for item in old["files"] if item["path"] == original)}
            for original, replacement in remap.items()
        ],
        "scientific_calculations_reexecuted": False,
    }
    write_json("inherited_map.json", inherited)
    gate = snapshot["gates"][GATE]
    listed_old = {item["path"] for item in old["files"]}
    todos = []
    for todo in gate["todos"]:
        evidence = []
        for item in todo["evidence"]:
            value = item["path"]
            if value not in listed_old:
                raise ValueError(f"todo evidence was not in round2 manifest: {value}")
            evidence.append({
                "path": remap.get(value, value), "basis": "historical",
                "locator": item.get("locator", "") + "; SHA-256/bytes rechecked in round3; no scientific rerun",
            })
        evidence.append({
            "path": str(ROUND3 / "inherited_map.json"), "basis": "executed",
            "locator": "All direct round2 manifest entries rechecked by SHA-256 and byte count",
        })
        todos.append({"id": todo["id"], "status": todo["status"], "evidence": evidence})
    write_json("todo_evidence.json", {"todos": todos})

    context = old_context_paths()
    approval_paths = [
        record["path"]
        for approved in snapshot["approved_predecessors"].values()
        for record in approved["records"].values()
    ]
    inputs = unique(
        [item["path"] for item in active]
        + context + [str(DECISION), str(snapshot_path)] + approval_paths
    )
    code = [str(ROUND3 / "build_candidate.py")]
    configuration = [str(ROUND3 / "gate_contract.json")]
    outputs = [
        str(ROUND3 / name) for name in
        ("inherited_map.json", "todo_evidence.json", "implementation.md")
    ]
    parent = PARENT[GATE]
    parent_approval = snapshot["approved_predecessors"][parent]["records"]
    run = {
        "gate_id": GATE, "round": "round3",
        "contract_sha256": canonical_hash(gate)[1],
        "executor_id": EXECUTOR_ID, "goal_id": EXECUTOR_ID,
        "created_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "dependency_manifests": {
            parent: parent_approval["candidate_manifest"]["sha256"]
        },
        "dependency_approvals": {
            parent: {
                "review_sha256": parent_approval["review"]["sha256"],
                "adjudication_sha256": parent_approval["adjudication"]["sha256"],
            }
        },
        "ledger_input_snapshot": str(snapshot_path),
        "ledger_input_snapshot_sha256": snapshot_hash,
        "source_ledger_sha256": snapshot["source_ledger_sha256"],
        "round2_manifest_sha256": source_manifest["sha256"],
        "round2_entries_verified": len(old["files"]),
        "round2_bytes_verified": total_bytes,
        "decision_sha256": DECISION_SHA256,
        "inputs": inputs, "code": code, "configuration": configuration, "outputs": outputs,
        "commands": [
            f"python3 -B {ROUND3 / 'build_candidate.py'} audit-round2",
            f"python3 -B {ROUND3 / 'build_candidate.py'} build",
            f"python3 -B {ROUND3 / 'build_candidate.py'} verify",
        ],
        "seeds": None, "scientific_execution": False, "MCMC": False,
        "software": {"python": sys.version.split()[0], "hash": "hashlib.sha256"},
        "scope": SCOPE[GATE],
        "limits": [
            "Previous calculations, data loads, tests, and scientific analyses were not rerun.",
            "Only documentary hashes, bytes, contract identity, and predecessor approvals were checked.",
            "Current ledger was read solely to capture the frozen metadata snapshot; no canonical mutable document enters the manifest.",
            "Candidate delivery is not independent QA, adjudication, gate PASS, or inference authorization.",
        ],
    }
    write_json("run.json", run)
    implementation = (
        f"# {GATE} round3: candidato de revalidação documental\n\n"
        f"Esta rodada conserva o contrato estático canônico {run['contract_sha256']} "
        f"e o escopo: {SCOPE[GATE]}\n\n"
        f"Foram reconferidas {len(old['files'])} entradas e {total_bytes} bytes do "
        f"manifesto round2 {source_manifest['sha256']}. O mapa inherited_map.json "
        f"registra os snapshots de código/configuração/testes; cálculos e testes científicos "
        f"anteriores não foram reexecutados.\n\n"
        f"O input consumido do ledger foi capturado em ledger_input_snapshot.json "
        f"(SHA-256 {snapshot_hash}) e relido antes de gerar run/todo_evidence. Esse snapshot "
        f"contém todos, IDs, records e aprovações reais da cadeia predecessora. "
        f"A decisão da coordenação é input fixado pelo SHA-256 {DECISION_SHA256}. "
        f"O ledger vivo e os documentos canônicos mutáveis não estão no manifesto.\n\n"
        f"O predecessor direto {parent} estava pass com manifesto "
        f"{parent_approval['candidate_manifest']['sha256']}, review "
        f"{parent_approval['review']['sha256']} e adjudicação "
        f"{parent_approval['adjudication']['sha256']} no snapshot consumido. "
        f"Esta entrega ainda requer QA independente e adjudicação próprias.\n\n"
        f"Verificação documental: python3 -B {ROUND3 / 'build_candidate.py'} verify.\n"
    )
    (HERE / "implementation.md").write_text(implementation, encoding="utf-8")
    paths = unique(
        [item["path"] for item in active] + inputs + code + configuration + outputs
        + [str(ROUND3 / "run.json")]
    )
    if MUTABLE_DOCUMENTS.intersection(paths):
        raise ValueError(f"canonical mutable file entered manifest: {MUTABLE_DOCUMENTS.intersection(paths)}")
    manifest = {
        "gate_id": GATE, "round": "round3",
        "contract_sha256": run["contract_sha256"],
        "files": [file_record(value) for value in paths],
    }
    write_json("candidate_manifest.json", manifest)
    verify()
    print(f"BUILT {GATE} round3 manifest SHA-256 "
          f"{file_record(ROUND3 / 'candidate_manifest.json')['sha256']}")


def verify():
    candidate = read_json(ROUND3 / "candidate_manifest.json")
    run = read_json(ROUND3 / "run.json")
    snapshot_path = ROUND3 / "ledger_input_snapshot.json"
    snapshot = read_json(snapshot_path)
    old = read_json(ROUND2 / "candidate_manifest.json")
    inherited = read_json(ROUND3 / "inherited_map.json")
    todos = read_json(ROUND3 / "todo_evidence.json")
    if run["ledger_input_snapshot_sha256"] != file_record(snapshot_path)["sha256"]:
        raise ValueError("consumed ledger input snapshot drift")
    if snapshot["target_gate_id"] != GATE or snapshot["source_decision"]["sha256"] != DECISION_SHA256:
        raise ValueError("snapshot target or decision drift")
    if snapshot["source_round2_manifest"] != file_record(ROUND2 / "candidate_manifest.json"):
        raise ValueError("round2 source manifest drift")
    if canonical_hash(snapshot["gates"][GATE])[1] != run["contract_sha256"]:
        raise ValueError("target static contract drift")
    if read_json(ROUND3 / "gate_contract.json") != canonical_hash(snapshot["gates"][GATE])[0]:
        raise ValueError("static contract snapshot drift")
    if approved_chain(snapshot["gates"], GATE) != snapshot["approved_predecessors"]:
        raise ValueError("predecessor approval drift")
    if (candidate["gate_id"], candidate["round"], candidate["contract_sha256"]) != (
            GATE, "round3", run["contract_sha256"]):
        raise ValueError("candidate binding mismatch")
    files = {}
    for item in candidate["files"]:
        value = item["path"]
        if value in files or file_record(value) != item:
            raise ValueError(f"candidate entry duplicate or stale: {value}")
        files[value] = item
    if MUTABLE_DOCUMENTS.intersection(files):
        raise ValueError("candidate contains canonical mutable files")
    remap = {item["original"]: item["snapshot"] for item in inherited["remapped"]}
    if inherited["source_manifest"] != snapshot["source_round2_manifest"]:
        raise ValueError("inherited manifest identity mismatch")
    if inherited["round2_entries_verified"] != len(old["files"]):
        raise ValueError("inherited item count mismatch")
    for item in old["files"]:
        active_path = remap.get(item["path"], item["path"])
        if files.get(active_path) != {"path": active_path, "sha256": item["sha256"],
                                      "bytes": item["bytes"]}:
            raise ValueError(f"old evidence not preserved: {item['path']}")
    for field in ("inputs", "code", "configuration", "outputs"):
        if not isinstance(run[field], list):
            raise ValueError(f"run.{field} is not a list")
        if any(value not in files for value in run[field]):
            raise ValueError(f"run.{field} escapes the manifest")
    if str(ROUND3 / "run.json") not in files:
        raise ValueError("run missing from manifest")
    current_todos = snapshot["gates"][GATE]["todos"]
    if [item["id"] for item in todos["todos"]] != [item["id"] for item in current_todos]:
        raise ValueError("todo IDs drift")
    for todo in todos["todos"]:
        if not all(item["path"] in files for item in todo["evidence"]):
            raise ValueError(f"todo evidence escapes manifest: {todo['id']}")
    print(f"PASS {GATE} round3: {len(old['files'])} inherited, "
          f"{len(candidate['files'])} frozen; manifest SHA-256 "
          f"{file_record(ROUND3 / 'candidate_manifest.json')['sha256']}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("audit-round2", "build", "verify"))
    args = parser.parse_args()
    try:
        if args.command == "audit-round2":
            old, record, _, size = audit_round2()
            print(f"PASS {GATE} round2: {len(old['files'])} files, {size} bytes; "
                  f"manifest SHA-256 {record['sha256']}; no candidate built")
        elif args.command == "build":
            build()
        else:
            verify()
    except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError) as error:
        raise SystemExit(f"FAIL: {error}")
