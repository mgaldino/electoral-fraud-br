"""Record bounded reviewer checks and logs; never run candidate output writers."""
import json
import os
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[5]
relative = str(HERE.relative_to(ROOT))
commands = [
    ["Rscript", "--vanilla", relative + "/independent_closure.R"],
    [sys.executable, relative + "/verify_integrity.py", "integrity_final.json"],
    ["git", "diff", "--check", "--", relative],
]
records = []
for i, command in enumerate(commands, 1):
    start = datetime.now(timezone.utc).isoformat()
    clock = time.monotonic()
    result = subprocess.run(command, cwd=ROOT, env={**os.environ, "LC_ALL": "C", "PYTHONDONTWRITEBYTECODE": "1"},
                            capture_output=True, text=True)
    log = HERE / f"qa_command_{i:02}.log"
    log.write_text(result.stdout + result.stderr)
    records.append({"argv": command, "cwd": str(ROOT), "started_at_utc": start,
                    "elapsed_seconds": time.monotonic() - clock, "exit_code": result.returncode,
                    "environment_override": {"LC_ALL": "C", "PYTHONDONTWRITEBYTECODE": "1"},
                    "log": str(log.relative_to(ROOT))})
    print(json.dumps({"command": command, "exit_code": result.returncode,
                      "stdout": result.stdout, "stderr_log": str(log.relative_to(ROOT))}))
(HERE / "commands.json").write_text(json.dumps(records, indent=2) + "\n")
sys.exit(1 if any(x["exit_code"] for x in records) else 0)
