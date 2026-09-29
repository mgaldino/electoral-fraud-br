#!/usr/bin/env python3
"""Bounded G0 F01 recheck. Never build, rewrite or delete candidate artifacts."""
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
R4 = HERE.parent.relative_to(ROOT).as_posix() + "/"
R3 = R4.replace("round4/", "round3/")
MANIFEST = "d73ecc86824fd5eaa66ece7cad41d6c21d913d455af864d32c11c5331fa5bb57"
INPUT = "bee1e870b49052601c5e5c574edf87d5d0811f75940a57a82cbac389a7be8a74"
CONTRACT = "e5ba78d6f8d314c2bf94738df85fce0a31d8e9986ef974f6c69ee9e30ee06ca3"


def read(path):
    return json.loads((ROOT / path).read_text())


def digest(path):
    file = ROOT / path
    assert file.resolve().is_relative_to(ROOT) and not file.is_symlink()
    h = hashlib.sha256()
    size = 0
    with file.open("rb") as stream:
        for block in iter(lambda: stream.read(2**20), b""):
            h.update(block)
            size += len(block)
    return {"path": path, "bytes": size, "sha256": h.hexdigest()}


def canonical(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, ensure_ascii=False,
                                     separators=(",", ":")).encode()).hexdigest()


checks = []


def check(name, passed, detail=None):
    checks.append({"id": name, "passed": bool(passed), "detail": detail})


manifest = read(R4 + "candidate_manifest.json")
prior = read(R3 + "candidate_manifest.json")
run = read(R4 + "run.json")
frozen = read(R4 + "construction_input.json")
todos = read(R4 + "todo_evidence.json")
check("delivered_manifest", digest(R4 + "candidate_manifest.json")["sha256"] == MANIFEST)
check("delivered_construction_input", digest(R4 + "construction_input.json")["sha256"] == INPUT)
check("identities", all((v["gate_id"], v["round"], v["contract_sha256"]) ==
      ("G0", "round4", CONTRACT) for v in (run, manifest)) and
      run["executor_id"] == "01a0edcd-cd1f-70f0-b9f5-95fb470b6c40")
records = []
for expected in manifest["files"]:
    actual = digest(expected["path"])
    records.append({"expected": expected, "actual": actual, "passed": expected == actual})
listed = {x["path"]: x for x in manifest["files"]}
check("186_files_full_hash_and_bytes", len(listed) == len(records) == 186 and all(x["passed"] for x in records))
check("171_round3_entries_exactly_retained", len(prior["files"]) == 171 and
      all(listed.get(x["path"]) == x for x in prior["files"]))
check("three_documentary_files_byte_identical", all((ROOT / R3 / name).read_bytes() ==
      (ROOT / R4 / name).read_bytes() for name in ("gate_contract.json", "inventory_current.json", "tombstone.json")))
before = read(frozen["source_before"]["path"])
gate = next(g for g in before["gates"] if g["id"] == "G0")
static = {k: v for k, v in gate.items() if k not in {"status", "records"}}
static["todos"] = [{k: v for k, v in t.items() if k not in {"status", "evidence"}} for t in gate["todos"]]
dynamic = {"status": gate["status"], "todos": [{k: t[k] for k in ("id", "status", "evidence")} for t in gate["todos"]]}
check("frozen_projection_exact_before", frozen["static_contract"] == static and frozen["consumed_dynamic"] == dynamic)
check("static_and_dynamic_hashes", canonical(static) == CONTRACT and canonical(dynamic) == frozen["consumed_dynamic_sha256"])
check("source_and_checker_bound", all(digest(frozen[k]["path"]) == frozen[k] == listed[frozen[k]["path"]]
      for k in ("source_before", "checker_snapshot")))
check("run_construction_binding", run["construction_input"] == R4 + "construction_input.json" and
      run["construction_input_sha256"] == INPUT and run["source_before_sha256"] == frozen["source_before"]["sha256"] and
      run["checker_snapshot_sha256"] == frozen["checker_snapshot"]["sha256"])
check("run_paths_and_dependency_bindings", run["dependency_manifests"] == run["dependency_approvals"] == {} and
      static["depends_on"] == [] and R4 + "run.json" in listed and all(
      p in listed for key in ("inputs", "code", "configuration", "outputs") for p in run[key]) and
      run["repaired_from_manifest_sha256"] == digest(R3 + "candidate_manifest.json")["sha256"])
check("todos_historical_evidence_exact", [t["id"] for t in todos["todos"]] == [t["id"] for t in dynamic["todos"]] and
      all(new["status"] == old["status"] and new["evidence"][:len(old["evidence"])] ==
          [{"path": e["path"], "basis": "historical", "locator": e.get("locator", "") +
            "; bytes reverified; calculation not rerun"} for e in old["evidence"]]
          for new, old in zip(todos["todos"], dynamic["todos"])))
check("todo_paths_bound", all(e["path"] in listed for t in todos["todos"] for e in t["evidence"]))
check("scientific_execution_explicitly_false", run["scientific_execution"] is False and run["MCMC"] is False)
check("absence_preserved", all(not (ROOT / p).exists() and p not in listed for p in
      ("ssrn-4073770.pdf.download/ssrn-4073770.pdf", "ssrn-4073770.pdf.download/Info.plist")))

