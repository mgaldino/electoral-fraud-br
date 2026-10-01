#!/usr/bin/env python3
"""Bounded, read-only integrity and comparison check for the JAGS20k review."""

import csv
from datetime import datetime
import hashlib
import json
import math
from pathlib import Path

ROOT = Path.cwd()
COORD = Path("quality_reports/results/mebane_gates/coordination")
NEW = COORD / "2026-10-01_ad_long_stan"
OLD = COORD / "2026-09-30_ad_study"
OUT = NEW / "review_jags_results"


def read_json(path):
    return json.loads((ROOT / path).read_text())


def sha(path):
    digest = hashlib.sha256()
    with (ROOT / path).open("rb") as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def rows(path):
    with (ROOT / path).open(newline="") as stream:
        return list(csv.DictReader(stream))


def number(value):
    return float(value) if value not in ("", "NA", None) else math.nan


def close(a, b, label, tol=1e-8):
    if math.isnan(a) and math.isnan(b):
        return
    if not (math.isfinite(a) and math.isfinite(b) and abs(a - b) <= tol):
        raise AssertionError(f"{label}: {a} != {b}")


assert sha(NEW / "jags_candidate/manifest.json") == "61ad865465a2696bf5986d2253defbf6fe64c09aaa2d7f290c8ce64f15692066"
assert sha(NEW / "contract.json") == "fb4a296c9bf0af25812d7d8dd2ab63340fe10d4e73e806e64b5dba3f7dcf481a"
assert sha(OLD / "data/run-20260930T235038Z-pid61600/dc2010_ad_data.rds") == "b2ef611dabb751f9286acbaae841a23c34948ed0a4b6306364cbe94d9d24903e"

manifests = [NEW / "jags_candidate/manifest.json"]
for model in "AD":
    manifests.extend((NEW / f"jags20k01/{model}/manifest.json",
                      NEW / f"jags20k01/{model}_diagnostics/manifest.json"))
manifests.append(NEW / "comparison_jags01/manifest.json")
checked = 0
for manifest in manifests:
    entries = read_json(manifest)["files"]
    assert len(entries) == len({x["path"] for x in entries}), manifest
    for entry in entries:
        file_path = Path(entry["path"])
        assert file_path.is_relative_to(NEW) or manifest == NEW / "jags_candidate/manifest.json"
        assert (ROOT / file_path).stat().st_size == entry["bytes"], file_path
        assert sha(file_path) == entry["sha256"], file_path
        checked += 1

source_hashes = {
    "A": (Path("quality_reports/results/mebane_gates/G0/round1/qbl_installed_3017de5.jags"),
          "f8360126424b7a463f76a1c99efc89a8a5cb81339213bd4931559f14595fbab6"),
    "D": (Path("models/experimental/mebane_ad/d_multinomial.jags"),
          "6ddb9624f60b15e196cc27ed9694852c40b6553a684a9962003168da4ecfaf5b"),
}
for model, (source, expected_hash) in source_hashes.items():
    old_copy = OLD / "pilot01" / model / "consumed_sources" / source
    new_copy = NEW / "jags20k01" / model / "consumed_sources" / source
    assert sha(source) == sha(old_copy) == sha(new_copy) == expected_hash

execution = read_json(NEW / "jags20k01/execution.json")
assert execution["retries"] == 0
assert [(r["model"], r["kind"]) for r in execution["records"]] == [
    ("A", "generation"), ("D", "generation"),
    ("A", "diagnostics"), ("D", "diagnostics")]
def events(model):
    with (ROOT / NEW / f"jags20k01/{model}/events.jsonl").open() as stream:
        return [json.loads(line) for line in stream]

first_d = events("D")[0]
last_a = events("A")[-1]
assert first_d["stage"] == "setup" and first_d["type"] == "start"
assert last_a["stage"] == "persist_raw" and last_a["type"] == "complete"
assert datetime.strptime(last_a["utc"], "%Y-%m-%d %H:%M:%S UTC") < datetime.strptime(
    first_d["utc"], "%Y-%m-%d %H:%M:%S UTC")

