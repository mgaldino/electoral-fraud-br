#!/usr/bin/env python3
"""Build or verify the finite G0 round3 documentary rebaseline."""

import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[5]
HERE = Path(__file__).resolve().parent
PREFIX = Path("quality_reports/results/mebane_gates/G0/round3")
OLD = Path("quality_reports/results/mebane_gates/G0/round2")
BASE = Path("quality_reports/results/mebane_gates/G0/round1/inventory.json")
G2 = Path("quality_reports/results/mebane_gates/G2/round2")
DECISION = Path("quality_reports/results/mebane_gates/coordination/2026-09-29_inventory_rebaseline/decision.md")
REMOVED = "ssrn-4073770.pdf.download/ssrn-4073770.pdf"
INFO = "ssrn-4073770.pdf.download/Info.plist"
REMOVED_SHA = "524dc82c59612ec91b3a6ab475dd34f0607546a37823c9a9b1fd652677a8acdf"
EXECUTOR = "01a0edcd-cd1f-70f0-b9f5-95fb470b6c40"
OUTPUTS = ("gate_contract.json", "tombstone.json", "inventory_current.json",
           "todo_evidence.json", "run.json", "candidate_manifest.json")


def rel(path):
    return str(path).replace("\\", "/")


def read_json(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def digest(path):
    file = ROOT / path
    if not file.is_file() or file.is_symlink() or not file.resolve().is_relative_to(ROOT):
        raise ValueError(f"missing, symlinked or out-of-root file: {path}")
    hash_ = hashlib.sha256()
    size = 0
    with file.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            hash_.update(block)
            size += len(block)
    return {"path": rel(path), "sha256": hash_.hexdigest(), "bytes": size}


def write_json(name, obj):
    (HERE / name).write_text(json.dumps(obj, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def check_predecessor():
    old_manifest = read_json(OLD / "candidate_manifest.json")
    missing = []
    mismatch = []
    active = []
    for item in old_manifest["files"]:
        path = item["path"]
        if not (ROOT / path).is_file():
            missing.append(item)
            continue
        actual = digest(path)
        if actual != item:
            mismatch.append({"expected": item, "actual": actual})
        else:
            active.append(actual)
    expected_missing = [{"path": REMOVED, "sha256": REMOVED_SHA, "bytes": 1360}]
    if missing != expected_missing or mismatch:
        raise ValueError(f"unexpected round2 drift: missing={missing}; mismatch={mismatch}")
    if (ROOT / INFO).exists() or (ROOT / REMOVED).exists():
        raise ValueError("excluded download paths must remain absent")
    return old_manifest, active


def check_contract(old_manifest):
    sys.path.insert(0, str(ROOT / "scripts"))
    from mebane_gates import contract_sha256

    ledger = read_json("quality_reports/plans/mebane_2022_2026_gates.json")
    gate = next(item for item in ledger["gates"] if item["id"] == "G0")
    old_contract = read_json(OLD / "gate_contract.json")
    static = {key: value for key, value in gate.items() if key not in {"status", "records"}}
    static["todos"] = [
        {key: value for key, value in todo.items() if key not in {"status", "evidence"}}
        for todo in gate["todos"]
    ]
    hash_ = contract_sha256(gate)
    if static != old_contract or hash_ != old_manifest["contract_sha256"]:
        raise ValueError("G0 static contract changed")
    return ledger, gate, hash_


def build():
    if any((HERE / name).exists() for name in OUTPUTS):
        raise ValueError("round3 is already materialized; use verify, never overwrite a freeze")
    old_manifest, active = check_predecessor()
    ledger, gate, contract_hash = check_contract(old_manifest)
    base = read_json(BASE)
    additions = read_json(OLD / "inventory_additions.json")
    old_run = read_json(OLD / "run.json")
    original_paths = {item["path"] for item in active}
    if len(base["items"]) != 108 or len(additions["added_files"]) != 5:
        raise ValueError("unexpected prior inventory cardinality")
    old_item = next(item for item in base["items"] if item["path"] == REMOVED)
    if (old_item["sha256"], old_item["bytes"], old_item["pdf_integrity"]) != (
            REMOVED_SHA, 1360, "invalid_or_incomplete"):
        raise ValueError("historical invalid-PDF description changed")
    if any(item["path"] == INFO for item in base["items"]):
        raise ValueError("Info.plist unexpectedly entered the base inventory")
    observed = dt.datetime.now(dt.timezone.utc).isoformat()

    # Preserve the static contract byte-for-byte. It is not a new model decision.
    (HERE / "gate_contract.json").write_bytes((ROOT / OLD / "gate_contract.json").read_bytes())
    tombstone = {
        "gate_id": "G0", "round": "round3", "record_type": "authorized_retained_absence",
        "path": REMOVED, "historical_sha256": REMOVED_SHA, "historical_bytes": 1360,
        "historical_quality": "invalid_or_incomplete", "scientific_source": False,
        "qa_last_present_at_utc": "2026-09-29T13:13:46.688626+00:00",
        "qa_first_absent_at_utc": "2026-09-29T13:19:25.178896+00:00",
        "deletion_actor": "unknown", "deletion_cause": "unknown",
        "git_checkpoint": "122e74a",
        "git_checkpoint_scope": "Records deletion in Git history, not the actor or cause of the filesystem operation.",
        "user_decision": "Keep the deletion and update the inventory; do not delete files without asking the user first.",
        "user_decision_timestamp": None,
        "current_status": "absent; authorized to remain absent; not an active input or valid source",
        "other_absence": {
            "path": INFO, "status": "absent; remains absent",
            "round2_g0_manifest_entry": False,
            "git_checkpoint": "122e74a",
            "note": "No deletion actor or filesystem cause is inferred."
        },
        "evidence_paths": [
            rel(DECISION),
            rel(BASE),
            rel(OLD / "candidate_manifest.json"),
            rel(G2 / "review/integrity_initial.json"),
            rel(G2 / "review/integrity_final.json"),
            rel(G2 / "adjudication_initial.json")
        ]
    }
    write_json("tombstone.json", tombstone)

    historical_only = sorted(item["path"] for item in base["items"] if item["path"] not in original_paths)
    inventory = {
        "gate_id": "G0", "round": "round3", "verified_at_utc": observed,
        "scope": "Direct files in G0 round2 candidate manifest only; active means bytes present and verified, not scientific validity.",
        "verification": "SHA-256 and byte count independently recomputed in this documentary run",
        "historical_base_inventory": {"path": rel(BASE), "sha256": digest(BASE)["sha256"],
                                      "recorded_items": 108,
                                      "note": "Immutable historical observation; not all original paths are attested current."},
        "historical_round2_additions": {"path": rel(OLD / "inventory_additions.json"),
                                       "sha256": digest(OLD / "inventory_additions.json")["sha256"],
                                       "recorded_items": 5},
        "source_manifest": {"path": rel(OLD / "candidate_manifest.json"),
                            "sha256": digest(OLD / "candidate_manifest.json")["sha256"],
                            "recorded_entries": len(old_manifest["files"])},
        "active_files": active,
        "active_file_count": len(active),
        "active_bytes": sum(item["bytes"] for item in active),
        "historical_original_paths_not_attested_as_active": historical_only,
        "removed_authorized": [{"path": REMOVED, "historical_sha256": REMOVED_SHA,
                                "historical_bytes": 1360,
                                "tombstone": rel(PREFIX / "tombstone.json")}],
        "other_absent_not_in_round2_manifest": [INFO],
        "prior_calculations_reexecuted": False
    }
    write_json("inventory_current.json", inventory)

    todos = []
    for todo in gate["todos"]:
        evidence = [{"path": item["path"], "basis": "historical",
                     "locator": item.get("locator", "") + "; bytes reverified now, calculation not rerun"}
                    for item in todo["evidence"]]
        if todo["id"] == "G0-T1":
            evidence.extend([
                {"path": rel(PREFIX / "inventory_current.json"), "basis": "executed",
                 "locator": "157 direct files rehashed; one invalid PDF excluded"},
                {"path": rel(PREFIX / "tombstone.json"), "basis": "inspected",
                 "locator": "authorized retained absence, unknown actor/cause"}
            ])
        todos.append({"id": todo["id"], "status": todo["status"], "evidence": evidence})
    write_json("todo_evidence.json", {"gate_id": "G0", "round": "round3", "todos": todos,
                                      "note": "Historical calculations and loads not rerun. Current execution is hash/byte verification only."})

    extras = [rel(path) for path in (
        DECISION,
        BASE, OLD / "inventory_additions.json", OLD / "candidate_manifest.json",
        OLD / "run.json", OLD / "review/review.json", OLD / "adjudication.json",
        G2 / "review/integrity_initial.json", G2 / "review/integrity_final.json",
        G2 / "adjudication_initial.json"
    )]
    inputs = list(dict.fromkeys([path for path in old_run["inputs"] if path != REMOVED] + extras))
    code = list(dict.fromkeys(old_run["code"] + [rel(PREFIX / "build_candidate.py")]))
    configuration = list(dict.fromkeys(old_run["configuration"] + [rel(PREFIX / "gate_contract.json")]))
    outputs = list(dict.fromkeys(old_run["outputs"] + [rel(PREFIX / name) for name in (
        "inventory_current.json", "tombstone.json", "todo_evidence.json", "implementation.md")]))
    run = {
        "gate_id": "G0", "round": "round3", "contract_sha256": contract_hash,
        "executor_id": EXECUTOR, "goal_id": EXECUTOR,
        "goal_objective": "Deliver documentary G0 round3 candidate; dependent candidates await coordinator approval",
        "started_at_utc": observed,
        "finished_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "dependency_manifests": {}, "dependency_approvals": {},
        "repaired_from_manifest_sha256": digest(OLD / "candidate_manifest.json")["sha256"],
        "inputs": inputs, "code": code, "configuration": configuration, "outputs": outputs,
        "commands": ["python3 -B quality_reports/results/mebane_gates/G0/round3/build_candidate.py build",
                     "python3 -B quality_reports/results/mebane_gates/G0/round3/build_candidate.py verify"],
        "seeds": None, "software": {"python": sys.version.split()[0], "hash": "hashlib.sha256"},
        "exit_codes": {"predecessor_sha256_and_bytes": 0, "static_contract_comparison": 0},
        "limits": ["Only SHA-256, byte counts and absence were checked now.",
                   "No R, MCMC, package installation, data transformation or prior scientific calculation was run.",
                   "Historical inventory and QA approvals are preserved as historical evidence, not inherited PASS.",
                   "The incomplete download PDF and Info.plist remain absent."]
    }
    write_json("run.json", run)

    all_paths = list(dict.fromkeys([item["path"] for item in active] + inputs + code + configuration +
                                   outputs + [rel(PREFIX / "run.json")]))
    if REMOVED in all_paths or INFO in all_paths or any(path in all_paths for path in
        ("README.md", "CLAUDE.md", "quality_reports/plans/mebane_2022_2026_gates.json")):
        raise ValueError("forbidden active path in candidate")
    manifest = {"gate_id": "G0", "round": "round3", "contract_sha256": contract_hash,
                "files": [digest(path) for path in all_paths]}
    write_json("candidate_manifest.json", manifest)
    print(f"BUILT G0 round3: {len(active)} retained, {len(manifest['files'])} frozen files, "
          f"manifest SHA-256 {digest(PREFIX / 'candidate_manifest.json')['sha256']}")


def verify():
    old_manifest, active = check_predecessor()
    _, gate, contract_hash = check_contract(old_manifest)
    manifest = read_json(PREFIX / "candidate_manifest.json")
    run = read_json(PREFIX / "run.json")
    inventory = read_json(PREFIX / "inventory_current.json")
    tombstone = read_json(PREFIX / "tombstone.json")
    todos = read_json(PREFIX / "todo_evidence.json")
    if (manifest["gate_id"], manifest["round"], manifest["contract_sha256"]) != ("G0", "round3", contract_hash):
        raise ValueError("manifest binding mismatch")
    if run["contract_sha256"] != contract_hash or run["executor_id"] != EXECUTOR:
        raise ValueError("run binding mismatch")
    if (ROOT / OLD / "gate_contract.json").read_bytes() != (HERE / "gate_contract.json").read_bytes():
        raise ValueError("static contract snapshot drift")
    if inventory["active_files"] != active or inventory["active_file_count"] != len(active):
        raise ValueError("inventory drift")
    if tombstone["path"] != REMOVED or tombstone["historical_sha256"] != REMOVED_SHA:
        raise ValueError("tombstone drift")
    if {todo["id"] for todo in todos["todos"]} != {todo["id"] for todo in gate["todos"]}:
        raise ValueError("todo coverage drift")
    listed = {item["path"] for item in manifest["files"]}
    if len(listed) != len(manifest["files"]) or REMOVED in listed or INFO in listed:
        raise ValueError("duplicate or excluded manifest path")
    for item in manifest["files"]:
        if digest(item["path"]) != item:
            raise ValueError(f"manifest file drift: {item['path']}")
    for path in [value for field in ("inputs", "code", "configuration", "outputs") for value in run[field]] + [rel(PREFIX / "run.json")]:
        if path not in listed:
            raise ValueError(f"run file outside manifest: {path}")
    for todo in todos["todos"]:
        for item in todo["evidence"]:
            if item["path"] not in listed:
                raise ValueError(f"todo evidence outside manifest: {item['path']}")
    print(f"PASS G0 round3: {len(active)}/{len(old_manifest['files'])} prior entries retained; "
          f"{len(manifest['files'])} candidate files verified; "
          f"manifest SHA-256 {digest(PREFIX / 'candidate_manifest.json')['sha256']}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("build", "verify"))
    args = parser.parse_args()
    try:
        {"build": build, "verify": verify}[args.command]()
    except (OSError, ValueError, KeyError) as error:
        raise SystemExit(f"FAIL: {error}")
