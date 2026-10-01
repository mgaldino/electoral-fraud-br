"""Verify frozen common candidate and create an isolated, byte-identical test tree."""
import hashlib
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path("/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud")
BASE = Path("quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study")
OUT = ROOT / BASE / "review_preflight"
SANDBOX = OUT / "common01_tree"
SOURCE = ROOT / BASE / "preflight_common01/candidate_manifest.json"

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def copy_new(source, relative):
    target = SANDBOX / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    assert not target.exists(), target
    shutil.copyfile(source, target)
    assert sha(source) == sha(target)

def main():
    manifest = json.loads(SOURCE.read_text())
    assert not manifest["D_implementation_included"]
    assert not SANDBOX.exists()
    SANDBOX.mkdir()
    records = []
    for item in manifest["files"]:
        snapshot = ROOT / item["snapshot"]
        current = ROOT / item["path"]
        assert sha(snapshot) == item["sha256"]
        assert snapshot.stat().st_size == item["bytes"]
        assert sha(current) == item["sha256"]
        copy_new(snapshot, Path(item["path"]))
        records.append({**item, "snapshot_and_current_match": True})
    data_rel = BASE / "data/run-20260930T235038Z-pid61600"
    dm = json.loads((ROOT / data_rel / "manifest.json").read_text())
    supplements = []
    for item in dm["inputs"].values():
        source = Path(item["path"])
        assert sha(source) == item["sha256"]
        relative = source.relative_to(ROOT)
        if not (SANDBOX / relative).exists():
            copy_new(source, relative)
            supplements.append({"path": str(relative), "sha256": sha(source), "basis": "data manifest input"})
    for item in dm["outputs"].values():
        relative = data_rel / item["file"]
        assert sha(ROOT / relative) == item["sha256"]
        if not (SANDBOX / relative).exists():
            copy_new(ROOT / relative, relative)
            supplements.append({"path": str(relative), "sha256": sha(ROOT / relative), "basis": "data manifest output"})
    checksum = data_rel / "SHA256SUMS"
    copy_new(ROOT / checksum, checksum)
    supplements.append({"path": str(checksum), "sha256": sha(ROOT / checksum), "basis": "independently captured data checksum file"})
    copy_new(SOURCE, BASE / "preflight_common01/candidate_manifest.json")
    result = {"created_utc": datetime.now(timezone.utc).isoformat(),
              "executor_id": "019d795a-acfa-72c2-a210-d55a46c606c2",
              "reviewer_id": "01a0f4b8-962b-77a3-a418-6247c6219e8b",
              "candidate_manifest_sha256": sha(SOURCE), "status": "hashes_verified",
              "candidate_files": records, "supplementary_dependencies": supplements,
              "source_D_read": False, "MCMC": False,
              "command": "PYTHONDONTWRITEBYTECODE=1 python3 " + str(BASE / "review_preflight/prepare_review.py")}
    with (OUT / "source_check_common01.json").open("x") as stream:
        json.dump(result, stream, indent=2)
    print(json.dumps({"candidate_files_verified": len(records), "supplements": len(supplements),
                      "manifest_sha256": sha(SOURCE), "sandbox": str(SANDBOX)}))

if __name__ == "__main__":
    main()
