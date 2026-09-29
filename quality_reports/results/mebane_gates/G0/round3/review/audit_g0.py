#!/usr/bin/env python3
"""Independent documentary audit; exclusive outputs under this review directory."""

import ast
import contextlib
import copy
import datetime as dt
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import sys

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[5]
BASE = "quality_reports/results/mebane_gates/G0/"
R1, R2, R3 = [BASE + value + "/" for value in ("round1", "round2", "round3")]
DECISION = "quality_reports/results/mebane_gates/coordination/2026-09-29_inventory_rebaseline/decision.md"
LEDGER = "quality_reports/plans/mebane_2022_2026_gates.json"
CHECKER = "scripts/mebane_gates.py"
REMOVED = "ssrn-4073770.pdf.download/ssrn-4073770.pdf"
INFO = "ssrn-4073770.pdf.download/Info.plist"
REVIEWER = "01a0edd1-ae42-7973-8cf9-2fda610d33cf"
EXECUTOR = "01a0edcd-cd1f-70f0-b9f5-95fb470b6c40"
EXPECTED = {
    R3 + "candidate_manifest.json": "42406b1ecb8ee843c95ef75a902ab15e6468c7bb7900b5ac8717d6476afd08bf",
    R3 + "inventory_current.json": "8b47e9a0c7939dc60a927e2a885f8e5fc0db19dd150685f94da0aca6081decd1",
    R3 + "tombstone.json": "e219e61c0b6a1ffc1d7b16cbda666945bb223dc9c8adbdc73b0d2ccdef082842",
    R2 + "candidate_manifest.json": "f71333db477385fc78dad8a7a1a7ca78e48479226dcdbde80ce97d724409fec7",
    R2 + "review/review.json": "ef624cb4b2d8ad098b87e196d87add358ce1eba93165d44fcc1939ff303f5376",
    CHECKER: "15601b30477b940bda011a7370d3a2edc269c7ffd89fe92e09d8dd9d34a93480",
    "tests/test_mebane_gates.py": "2509b41b2cea142f2a4e17e64e2f3842ead8abff71409f3cf8462f50cd5d169e",
    DECISION: "fe62bfd30ffd6e985a6070fb6f575770e5097f6c96de543eed145df3df75007a",
}


def read(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def digest(path):
    file = ROOT / path
    if file.is_symlink() or not file.resolve().is_relative_to(ROOT):
        raise ValueError("unsafe input: " + path)
    h = hashlib.sha256()
    size = 0
    with file.open("rb") as stream:
        for block in iter(lambda: stream.read(2**20), b""):
            h.update(block)
            size += len(block)
    return {"path": path, "sha256": h.hexdigest(), "bytes": size}


def canonical(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, ensure_ascii=False,
                                     separators=(",", ":")).encode()).hexdigest()


def write_new(path, value):
    if not path.resolve().is_relative_to(HERE):
        raise ValueError("write outside review")
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x", encoding="utf-8") as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write("\n")


