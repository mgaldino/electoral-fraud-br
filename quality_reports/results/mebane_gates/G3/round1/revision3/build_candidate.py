"""Validate and seal the bounded diagnostic-shape repair without sampling."""
import csv
import difflib
import hashlib
import json
import math
import re
import shutil
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[6]
HERE = Path(__file__).resolve().parent
ROUND = HERE.parent
PRIOR = ROUND / "revision2"
EXECUTOR = "01a0ee04-c901-7831-8ac6-0160da2e3883"
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
rel = lambda p: str(p.relative_to(ROOT))


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def dump_new(path, obj):
    assert not path.exists(), path
    path.write_text(json.dumps(obj, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def table(path):
    with path.open() as stream:
        return list(csv.DictReader(stream))


def same_number(a, b, tolerance=1e-12):
    if a == "NA" or b == "NA":
        return a == b
    return abs(float(a) - float(b)) < tolerance


predecessor = read(HERE / "predecessor_files.json")
assert sha(PRIOR / "candidate_manifest.json") == predecessor["prior_manifest_sha256"]
assert sha(PRIOR / "candidate_manifest.json") == "de779221e40964b9729bdd928a814e7e7dfd9738df866b91f6ee97307a14bd0f"
for row in predecessor["files"]:
    path = ROOT / row["frozen_path"]
    assert sha(path) == row["sha256"] and path.stat().st_size == row["bytes"], path
prior_run = read(PRIOR / "run.json")
contract = read(ROUND / "gate_contract.json")
contract_hash = hashlib.sha256(json.dumps(contract, sort_keys=True, ensure_ascii=False,
                                          separators=(",", ":")).encode()).hexdigest()
assert contract_hash == prior_run["contract_sha256"]
frozen_by_original = {row["path"]: ROOT / row["frozen_path"] for row in predecessor["files"]}
metadata = read(ROUND / "metadata_consumed.json")
assert sha(ROUND / "metadata_consumed.json") == prior_run["metadata_consumed_sha256"]
g2 = metadata["G2"]
assert g2["status"] == "pass"
assert sha(frozen_by_original[g2["records"]["candidate_manifest"]]) == prior_run["dependency_manifests"]["G2"]
for key in ("review", "adjudication"):
    assert sha(frozen_by_original[g2["records"][key]]) == prior_run["dependency_approvals"]["G2"][key + "_sha256"]

repair_inputs = read(HERE / "repair_inputs.json")
for row in repair_inputs:
    assert sha(ROOT / row["path"]) == row["sha256"]
adjud_row = next(row for row in repair_inputs if row["original_path"].endswith("diagnostic_shape_adjudication.json"))
adjud = read(ROOT / adjud_row["path"])
assert adjud["adjudication"]["verdict"] == "READY_FOR_IMPLEMENTATION"
assert adjud["source"]["sha256"] == sha(PRIOR / "candidate_manifest.json")
qa_path = ROOT / next(row["path"] for row in repair_inputs if row["original_path"].endswith("shape_counterexample.csv"))
qa = {row["target"]: row for row in table(qa_path)}
current = table(HERE / "postprocess/conditional_comparison.csv")
old = {row["target"]: row for row in table(PRIOR / "conditional_comparison.csv")}
aliases = {"r_im": "N.iota.m", "r_is": "N.iota.s", "r_cm": "N.chi.m", "r_cs": "N.chi.s"}
qa_comparison = []
for row in current:
    previous = old[row["target"]]
    assert all(same_number(row[field], previous[field]) for field in
               ("exact", "mc_mean", "mcse", "tolerance", "difference"))
    if row["constant"] == "TRUE":
        assert row["target"] == "S" and row["rhat"] == row["ess_bulk"] == row["ess_tail"] == "NA"
        continue
    reference = qa[aliases.get(row["target"], row["target"])]
    matches = all(same_number(row[key], reference[qa_key]) for key, qa_key in
                  (("rhat", "correct_rhat"), ("ess_bulk", "correct_bulk"), ("ess_tail", "correct_tail")))
    assert matches, row["target"]
    qa_comparison.append({"target": row["target"], "matches_QA": matches,
                          "tail_NA_retained": row["ess_tail"] == previous["ess_tail"] == "NA"})
same_outputs = {}
for name in ("functionals_by_draw.csv", "conditional_exact_states.csv"):
    same_outputs[name] = sha(HERE / "postprocess" / name) == sha(PRIOR / name)
    assert same_outputs[name]
assert sha(PRIOR / "raw_chains.rds") == "66ddb0aaef7448b25e817e25c931d5608ee9c7141165842613925e9e145baf6d"
result = read(HERE / "postprocess/postprocess_result.json")
assert result["status"] == "inconclusive" and result["new_mcmc_runs"] == 0
assert len(result["missing_tail_ess_targets"]) == 9
assert read(HERE / "shape_regression/result.json")["all_pass"] is True
dump_new(HERE / "repair_validation.json", {
    "predecessor_entries_preserved": len(predecessor["files"]),
    "raw_RDS_unchanged": True, "new_mcmc_runs": 0,
    "prior_means_MCSE_and_tolerances_unchanged": True,
    "byte_identical_outputs": same_outputs, "QA_diagnostic_comparisons": qa_comparison,
    "remaining_tail_NA": 9, "criteria_unchanged": True,
    "candidate_status": "inconclusive", "independent_repair_review_pending": True})

code = []
for original in ("tests/mebane/likelihood/g3_draw_postprocess.R", "tests/mebane/likelihood/g3_diagnostic_shape.R"):
    dest = HERE / "code_snapshots" / original
    assert not dest.exists(), dest
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ROOT / original, dest)
    code.append(rel(dest))
before = frozen_by_original["tests/mebane/likelihood/g3_draw_postprocess.R"]
after = ROOT / "tests/mebane/likelihood/g3_draw_postprocess.R"
diff = "".join(difflib.unified_diff(before.read_text().splitlines(keepends=True),
                                  after.read_text().splitlines(keepends=True),
                                  fromfile="revision2/g3_draw_postprocess.R",
                                  tofile="revision3/g3_draw_postprocess.R"))
assert not (HERE / "postprocessor.diff").exists()
(HERE / "postprocessor.diff").write_text(diff, encoding="utf-8")
code += [rel(HERE / "prepare_inputs.py"), rel(HERE / "build_candidate.py"),
         rel(frozen_by_original["R/lib/mebane_model.R"])]

commands = []
for ident, script, log in (
    ("shape_regression", "tests/mebane/likelihood/g3_diagnostic_shape.R", "shape_regression.log"),
    ("postprocess", "tests/mebane/likelihood/g3_draw_postprocess.R", "postprocess.log")):
    match = re.search(r"^real ([0-9.]+)$", (HERE / log).read_text(), re.MULTILINE)
    assert match
    commands.append({"id": ident, "command": f"/usr/bin/time -p timeout 120 Rscript --vanilla {script}",
                     "exit_code": 0, "elapsed_seconds": float(match.group(1)), "log": rel(HERE / log)})
inputs = sorted(set([row["frozen_path"] for row in predecessor["files"]] +
                    [row["path"] for row in repair_inputs] +
                    [rel(PRIOR / "candidate_manifest.json"), rel(HERE / "predecessor_files.json"),
                     rel(HERE / "repair_inputs.json")]))
config = [rel(ROUND / "gate_contract.json"), rel(ROUND / "protocol_v2.json"),
          rel(HERE / "repair_plan.json")]
outputs = sorted(rel(path) for path in HERE.rglob("*") if path.is_file() and
                 rel(path) not in set(inputs + code + config))
run = {
    "gate_id": "G3", "round": "round1", "revision": "revision3",
    "contract_sha256": contract_hash, "executor_id": EXECUTOR, "goal_id": EXECUTOR,
    "executor_role": "SOL-MODELO", "requested_model": "gpt-6-sol", "requested_effort": "xhigh",
    "repair_id": "G3-COORD-DIAG-01", "candidate_status": "inconclusive", "gate_approved": False,
    "repair_adjudication_sha256": adjud_row["sha256"],
    "prior_candidate_manifest_sha256": sha(PRIOR / "candidate_manifest.json"),
    "metadata_consumed_sha256": prior_run["metadata_consumed_sha256"],
    "dependency_manifests": prior_run["dependency_manifests"],
    "dependency_approvals": prior_run["dependency_approvals"],
    "benchmark_contract_sha256": prior_run["benchmark_contract_sha256"],
    "qbl_sha256": prior_run["qbl_sha256"],
    "raw_draws_path": rel(PRIOR / "raw_chains.rds"), "raw_draws_sha256": sha(PRIOR / "raw_chains.rds"),
    "new_mcmc_runs": 0, "versions": {"posterior": "1.7.0", "session": rel(HERE / "shape_regression/session.txt")},
    "started_at_utc": datetime.fromtimestamp((HERE / "repair_plan.json").stat().st_mtime, tz=timezone.utc).isoformat(),
    "ended_at_utc": datetime.now(timezone.utc).isoformat(),
    "commands": commands, "time_limit_seconds_per_process": 120,
    "timed_test_seconds_total": sum(item["elapsed_seconds"] for item in commands),
    "round_timed_test_seconds_total": prior_run["timed_test_seconds_total"] + sum(item["elapsed_seconds"] for item in commands),
    "execution_code_map": [{"executed_path": "tests/mebane/likelihood/" + Path(path).name,
                             "frozen_path": path, "sha256": sha(ROOT / path)} for path in code[:2]],
    "inputs": inputs, "code": code, "configuration": config, "outputs": outputs,
}
dump_new(HERE / "run.json", run)
paths = sorted(set(inputs + code + config + outputs + [rel(HERE / "run.json")]))
assert "quality_reports/plans/mebane_2022_2026_gates.json" not in paths
dump_new(HERE / "candidate_manifest.json", {
    "gate_id": "G3", "round": "round1", "revision": "revision3", "contract_sha256": contract_hash,
    "prior_candidate_manifest_sha256": run["prior_candidate_manifest_sha256"],
    "raw_draws_sha256": run["raw_draws_sha256"],
    "files": [{"path": path, "sha256": sha(ROOT / path), "bytes": (ROOT / path).stat().st_size}
              for path in paths]})
print("revision3 sealed", len(paths), "files; manifest", sha(HERE / "candidate_manifest.json"))
