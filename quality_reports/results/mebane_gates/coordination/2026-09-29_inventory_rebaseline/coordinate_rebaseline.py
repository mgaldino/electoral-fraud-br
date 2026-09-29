#!/usr/bin/env python3
"""Preserve the prior state and adjudicate independently reviewed rebindings."""

import argparse
import datetime
import difflib
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess


BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[4]
LEDGER = ROOT / "quality_reports/plans/mebane_2022_2026_gates.json"
GATES = ROOT / "quality_reports/results/mebane_gates"
COORDINATOR = "019d795a-acfa-72c2-a210-d55a46c606c2"


def digest(path):
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


def relative(path):
    return path.relative_to(ROOT).as_posix()


def write_new(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x", encoding="utf-8") as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write("\n")


def preserve():
    rows = []
    for name in ("README.md", "CLAUDE.md",
                 "quality_reports/plans/mebane_2022_2026_gates.json",
                 "quality_reports/plans/2026-09-28_mebane_2022_2026_gates.md"):
        source = ROOT / name
        target = BASE / "before" / name
        target.parent.mkdir(parents=True, exist_ok=True)
        with target.open("xb") as stream:
            stream.write(source.read_bytes())
        assert digest(source) == digest(target)
        rows.append({"original": name, "snapshot": relative(target),
                     "sha256": digest(target), "bytes": target.stat().st_size})
    write_new(BASE / "preserved_state.json", {"files": rows})


def adjudicate(gate_id, round_id):
    spec = importlib.util.spec_from_file_location(
        "gate_checker", ROOT / "scripts/mebane_gates.py")
    checker = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(checker)
    ledger = json.loads(LEDGER.read_text(encoding="utf-8"))
    gates = {gate["id"]: gate for gate in ledger["gates"]}
    gate = gates[gate_id]
    base = GATES / gate_id / round_id
    manifest_path = base / "candidate_manifest.json"
    review_path = base / "review/review.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    review = json.loads(review_path.read_text(encoding="utf-8"))
    run = json.loads((base / "run.json").read_text(encoding="utf-8"))
    assert review["status"] == "pass" and review["manifest_complete"] is True
    assert review["findings"] == [], "Findings require individual adjudication"
    assert review["reviewer_id"] != run["executor_id"]
    assert review["candidate_manifest_sha256"] == digest(manifest_path)
    for entry in manifest["files"]:
        path = ROOT / entry["path"]
        assert digest(path) == entry["sha256"], entry["path"]
        assert path.stat().st_size == entry["bytes"], entry["path"]
    for predecessor in gate["depends_on"]:
        assert gates[predecessor]["status"] == "pass", predecessor
    contract = checker.contract_sha256(gate)
    assert all(item["contract_sha256"] == contract
               for item in (manifest, review, run))
    assert all(item["gate_id"] == gate_id and item["round"] == round_id
               for item in (manifest, review, run))
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()
    result = {
        "schema_version": "1.0",
        "adjudication_id": f"mebane-{gate_id}:inventory-rebaseline:{round_id}",
        "gate_id": gate_id, "round": round_id, "contract_sha256": contract,
        "candidate_manifest_sha256": digest(manifest_path),
        "review_sha256": digest(review_path), "status": "pass",
        "unresolved_material_findings": 0, "coordinator_id": COORDINATOR,
        "source": {"reviewed_artifact": relative(manifest_path),
                   "sha256": digest(manifest_path), "artifact_intact": True},
        "contract": {"required": False, "path": None, "sha256": None,
                     "contract_id": None, "artifact_sha256": None,
                     "status": None, "stale": False},
        "review_sources": [{"review_id": f"QA-{gate_id}-{round_id}",
                            "path": relative(review_path),
                            "sha256": digest(review_path)}],
        "findings": [],
        "summary": {"total": 0, "confirmed": 0, "partial": 0,
                    "refuted": 0, "unresolved": 0, "held_decisions": 0},
        "adjudication": {"verdict": "NO_CONFIRMED_DEFECTS", "checked_at": now,
                         "reasons": [
                             "Independent review and all candidate hashes checked.",
                             "Documentary revalidation only; prior scientific tests not rerun.",
                             "User-authorized removal from active inventory, not file deletion."]},
        "resolved_prior_incident": {
            "id": "G2-R2-QA-I1", "status": "CONFIRMED", "resolved": True,
            "decision": relative(BASE / "decision.md"),
            "resolution": "Keep both files absent; use new inventory and dependency bindings; preserve prior records.",
            "deletion_actor": "unknown", "deletion_cause": "unknown"},
        "resolved_prior_findings": review.get("resolved_prior_findings", []),
        "scope": "No model change, no new analysis or MCMC, no G3/G10 or inferential approval."
    }
    path = base / "adjudication.json"
    if path.exists():
        existing = json.loads(path.read_text(encoding="utf-8"))
        for field in ("gate_id", "round", "contract_sha256", "candidate_manifest_sha256",
                      "review_sha256", "status", "findings", "unresolved_material_findings"):
            assert existing[field] == result[field], field
        result = existing
    else:
        write_new(path, result)
    records = {"executor_id": run["executor_id"], "reviewer_id": review["reviewer_id"],
               "run": relative(base / "run.json"),
               "candidate_manifest": relative(manifest_path),
               "review": relative(review_path), "adjudication": relative(path)}
    gate["records"] = records
    gate["status"] = "pass"
    mapped_todos = {item["id"]: item for item in json.loads(
        (base / "todo_evidence.json").read_text(encoding="utf-8"))["todos"]}
    assert set(mapped_todos) == {item["id"] for item in gate["todos"]}
    for todo in gate["todos"]:
        mapped = mapped_todos[todo["id"]]
        todo["status"], todo["evidence"] = mapped["status"], mapped["evidence"]
    errors = checker.check_records(gate, ROOT, gates)
    assert not errors, errors
    with (base / "adjudication.md").open("x", encoding="utf-8") as stream:
        stream.write(
            f"# {gate_id} {round_id}: adjudicação documental\n\n"
            "**PASS no escopo documental; NO_CONFIRMED_DEFECTS vigentes.** "
            f"Parecer independente de `{review['reviewer_id']}`, distinto do executor, "
            f"vinculado ao manifesto `{digest(manifest_path)}`.\n\n"
            f"A coordenação conferiu os {len(manifest['files'])} arquivos do candidato, "
            "seus tamanhos, contratos e vínculos de aprovação. O checker dos records "
            "não apontou inconsistência. A decisão do usuário mantém a ausência do "
            "download incompleto; ninguém foi identificado como autor da remoção.\n\n"
            "As análises e os testes científicos reaproveitados são históricos. "
            "Não houve nova execução de R/MCMC, restauração ou exclusão. Esta "
            "assinatura não executa G3/G10 nem libera inferência nacional. "
            "Detalhes, hashes e achados anteriores resolvidos estão em adjudication.json.\n")
    print(json.dumps({"gate": gate_id, "records": records,
                      "files_verified": len(manifest["files"]),
                      "adjudication_sha256": digest(path)}, indent=2))


def ledger_patch(gate_id, round_id):
    """Emit an apply_patch change without rewriting the ledger on disk."""
    source = LEDGER.read_text(encoding="utf-8")
    base = GATES / gate_id / round_id
    run = json.loads((base / "run.json").read_text(encoding="utf-8"))
    review = json.loads((base / "review/review.json").read_text(encoding="utf-8"))
    adjudication = json.loads((base / "adjudication.json").read_text(encoding="utf-8"))
    assert adjudication["status"] == "pass"
    assert adjudication["review_sha256"] == digest(base / "review/review.json")
    records = {"executor_id": run["executor_id"], "reviewer_id": review["reviewer_id"],
               "run": relative(base / "run.json"),
               "candidate_manifest": relative(base / "candidate_manifest.json"),
               "review": relative(base / "review/review.json"),
               "adjudication": relative(base / "adjudication.json")}
    todos = {item["id"]: item for item in json.loads(
        (base / "todo_evidence.json").read_text(encoding="utf-8"))["todos"]}
    start = source.index('    {\n      "id": "' + gate_id + '"')
    end = source.index('\n    },', start) + len('\n    }')
    block = source[start:end]
    lines = block.splitlines(keepends=True)
    for index, line in enumerate(lines):
        if line.startswith('      "status":'):
            lines[index] = '      "status": "pass",\n'
        for todo_id, todo in todos.items():
            if line.startswith('        {"id": "' + todo_id + '"'):
                original = json.loads(line.strip().rstrip(','))
                assert set(todo) >= {"id", "status", "evidence"}
                original["status"] = todo["status"]
                original["evidence"] = todo["evidence"]
                suffix = ',\n' if line.rstrip().endswith(',') else '\n'
                lines[index] = '        ' + json.dumps(original, ensure_ascii=False) + suffix
    block = ''.join(lines)
    record_start = block.index('      "records": {')
    record_end = block.index('\n      }', record_start) + len('\n      }')
    formatted = json.dumps(records, ensure_ascii=False, indent=2).splitlines()
    replacement = '      "records": ' + formatted[0] + '\n'
    replacement += '\n'.join('      ' + line for line in formatted[1:])
    block = block[:record_start] + replacement + block[record_end:]
    revised = source[:start] + block + source[end:]
    json.loads(revised)
    diff = list(difflib.unified_diff(source.splitlines(keepends=True),
                                   revised.splitlines(keepends=True)))[2:]
    diff = ['@@\n' if line.startswith('@@ ') else line for line in diff]
    print('*** Begin Patch\n*** Update File: ' + str(LEDGER))
    print(''.join(diff), end='')
    print('*** End Patch')


def finish():
    spec = importlib.util.spec_from_file_location(
        "gate_checker_final", ROOT / "scripts/mebane_gates.py")
    checker = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(checker)
    ledger = json.loads(LEDGER.read_text(encoding="utf-8"))
    before = json.loads((BASE / "before" / relative(LEDGER)).read_text(encoding="utf-8"))
    gates = {gate["id"]: gate for gate in ledger["gates"]}
    assert not checker.validate(ledger, ROOT)
    assert all(gates[key]["status"] == "pass" for key in ("G0", "G1", "G2", "G7"))
    assert all(gates[key]["status"] == "queued" and gates[key]["records"] is None
               for key in ("G3", "G10"))
    assert all(checker.contract_sha256(gate) == checker.contract_sha256(gates[gate["id"]])
               for gate in before["gates"])
    preserved = json.loads((BASE / "preserved_state.json").read_text(encoding="utf-8"))
    assert all(digest(ROOT / item["snapshot"]) == item["sha256"] for item in preserved["files"])
    paths = ["ssrn-4073770.pdf.download/ssrn-4073770.pdf",
             "ssrn-4073770.pdf.download/Info.plist"]
    assert all(not (ROOT / path).exists() for path in paths)
    deletions = subprocess.run(
        ["git", "diff", "--name-only", "--diff-filter=D", "HEAD"],
        cwd=ROOT, text=True, capture_output=True, check=True).stdout.splitlines()
    assert not deletions, deletions
    result = {
        "checked_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "scope": "Documentary inventory reconciliation only",
        "integrity_hold_resolved": ledger["integrity_hold"]["status"] == "resolved_by_authorized_rebaseline",
        "all_static_contracts_unchanged": True, "prior_document_snapshots_intact": True,
        "absent_paths": paths, "files_deleted_or_restored_by_this_update": False,
        "deletion_actor": "unknown", "deletion_cause": "unknown",
        "gate_statuses": {key: gate["status"] for key, gate in gates.items()},
        "gate_records": {key: gates[key]["records"] for key in ("G0", "G1", "G2", "G7")},
        "scientific_analyses_rerun": False, "G3_executed": False, "G10_executed": False,
        "overall_goal_complete": False,
        "remaining_goal_work": "G3 implementation/engine tests and decision have not run.",
        "coordinator_script_sha256": digest(Path(__file__).resolve()),
        "ledger_sha256": digest(LEDGER)
    }
    assert result["integrity_hold_resolved"]
    write_new(BASE / "completion.json", result)
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=("preserve", "adjudicate", "ledger-patch", "finish"))
    parser.add_argument("--gate", choices=("G0", "G1", "G2", "G7"))
    parser.add_argument("--round", choices=("round3", "round4"), default="round3")
    args = parser.parse_args()
    if args.action == "preserve":
        preserve()
    elif args.action == "finish":
        finish()
    else:
        if not args.gate:
            parser.error("--gate is required")
        if args.action == "adjudicate":
            adjudicate(args.gate, args.round)
        else:
            ledger_patch(args.gate, args.round)
