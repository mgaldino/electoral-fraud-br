"""Independent subprocess and orchestration fixtures. No R/JAGS model is invoked."""
import hashlib
import importlib.util
import json
import os
import sys
import time
from pathlib import Path

ROOT = Path("/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud")
BASE = Path("quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study")
OUT = ROOT / BASE / "review_preflight"
TREE = OUT / "common01_tree"
TEST = TREE / "independent_supervisor"
TEST.mkdir()
os.chdir(TREE)
source = Path("R/experimental/mebane_ad/run_pair.py")
spec = importlib.util.spec_from_file_location("frozen_supervisor", source)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
results = []

def record(label, passed, evidence=None):
    results.append({"check": label, "pass": bool(passed), "evidence": evidence})
    print(label, bool(passed), flush=True)

actual_run = module.run_command
for label, script, timeout, expected in [
    ("success", "print('single call', flush=True)", 3, 0),
    ("failure", "print('failed once', flush=True); raise SystemExit(7)", 3, 7),
    ("timeout", "import time; print('started once',flush=True); time.sleep(2)", .15, None),
]:
    value = actual_run([sys.executable, "-c", script], TEST / f"{label}.log", timeout)
    passed = value["returncode"] == expected if expected is not None else value["timed_out"]
    record(label, passed and value["log_sha256"] == module.sha(Path(value["log"])), value)
try:
    actual_run([sys.executable, "-c", "print('must not run')"], TEST / "success.log", 1)
except FileExistsError:
    record("existing-log-refused-before-process", True)
else:
    record("existing-log-refused-before-process", False)

# A child survives SIGTERM if only the exited group leader is waited on. It
# terminates itself after a short fixed interval; nothing is deleted or killed later.
child = "import signal,time; signal.signal(signal.SIGTERM,signal.SIG_IGN); print('child_ready',flush=True); time.sleep(1); print('child_finished_after_timeout',flush=True)"
parent = f"import subprocess,sys,time; subprocess.Popen([sys.executable,'-c',{child!r}]); time.sleep(3)"
value = actual_run([sys.executable, "-c", parent], TEST / "descendant.log", .2)
time.sleep(1.2)
changed = module.sha(TEST / "descendant.log") != value["log_sha256"]
record("timeout-descendant-log-closed-before-seal", not changed,
       {**value, "sha256_after_child_exit": module.sha(TEST / "descendant.log"),
        "log_after_child_exit": (TEST / "descendant.log").read_text(),
        "scope": "adversarial subprocess fixture, not a demonstrated child in current rjags runner"})

contract_path = BASE / "contract_v2.json"
data_path = BASE / "data/run-20260930T235038Z-pid61600/dc2010_ad_data.rds"
release = {"status": "approved_for_bounded_experiment", "SYNTHETIC_TEST_NOT_A_RELEASE": True,
           "contract_path": str(contract_path), "contract_sha256": module.sha(contract_path),
           "data_path": str(data_path),
           "files": [{"path": str(p), "sha256": module.sha(p)} for p in (source, contract_path, data_path)]}
module.write_new(TEST / "synthetic_release.json", release)
calls = []

def fake_run(command, log_path, timeout):
    calls.append({"command": command, "timeout": timeout})
    log_path.write_text("SYNTHETIC orchestration stub; no subprocess invoked\n")
    is_sample = command[2].endswith("run_jags.R")
    model = command[3] if is_sample else "D"
    if is_sample and model == "D":
        path = Path(command[-1]); path.mkdir()
        (path / "raw_chains.rds").write_bytes(b"SYNTHETIC marker only, not an RDS")
    return {"command": command, "returncode": 7 if is_sample and model == "A" else 0,
            "timed_out": False, "elapsed_seconds": .01,
            "log": str(log_path), "log_sha256": module.sha(log_path)}

module.run_command = fake_run
sys.argv = [str(source), str(TEST / "synthetic_release.json"), str(TEST / "pair")]
module.main()
record("A-failure-does-not-retry-and-D-runs-once", len(calls) == 3 and
       [x["command"][3] for x in calls[:2]] == ["A", "D"] and
       calls[2]["command"][2].endswith("diagnostics.R"), calls)
execution = json.loads((TEST / "pair/execution.json").read_text())
record("pair-record-retries-zero-and-no-production", execution["retries"] == 0 and not execution["production_approved"])
before = len(calls)
try:
    module.main()
except AssertionError:
    record("existing-pair-refused", len(calls) == before)
else:
    record("existing-pair-refused", False)
bad = {**release, "contract_sha256": "0" * 64}
module.write_new(TEST / "bad_release.json", bad)
sys.argv = [str(source), str(TEST / "bad_release.json"), str(TEST / "bad_pair")]
try:
    module.main()
except AssertionError:
    record("bad-contract-hash-rejected-before-run", len(calls) == before and not (TEST / "bad_pair").exists())
else:
    record("bad-contract-hash-rejected-before-run", False)
module.run_command = actual_run
summary = {"status": "review_fixtures_complete", "checks": results,
           "failures": [x["check"] for x in results if not x["pass"]],
           "supervisor_sha256": module.sha(source), "MCMC": False,
           "reviewer_id": "01a0f4b8-962b-77a3-a418-6247c6219e8b"}
with (OUT / "checks_supervisor.json").open("x") as stream:
    json.dump(summary, stream, indent=2)
print(json.dumps({"checks": len(results), "failures": summary["failures"], "MCMC": False}))
