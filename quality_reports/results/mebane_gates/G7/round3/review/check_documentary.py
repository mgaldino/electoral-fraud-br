#!/usr/bin/env python3
"""Last bounded documentary QA; reuse pinned helpers and preserve all earlier QA."""
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
PREFIX = "quality_reports/results/mebane_gates/G7/round3/"
OLD = PREFIX.replace("round3/", "round2/")
SOURCE = ROOT / "quality_reports/results/mebane_gates/G1/round3/review/check_documentary.py"
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == "fdd479573b86944ee004bac6ad35e27c3eec51af0064527164f2f3d28bb992d2"
spec = importlib.util.spec_from_file_location("frozen_documentary_helpers", SOURCE)
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)
digest, load, static, canonical = helper.digest, helper.load, helper.static, helper.canonical
EXPECTED_MANIFEST = "7cd76163b6092cbde5b25dfc0bbb5386f001a456e7982018f7cf57fbc558bd92"
EXPECTED_SNAPSHOT = "ef836760b1f885b2f383b81521cea6ca65b4b8ac469c0475b0dbc768feddc5e2"
checks = []


def check(name, value, detail=None):
    checks.append({"id": name, "passed": bool(value), "detail": detail})


manifest, run, snapshot, inherited, todos = [load(PREFIX + name + ".json") for name in
    ("candidate_manifest", "run", "ledger_input_snapshot", "inherited_map", "todo_evidence")]
old = load(OLD + "candidate_manifest.json")
gate = snapshot["gates"]["G7"]
contract = load(PREFIX + "gate_contract.json")
check("delivered_manifest", digest(PREFIX + "candidate_manifest.json")["sha256"] == EXPECTED_MANIFEST)
check("delivered_snapshot", digest(PREFIX + "ledger_input_snapshot.json")["sha256"] == EXPECTED_SNAPSHOT)
check("static_contract_preserved", contract == static(gate) == load(OLD + "gate_contract.json") and
      canonical(contract) == manifest["contract_sha256"] == run["contract_sha256"] == old["contract_sha256"] ==
      "fc071a8664d04ba6a0a4ca91298d333ee1ca89868a26b23e705946fef1c2f94d")
check("gate_round_executor", (manifest["gate_id"], manifest["round"], run["gate_id"], run["round"], snapshot["target_gate_id"]) ==
      ("G7", "round3", "G7", "round3", "G7") and run["executor_id"] == "01a0edcd-cd1f-70f0-b9f5-95fb470b6c40")
records = []
for expected in manifest["files"]:
    actual = digest(expected["path"])
    records.append({"expected": expected, "actual": actual, "passed": expected == actual})
listed = {x["path"]: x for x in manifest["files"]}
check("1878_active_hashes_and_bytes", len(listed) == len(records) == 1878 and all(x["passed"] for x in records))
remap = {x["original"]: x["snapshot"] for x in inherited["remapped"]}
preserved = [{"path": remap.get(x["path"], x["path"]), "sha256": x["sha256"], "bytes": x["bytes"]} for x in old["files"]]
old_lookup = {x["path"]: x for x in old["files"]}
check("1859_prior_entries_preserved", len(old["files"]) == 1859 and all(listed.get(x["path"]) == x for x in preserved))
check("18_snapshot_mappings_exact", len(remap) == len(inherited["remapped"]) == 18 and
      all(x["sha256"] == old_lookup[x["original"]]["sha256"] and x["snapshot"].startswith(PREFIX + "snapshots/")
          for x in inherited["remapped"]))
check("prior_identity_and_byte_counts", inherited["source_manifest"] == snapshot["source_round2_manifest"] ==
      digest(OLD + "candidate_manifest.json") and run["round2_manifest_sha256"] == inherited["source_manifest"]["sha256"] and
      run["round2_entries_verified"] == inherited["round2_entries_verified"] == 1859 and
      run["round2_bytes_verified"] == inherited["round2_bytes_verified"] == sum(x["bytes"] for x in old["files"]) == 5119223)
