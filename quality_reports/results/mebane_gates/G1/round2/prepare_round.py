"""Preserve reviewed G1 source bytes before the authorized round2 edits."""
import hashlib
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[5]
OLD = ROOT / "quality_reports/results/mebane_gates/G1/round1"
NEW = Path(__file__).resolve().parent
EXPECTED_MANIFEST = "009e0fd39f8ab495e52fcb214476fcc7b6095f895381006a924df6a2ffbd7003"


def sha(path):
    with path.open("rb") as handle:
        return hashlib.file_digest(handle, "sha256").hexdigest()


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def main():
    manifest_path = OLD / "candidate_manifest.json"
    if sha(manifest_path) != EXPECTED_MANIFEST:
        raise RuntimeError("Reviewed manifest changed")
    manifest = json.loads(manifest_path.read_text())
    old_run = json.loads((OLD / "run.json").read_text())
    by_path = {entry["path"]: entry for entry in manifest["files"]}
    for entry in manifest["files"]:
        path = ROOT / entry["path"]
        if sha(path) != entry["sha256"] or path.stat().st_size != entry["bytes"]:
            raise RuntimeError(f"Reviewed file changed before preservation: {path}")
    snapshot_dir = NEW / "previous_candidate_sources"
    if snapshot_dir.exists():
        raise RuntimeError("Previous-source snapshot already exists; refusing overwrite")
    mappings = []
    for original in sorted(old_run["code"] + old_run["configuration"]):
        destination = snapshot_dir / original
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / original, destination)
        digest = sha(destination)
        if digest != by_path[original]["sha256"]:
            raise RuntimeError(f"Snapshot differs: {original}")
        mappings.append({"original_path": original,
                         "snapshot_path": str(destination.relative_to(ROOT)),
                         "sha256": digest, "snapshotmatchedoldmanifest": True})
    save(NEW / "previous_candidate_sources_map.json", {
        "reviewed_manifest": str(manifest_path.relative_to(ROOT)),
        "reviewed_manifest_sha256": EXPECTED_MANIFEST,
        "files": mappings,
    })
    save(NEW / "round1_tree_before.json", {
        "files": [{"path": str(path.relative_to(ROOT)), "sha256": sha(path),
                   "bytes": path.stat().st_size}
                  for path in sorted(OLD.rglob("*")) if path.is_file()]
    })
    print(f"Preserved {len(mappings)} reviewed code/configuration files; all 53 manifest files verified.")


if __name__ == "__main__":
    main()
