#!/usr/bin/env python3
"""Run finite QA in a fresh, review-only namespace and retain exact logs/timings."""
import datetime as dt
import hashlib
import json
import os
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[6]
REVIEW = Path(__file__).resolve().parent
name = sys.argv[1]
assert name.isalnum()
OUT = REVIEW / name
OUT.mkdir(exist_ok=False)
(OUT / "tmp").mkdir()
env_base = dict(os.environ, PYTHONDONTWRITEBYTECODE="1", TMPDIR=str(OUT / "tmp"))
records = []
started = dt.datetime.now(dt.timezone.utc).isoformat()


def run(label, args, locale=None):
    env = env_base.copy()
    if locale:
        env["LC_ALL"] = locale
    begin = time.monotonic()
    result = subprocess.run(args, cwd=ROOT, env=env, capture_output=True)
    (OUT / (label + ".log")).write_bytes(result.stdout + result.stderr)
    records.append({"id": label, "command": args, "LC_ALL": env.get("LC_ALL"),
                    "exit_code": result.returncode, "wall_seconds": time.monotonic() - begin,
                    "log": str((OUT / (label + ".log")).relative_to(ROOT))})
    print(label, result.returncode, flush=True)
    return result


relative = lambda p: str(p.relative_to(ROOT))
run("integrity_before", [sys.executable, "-B", str(REVIEW / "audit_inputs.py"), str(OUT / "integrity_before.json")])
locales = run("locales", ["locale", "-a"]).stdout.decode().splitlines()
utf8 = next((x for x in ("pt_BR.UTF-8", "en_US.UTF-8") if x in locales), None)
assert utf8 is not None, "No installed UTF-8 locale"
for mode, locale in (("C", "C"), ("UTF8", utf8)):
    run(mode + "_independent", ["Rscript", "--vanilla", str(REVIEW / "probes.R"), relative(OUT / (mode + "_independent"))], locale)
    for script, label in (("run_tests.R", "legacy"), ("test_round2.R", "repairs")):
        run(mode + "_" + label, ["Rscript", "--vanilla", "tests/mebane/2026/" + script,
                                  relative(OUT / (mode + "_" + label))], locale)
run("G1_fixtures", ["Rscript", "--vanilla", "tests/mebane/data/test_g1.R"], "C")
run("DAG_checker", [sys.executable, "-B", str(REVIEW / "trace_checker.py"), str(OUT / "checker_reads.json")])
for stem in ("tse-ea11-arquivo-de-configuracao-de-eleicoes", "tse-ea16-arquivo-de-configuracao-de-secoes-eleitorais",
             "tse-ea18-arquivo-auxiliar-de-secao", "tse-ea20-arquivo-de-resultado-unificado",
             "tse-instrucoes-para-download-dos-arquivos-da-divulgacao-2026"):
    path = REVIEW.parent / "previous_sources/quality_reports/results/mebane_gates/coordination" / (stem + ".pdf")
    run(stem, ["pdftotext", "-layout", str(path), "-"])
run("integrity_after", [sys.executable, "-B", str(REVIEW / "audit_inputs.py"), str(OUT / "integrity_after.json")])
before = json.loads((OUT / "integrity_before.json").read_text())
after = json.loads((OUT / "integrity_after.json").read_text())
unchanged = before["ledger_sha256"] == after["ledger_sha256"] and before["ledger_states"] == after["ledger_states"]
report = {"started_at_utc": started, "finished_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
          "commands": records, "selected_utf8_locale": utf8,
          "ledger_unchanged": unchanged, "status": "PASS" if unchanged and
              all(x["exit_code"] == 0 for x in records) else "FAIL",
          "script_hashes": {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in REVIEW.glob("*.py")}}
(OUT / "execution.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
print(report["status"], flush=True)
if report["status"] != "PASS":
    raise SystemExit(1)
