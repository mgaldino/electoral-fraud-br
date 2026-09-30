"""Seal non-destructive revision of the G3 round1 executor candidate."""
import hashlib
import json
import re
import shutil
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[6]
HERE = Path(__file__).resolve().parent
ROUND = HERE.parent


def rel(p):
    return str(p.relative_to(ROOT))


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def dump_new(p, x):
    if p.exists():
        raise FileExistsError(p)
    p.write_text(json.dumps(x, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


old = json.loads((ROUND / "run.json").read_text())
assert old["candidate_status"] == "inconclusive"
assert sha(ROUND / "candidate_manifest.json")
assert sha(ROUND / "gate_contract.json") == sha(ROUND / "gate_contract.json")

new_snaps = []
for source in ("R/lib/mebane_model.R", "tests/mebane/likelihood/g3_jags.R",
               "tests/mebane/likelihood/g3_deterministic.R",
               "tests/mebane/likelihood/g3_source_contract.R"):
    src = ROOT / source
    dst = HERE / "snapshots" / source
    if dst.exists():
        raise FileExistsError(dst)
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    assert sha(src) == sha(dst)
    new_snaps.append(rel(dst))

commands = list(old["commands"])
for name, log, exit_code, outcome in (
    ("jags_v2_attempt4", "g3_jags_attempt4.log", 1,
     "failed_status_serialization_after_analytic_degeneracy_fix"),
    ("jags_v2_attempt5", "g3_jags_attempt5.log", 0,
     "conditioned_comparison_inconclusive_tail_ESS")):
    txt = (ROUND / log).read_text()
    match = re.search(r"^real ([0-9.]+)$", txt, re.MULTILINE)
    assert match
    commands.append({"id": name,
      "command": "/usr/bin/time -p timeout 120 Rscript --vanilla tests/mebane/likelihood/g3_jags.R",
      "log": rel(ROUND / log), "exit_code": exit_code,
      "elapsed_seconds": float(match.group(1)), "semantic_outcome": outcome})

inputs = list(old["inputs"]) + new_snaps + [rel(ROUND / "candidate_manifest.json"),
    rel(HERE / "snapshots/root_candidate_old/tests/mebane/likelihood/g3_jags.R"),
    rel(HERE / "old_code_mapping.json")]
code = list(old["code"]) + [rel(HERE / "build_revision.py"), rel(HERE / "recover_old_code.py")]
config = list(old["configuration"])
excluded = set(inputs + code + config)
outputs = sorted(rel(p) for p in ROUND.rglob("*") if p.is_file() and
                 p not in {HERE / "run.json", HERE / "candidate_manifest.json"} and
                 rel(p) not in excluded)
run = dict(old)
run.update({"revision": "revision1", "prior_candidate_manifest_sha256": sha(ROUND / "candidate_manifest.json"),
            "ended_at_utc": datetime.now(timezone.utc).isoformat(),
            "commands": commands,
            "timed_test_seconds_total": sum(c["elapsed_seconds"] for c in commands),
            "inputs": inputs, "code": code, "configuration": config,
            "outputs": outputs,
            "comparison_result": rel(ROUND / "jags_attempt5/comparison_result.json"),
            "todo_evidence": rel(HERE / "todo_evidence.json")})
dump_new(HERE / "run.json", run)

paths = sorted(set(inputs + code + config + outputs + [rel(HERE / "run.json")] +
                   [rel(p) for p in ROUND.rglob("*") if p.is_file() and
                    p != HERE / "candidate_manifest.json"]))
assert "quality_reports/plans/mebane_2022_2026_gates.json" not in paths
manifest = {"gate_id": "G3", "round": "round1", "revision": "revision1",
            "contract_sha256": run["contract_sha256"],
            "prior_candidate_manifest_sha256": run["prior_candidate_manifest_sha256"],
            "files": [{"path": p, "sha256": sha(ROOT / p),
                       "bytes": (ROOT / p).stat().st_size} for p in paths]}
dump_new(HERE / "candidate_manifest.json", manifest)
print("revision1 sealed", len(paths), "files", run["contract_sha256"])
