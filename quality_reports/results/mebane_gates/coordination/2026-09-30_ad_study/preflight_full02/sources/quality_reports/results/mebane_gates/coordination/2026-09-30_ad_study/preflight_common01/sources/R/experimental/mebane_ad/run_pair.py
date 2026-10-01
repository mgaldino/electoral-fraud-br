"""Run a frozen, independently reviewed A/D release without retrying failed fits."""

import argparse
import hashlib
import json
import os
import signal
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path


def sha(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def write_new(path, value):
    with path.open("x", encoding="utf-8") as stream:
        json.dump(value, stream, indent=2, ensure_ascii=False)
        stream.write("\n")


def run_command(command, log_path, timeout):
    start = time.monotonic()
    with log_path.open("x", encoding="utf-8") as log:
        proc = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT,
                                env={**os.environ, "LC_ALL": "C", "LANG": "C"},
                                start_new_session=True)
        timed_out = False
        try:
            returncode = proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            os.killpg(proc.pid, signal.SIGTERM)
            try:
                returncode = proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                os.killpg(proc.pid, signal.SIGKILL)
                returncode = proc.wait()
    return {"command": command, "returncode": returncode, "timed_out": timed_out,
            "elapsed_seconds": time.monotonic() - start,
            "log": str(log_path), "log_sha256": sha(log_path)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("release", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    release = json.loads(args.release.read_text(encoding="utf-8"))
    assert release["status"] == "approved_for_bounded_experiment"
    for item in release["files"]:
        assert sha(item["path"]) == item["sha256"], item["path"]
    contract_path = release["contract_path"]
    data_path = release["data_path"]
    contract = json.loads(Path(contract_path).read_text(encoding="utf-8"))
    assert contract["contract_id"] == "AD-DC2010-v2"
    assert sha(contract_path) == release["contract_sha256"]
    assert not args.output.exists(), "Keep earlier attempts; use a new output directory"
    args.output.mkdir(parents=True)
    write_new(args.output / "release_consumed.json", release)
    execution = {"start_utc": datetime.now(timezone.utc).isoformat(),
                 "release_sha256": sha(args.release), "runs": [], "retries": 0,
                 "production_approved": False, "G10_approved": False}
    for model in contract["paired_design"]["model_execution_order"]:
        # Recheck each frozen dependency immediately before each model.
        for item in release["files"]:
            assert sha(item["path"]) == item["sha256"], item["path"]
        command = ["Rscript", "--vanilla", "R/experimental/mebane_ad/run_jags.R",
                   model, contract_path, data_path, str(args.output / model)]
        record = run_command(command, args.output / f"{model}_sampling.log",
                             contract["paired_design"]["max_elapsed_seconds_per_model"])
        record["model"] = model
        execution["runs"].append(record)
        write_new(args.output / f"{model}_supervisor.json", record)
        print(json.dumps(record), flush=True)
    # Both model runs finish before postprocessing so diagnostics do not change
    # the predeclared protocol or create model-specific extensions.
    for model in ("A", "D"):
        raw_path = args.output / model / "raw_chains.rds"
        if not raw_path.exists():
            continue
        command = ["Rscript", "--vanilla", "R/experimental/mebane_ad/diagnostics.R",
                   str(args.output / model), data_path, contract_path,
                   str(args.output / f"{model}_diagnostics")]
        record = run_command(command, args.output / f"{model}_diagnostics.log", 1200)
        write_new(args.output / f"{model}_diagnostics_supervisor.json", record)
        print(json.dumps(record), flush=True)
    execution["end_utc"] = datetime.now(timezone.utc).isoformat()
    execution["result_interpretation"] = "Raw execution only; independent result review required"
    write_new(args.output / "execution.json", execution)


if __name__ == "__main__":
    main()