check("snapshot_run_binding", run["ledger_input_snapshot"] == PREFIX + "ledger_input_snapshot.json" and
      run["ledger_input_snapshot_sha256"] == EXPECTED_SNAPSHOT and run["source_ledger_sha256"] == snapshot["source_ledger_sha256"])
check("decision_bound", digest(snapshot["source_decision"]["path"]) == snapshot["source_decision"] and
      run["decision_sha256"] == snapshot["source_decision"]["sha256"] ==
      "fe62bfd30ffd6e985a6070fb6f575770e5097f6c96de543eed145df3df75007a")
check("run_covered", PREFIX + "run.json" in listed and all(isinstance(run[k], list) and
      len(run[k]) == len(set(run[k])) and all(p in listed for p in run[k]) for k in ("inputs", "code", "configuration", "outputs")))
expected_todos = []
for todo in gate["todos"]:
    evidence = [{"path": remap.get(e["path"], e["path"]), "basis": "historical",
                 "locator": e.get("locator", "") + "; SHA-256/bytes rechecked in round3; no scientific rerun"}
                for e in todo["evidence"]]
    evidence.append({"path": PREFIX + "inherited_map.json", "basis": "executed",
                     "locator": "All direct round2 manifest entries rechecked by SHA-256 and byte count"})
    expected_todos.append({"id": todo["id"], "status": todo["status"], "evidence": evidence})
check("todos_exact_frozen_projection", todos["todos"] == expected_todos and all(t["status"] == "done" and
      all(e["path"] in listed for e in t["evidence"]) for t in todos["todos"]))
prior_review = load(OLD + "review/review.json")
check("historical_science_and_staging_scope", run["scientific_execution"] is False and run["MCMC"] is False and
      inherited["scientific_calculations_reexecuted"] is False and prior_review["status"] == "pass" and
      run["scope"] == "Normalized-CSV staging rehearsal only; not an official-raw converter or 2026 inference.")

parent_records, parent_checks, parent_manifests = {}, [], {}
expected_parents = {"G0": ("round4", "d73ecc86824fd5eaa66ece7cad41d6c21d913d455af864d32c11c5331fa5bb57", 186),
                    "G1": ("round3", "abfca9053b1023ceceab6504c12f9774f36d085727f47118418ea3f87cf5dfcd", 209)}
check("chain_exact", set(snapshot["gates"]) == {"G0", "G1", "G7"} and
      set(snapshot["approved_predecessors"]) == {"G0", "G1"} and gate["depends_on"] == ["G1"] and
      snapshot["gates"]["G1"]["depends_on"] == ["G0"] and snapshot["gates"]["G0"]["depends_on"] == [])
for key, (round_id, expected_hash, count) in expected_parents.items():
    parent = snapshot["gates"][key]
    approved = snapshot["approved_predecessors"][key]
    rec = {field: digest(parent["records"][field]) for field in ("run", "candidate_manifest", "review", "adjudication")}
    parent_records[key] = rec
    pm, pr, pa, rr = [load(parent["records"][field]) for field in ("candidate_manifest", "review", "adjudication", "run")]
    parent_manifests[key] = pm
    check(key + "_real_approval", parent["status"] == "pass" and approved["round"] == round_id and
          approved["records"] == rec and rec["candidate_manifest"]["sha256"] == expected_hash and
          pr["status"] == pa["status"] == "pass" and pr["manifest_complete"] is True and
          pr["candidate_manifest_sha256"] == pa["candidate_manifest_sha256"] == expected_hash and
          pa["review_sha256"] == rec["review"]["sha256"] and pa["unresolved_material_findings"] == 0 and
          pr["executor_id"] == rr["executor_id"] == parent["records"]["executor_id"] and
          pr["reviewer_id"] == parent["records"]["reviewer_id"] != pr["executor_id"] and
          all((v["gate_id"], v["round"], v["contract_sha256"]) == (key, round_id, canonical(static(parent))) for v in (pm, pr, pa, rr)))
    rows = []
    for expected in pm["files"]:
        actual = digest(expected["path"])
        rows.append({"expected": expected, "actual": actual, "passed": expected == actual, "gate_id": key})
    parent_checks.extend(rows)
    check(key + "_active_hashes_bytes", len(rows) == count and all(x["passed"] for x in rows))
    deps = parent["depends_on"]
    check(key + "_dependency_bindings", rr["dependency_manifests"] ==
          {d: parent_records[d]["candidate_manifest"]["sha256"] for d in deps} and rr["dependency_approvals"] ==
          {d: {f + "_sha256": parent_records[d][f]["sha256"] for f in ("review", "adjudication")} for d in deps})