def module(path, name):
    spec = importlib.util.spec_from_file_location(name, ROOT / path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def coverage_errors(manifest, run, inventory, old):
    listed = {x["path"]: x for x in manifest["files"]}
    expected = {x["path"]: x for x in old["files"] if x["path"] != REMOVED}
    errors = []
    if not expected.keys() <= listed.keys():
        errors.append("extra_omission_from_predecessor")
    if any(listed.get(k) != v for k, v in expected.items()):
        errors.append("predecessor_entry_changed_or_missing")
    if {x["path"]: x for x in inventory["active_files"]} != expected:
        errors.append("inventory_not_exact_predecessor_minus_authorized_absence")
    declared = {p for k in ("inputs", "code", "configuration", "outputs") for p in run[k]}
    if not declared <= listed.keys():
        errors.append("declared_path_outside_manifest")
    return errors


def main():
    if len(sys.argv) != 2 or not sys.argv[1].isalnum():
        raise SystemExit("usage: python3 -B audit_g0.py UNIQUE_RUN_ID")
    out = HERE / sys.argv[1]
    out.mkdir(exist_ok=False)
    started = dt.datetime.now(dt.timezone.utc).isoformat()
    checker = module(CHECKER, "review_checker")
    plan = read(LEDGER)
    gate = next(g for g in plan["gates"] if g["id"] == "G0")
    manifest, old, prior = [read(prefix + "candidate_manifest.json") for prefix in (R3, R2, R1)]
    run, inv, tomb, todos = [read(R3 + f + ".json") for f in
                            ("run", "inventory_current", "tombstone", "todo_evidence")]
    listed = {x["path"]: x for x in manifest["files"]}
    checks = []

    def check(name, passed, detail=None):
        checks.append({"id": name, "passed": bool(passed), "detail": detail})

    fingerprints = {path: digest(path) for path in EXPECTED}
    for path, expected in EXPECTED.items():
        check("delivered_or_preparation_hash:" + path, fingerprints[path]["sha256"] == expected)
    contract = read(R3 + "gate_contract.json")
    expected_contract = "e5ba78d6f8d314c2bf94738df85fce0a31d8e9986ef974f6c69ee9e30ee06ca3"
    check("static_contract", canonical(contract) == checker.contract_sha256(gate) == expected_contract)
    check("static_contract_bytes_retained", (ROOT / R3 / "gate_contract.json").read_bytes() ==
          (ROOT / R2 / "gate_contract.json").read_bytes())
    before = read("quality_reports/results/mebane_gates/coordination/2026-09-29_inventory_rebaseline/before/" + LEDGER)
    old_gate = next(g for g in before["gates"] if g["id"] == "G0")
    check("contract_unchanged_since_authorization", checker.contract_sha256(old_gate) == expected_contract)
    for name, obj in (("manifest", manifest), ("run", run)):
        check(name + "_identity", (obj["gate_id"], obj["round"], obj["contract_sha256"]) ==
              ("G0", "round3", expected_contract))
    check("identities_independent", run["executor_id"] == EXECUTOR and
          checker.canonical_uuid(EXECUTOR) and checker.canonical_uuid(REVIEWER) and EXECUTOR != REVIEWER)
    check("g0_dependencies_exactly_empty", gate["depends_on"] == [] and
          run["dependency_manifests"] == {} and run["dependency_approvals"] == {})
    check("unique_paths_no_self", len(listed) == len(manifest["files"]) == 171 and
          R3 + "candidate_manifest.json" not in listed)
    checks_actual = []
    for entry in manifest["files"]:
        actual = digest(entry["path"])
        checks_actual.append({"expected": entry, "actual": actual, "passed": entry == actual})
    check("all_171_active_files_full_hash_and_bytes", all(x["passed"] for x in checks_actual))
    check("predecessor_and_inventory_exact", not coverage_errors(manifest, run, inv, old),
          coverage_errors(manifest, run, inv, old))
    kept = [x for x in old["files"] if x["path"] != REMOVED]
    removed = [x for x in old["files"] if x["path"] == REMOVED]
    check("only_authorized_entry_removed", set(x["path"] for x in old["files"]) - listed.keys() == {REMOVED})
    check("157_retained_bytes", inv["active_file_count"] == len(kept) == 157 and
          inv["active_bytes"] == sum(x["bytes"] for x in kept) == 4247644144)
    check("absence_not_restored", not (ROOT / REMOVED).exists() and not (ROOT / INFO).exists())
    check("absence_not_active", REMOVED not in listed and INFO not in listed)
    check("tombstone_identity", tomb["path"] == REMOVED and tomb["historical_bytes"] == 1360 and
          tomb["historical_sha256"] == removed[0]["sha256"] ==
          "524dc82c59612ec91b3a6ab475dd34f0607546a37823c9a9b1fd652677a8acdf")
    check("tombstone_limits", tomb["deletion_actor"] == tomb["deletion_cause"] == "unknown" and
          tomb["scientific_source"] is False and tomb["historical_quality"] == "invalid_or_incomplete" and
          tomb["other_absence"]["round2_g0_manifest_entry"] is False)
    check("tombstone_evidence_bound", set(tomb["evidence_paths"]) <= listed.keys() and DECISION in run["inputs"])
    inventory_base = read(R1 + "inventory.json")
    item = next(x for x in inventory_base["items"] if x["path"] == REMOVED)
    check("historical_invalid_status", item["pdf_integrity"] == tomb["historical_quality"] and
          item["sha256"] == tomb["historical_sha256"] and item["bytes"] == 1360)
    check("historical_original_paths_explicit", set(inv["historical_original_paths_not_attested_as_active"]) ==
          {x["path"] for x in inventory_base["items"]} - {x["path"] for x in kept})
    check("historical_calculations_not_rerun", inv["prior_calculations_reexecuted"] is False and
          all(e["basis"] == "historical" for t in todos["todos"] for e in t["evidence"]
              if not e["path"].startswith(R3)))
    check("todo_ids_exact", {x["id"] for x in todos["todos"]} == {x["id"] for x in gate["todos"]}
          and len(todos["todos"]) == len(gate["todos"]))
    check("todos_nonempty_and_bound", all(t["status"] == "done" and t["evidence"] and
          all(e["path"] in listed and e["basis"] in {"historical", "inspected", "executed"}
              for e in t["evidence"]) for t in todos["todos"]))
    check("all_run_fields_complete", all(isinstance(run[k], list) and len(run[k]) == len(set(run[k]))
          for k in ("inputs", "code", "configuration", "outputs")) and R3 + "run.json" in listed)
    check("predecessor_binding", run["repaired_from_manifest_sha256"] ==
          fingerprints[R2 + "candidate_manifest.json"]["sha256"])
    prior_review, prior_adjudication = [read(R2 + p) for p in ("review/review.json", "adjudication.json")]
    check("prior_approval_bindings_historical_only", prior_adjudication["review_sha256"] ==
          fingerprints[R2 + "review/review.json"]["sha256"] and prior_review["candidate_manifest_sha256"] ==
          prior_adjudication["candidate_manifest_sha256"] == run["repaired_from_manifest_sha256"])

    transitive = []
    for entry in prior["files"]:
        if entry["path"] not in listed and entry["path"] != REMOVED:
            actual = digest(entry["path"])
            transitive.append({"expected": entry, "actual": actual, "passed": entry == actual})
    check("22_transitive_round1_artifacts_retained", len(transitive) == 22 and all(x["passed"] for x in transitive))

    # Execute verify only, with actual reads logged and all writes/removals forbidden.
    trace = {"active": False, "reads": set(), "writes_or_deletions": []}

    def hook(event, args):
        if not trace["active"]:
            return
        if event in {"os.remove", "os.rmdir", "os.rename", "os.mkdir", "os.truncate"}:
            trace["writes_or_deletions"].append([event, repr(args)])
            raise RuntimeError("candidate attempted filesystem mutation")
        if event == "open" and isinstance(args[0], (str, bytes, os.PathLike)):
            path = Path(os.fsdecode(args[0])).resolve()
            mode, flags = args[1], args[2]
            if (isinstance(mode, str) and any(c in mode for c in "wax+")) or (
                    isinstance(flags, int) and flags & (os.O_WRONLY | os.O_RDWR | os.O_CREAT | os.O_TRUNC)):
                trace["writes_or_deletions"].append([event, str(path)])
                raise RuntimeError("candidate attempted write")
            if path.is_file() and path.is_relative_to(ROOT):
                trace["reads"].add(path.relative_to(ROOT).as_posix())

    sys.addaudithook(hook)
    stdout = io.StringIO()
    trace["active"] = True
    try:
        builder = module(R3 + "build_candidate.py", "reviewed_builder")
        with contextlib.redirect_stdout(stdout):
            builder.verify()
        verify_error = None
    except Exception as error:
        verify_error = repr(error)
    finally:
        trace["active"] = False
    check("executor_verify_completed_read_only", verify_error is None and not trace["writes_or_deletions"],
          {"stdout": stdout.getvalue(), "error": verify_error})
    closure_paths = listed.keys() | {R3 + "candidate_manifest.json"} | {x["expected"]["path"] for x in transitive}
    substantive_reads = {p for p in trace["reads"] if "__pycache__" not in p}
    # The explicit import in check_contract resolves to the current source even with bytecode cache.
    substantive_reads.add(CHECKER)
    outside = sorted(substantive_reads - closure_paths)
    read_records = [dict(digest(p), in_frozen_closure=p in closure_paths) for p in sorted(substantive_reads)]
    check("actual_executor_input_code_closure_complete", not outside, outside)

    # Isolate the actual todo-emission block; a changed live ledger is only supplied in memory.
    tree = ast.parse((ROOT / R3 / "build_candidate.py").read_text())
    build = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == "build")
    start = next(i for i, n in enumerate(build.body) if isinstance(n, ast.Assign) and
                 any(isinstance(t, ast.Name) and t.id == "todos" for t in n.targets))
    stop = next(i for i in range(start, len(build.body)) if isinstance(build.body[i], ast.Expr) and
                isinstance(build.body[i].value, ast.Call) and build.body[i].value.args and
                isinstance(build.body[i].value.args[0], ast.Constant) and
                build.body[i].value.args[0].value == "todo_evidence.json")
    block = compile(ast.Module(body=build.body[start:stop + 1], type_ignores=[]), "<candidate-todo-block>", "exec")
    ledger_probe = copy.deepcopy(plan)
    altered_gate = next(g for g in ledger_probe["gates"] if g["id"] == "G0")
    altered_gate["todos"][0]["evidence"][0]["path"] = R3 + "tombstone.json"
    original_reader = builder.read_json
    builder.read_json = lambda p: ledger_probe if str(p) == LEDGER else original_reader(p)
    try:
        _, accepted_gate, accepted_hash = builder.check_contract(old)
        contract_accepts_mutated_evidence = accepted_hash == expected_contract
    finally:
        builder.read_json = original_reader
    emitted = []
    for g in (gate, accepted_gate):
        captures = {}
        namespace = dict(vars(builder))
        namespace.update(gate=g, write_json=lambda name, obj: captures.update({name: obj}))
        exec(block, namespace)
        emitted.append(captures["todo_evidence.json"])
    ledger_probe_result = {
        "synthetic_in_memory_only": True,
        "changed_field": "G0.todos[0].evidence[0].path",
        "original_path": gate["todos"][0]["evidence"][0]["path"],
        "mutated_path": altered_gate["todos"][0]["evidence"][0]["path"],
        "same_static_contract_accepted": contract_accepts_mutated_evidence,
        "todo_output_changed": emitted[0] != emitted[1],
        "baseline_matches_frozen_todo": emitted[0] == todos,
        "emitted_outputs": emitted,
        "candidate_build_executed": False,
    }
    check("hidden_ledger_dependency_counterexample_confirmed", contract_accepts_mutated_evidence and
          emitted[0] == todos and emitted[0] != emitted[1])

    target = "replication_authors/extracted/fingerprint_brazil/raw-data/votacao_secao_2022_BR.csv"
    omission_probes = []
    for coordinated in (False, True):
        mm, rr, ii = copy.deepcopy(manifest), copy.deepcopy(run), copy.deepcopy(inv)
        mm["files"] = [x for x in mm["files"] if x["path"] != target]
        if coordinated:
            for field in ("inputs", "code", "configuration", "outputs"):
                rr[field] = [p for p in rr[field] if p != target]
            ii["active_files"] = [x for x in ii["active_files"] if x["path"] != target]
        errors = coverage_errors(mm, rr, ii, old)
        omission_probes.append({"target": target, "coordinated_removal": coordinated,
                                "rejected": bool(errors), "errors": errors})
    check("extra_omission_counterexamples_rejected", all(x["rejected"] for x in omission_probes))

    # Exercise the unmodified checker on tiny, explicitly synthetic records, never the ledger.
    fixture_root = out / "synthetic_checker"
    fixture_root.mkdir()
    synthetic = copy.deepcopy(gate)
    synthetic["depends_on"] = ["G1"]
    synthetic_contract = checker.contract_sha256(synthetic)
    for todo in synthetic["todos"]:
        todo["evidence"] = [{"path": "input.json", "basis": "inspected"}]
    for file in ("input.json", "output.json", "parent_manifest.json", "parent_review.json", "parent_adjudication.json"):
        write_new(fixture_root / file, {"synthetic": True, "file": file})
    parent = {"id": "G1", "records": {"candidate_manifest": "parent_manifest.json",
              "review": "parent_review.json", "adjudication": "parent_adjudication.json"}}
    synthetic_results = []
    for label in ("valid_control", "wrong_dependency_manifest", "wrong_dependency_review", "wrong_dependency_keys"):
        sr = {"gate_id": "G0", "round": "round3", "contract_sha256": synthetic_contract,
              "executor_id": EXECUTOR, "inputs": ["input.json"], "outputs": ["output.json"],
              "code": [], "configuration": [],
              "dependency_manifests": {"G1": checker.sha256(fixture_root / "parent_manifest.json")},
              "dependency_approvals": {"G1": {f + "_sha256": checker.sha256(fixture_root / ("parent_" + f + ".json"))
                                              for f in ("review", "adjudication")}}}
        if label == "wrong_dependency_manifest":
            sr["dependency_manifests"]["G1"] = "0" * 64
        elif label == "wrong_dependency_review":
            sr["dependency_approvals"]["G1"]["review_sha256"] = "0" * 64
        elif label == "wrong_dependency_keys":
            sr["dependency_manifests"] = {"G2": "0" * 64}
        write_new(fixture_root / (label + "_run.json"), sr)
        sm = {"gate_id": "G0", "round": "round3", "contract_sha256": synthetic_contract,
              "files": [{"path": p, "sha256": checker.sha256(fixture_root / p)}
                        for p in ("input.json", "output.json", label + "_run.json")]}
        write_new(fixture_root / (label + "_manifest.json"), sm)
        sh = checker.sha256(fixture_root / (label + "_manifest.json"))
        review = {"gate_id": "G0", "round": "round3", "contract_sha256": synthetic_contract,
                  "candidate_manifest_sha256": sh, "executor_id": EXECUTOR, "reviewer_id": REVIEWER,
                  "manifest_complete": True, "status": "pass", "findings": [], "synthetic": True}
        write_new(fixture_root / (label + "_review.json"), review)
        adj = {"gate_id": "G0", "round": "round3", "contract_sha256": synthetic_contract,
               "candidate_manifest_sha256": sh, "status": "pass", "findings": [],
               "unresolved_material_findings": 0, "synthetic": True,
               "review_sha256": checker.sha256(fixture_root / (label + "_review.json"))}
        write_new(fixture_root / (label + "_adjudication.json"), adj)
        synthetic["records"] = {"executor_id": EXECUTOR, "reviewer_id": REVIEWER,
                                "run": label + "_run.json", "candidate_manifest": label + "_manifest.json",
                                "review": label + "_review.json", "adjudication": label + "_adjudication.json"}
        errors = checker.check_records(synthetic, fixture_root, {"G0": synthetic, "G1": parent})
        expected_message = {"wrong_dependency_manifest": "stale dependency manifest G1",
                            "wrong_dependency_review": "stale dependency approval G1 review",
                            "wrong_dependency_keys": "run.dependency_manifests must match dependencies"}.get(label)
        ok = errors == [] if expected_message is None else any(expected_message in e for e in errors)
        synthetic_results.append({"case": label, "passed": ok, "errors": errors})
    check("checker_dependency_probes", all(x["passed"] for x in synthetic_results))

    final_hashes = {p: digest(p) for p in EXPECTED}
    check("frozen_and_checker_hashes_unchanged_at_end", fingerprints == final_hashes)
    historical_qa = [digest(str(p.relative_to(ROOT))) for p in sorted((ROOT / R2 / "review").iterdir()) if p.is_file()]
    results = {
        "gate_id": "G0", "round": "round3", "reviewer_id": REVIEWER,
        "started_at_utc": started, "finished_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "command": ["python3", "-B", str(Path(__file__).relative_to(ROOT)), sys.argv[1]],
        "checks": checks, "failed_checks": [c["id"] for c in checks if not c["passed"]],
        "counts": {"candidate_files": len(checks_actual), "candidate_bytes": sum(x["actual"]["bytes"] for x in checks_actual),
                   "retained_predecessor_files": len(kept), "retained_predecessor_bytes": sum(x["bytes"] for x in kept),
                   "transitive_round1_files": len(transitive), "checks": len(checks)},
        "actual_executor_reads_not_frozen": outside, "executor_verify_stdout": stdout.getvalue(),
        "executor_verify_error": verify_error, "executor_write_attempts": trace["writes_or_deletions"],
        "closure_policy": "Historical manifests remain immutable records. Their authorized absent PDF is not active. All other inherited active/transitive bytes are checked, including qbl and DESCRIPTION.",
        "limits": ["No R, MCMC, installation, network or electoral analysis.",
                   "Only verify and the isolated todo-emission block executed; build never executed.",
                   "Synthetic checker approvals confer no gate approval.",
                   "Prior scientific tests inspected as historical, not rerun."],
        "fingerprints_initial": fingerprints, "fingerprints_final": final_hashes,
    }
    write_new(out / "active_hashes.json", checks_actual)
    write_new(out / "transitive_hashes.json", transitive)
    write_new(out / "historical_qa_hashes.json", historical_qa)
    write_new(out / "executor_reads.json", {"effective_project_reads": read_records,
              "all_traced_project_reads": sorted(trace["reads"]), "outside_frozen_closure": outside,
              "note": "Python bytecode cache reads are listed but not treated as additional scientific inputs."})
    write_new(out / "ledger_counterexample.json", ledger_probe_result)
    write_new(out / "omission_probes.json", omission_probes)
    write_new(out / "dependency_probes.json", synthetic_results)
    write_new(out / "results.json", results)
    print(json.dumps({"results": str((out / "results.json").relative_to(ROOT)),
                      "counts": results["counts"], "failed_checks": results["failed_checks"],
                      "outside_frozen_closure": outside}, indent=2))
    return 1 if results["failed_checks"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
