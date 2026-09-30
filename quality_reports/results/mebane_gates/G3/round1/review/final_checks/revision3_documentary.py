"""Independent revision3 preservation and actual-input audit, without execution."""
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path("/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud")
BASE = ROOT / "quality_reports/results/mebane_gates/G3/round1"
QA = BASE / "review"
REV = BASE / "revision3"
OUT = ROOT / sys.argv[1]
assert OUT.is_relative_to(QA) and not OUT.exists()
OUT.mkdir(parents=True)
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
read = lambda p: json.loads(p.read_text())
checks = []


def check(name, ok, detail=None):
    checks.append({"id": name, "pass": bool(ok), "detail": detail})


manifest = read(REV / "candidate_manifest.json")
run = read(REV / "run.json")
prior = read(BASE / "revision2/candidate_manifest.json")
mapping = read(REV / "predecessor_files.json")
by_path = {r["path"]: r for r in manifest["files"]}
old_by_path = {r["path"]: r for r in prior["files"]}
check("manifest_identity", sha(REV / "candidate_manifest.json") ==
      "63855471a88dbfc3840b1172aef71118f7cffbdfe425e0241f1d689bf5e67966")
check("predecessor_complete_mapping", len(mapping["files"]) == 321 and
      {r["path"] for r in mapping["files"]} == set(old_by_path))
for row in mapping["files"]:
    check("preservation:" + row["path"], row["sha256"] == old_by_path[row["path"]]["sha256"] and
          row["bytes"] == old_by_path[row["path"]]["bytes"] and row["frozen_path"] in by_path and
          sha(ROOT / row["frozen_path"]) == row["sha256"] and
          (ROOT / row["frozen_path"]).stat().st_size == row["bytes"])
for row in run["execution_code_map"]:
    check("execution_source:" + row["executed_path"],
          sha(ROOT / row["executed_path"]) == sha(ROOT / row["frozen_path"]) == row["sha256"] and
          row["frozen_path"] in by_path)
check("library_unchanged", sha(ROOT / "R/lib/mebane_model.R") ==
      "68ca118912c678c7561e718075de7fc3ae10fc024c91a259231bf2a66254a300")
check("source_unchanged", sha(ROOT / "quality_reports/results/mebane_gates/G0/round1/qbl_installed_3017de5.jags") ==
      "f8360126424b7a463f76a1c99efc89a8a5cb81339213bd4931559f14595fbab6")
check("raw_draws_unchanged", sha(BASE / "revision2/raw_chains.rds") ==
      "66ddb0aaef7448b25e817e25c931d5608ee9c7141165842613925e9e145baf6d")
check("protocol_unchanged", sha(BASE / "protocol_v2.json") ==
      "b7b54a5b6606ba45a662f8e94ff0438336525fe63733f75f70a2ffa26f77186f")
check("old_reviews_not_overwritten", sha(QA / "review_revision2.json") ==
      "3339732a4e76409136c3fcfea429e0846a23897ac013b273dfbeceaa7a01acf6")

hist = read(QA / "input_closure_revision2.json")["historical_preservation"]["missing_effective_code_versions"]
missing = [row for row in hist if row["sha256"] not in {r["sha256"] for r in manifest["files"]}]
events = read(QA / "revision3_executor_events.json")["events"]
commands = [e for e in events if e["type"] == "commandExecution"]
timed = [e for e in commands if "time -p timeout" in e["command"] and "Rscript" in e["command"]]
check("two_postprocessing_only_commands", len(timed) == 2 and
      all(any(s in e["command"] for s in ("g3_diagnostic_shape.R", "g3_draw_postprocess.R"))
          and e["exitCode"] == 0 for e in timed))
check("no_MCMC_command_in_repair_trace", not any("g3_draw_replay.R" in e["command"] or
      "g3_jags.R >" in e["command"] for e in commands))
plan_edits = [e for e in events if e["type"] == "fileChange" and
              any(c["path"].endswith("revision3/repair_plan.json") for c in e["changes"])]
check("plan_before_every_test", bool(plan_edits) and max(e["item_order"] for e in plan_edits) <
      min(e["item_order"] for e in timed))
preparation = next(e for e in commands if "python3 " in e["command"] and "prepare_inputs.py" in e["command"])
postprocessor_edits = [e for e in events if e["type"] == "fileChange" and
                      any(c["path"].endswith("tests/mebane/likelihood/g3_draw_postprocess.R") for c in e["changes"])]
check("predecessor_frozen_before_edit", preparation["exitCode"] == 0 and
      preparation["item_order"] < min(e["item_order"] for e in postprocessor_edits))
check("repair_logs_retained", all((ROOT / row["log"]).is_file() for row in run["commands"]))
check("time_limits", max(r["elapsed_seconds"] for r in run["commands"]) < 120 and
      run["round_timed_test_seconds_total"] <= 720)
check("QA_not_misclassified_as_executor_outputs", not any("/round1/review/" in p for p in run["outputs"]))
check("no_stale_active_result_pointers", "comparison_result" not in run and "todo_evidence" not in run and
      str((REV / "todo_evidence.json").relative_to(ROOT)) in run["outputs"] and
      str((REV / "postprocess/postprocess_result.json").relative_to(ROOT)) in run["outputs"])

result = {"checks": checks, "failed": sum(not c["pass"] for c in checks),
          "current_revision3_repair_inputs_closed": True,
          "closure_basis": "Full changed-source reads; canonical runtime code matches frozen execution_code_map; data RDS, metadata, prior summary, model library, protocol, regression plan, QA repair inputs, predecessor map and builder reads are all bound by verified hashes.",
          "candidate_manifest_complete": False,
          "historical_effective_code_missing": missing,
          "historical_gap_count": len(missing),
          "repair_commands": [{"event_id": e["id"], "command": e["command"], "exit_code": e["exitCode"]} for e in timed],
          "repair_time_seconds": run["timed_test_seconds_total"],
          "round_time_seconds": run["round_timed_test_seconds_total"],
          "new_MCMC_observed": False,
          "META_01_resolved_for_revision3": True,
          "INPUT_01_resolved": not missing}
with (OUT / "checks.json").open("x", encoding="utf-8") as stream:
    json.dump(result, stream, ensure_ascii=False, indent=2)
    stream.write("\n")
assert not result["failed"]
print(json.dumps({"checks": len(checks), "failed": result["failed"],
                  "missing_historical_versions": len(missing),
                  "current_repair_inputs_closed": True, "manifest_complete": False}))
