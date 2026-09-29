"""Log reviewer commands without permitting evidence writes outside this review."""
import json
import os
import shlex
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[5]
label, *command = sys.argv[1:]
assert label.replace("_", "").isalnum() and command
logs = OUT / "logs"
logs.mkdir(exist_ok=True)
tmp = OUT / "tmp"
tmp.mkdir(exist_ok=True)
log = logs / f"{label}.txt"
record = logs / f"{label}.json"
assert not log.exists() and not record.exists(), "Log already exists"
env = dict(os.environ, TMPDIR=str(tmp), PYTHONDONTWRITEBYTECODE="1")
started = datetime.now(timezone.utc).isoformat()
clock = time.monotonic()
with log.open("w") as output:
    completed = subprocess.run(command, cwd=ROOT, env=env, stdout=output,
                               stderr=subprocess.STDOUT, text=True, check=False)
result = {"command": command, "command_display": shlex.join(command),
          "started_at_utc": started, "ended_at_utc": datetime.now(timezone.utc).isoformat(),
          "elapsed_seconds": round(time.monotonic() - clock, 3),
          "exit_code": completed.returncode, "output": str(log.relative_to(ROOT))}
record.write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps(result))
print(log.read_text())
raise SystemExit(completed.returncode)
