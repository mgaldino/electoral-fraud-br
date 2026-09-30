#!/usr/bin/env python3
"""Run only the documentary Python repair and preserve command/exit/time logs."""

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import platform
import subprocess
import sys
import time


ROOT = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("build", "verify", "verify-seal"))
    parser.add_argument("--label", required=True)
    args = parser.parse_args()
    run_dir = ROOT / "runs" / args.label
    if run_dir.parent != ROOT / "runs" or run_dir.exists():
        raise ValueError("Use a new, single-component run label; existing runs are never overwritten")
    run_dir.mkdir(parents=True)
    source_snapshots = []
    for name in ("reconstruct_sources.py", "run_documentary.py", "repair_plan.json"):
        data = (ROOT / name).read_bytes()
        snapshot = run_dir / "source_snapshot" / name
        snapshot.parent.mkdir(parents=True, exist_ok=True)
        with snapshot.open("xb") as stream:
            stream.write(data)
        source_snapshots.append({"path": str(snapshot.relative_to(ROOT)),
                                 "sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data)})
    command = [sys.executable, "-B", str(ROOT / "reconstruct_sources.py"), args.mode]
    started_at = datetime.now(timezone.utc).isoformat()
    started = time.monotonic()
    timeout = False
    try:
        result = subprocess.run(command, capture_output=True, timeout=120, check=False)
        stdout, stderr, code = result.stdout, result.stderr, result.returncode
    except subprocess.TimeoutExpired as error:
        stdout, stderr, code = error.stdout or b"", error.stderr or b"", 124
        timeout = True
    elapsed = time.monotonic() - started
    for name, content in (("stdout.log", stdout), ("stderr.log", stderr)):
        with (run_dir / name).open("xb") as stream:
            stream.write(content)
    record = {"command": command, "cwd": str(Path.cwd()), "started_at": started_at,
              "finished_at": datetime.now(timezone.utc).isoformat(), "wall_seconds": elapsed,
              "exit_code": code, "timed_out": timeout, "timeout_seconds": 120,
              "python": sys.version, "platform": platform.platform(),
              "source_snapshots": source_snapshots,
              "reconstructor_sha256": hashlib.sha256((ROOT / "reconstruct_sources.py").read_bytes()).hexdigest(),
              "runner_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              "plan_sha256": hashlib.sha256((ROOT / "repair_plan.json").read_bytes()).hexdigest(),
              "new_scientific_executions": 0}
    with (run_dir / "run.json").open("x") as stream:
        json.dump(record, stream, indent=2)
        stream.write("\n")
    print(json.dumps({"run": str(run_dir), "exit_code": code, "wall_seconds": elapsed}))
    print(stdout.decode("utf-8", errors="replace"), end="")
    print(stderr.decode("utf-8", errors="replace"), end="", file=sys.stderr)
    return code


if __name__ == "__main__":
    sys.exit(main())
