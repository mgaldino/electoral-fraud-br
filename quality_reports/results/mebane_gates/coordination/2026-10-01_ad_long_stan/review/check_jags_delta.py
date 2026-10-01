"""Bounded independent JAGS delta checks. No model engine is invoked."""
import copy
import difflib
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
from datetime import datetime, timezone

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[6]
os.chdir(ROOT)
BASE = Path("quality_reports/results/mebane_gates/coordination/2026-10-01_ad_long_stan")
OUT = BASE / "review"
OLD = Path("quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study")
MANIFEST = BASE / "jags_candidate/manifest.json"
CONTRACT = BASE / "contract.json"
EXPECTED_MANIFEST = "61ad865465a2696bf5986d2253defbf6fe64c09aaa2d7f290c8ce64f15692066"
EXPECTED_CONTRACT = "fb4a296c9bf0af25812d7d8dd2ab63340fe10d4e73e806e64b5dba3f7dcf481a"


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write(path, value):
    with path.open("x", encoding="utf-8") as stream:
        json.dump(value, stream, indent=2, ensure_ascii=False)
        stream.write("\n")


checks = []


def check(name, value, evidence=None):
    checks.append(dict(check=name, pass_=bool(value), evidence=evidence))
    if not value:
        raise AssertionError(name)


def differences(a, b, prefix=""):
    if isinstance(a, dict) and isinstance(b, dict):
        result = []
        for key in sorted(a.keys() | b.keys()):
            path = prefix + "/" + key
            if key not in a or key not in b:
                result.append(dict(path=path, before=a.get(key), after=b.get(key)))
            else:
                result += differences(a[key], b[key], path)
        return result
    return [] if a == b else [dict(path=prefix, before=a, after=b)]


check("candidate_manifest_hash", sha(MANIFEST) == EXPECTED_MANIFEST)
check("contract_hash", sha(CONTRACT) == EXPECTED_CONTRACT)
manifest = json.loads(MANIFEST.read_text())
for item in manifest["files"]:
    check("frozen_bytes:" + item["path"],
          sha(item["path"]) == sha(item["snapshot"]) == item["sha256"]
          and Path(item["path"]).stat().st_size == item["bytes"], item)

previous = json.loads((OLD / "preflight_full02/candidate_manifest.json").read_text())
previous_hashes = {x["path"]: x["sha256"] for x in previous["files"]}
reused = []
for item in manifest["files"]:
    if item["path"] in previous_hashes:
        check("unchanged_prior_source:" + item["path"],
              item["sha256"] == previous_hashes[item["path"]])
        reused.append(item["path"])
for name, expected in {
    "run_jags.R": "7a92fdc9d234c8652cf6ae764f2dd22d86ef0b0f10ab8b929c8c2b4461dc651d",
    "diagnostics.R": "4f30f9ff1772f83b54519e941cd9c6edea24fbe359d5019836223f60b995061c",
}.items():
    old_path = Path("R/experimental/mebane_ad") / name
    new_path = Path("R/experimental/mebane_ad_long") / name
    check("historical_source_hash:" + name, sha(old_path) == expected)
    before = old_path.read_bytes()
    derived = before.replace(b"AD-DC2010-v2", b"AD-DC2010-LONG-v1")
    derived = derived.replace(b"2000", b"20000")
    derived = derived.replace(str(old_path).encode(), str(new_path).encode())
    check("exact_three_substitutions:" + name, derived == new_path.read_bytes())
    with (OUT / (name + ".diff")).open("x") as stream:
        stream.writelines(difflib.unified_diff(
            before.decode().splitlines(keepends=True),
            new_path.read_text().splitlines(keepends=True),
            fromfile=str(old_path), tofile=str(new_path)))

check("previous_contract_hash", sha(OLD / "contract_v2.json") ==
      "d17b7f508a7ce87eec3ca71ed7df67666b528c755e005ec9e1299e5ff9deb509")
check("previous_review_hash", sha(OLD / "review_preflight_delta/review.json") ==
      "fad1ec65544cb5e43647a3bee359b30f2eb379bc2bfb6f34f31d3d1fe7f3f37d")
old_contract = json.loads((OLD / "contract_v2.json").read_text())
contract = json.loads(CONTRACT.read_text())
for key in ("case", "A", "D", "monitoring", "diagnostics", "preflight_tests"):
    check("unchanged_scientific_contract:" + key, old_contract[key] == contract[key])
allowed = {"/authorization_quote", "/checkpoints", "/comparison/new_round",
           "/contract_id", "/date", "/paired_design/max_elapsed_seconds_per_model",
           "/paired_design/max_postprocess_seconds_per_model", "/paired_design/post_iterations",
           "/paired_design/timing", "/purpose", "/stan_design", "/supersedes/path",
           "/supersedes/reason", "/supersedes/sha256"}
delta = differences(old_contract, contract)
check("contract_delta_no_unlisted_change", {x["path"] for x in delta} == allowed)
check("JAGS_schedule_and_limits", all(contract["paired_design"][key] == val for key, val in {
    "chains": 4, "adapt_iterations": 1000, "burn_iterations": 5000,
    "post_iterations": 20000, "thin": 1, "max_concurrent_chains": 4,
    "max_elapsed_seconds_per_model": 3600, "max_postprocess_seconds_per_model": 3600,
    "extension_or_automatic_retry": False}.items()))
write(OUT / "source_delta.json", dict(candidate_manifest_sha256=sha(MANIFEST),
      contract_sha256=sha(CONTRACT), frozen_entries=len(manifest["files"]),
      reused_unchanged_paths=reused, contract_delta=delta))

