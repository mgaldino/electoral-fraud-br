"""Freeze G3 executor candidate metadata and all consumed bytes; no cleanup."""
import hashlib
import json
import re
import shutil
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[5]
HERE = Path(__file__).resolve().parent
GATE = "G3"
EXECUTOR = "01a0ee04-c901-7831-8ac6-0160da2e3883"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def dump_new(path, value):
    if path.exists():
        raise FileExistsError(path)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n",
                    encoding="utf-8")


def canonical(value):
    return hashlib.sha256(json.dumps(value, ensure_ascii=False, sort_keys=True,
        separators=(",", ":")).encode("utf-8")).hexdigest()


def static(gate):
    obj = {k: v for k, v in gate.items() if k not in {"status", "records"}}
    obj["todos"] = [{k: v for k, v in todo.items()
                     if k not in {"status", "evidence"}} for todo in gate["todos"]]
    return obj


def rel(path):
    return str(path.relative_to(ROOT))


ledger = json.loads((ROOT / "quality_reports/plans/mebane_2022_2026_gates.json").read_text())
gates = {g["id"]: g for g in ledger["gates"]}
g2, g3 = gates["G2"], gates["G3"]
assert g2["status"] == "pass" and g3["status"] == "running"
contract = static(g3)
contract_hash = canonical(contract)
assert contract_hash == canonical(static(g3))

approvals = {
    "candidate_manifest": ("quality_reports/results/mebane_gates/G2/round3/candidate_manifest.json",
                           "2ffd63203a6af407c5f17c708ce2c42120fef0dc9600e3585f83be6e48313173"),
    "review": ("quality_reports/results/mebane_gates/G2/round3/review/review.json",
               "0b6a2c4268e1b7d58c2964e31db54df2c894056634939c24681d38ad54ef96f3"),
    "adjudication": ("quality_reports/results/mebane_gates/G2/round3/adjudication.json",
                     "4999cc69a32e53e5bc0f6308acbfb77671c192a9b4126715794e1acfcc8b2ca9"),
}
for path, expected in approvals.values():
    assert sha(ROOT / path) == expected
assert g2["records"]["candidate_manifest"] == approvals["candidate_manifest"][0]
assert g2["records"]["review"] == approvals["review"][0]
assert g2["records"]["adjudication"] == approvals["adjudication"][0]

benchmark = ROOT / "quality_reports/results/mebane_gates/G2/round2/benchmark_contract.json"
qbl = ROOT / "quality_reports/results/mebane_gates/G0/round1/qbl_installed_3017de5.jags"
assert sha(benchmark) == "63b61fb0594d0302a03d999bcff6c62967b6e999f37b4c9a8821f0f8e9ed18d2"
assert sha(qbl) == "f8360126424b7a463f76a1c99efc89a8a5cb81339213bd4931559f14595fbab6"

dump_new(HERE / "gate_contract.json", contract)
dump_new(HERE / "metadata_consumed.json", {
    "source": "quality_reports/plans/mebane_2022_2026_gates.json",
    "scope": "full G2 and G3 gate objects, including status/evidence/records; ledger is not a manifest input",
    "G2": g2, "G3": g3,
})

canonical_inputs = [
    "CLAUDE.md",
    "quality_reports/results/mebane_gates/coordination/2026-09-29_g3_runtime/dispatch.md",
    "quality_reports/results/mebane_gates/coordination/2026-09-29_benchmark_round/g3_dispatch_requirements.md",
    rel(benchmark), rel(qbl),
    "quality_reports/results/mebane_gates/G2/round2/sources/ef_main_3017de5.R",
    *(v[0] for v in approvals.values()),
    "R/05_eforensics_umeforensics_qbl.R",
    "R/07_brasil_full_qbl.R",
    "tests/mebane/likelihood/test_ar02_interface.R",
    "scripts/mebane_gates.py",
]
snapshots = []
for source in canonical_inputs:
    src = ROOT / source
    dst = HERE / "snapshots" / source
    if dst.exists():
        raise FileExistsError(dst)
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    assert sha(src) == sha(dst)
    snapshots.append(rel(dst))