old_timing = {r["model"]: r for r in rows(OLD / "comparison01/timings_diagnostics.csv")}
comparison_timing = {r["id"]: r for r in rows(NEW / "comparison_jags01/timings_diagnostics.csv")}
recomputed = read_json(NEW / "review_jags_results/recomputed_results.json")
for model in "AD":
    before = old_timing[model]
    current_old = comparison_timing[f"{model}_JAGS_2k"]
    for old_key, new_key in (("total_process_seconds", "generation_process_seconds"),
                             ("postprocess_seconds", "diagnostic_process_seconds"),
                             ("end_to_end_compute_seconds", "total_compute_including_compilation_seconds"),
                             ("global_rhat_max", "max_global_Rhat"),
                             ("global_bulk_ESS_min", "min_global_bulk_ESS"),
                             ("global_tail_ESS_min", "min_global_tail_ESS"),
                             ("required_targets", "mandatory_targets"),
                             ("failed_targets", "failed_targets"),
                             ("undefined_targets", "undefined_targets")):
        close(number(before[old_key]), number(current_old[new_key]), f"old {model} {old_key}")
    current = comparison_timing[f"{model}_JAGS_20k"]
    generation = read_json(NEW / f"jags20k01/{model}_supervisor.json")
    diagnostics = read_json(NEW / f"jags20k01/{model}_diagnostics_supervisor.json")
    run = read_json(NEW / f"jags20k01/{model}/run_result.json")
    diagnostic_result = read_json(NEW / f"jags20k01/{model}_diagnostics/diagnostic_result.json")
    for process, key in ((generation, "generation_process_seconds"),
                         (diagnostics, "diagnostic_process_seconds")):
        assert process["returncode"] == 0 and not process["timed_out"]
        assert sha(Path(process["log"])) == process["log_sha256"]
        close(process["elapsed_seconds"], number(current[key]), f"{model} {key}")
    close(generation["elapsed_seconds"] + diagnostics["elapsed_seconds"],
          number(current["total_compute_including_compilation_seconds"]), f"{model} total")
    close(run["phases"]["compile"]["elapsed"], number(current["compilation_seconds"]),
          f"{model} compilation")
    assert current["compilation_is_inside_generation"] == "TRUE"
    assert current["mandatory_targets"] == str(recomputed[model]["mandatory"])
    assert current["failed_targets"] == str(recomputed[model]["failed"])
    assert current["undefined_targets"] == str(recomputed[model]["undefined_subset_failed"])
    assert diagnostic_result["status"] == current["status"] == "computationally_inconclusive"
    assert run["raw_sha256"] == sha(NEW / f"jags20k01/{model}/raw_chains.rds")

old_global = rows(OLD / "comparison01/common_functionals.csv")
new_global = rows(NEW / "comparison_jags01/global_functionals.csv")
assert len(old_global) == 50 and len(new_global) == 92
metrics = ("mean", "sd", "q025", "q50", "q975", "rhat", "ess_bulk", "ess_tail",
           "mcse_mean", "chain1", "chain2", "chain3", "chain4", "chain_mean_range")
for model in "AD":
    for length in ("2k", "20k"):
        selection = [r for r in new_global if r["id"] == f"{model}_JAGS_{length}"]
        assert len(selection) == 23
        reference = (old_global if length == "2k" else
                     rows(NEW / f"jags20k01/{model}_diagnostics/diagnostics.csv"))
        reference = {r["target"]: r for r in reference
                     if r["group"] == "global" and (length != "2k" or r["model"] == model)}
        assert len(reference) == 23
        total = number(comparison_timing[f"{model}_JAGS_{length}"]["total_compute_including_compilation_seconds"])
        for row in selection:
            original = reference[row["target"]]
            for key in metrics:
                close(number(row[key]), number(original[key]), f"{model} {length} {row['target']} {key}")
            assert row["diagnostic_pass"] == original["diagnostic_pass"]
            close(number(row["bulk_ESS_per_total_compute_second"]), number(row["ess_bulk"]) / total,
                  f"{model} {length} {row['target']} bulk/s")
            close(number(row["tail_ESS_per_total_compute_second"]), number(row["ess_tail"]) / total,
                  f"{model} {length} {row['target']} tail/s")

group_rows = rows(NEW / "comparison_jags01/diagnostic_groups.csv")
assert len(group_rows) == 18
for model in "AD":
    for length in ("2k", "20k"):
        source = (OLD / f"pilot01/{model}_diagnostics/diagnostics.csv" if length == "2k"
                  else NEW / f"jags20k01/{model}_diagnostics/diagnostics.csv")
        diagnostic_rows = [r for r in rows(source) if r["mandatory"] == "TRUE"]
        groups = {r["group"] for r in diagnostic_rows}
        selected = [r for r in group_rows if r["id"] == f"{model}_JAGS_{length}"]
        assert {r["group"] for r in selected} == groups
        for reported in selected:
            values = [r for r in diagnostic_rows if r["group"] == reported["group"]]
            assert len(values) == int(reported["targets"])
            assert sum(r["diagnostic_pass"] == "FALSE" for r in values) == int(reported["failed"])
            missing = sum(not all(math.isfinite(number(r[key]))
                                  for key in ("rhat", "ess_bulk", "ess_tail")) for r in values)
            assert missing == int(reported["undefined"])
            for key, function, output_key in (("rhat", max, "max_Rhat"),
                                              ("ess_bulk", min, "min_bulk_ESS"),
                                              ("ess_tail", min, "min_tail_ESS")):
                finite_values = [number(r[key]) for r in values if math.isfinite(number(r[key]))]
                expected = function(finite_values) if finite_values else math.nan
                close(expected, number(reported[output_key]),
                      f"{model} {length} {reported['group']} {output_key}")

summary = {"status": "pass", "manifests": len(manifests), "manifest_entries_verified": checked,
           "source_A_D_preserved": True, "comparison_global_rows_verified": 92,
           "diagnostic_group_rows_verified": 18,
           "execution_order_verified": "A generation, D generation, A diagnostics, D diagnostics",
           "old_timing_rows_matched": 2, "new_timing_rows_matched": 2,
           "stan_row": comparison_timing["D_Stan_2k"]["status"],
           "scope": "JAGS results and descriptive 2k/20k comparison only; no Stan or PDF QA"}
assert summary["stan_row"] == "not_available"
(ROOT / OUT / "binding_results.json").write_text(json.dumps(summary, indent=2) + "\n")
print(json.dumps(summary, indent=2))
