"""Verify predecessors and preserve canonical bytes before the diagnostic repair."""
import hashlib
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[6]
HERE = Path(__file__).resolve().parent
ROUND = HERE.parent
PRIOR = ROUND / "revision2"
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
rel = lambda p: str(p.relative_to(ROOT))


def dump_new(path, obj):
    assert not path.exists(), path
    path.write_text(json.dumps(obj, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


manifest = json.loads((PRIOR / "candidate_manifest.json").read_text())
assert sha(PRIOR / "candidate_manifest.json") == "de779221e40964b9729bdd928a814e7e7dfd9738df866b91f6ee97307a14bd0f"
assert sha(ROUND / "revision1/candidate_manifest.json") == "4b84fe6996a72321225fd3e5f4713439b77b74fc8a7f039d09e3dcaf7beb72a9"
assert sha(PRIOR / "raw_chains.rds") == "66ddb0aaef7448b25e817e25c931d5608ee9c7141165842613925e9e145baf6d"
rows = []
for entry in manifest["files"]:
    src = ROOT / entry["path"]
    assert sha(src) == entry["sha256"] and src.stat().st_size == entry["bytes"], src
    if src.is_relative_to(ROUND):
        dst = src
    else:
        dst = HERE / "inherited_snapshots" / entry["path"]
        assert not dst.exists(), dst
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
    rows.append({**entry, "frozen_path": rel(dst)})
dump_new(HERE / "predecessor_files.json", {
    "prior_manifest_sha256": sha(PRIOR / "candidate_manifest.json"),
    "all_entries_verified_before_edit": True, "files": rows})

inputs = [
    "CLAUDE.md",
    "quality_reports/results/mebane_gates/coordination/2026-09-29_g3_runtime/diagnostic_shape_adjudication.json",
    "quality_reports/results/mebane_gates/G3/round1/review/diagnostic_shape_counterexample/counterexample.json",
    "quality_reports/results/mebane_gates/G3/round1/review/diagnostic_shape_counterexample/shape_counterexample.csv",
]
frozen = []
for path in inputs:
    src = ROOT / path
    dst = HERE / "repair_inputs" / path
    assert not dst.exists(), dst
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    frozen.append({"original_path": path, "path": rel(dst), "sha256": sha(dst),
                   "bytes": dst.stat().st_size})
adjud = json.loads((ROOT / inputs[1]).read_text())
assert adjud["source"]["sha256"] == sha(PRIOR / "candidate_manifest.json")
assert adjud["adjudication"]["verdict"] == "READY_FOR_IMPLEMENTATION"
assert adjud["review_sources"][0]["sha256"] == sha(ROOT / inputs[2])
dump_new(HERE / "repair_inputs.json", frozen)
print("pre-edit freeze PASS", len(rows), "predecessor entries", len(frozen), "repair inputs")
