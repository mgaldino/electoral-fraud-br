#!/usr/bin/env python3
"""Bounded documentary recheck, using the G0 QA hash/trace/probe pattern."""
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
ROOT = Path(__file__).resolve().parents[6]
REVIEWER = "01a0edd1-ae42-7973-8cf9-2fda610d33cf"
EXECUTOR = "01a0edcd-cd1f-70f0-b9f5-95fb470b6c40"
EXPECTED = {
    "G1": ("abfca9053b1023ceceab6504c12f9774f36d085727f47118418ea3f87cf5dfcd",
           "f729008b8179805acda7c24a6c9cb2669cfa767fa76bd48edfb1b320141af0a9", 209, 194),
    "G2": ("2ffd63203a6af407c5f17c708ce2c42120fef0dc9600e3585f83be6e48313173",
           "55095ed3b69d0ee0dc933c2be0c8af05f4012aac3c31bc19f60b5535521a81e3", 178, 163),
}


def load(path):
    return json.loads((ROOT / path).read_text())


def digest(path):
    file = ROOT / path
    assert not file.is_symlink() and file.resolve().is_relative_to(ROOT)
    h, size = hashlib.sha256(), 0
    with file.open("rb") as stream:
        for block in iter(lambda: stream.read(2**20), b""):
            h.update(block)
            size += len(block)
    return {"path": path, "sha256": h.hexdigest(), "bytes": size}


def static(gate):
    result = {k: v for k, v in gate.items() if k not in {"status", "records"}}
    result["todos"] = [{k: v for k, v in t.items() if k not in {"status", "evidence"}} for t in gate["todos"]]
    return result


def canonical(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(",", ":")).encode()).hexdigest()


