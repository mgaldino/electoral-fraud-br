"""Verify the complete candidate and add only new frozen sources to the QA tree."""
import hashlib
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path("/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud")
BASE = Path("quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study")
OUT = ROOT / BASE / "review_preflight"
TREE = OUT / "common01_tree"
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
manifest_path = ROOT / BASE / "preflight_full01/candidate_manifest.json"
full = json.loads(manifest_path.read_text())
common = json.loads((ROOT / BASE / "preflight_common01/candidate_manifest.json").read_text())
assert full["D_implementation_included"] and not full["MCMC_empirical"]
full_by_path = {x["path"]: x for x in full["files"]}
assert len(full_by_path) == len(full["files"])
for item in common["files"]:
    assert full_by_path[item["path"]]["sha256"] == item["sha256"]
records = []
for item in full["files"]:
    source = ROOT / item["snapshot"]
    original = ROOT / item["path"]
    assert sha(source) == sha(original) == item["sha256"]
    assert source.stat().st_size == item["bytes"]
    target = TREE / item["path"]
    if target.exists():
        assert sha(target) == item["sha256"]
    else:
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        assert sha(target) == item["sha256"]
    records.append({"path": item["path"], "snapshot": item["snapshot"], "sha256": item["sha256"], "verified": True})
target = TREE / BASE / "preflight_full01/candidate_manifest.json"
assert not target.exists()
target.parent.mkdir(parents=True, exist_ok=True)
shutil.copyfile(manifest_path, target)
result = {"status": "pass_source_identity", "created_utc": datetime.now(timezone.utc).isoformat(),
          "candidate_manifest_sha256": sha(manifest_path), "contract_sha256": full["contract_sha256"],
          "files_verified": records, "common_files_preserved": len(common["files"]),
          "reviewer_id": "01a0f4b8-962b-77a3-a418-6247c6219e8b", "MCMC": False}
with (OUT / "source_check_full01.json").open("x") as f:
    json.dump(result, f, indent=2)
print(json.dumps({"manifest_sha256": sha(manifest_path), "files_verified": len(records), "common_intact": len(common["files"])}))