commands = [
    ("deterministic_v2_attempt1", "timeout 120 Rscript --vanilla tests/mebane/likelihood/g3_deterministic.R",
     "g3_deterministic.log", 1, "failed_R_vector_name"),
    ("deterministic_v2_attempt2", "timeout 120 Rscript --vanilla tests/mebane/likelihood/g3_deterministic.R",
     "g3_deterministic_attempt2.log", 0, "passed_before_margin_flags"),
    ("deterministic_v2_attempt3", "timeout 120 Rscript --vanilla tests/mebane/likelihood/g3_deterministic.R",
     "g3_deterministic_attempt3.log", 0, "passed_with_margin_flags"),
    ("jags_v2_attempt1", "timeout 120 Rscript --vanilla tests/mebane/likelihood/g3_jags.R",
     "g3_jags_attempt1.log", 0, "inconclusive_update_method_bug_caught"),
    ("jags_v2_attempt2", "timeout 120 Rscript --vanilla tests/mebane/likelihood/g3_jags.R",
     "g3_jags_attempt2.log", 1, "failed_scalar_column_extraction_after_sampling"),
    ("jags_v2_attempt3", "timeout 120 Rscript --vanilla tests/mebane/likelihood/g3_jags.R",
     "g3_jags_attempt3.log", 0, "conditioned_comparison_inconclusive_diagnostics"),
    ("interface", "timeout 120 Rscript --vanilla tests/mebane/likelihood/test_ar02_interface.R",
     "g3_interface_attempt1.log", 0, "pass_wrapper_sentinel"),
    ("source", "timeout 120 Rscript --vanilla tests/mebane/likelihood/g3_source_contract.R",
     "g3_source_attempt1.log", 0, "pass_static_checks"),
]
recorded = []
for name, cmd, log, exit_code, outcome in commands:
    text = (HERE / log).read_text()
    match = re.search(r"^real ([0-9.]+)$", text, re.MULTILINE)
    assert match, log
    recorded.append({"id": name, "command": "/usr/bin/time -p " + cmd,
                     "log": rel(HERE / log), "exit_code": exit_code,
                     "elapsed_seconds": float(match.group(1)),
                     "semantic_outcome": outcome})

code = [
    "R/lib/mebane_model.R",
    "tests/mebane/likelihood/g3_deterministic.R",
    "tests/mebane/likelihood/g3_jags.R",
    "tests/mebane/likelihood/g3_source_contract.R",
    "tests/mebane/likelihood/test_ar02_interface.R",
    rel(HERE / "build_candidate.py"),
]
config = [rel(HERE / p) for p in ("protocol.json", "protocol_v2.json",
                                     "preflight_v1.md", "protocol_provenance_errata.md")]
inputs = [rel(HERE / "gate_contract.json"), rel(HERE / "metadata_consumed.json"),
          *snapshots, *canonical_inputs]
outputs = [rel(p) for p in HERE.rglob("*") if p.is_file() and
           p.name not in {"run.json", "candidate_manifest.json"} and
           rel(p) not in set(inputs + code + config)]
run = {
    "gate_id": GATE, "round": "round1", "contract_sha256": contract_hash,
    "executor_id": EXECUTOR, "goal_id": EXECUTOR,
    "requested_model": "gpt-6-sol", "requested_effort": "xhigh",
    "candidate_status": "inconclusive", "gate_approved": False,
    "started_at_utc": datetime.fromtimestamp((HERE / "protocol.json").stat().st_mtime,
                                      tz=timezone.utc).isoformat(),
    "ended_at_utc": datetime.now(timezone.utc).isoformat(),
    "dependency_manifests": {"G2": approvals["candidate_manifest"][1]},
    "dependency_approvals": {"G2": {"review_sha256": approvals["review"][1],
                                     "adjudication_sha256": approvals["adjudication"][1]}},
    "benchmark_contract_sha256": sha(benchmark), "qbl_sha256": sha(qbl),
    "metadata_consumed_sha256": sha(HERE / "metadata_consumed.json"),
    "versions": {"R": "4.4.2", "JAGS": "4.3.2", "package_details": rel(HERE / "environment.log")},
    "seeds": {"generator": 31101, "JAGS": [31102, 31103, 31104, 31105]},
    "time_limit_seconds_per_process": 120, "compute_ceiling_seconds": 720,
    "timed_test_seconds_total": sum(c["elapsed_seconds"] for c in recorded),
    "commands": recorded,
    "inputs": inputs, "code": code, "configuration": config, "outputs": sorted(outputs),
    "not_executed": ["national fit", "historical Stan equivalence", "physical generator certification", "G10 author replication"],
}
dump_new(HERE / "run.json", run)
files = sorted(set(inputs + code + config + outputs + [rel(HERE / "run.json")] +
                   [rel(p) for p in HERE.rglob("*") if p.is_file() and p.name != "candidate_manifest.json"]))
assert rel(HERE / "candidate_manifest.json") not in files
assert "quality_reports/plans/mebane_2022_2026_gates.json" not in files
manifest = {"gate_id": GATE, "round": "round1", "contract_sha256": contract_hash,
            "snapshot_policy": "canonical consumed inputs copied and hashed; no live ledger",
            "files": [{"path": path, "sha256": sha(ROOT / path),
                       "bytes": (ROOT / path).stat().st_size} for path in files]}
dump_new(HERE / "candidate_manifest.json", manifest)
print("G3 candidate frozen", contract_hash, len(files), "files")
