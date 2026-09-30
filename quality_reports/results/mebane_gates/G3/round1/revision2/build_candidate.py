"""Seal revision2 with new persisted draws and all consumed inputs."""
import hashlib
import json
import re
import shutil
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[6]
HERE = Path(__file__).resolve().parent
ROUND = HERE.parent
PRIOR = ROUND / "revision1"
COORD = ROOT / "quality_reports/results/mebane_gates/coordination/2026-09-29_g3_runtime"


def rel(path):
    return str(path.relative_to(ROOT))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def dump_new(path, obj):
    if path.exists():
        raise FileExistsError(path)
    path.write_text(json.dumps(obj, ensure_ascii=False, indent=2) + "\n",
                    encoding="utf-8")


prior = json.loads((PRIOR / "run.json").read_text())
prior_hash = sha(PRIOR / "candidate_manifest.json")
assert prior_hash == "4b84fe6996a72321225fd3e5f4713439b77b74fc8a7f039d09e3dcaf7beb72a9"
adjud = json.loads((COORD / "draw_persistence_adjudication.json").read_text())
assert adjud["source"]["sha256"] == prior_hash
assert adjud["adjudication"]["verdict"] == "READY_FOR_IMPLEMENTATION"
assert adjud["review_sources"][0]["sha256"] == sha(COORD / "draw_persistence_review.md")
assert adjud["findings"][0]["finding_id"] == "G3-COORD-DRAW-01"
assert adjud["findings"][0]["status"] == "CONFIRMED"
assert prior["contract_sha256"] == json.loads((PRIOR / "candidate_manifest.json").read_text())["contract_sha256"]
assert json.loads((HERE / "postprocess_result.json").read_text())["status"] == "inconclusive"

canonical = [
    COORD / "draw_persistence_adjudication.json",
    COORD / "draw_persistence_review.md",
    ROOT / "tests/mebane/likelihood/g3_draw_replay.R",
    ROOT / "tests/mebane/likelihood/g3_draw_postprocess.R",
]
snapshots = []
for src in canonical:
    dst = HERE / "snapshots" / rel(src)
    if dst.exists():
        raise FileExistsError(dst)
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    assert sha(src) == sha(dst)
    snapshots.append(rel(dst))

command_specs = [
    ("draw_replay", "tests/mebane/likelihood/g3_draw_replay.R", "replay.log", "new_draws_persisted"),
    ("rds_postprocess", "tests/mebane/likelihood/g3_draw_postprocess.R", "postprocess.log", "summaries_from_reopened_RDS_inconclusive"),
]
commands = list(prior["commands"])
for name, script, log, outcome in command_specs:
    txt = (HERE / log).read_text()
    match = re.search(r"^real ([0-9.]+)$", txt, re.MULTILINE)
    assert match, log
    commands.append({"id": name,
      "command": f"/usr/bin/time -p timeout 120 Rscript --vanilla {script}",
      "log": rel(HERE / log), "exit_code": 0,
      "elapsed_seconds": float(match.group(1)), "semantic_outcome": outcome})

inputs = list(prior["inputs"]) + [
    rel(PRIOR / "candidate_manifest.json"),
    rel(ROUND / "jags_attempt5/conditional_comparison.csv"),
    *(rel(p) for p in canonical[:2]),
    *snapshots,
]
code = list(prior["code"]) + [rel(p) for p in canonical[2:]] + [rel(HERE / "build_candidate.py")]
config = list(prior["configuration"]) + [rel(HERE / "replay_plan.json")]
excluded = set(inputs + code + config)
outputs = sorted(rel(p) for p in ROUND.rglob("*") if p.is_file() and
                 p not in {HERE / "run.json", HERE / "candidate_manifest.json"} and
                 rel(p) not in excluded)
run = dict(prior)
run.update({
    "revision": "revision2", "candidate_status": "inconclusive", "gate_approved": False,
    "repair_id": "G3-COORD-DRAW-01", "repair_adjudication_sha256": sha(canonical[0]),
    "prior_candidate_manifest_sha256": prior_hash,
    "started_at_utc": datetime.fromtimestamp((HERE / "replay_plan.json").stat().st_mtime,
                                       tz=timezone.utc).isoformat(),
    "ended_at_utc": datetime.now(timezone.utc).isoformat(),
    "commands": commands,
    "timed_test_seconds_total": sum(item["elapsed_seconds"] for item in commands),
    "inputs": inputs, "code": code, "configuration": config, "outputs": outputs,
    "raw_draws_path": rel(HERE / "raw_chains.rds"),
    "raw_draws_sha256": sha(HERE / "raw_chains.rds"),
    "sampling_metadata_path": rel(HERE / "sampling_metadata.json"),
    "postprocess_result_path": rel(HERE / "postprocess_result.json"),
    "raw_draws_are_new_not_recovered": True,
    "new_mcmc_runs": 1,
})
dump_new(HERE / "run.json", run)
files = sorted(set(inputs + code + config + outputs + [rel(HERE / "run.json")] +
                   [rel(p) for p in ROUND.rglob("*") if p.is_file() and
                    p != HERE / "candidate_manifest.json"]))
assert "quality_reports/plans/mebane_2022_2026_gates.json" not in files
manifest = {"gate_id": "G3", "round": "round1", "revision": "revision2",
            "contract_sha256": run["contract_sha256"],
            "prior_candidate_manifest_sha256": prior_hash,
            "raw_draws_sha256": run["raw_draws_sha256"],
            "files": [{"path": path, "sha256": sha(ROOT / path),
                       "bytes": (ROOT / path).stat().st_size} for path in files]}
dump_new(HERE / "candidate_manifest.json", manifest)
print("revision2 sealed", len(files), "files", run["contract_sha256"])
