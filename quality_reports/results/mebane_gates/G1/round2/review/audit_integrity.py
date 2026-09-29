"""Independent file closure, prior-round recovery, and static-contract probes."""
import hashlib
import json
import runpy
from pathlib import Path
from unittest.mock import patch

ROOT = Path.cwd()
BASE = Path("quality_reports/results/mebane_gates/G1")
R2 = BASE / "round2"
OUT = R2 / "review"
EXPECTED = "517c17c724cca82a820519c476981d47c8892c7383dd2c3dded9373eba6d31e8"
CONTRACT = "f985ab97469aa66755b977a09781b30608afa6e245896d9d9788b4461190975d"

def digest(path):
    with Path(path).open("rb") as handle:
        return hashlib.file_digest(handle, "sha256").hexdigest()

def read(path):
    return json.loads(Path(path).read_text())

def canonical(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, ensure_ascii=False,
                                     separators=(",", ":")).encode()).hexdigest()

assert digest(R2 / "candidate_manifest.json") == EXPECTED
m = read(R2 / "candidate_manifest.json")
r = read(R2 / "run.json")
assert r["executor_id"] == "01a0eaee-0164-7530-884d-adec564a8327"
assert m["contract_sha256"] == r["contract_sha256"] == CONTRACT
assert canonical(read(R2 / "gate_contract.json")) == CONTRACT
assert (R2 / "gate_contract.json").read_bytes() == (BASE / "round1/gate_contract.json").read_bytes()
included = {x["path"]: x for x in m["files"]}
assert len(included) == len(m["files"])
actual_hashes = {}
for name, entry in included.items():
    actual_hashes[name] = digest(name)
    assert actual_hashes[name] == entry["sha256"], name
    assert Path(name).stat().st_size == entry["bytes"], name
fields = ("inputs", "code", "configuration", "outputs")
declared = {name for field in fields for name in r[field]}
assert set(included) == declared | {str(R2 / "run.json")}
for field in fields:
    assert set(r[field]) == set(r["component_sha256"][field])
    for name in r[field]:
        assert actual_hashes[name] == r["component_sha256"][field][name]
assert "quality_reports/plans/mebane_2022_2026_gates.json" not in included
assert str(BASE / "round1/gate_contract.json") in r["inputs"]
expected_g0 = {
    "candidate_manifest.json": "f71333db477385fc78dad8a7a1a7ca78e48479226dcdbde80ce97d724409fec7",
    "review/review.json": "ef624cb4b2d8ad098b87e196d87add358ce1eba93165d44fcc1939ff303f5376",
    "adjudication.json": "ea1b4905fdfa14f6e3f36c41974ea948ba0c39d1f81f87d6eaf479782216267b",
}
for name, expected in expected_g0.items():
    assert digest(BASE.parent / "G0/round2" / name) == expected
assert r["dependency_manifests"]["G0"] == expected_g0["candidate_manifest.json"]
assert r["dependency_approvals"]["G0"]["review_sha256"] == expected_g0["review/review.json"]
assert r["dependency_approvals"]["G0"]["adjudication_sha256"] == expected_g0["adjudication.json"]

old = read(BASE / "round1/candidate_manifest.json")
assert digest(BASE / "round1/candidate_manifest.json") == "009e0fd39f8ab495e52fcb214476fcc7b6095f895381006a924df6a2ffbd7003"
mapping = read(R2 / "previous_candidate_sources_map.json")
snapshots = {x["original_path"]: x for x in mapping["files"]}
old_run = read(BASE / "round1/run.json")
assert set(snapshots) == set(old_run["code"] + old_run["configuration"])
recovery = []
for entry in old["files"]:
    resolved = snapshots.get(entry["path"], {}).get("snapshot_path", entry["path"])
    assert digest(resolved) == entry["sha256"], resolved
    assert Path(resolved).stat().st_size == entry["bytes"]
    if entry["path"] in snapshots:
        assert snapshots[entry["path"]]["sha256"] == entry["sha256"]
    recovery.append({"original": entry["path"], "recovered_from": resolved,
                     "sha256": entry["sha256"]})
before = read(R2 / "round1_tree_before.json")
for entry in before["files"]:
    assert digest(entry["path"]) == entry["sha256"]
    assert Path(entry["path"]).stat().st_size == entry["bytes"]
preservation = read(R2 / "checks/round1_preservation.json")
before_paths = {x["path"] for x in before["files"]}
added_paths = {x["path"] for x in preservation["coordinator_additions_since_initial_snapshot"]}
current_old = {str(p) for p in (BASE / "round1").rglob("*") if p.is_file()}
assert current_old == before_paths | added_paths
assert digest(BASE / "round1/review/review.json") == "5702f2bf4dd306bdfb7af86e81477faceecd54a4b3b4024cdfdf1d048b5d2c5f"

# Invoke only the candidate's read-only contract validator, with all reads guarded.
module = runpy.run_path(str(R2 / "freeze_candidate.py"), run_name="qa_static_contract")
reader = module["read_contract"]
target = BASE / "round1/gate_contract.json"
reads = []
original_open = Path.open
def guarded_open(path, *args, **kwargs):
    assert path == target, f"Undeclared read: {path}"
    assert not args or args[0] in ("r", "rb")
    reads.append(str(path))
    return original_open(path, *args, **kwargs)
with patch.object(Path, "open", guarded_open):
    content, contract = reader(target)
assert reads == [str(target)]
case_dir = OUT / "static_contract_cases"
case_dir.mkdir(exist_ok=True)
changed = case_dir / "changed.json"
changed.write_bytes(content + b" ")
probes = []
for label, action in [
    ("altered_file_bytes", lambda: reader(changed)),
    ("wrong_canonical_digest", lambda: reader(target, contract_sha="0" * 64)),
]:
    try:
        action()
    except RuntimeError as error:
        probes.append({"case": label, "rejected": True, "error": str(error)})
    else:
        raise AssertionError(f"Accepted invalid static contract: {label}")
result = {
    "candidate_manifest_sha256": EXPECTED, "contract_sha256": CONTRACT,
    "declared_files_verified": len(included), "path_and_hash_closure": True,
    "g0_exact": True, "preserved_sources": len(snapshots),
    "recoverable_round1_manifest_entries": recovery,
    "round1_tree_before_count": len(before_paths), "round1_additions_count": len(added_paths),
    "round1_tree_unchanged": True, "static_contract_reads": reads, "static_contract_probes": probes,
}
(OUT / "integrity_results.json").write_text(json.dumps(result, indent=2) + "\n")
print(f"PASS: {len(included)} manifest files; {len(recovery)} old entries recoverable; {len(snapshots)} exact source copies; static-contract probes rejected.")