# Observe the actual read-only path; any canonical-ledger/checker read or write aborts.
trace = {"active": False, "reads": set(), "forbidden": []}
forbidden = {"quality_reports/plans/mebane_2022_2026_gates.json", "scripts/mebane_gates.py"}


def hook(event, args):
    if not trace["active"]:
        return
    if event in {"os.remove", "os.rmdir", "os.rename", "os.mkdir", "os.truncate"}:
        raise RuntimeError("filesystem mutation forbidden")
    if event == "open" and isinstance(args[0], (str, bytes, os.PathLike)):
        path = Path(os.fsdecode(args[0])).resolve()
        mode, flags = args[1:3]
        if (isinstance(mode, str) and any(c in mode for c in "wax+")) or (
                isinstance(flags, int) and flags & (os.O_WRONLY | os.O_RDWR | os.O_CREAT | os.O_TRUNC)):
            raise RuntimeError("write forbidden")
        if path.is_relative_to(ROOT):
            relative = path.relative_to(ROOT).as_posix()
            if relative in forbidden:
                trace["forbidden"].append(relative)
                raise RuntimeError("live input forbidden: " + relative)
            if path.is_file():
                trace["reads"].add(relative)


sys.addaudithook(hook)
trace["active"] = True
buffer = io.StringIO()
try:
    spec = importlib.util.spec_from_file_location("g0_round4_reviewed", ROOT / R4 / "build_candidate.py")
    builder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(builder)
    with contextlib.redirect_stdout(buffer):
        builder.source_preflight()
        builder.verify()
    verify_error = None
except Exception as error:
    verify_error = repr(error)
finally:
    trace["active"] = False
check("verify_without_live_inputs_or_writes", verify_error is None and not trace["forbidden"], verify_error)
extra_reads = sorted(p for p in trace["reads"] if p not in listed and p != R4 + "candidate_manifest.json" and "__pycache__" not in p)
check("actual_read_closure", not extra_reads, extra_reads)

# Same kind of dynamic-evidence mutation as F01, without changing a file.
mutated = copy.deepcopy(frozen)
mutated["consumed_dynamic"]["todos"][0]["evidence"][0]["path"] = R4 + "tombstone.json"
original_reader = builder.read_json
builder.read_json = lambda p: mutated if str(p) == R4 + "construction_input.json" else original_reader(p)
try:
    builder.frozen_input()
    tamper_error = None
except ValueError as error:
    tamper_error = str(error)
finally:
    builder.read_json = original_reader
check("F01_mutation_rejected", tamper_error == "dynamic construction metadata drift", tamper_error)

# Even a self-rehashed projection is rejected by the run's full-file binding.
mutated["consumed_dynamic_sha256"] = canonical(mutated["consumed_dynamic"])
new_bytes = (json.dumps(mutated, ensure_ascii=False, indent=2) + "\n").encode()
original_record, original_old = builder.file_record, builder.old_files
builder.read_json = lambda p: mutated if str(p) == R4 + "construction_input.json" else original_reader(p)
builder.file_record = lambda p: ({"path": str(p), "bytes": len(new_bytes), "sha256": hashlib.sha256(new_bytes).hexdigest()}
                                if str(p) == R4 + "construction_input.json" else original_record(p))
# Previously fully verified files are reused here; the counterexample targets only the binding.
builder.old_files = lambda: (prior, sum(x["bytes"] for x in prior["files"]))
try:
    builder.verify()
    binding_error = None
except ValueError as error:
    binding_error = str(error)
finally:
    builder.read_json, builder.file_record, builder.old_files = original_reader, original_record, original_old
check("self_rehashed_mutation_rejected_by_run", binding_error == "construction input hash drift", binding_error)

check("candidate_unchanged_after_probes", digest(R4 + "candidate_manifest.json")["sha256"] == MANIFEST and
      digest(R4 + "construction_input.json")["sha256"] == INPUT)
report = {"gate_id": "G0", "round": "round4", "reviewer_id": "01a0edd1-ae42-7973-8cf9-2fda610d33cf",
          "checked_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(), "checks": checks,
          "failed_checks": [x["id"] for x in checks if not x["passed"]], "file_checks": records,
          "actual_executor_reads": sorted(trace["reads"]), "unexpected_project_reads": extra_reads,
          "forbidden_live_read_attempts": trace["forbidden"], "verify_output": buffer.getvalue(),
          "counterexamples": {"dynamic_mutation": tamper_error, "self_rehashed_mutation": binding_error,
                             "in_memory_only": True, "build_executed": False},
          "prior_reuse": "Round3 omission/dependency probes, inventory content, tombstone and 22 transitive hash checks reused historically; no scientific tests rerun.",
          "command": "python3 -B " + R4 + "review/check_repair.py"}
with (HERE / "checks.json").open("x", encoding="utf-8") as stream:
    json.dump(report, stream, ensure_ascii=False, indent=2)
    stream.write("\n")
print(json.dumps({"checks": len(checks), "failed": report["failed_checks"], "files": len(records),
                  "bytes": sum(x["actual"]["bytes"] for x in records),
                  "unexpected_reads": extra_reads, "counterexamples": report["counterexamples"]}, indent=2))
raise SystemExit(bool(report["failed_checks"]))