def audit(directory):
    gate_id = directory.parent.name
    expected_hash, expected_snapshot, count, old_count = EXPECTED[gate_id]
    prefix = directory.relative_to(ROOT).as_posix() + "/"
    old_prefix = prefix.replace("round3/", "round2/")
    out = directory / "review"
    manifest, run, snapshot, inherited, todos = [load(prefix + name + ".json") for name in
        ("candidate_manifest", "run", "ledger_input_snapshot", "inherited_map", "todo_evidence")]
    old = load(old_prefix + "candidate_manifest.json")
    gate = snapshot["gates"][gate_id]
    checks = []

    def check(name, condition, detail=None):
        checks.append({"id": name, "passed": bool(condition), "detail": detail})

    check("delivered_manifest", digest(prefix + "candidate_manifest.json")["sha256"] == expected_hash)
    check("delivered_snapshot", digest(prefix + "ledger_input_snapshot.json")["sha256"] == expected_snapshot)
    contract = load(prefix + "gate_contract.json")
    check("static_contract_preserved", contract == static(gate) == load(old_prefix + "gate_contract.json") and
          canonical(contract) == manifest["contract_sha256"] == run["contract_sha256"] == old["contract_sha256"])
    check("identities_and_round", run["executor_id"] == EXECUTOR and EXECUTOR != REVIEWER and
          (manifest["gate_id"], manifest["round"], run["gate_id"], run["round"], snapshot["target_gate_id"]) ==
          (gate_id, "round3", gate_id, "round3", gate_id))
    records = []
    for expected in manifest["files"]:
        actual = digest(expected["path"])
        records.append({"expected": expected, "actual": actual, "passed": actual == expected})
    listed = {x["path"]: x for x in manifest["files"]}
    check("all_active_hashes_bytes", len(listed) == len(records) == count and all(x["passed"] for x in records))
    remap = {x["original"]: x["snapshot"] for x in inherited["remapped"]}
    expected_inherited = [{"path": remap.get(x["path"], x["path"]), "sha256": x["sha256"], "bytes": x["bytes"]}
                          for x in old["files"]]
    check("all_prior_entries_preserved_via_snapshots", len(old["files"]) == old_count and
          len(remap) == len(inherited["remapped"]) and all(listed.get(x["path"]) == x for x in expected_inherited))
    old_lookup = {x["path"]: x for x in old["files"]}
    check("snapshot_map_exact", all(x["original"] in old_lookup and
          x["sha256"] == old_lookup[x["original"]]["sha256"] and x["snapshot"].startswith(prefix + "snapshots/")
          for x in inherited["remapped"]))
    check("prior_identity_and_byte_counts", inherited["source_manifest"] == snapshot["source_round2_manifest"] ==
          digest(old_prefix + "candidate_manifest.json") and run["round2_manifest_sha256"] == inherited["source_manifest"]["sha256"] and
          run["round2_entries_verified"] == inherited["round2_entries_verified"] == old_count and
          run["round2_bytes_verified"] == inherited["round2_bytes_verified"] == sum(x["bytes"] for x in old["files"]))
    check("snapshot_run_binding", run["ledger_input_snapshot"] == prefix + "ledger_input_snapshot.json" and
          run["ledger_input_snapshot_sha256"] == expected_snapshot and
          run["source_ledger_sha256"] == snapshot["source_ledger_sha256"])
    check("decision_binding", digest(snapshot["source_decision"]["path"]) == snapshot["source_decision"] and
          run["decision_sha256"] == snapshot["source_decision"]["sha256"] ==
          "fe62bfd30ffd6e985a6070fb6f575770e5097f6c96de543eed145df3df75007a")
    check("run_paths_covered", prefix + "run.json" in listed and all(isinstance(run[k], list) and
          len(run[k]) == len(set(run[k])) and all(p in listed for p in run[k])
          for k in ("inputs", "code", "configuration", "outputs")))
    expected_todos = []
    for todo in gate["todos"]:
        evidence = [{"path": remap.get(e["path"], e["path"]), "basis": "historical",
                     "locator": e.get("locator", "") + "; SHA-256/bytes rechecked in round3; no scientific rerun"}
                    for e in todo["evidence"]]
        evidence.append({"path": prefix + "inherited_map.json", "basis": "executed",
                         "locator": "All direct round2 manifest entries rechecked by SHA-256 and byte count"})
        expected_todos.append({"id": todo["id"], "status": todo["status"], "evidence": evidence})
    check("todos_exact_frozen_projection_and_covered", todos["todos"] == expected_todos and
          all(t["status"] == "done" and all(e["path"] in listed for e in t["evidence"]) for t in todos["todos"]))
    check("scientific_reuse_explicit", run["scientific_execution"] is False and run["MCMC"] is False and
          inherited["scientific_calculations_reexecuted"] is False)

    parent = snapshot["gates"]["G0"]
    approvals = snapshot["approved_predecessors"]["G0"]
    parent_records = {k: digest(parent["records"][k]) for k in ("run", "candidate_manifest", "review", "adjudication")}
    pm, pr, pa, parent_run = [load(parent["records"][k]) for k in ("candidate_manifest", "review", "adjudication", "run")]
    check("G0_round4_real_approval", parent["status"] == "pass" and approvals["round"] == "round4" and
          approvals["records"] == parent_records and
          parent_records["candidate_manifest"]["sha256"] == "d73ecc86824fd5eaa66ece7cad41d6c21d913d455af864d32c11c5331fa5bb57" and
          pr["status"] == pa["status"] == "pass" and pr["manifest_complete"] is True and
          pr["candidate_manifest_sha256"] == pa["candidate_manifest_sha256"] == parent_records["candidate_manifest"]["sha256"] and
          pa["review_sha256"] == parent_records["review"]["sha256"] and pa["unresolved_material_findings"] == 0 and
          pr["executor_id"] == parent_run["executor_id"] == parent["records"]["executor_id"] and
          pr["reviewer_id"] == parent["records"]["reviewer_id"] != pr["executor_id"] and
          all((x["gate_id"], x["round"], x["contract_sha256"]) == ("G0", "round4", canonical(static(parent)))
              for x in (pm, pr, pa, parent_run)))
    parent_checks = []
    for expected in pm["files"]:
        actual = digest(expected["path"])
        parent_checks.append({"expected": expected, "actual": actual, "passed": actual == expected})
    check("active_G0_dependency_hashes_bytes", len(parent_checks) == 186 and all(x["passed"] for x in parent_checks))
    expected_deps = {"G0": parent_records["candidate_manifest"]["sha256"]}
    expected_approvals = {"G0": {k + "_sha256": parent_records[k]["sha256"] for k in ("review", "adjudication")}}

    def dependency_ok(value):
        return gate["depends_on"] == ["G0"] and value["dependency_manifests"] == expected_deps and value["dependency_approvals"] == expected_approvals

    check("direct_dependency_bindings_exact", dependency_ok(run))
    bad = copy.deepcopy(run)
    bad["dependency_approvals"]["G0"]["review_sha256"] = "0" * 64
    check("wrong_dependency_counterexample_rejected", not dependency_ok(bad))
    omitted = dict(listed)
    del omitted[expected_inherited[0]["path"]]
    check("extra_omission_counterexample_rejected", not all(omitted.get(x["path"]) == x for x in expected_inherited))

    trace = {"active": False, "reads": set(), "violations": []}

    def hook(event, args):
        if not trace["active"]:
            return
        if event in {"os.remove", "os.rmdir", "os.rename", "os.mkdir", "os.truncate"}:
            trace["violations"].append(event)
            raise RuntimeError("filesystem mutation forbidden")
        if event == "open" and isinstance(args[0], (str, bytes, os.PathLike)):
            p = Path(os.fsdecode(args[0])).resolve()
            mode, flags = args[1:3]
            if (isinstance(mode, str) and any(c in mode for c in "wax+")) or (isinstance(flags, int) and
                    flags & (os.O_WRONLY | os.O_RDWR | os.O_CREAT | os.O_TRUNC)):
                raise RuntimeError("write forbidden")
            if p.is_relative_to(ROOT):
                rel = p.relative_to(ROOT).as_posix()
                if rel in {"quality_reports/plans/mebane_2022_2026_gates.json", "scripts/mebane_gates.py"}:
                    trace["violations"].append(rel)
                    raise RuntimeError("live input forbidden")
                if p.is_file():
                    trace["reads"].add(rel)

    sys.addaudithook(hook)
    output = io.StringIO()
    trace["active"] = True
    try:
        spec = importlib.util.spec_from_file_location("reviewed_" + gate_id, directory / "build_candidate.py")
        builder = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(builder)
        with contextlib.redirect_stdout(output):
            builder.verify()
        verify_error = None
    except Exception as error:
        verify_error = repr(error)
    finally:
        trace["active"] = False
    allowed = set(listed) | {prefix + "candidate_manifest.json"} | {x["path"] for x in pm["files"]}
    unexpected = sorted(p for p in trace["reads"] if p not in allowed and "__pycache__" not in p)
    check("verify_read_only_frozen_closure", verify_error is None and not unexpected and not trace["violations"],
          {"error": verify_error, "unexpected": unexpected, "violations": trace["violations"]})
    mutated = copy.deepcopy(snapshot)
    mutated["gates"]["G0"]["records"]["review"] = parent["records"]["adjudication"]
    try:
        builder.approved_chain(mutated["gates"], gate_id)
        wrong_parent_error = None
    except ValueError as error:
        wrong_parent_error = str(error)
    check("wrong_parent_record_rejected_by_executor", wrong_parent_error is not None, wrong_parent_error)
    check("candidate_hash_unchanged", digest(prefix + "candidate_manifest.json")["sha256"] == expected_hash and
          digest(prefix + "ledger_input_snapshot.json")["sha256"] == expected_snapshot)
    prior_review = load(old_prefix + "review/review.json")
    if gate_id == "G2":
        benchmark = load(old_prefix + "benchmark_contract.json")
        check("G2_methodological_scope_preserved", benchmark["target_kind"] == "literal_software_benchmark_not_certified_data_generator" and
              benchmark["inferential_approval"] is False and prior_review["inferential_approval"] is False and
              prior_review["benchmark_closure_result"] == "pass_in_delimited_methodological_scope")
    report = {"gate_id": gate_id, "round": "round3", "reviewer_id": REVIEWER,
              "checked_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(), "checks": checks,
              "failed_checks": [x["id"] for x in checks if not x["passed"]], "file_checks": records,
              "active_dependency_file_checks": parent_checks, "dependency_records": parent_records,
              "actual_reads": sorted(trace["reads"]), "unexpected_reads": unexpected,
              "verify_stdout": output.getvalue(), "prior_review": digest(old_prefix + "review/review.json"),
              "prior_review_status": prior_review["status"], "snapshot_count": len(remap),
              "run": digest(prefix + "run.json"), "manifest": digest(prefix + "candidate_manifest.json"),
              "snapshot": digest(prefix + "ledger_input_snapshot.json"),
              "scope": "Documentary only. Historical mathematical/data tests not rerun; build not executed.",
              "counterexamples_in_memory_only": True}
    with (out / "checks.json").open("x", encoding="utf-8") as stream:
        json.dump(report, stream, ensure_ascii=False, indent=2)
        stream.write("\n")
    print(json.dumps({"gate": gate_id, "checks": len(checks), "failed": report["failed_checks"],
                      "files": len(records), "bytes": sum(x["actual"]["bytes"] for x in records),
                      "remapped": len(remap), "run_sha256": report["run"]["sha256"],
                      "prior_review_sha256": report["prior_review"]["sha256"]}, indent=2))
    return bool(report["failed_checks"])


if __name__ == "__main__":
    raise SystemExit(audit(Path(__file__).resolve().parents[1]))