spec = importlib.util.spec_from_file_location("reviewed_long_supervisor", "R/experimental/mebane_ad_long/run.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
release = dict(status="approved_for_JAGS20k", fixture_only=True,
               warning="SYNTHETIC RELEASE FOR FAKE SUPERVISOR; NOT AN EMPIRICAL RELEASE",
               files=manifest["files"], contract_path=str(CONTRACT),
               data_path=str(OLD / "data/run-20260930T235038Z-pid61600/dc2010_ad_data.rds"))
fake_root = OUT / "fake_orchestration"
fake_root.mkdir()
release_path = fake_root / "synthetic_release_fake_only.json"
write(release_path, release)
captures = []


def run_fake(scenario):
    target = fake_root / scenario
    calls = []

    def fake_command(command, log_path, timeout):
        generation = command[2].endswith("run_jags.R")
        model = command[3] if generation else Path(command[3]).name
        failed = generation and model == "A" and scenario in ("failure", "timeout")
        kind = "generation" if generation else "diagnostics"
        calls.append(dict(kind=kind, model=model, command=command, timeout=timeout))
        if generation and not failed:
            model_out = Path(command[-1])
            model_out.mkdir()
            write(model_out / "run_result.json", dict(fixture_only=True))
            with (model_out / "raw_chains.rds").open("x") as stream:
                stream.write("FAKE EXISTENCE MARKER ONLY; NOT RDS OR DRAWS\n")
        record = dict(command=command, returncode=2 if failed else 0,
                      timed_out=failed and scenario == "timeout", elapsed_seconds=0,
                      log=str(log_path), fixture_only=True)
        with log_path.open("x") as stream:
            stream.write("FAKE ORCHESTRATION; NO PROCESS LAUNCHED\n")
        record["log_sha256"] = sha(log_path)
        return record

    module.supervisor.run_command = fake_command
    sys.argv = [str(spec.origin), str(release_path), str(target)]
    module.main()
    execution = json.loads((target / "execution.json").read_text())
    expected = [("generation", "A"), ("generation", "D")]
    if scenario == "success":
        expected.append(("diagnostics", "A"))
    expected.append(("diagnostics", "D"))
    check(scenario + ":sequential_one_attempt", [(x["kind"], x["model"]) for x in calls] == expected)
    check(scenario + ":3600_per_process", all(x["timeout"] == 3600 for x in calls))
    check(scenario + ":new_R_entrypoints", all(x["command"][2].startswith("R/experimental/mebane_ad_long/") for x in calls))
    check(scenario + ":exact_contract_data_arguments", all(
        (x["command"][4:6] == [str(CONTRACT), release["data_path"]]) if x["kind"] == "generation" else
        (x["command"][4:6] == [release["data_path"], str(CONTRACT)]) for x in calls))
    check(scenario + ":no_retry_record", execution["retries"] == 0 and not execution["production_approved"])
    check(scenario + ":release_bound", execution["release_sha256"] == sha(release_path))
    before = len(calls)
    try:
        module.main()
    except AssertionError:
        rejected = True
    else:
        rejected = False
    check(scenario + ":anti_overwrite_before_calls", rejected and len(calls) == before)
    captures.append(dict(scenario=scenario, calls=calls))


for scenario in ("success", "failure", "timeout"):
    run_fake(scenario)
bad_release = copy.deepcopy(release)
bad_release["files"][0]["sha256"] = "0" * 64
bad_path = fake_root / "synthetic_bad_hash_release.json"
write(bad_path, bad_release)
sys.argv = [str(spec.origin), str(bad_path), str(fake_root / "rejected_hash")]
try:
    module.main()
except AssertionError:
    rejected = True
else:
    rejected = False
check("bad_hash_rejected_before_output", rejected and not (fake_root / "rejected_hash").exists())
write(OUT / "orchestration_calls.json", captures)

commands = []
for name in ("runner", "timing"):
    command = ["Rscript", "--vanilla", f"tests/mebane/ad_long/test_{name}.R",
               str(CONTRACT), release["data_path"], str(OUT / (name + "_repeat"))]
    start = datetime.now(timezone.utc).isoformat()
    with (OUT / (name + "_repeat.log")).open("x") as log:
        process = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT,
                                 env={**os.environ, "LC_ALL": "C", "LANG": "C"})
    commands.append(dict(command=command, started_utc=start, returncode=process.returncode,
                         log=str(OUT / (name + "_repeat.log"))))
    check("reexecuted_supplied_" + name + "_fixtures", process.returncode == 0)
for item in manifest["files"]:
    check("postcheck_unchanged:" + item["path"], sha(item["path"]) == sha(item["snapshot"]) == item["sha256"])
check("postcheck_manifest_unchanged", sha(MANIFEST) == EXPECTED_MANIFEST)
write(OUT / "checks_jags_delta.json", dict(
    status="pass", created_utc=datetime.now(timezone.utc).isoformat(),
    executor_id="019d795a-acfa-72c2-a210-d55a46c606c2",
    reviewer_id="01a0f4b8-962b-77a3-a418-6247c6219e8b",
    candidate_manifest_sha256=sha(MANIFEST), contract_sha256=sha(CONTRACT),
    checks=checks, total=len(checks), failed=0, commands=commands,
    empirical_MCMC=False, model_engine_invoked=False,
    reused_evidence=str(OLD / "review_preflight_delta/review.json")))
print(f"PASS {len(checks)} bounded delta checks; supplied 69 runner checks and 3 fake timing scenarios rerun; no MCMC")
