"""Run one command with immutable per-command output and elapsed-time evidence."""
import json
import shlex
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

ROUND = Path(__file__).resolve().parent
ROOT = ROUND.parents[4]

if len(sys.argv) < 5 or sys.argv[3] != "--":
    raise SystemExit("Usage: run_logged.py LABEL SCOPE -- COMMAND [ARGS...]")
label, scope = sys.argv[1:3]
command = sys.argv[4:]
if not label.replace("_", "").isalnum():
    raise SystemExit("Invalid log label")
log_dir = ROUND / "logs"
log_dir.mkdir(exist_ok=True)
record_path = log_dir / (label + ".json")
output_path = log_dir / (label + ".txt")
if record_path.exists() or output_path.exists():
    raise SystemExit("Command record exists; refusing overwrite")
started = datetime.now(timezone.utc).isoformat()
t0 = time.monotonic()
with output_path.open("w", encoding="utf-8") as output:
    result = subprocess.run(command, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT,
                            check=False, text=True)
record = {"command": command, "command_display": shlex.join(command), "scope": scope,
          "started_at_utc": started, "ended_at_utc": datetime.now(timezone.utc).isoformat(),
          "elapsed_seconds": round(time.monotonic() - t0, 6),
          "exit_code": result.returncode,
          "output": str(output_path.relative_to(ROOT))}
record_path.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
print(json.dumps(record, ensure_ascii=False))
print(output_path.read_text())
raise SystemExit(result.returncode)
