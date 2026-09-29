"""Run serial locale regressions and record commands, output and elapsed time."""
import datetime as dt
import hashlib
import json
import os
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[5]
ROUND = Path(__file__).resolve().parent
name = sys.argv[1]
if not name.isalnum():
    raise SystemExit("Use an alphanumeric execution name")
out = ROUND / "executions" / name
out.mkdir(parents=True, exist_ok=False)
records = []
tracked = [ROOT / path for path in (
    "R/lib/mebane_2026_intake.R", "R/lib/mebane_data.R", "config/mebane/2022.json",
    "config/mebane/2026/intake.json", "tests/mebane/data/test_g1.R",
    "scripts/mebane_gates.py", "tests/test_mebane_gates.py")]
tracked += [path for path in (ROOT / "tests/mebane/2026").rglob("*")
            if path.is_file() and "__pycache__" not in path.parts]
tracked += [Path(__file__).resolve(), ROUND / "ledger_dag_snapshot.json"]
before = {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in tracked}

def run(label, command, environment=None):
    env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1")
    if environment:
        env.update(environment)
    start = time.monotonic()
    result = subprocess.run(command, cwd=ROOT, env=env, capture_output=True)
    log = out / (label + ".log")
    log.write_bytes(result.stdout + result.stderr)
    records.append({"label": label, "command": command, "environment_overrides": environment or {},
                    "locale_environment": {key: env.get(key) for key in ("LANG", "LC_ALL", "LC_CTYPE")},
                    "exit_code": result.returncode, "wall_seconds": time.monotonic() - start,
                    "log": str(log.relative_to(ROOT))})
    print(f"{label}: exit={result.returncode}", flush=True)
    return result

locales = run("locales", ["locale", "-a"]).stdout.decode().splitlines()
utf8 = next((x for x in ("pt_BR.UTF-8", "en_US.UTF-8") if x in locales), None)
if utf8 is None:
    raise SystemExit("No requested UTF-8 locale available")
for mode, env in (("C", {"LC_ALL": "C"}), ("default", {}), ("UTF8", {"LC_ALL": utf8})):
    for script, suffix in (("run_tests.R", "legacy"), ("test_round2.R", "repairs")):
        target = out / (mode + "_" + suffix)
        run(mode + "_" + suffix, ["Rscript", "--vanilla", "tests/mebane/2026/" + script,
                                 str(target.relative_to(ROOT))], env)
run("G1_fixtures", ["Rscript", "--vanilla", "tests/mebane/data/test_g1.R"], {"LC_ALL": "C"})
run("DAG_checker", [sys.executable, "tests/mebane/2026/check_dag.py"])
report = {"finished_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
          "status": "PASS" if all(x["exit_code"] == 0 for x in records) else "FAIL",
          "selected_utf8_locale": utf8, "commands": records,
          "code_input_sha256": before,
          "test_inputs_unchanged": all(hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == digest
                                       for path, digest in before.items())}
if not report["test_inputs_unchanged"]:
    report["status"] = "FAIL"
(out / "execution.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
if report["status"] != "PASS":
    raise SystemExit(1)