def dependency_ok(value):
    return value["dependency_manifests"] == {"G1": parent_records["G1"]["candidate_manifest"]["sha256"]} and \
        value["dependency_approvals"] == {"G1": {f + "_sha256": parent_records["G1"][f]["sha256"] for f in ("review", "adjudication")}}


check("G7_direct_dependency_exact", dependency_ok(run))
bad_run = copy.deepcopy(run)
bad_run["dependency_approvals"]["G1"]["review_sha256"] = "0" * 64
check("wrong_dependency_hash_rejected", not dependency_ok(bad_run))
omitted = dict(listed)
del omitted[preserved[0]["path"]]
check("extra_omission_rejected", not all(omitted.get(x["path"]) == x for x in preserved))

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
trace["active"] = True
output = io.StringIO()
try:
    spec = importlib.util.spec_from_file_location("reviewed_G7", HERE.parent / "build_candidate.py")
    builder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(builder)
    with contextlib.redirect_stdout(output):
        builder.verify()
    verify_error = None
except Exception as error:
    verify_error = repr(error)
finally:
    trace["active"] = False
allowed = set(listed) | {PREFIX + "candidate_manifest.json"} | {x["path"] for pm in parent_manifests.values() for x in pm["files"]}
unexpected = sorted(p for p in trace["reads"] if p not in allowed and "__pycache__" not in p)
check("verify_read_only_frozen_closure", verify_error is None and not unexpected and not trace["violations"],
      {"error": verify_error, "unexpected": unexpected, "violations": trace["violations"]})
bad_gates = copy.deepcopy(snapshot["gates"])
bad_gates["G1"]["records"]["review"] = bad_gates["G1"]["records"]["adjudication"]
try:
    builder.approved_chain(bad_gates, "G7")
    dependency_error = None
except ValueError as error:
    dependency_error = str(error)
check("wrong_parent_record_rejected_by_executor", dependency_error is not None, dependency_error)
check("candidate_unchanged", digest(PREFIX + "candidate_manifest.json")["sha256"] == EXPECTED_MANIFEST and
      digest(PREFIX + "ledger_input_snapshot.json")["sha256"] == EXPECTED_SNAPSHOT)
report = {"gate_id": "G7", "round": "round3", "reviewer_id": "01a0edd1-ae42-7973-8cf9-2fda610d33cf",
          "checked_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(), "checks": checks,
          "failed_checks": [x["id"] for x in checks if not x["passed"]], "file_checks": records,
          "active_dependency_file_checks": parent_checks, "dependency_records": parent_records,
          "actual_reads": sorted(trace["reads"]), "unexpected_reads": unexpected,
          "verify_stdout": output.getvalue(), "prior_review": digest(OLD + "review/review.json"),
          "run": digest(PREFIX + "run.json"), "manifest": digest(PREFIX + "candidate_manifest.json"),
          "snapshot": digest(PREFIX + "ledger_input_snapshot.json"), "snapshot_count": len(remap),
          "scope": "Documentary hashes, snapshots, approved chain and scope only; no scientific reruns or build.",
          "counterexamples_in_memory_only": True}
with (HERE / "checks.json").open("x", encoding="utf-8") as stream:
    json.dump(report, stream, ensure_ascii=False, indent=2)
    stream.write("\n")
print(json.dumps({"checks": len(checks), "failed": report["failed_checks"], "files": len(records),
                  "bytes": sum(x["actual"]["bytes"] for x in records), "dependency_files": len(parent_checks),
                  "run_sha256": report["run"]["sha256"], "prior_review_sha256": report["prior_review"]["sha256"]}, indent=2))
raise SystemExit(bool(report["failed_checks"]))
