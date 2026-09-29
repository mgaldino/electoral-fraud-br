"""Verify unchanged round1 artifacts and recovery of reviewed source bytes."""
import hashlib
import json
from pathlib import Path

ROUND = Path(__file__).resolve().parent
ROOT = ROUND.parents[4]
OLD = ROOT / "quality_reports/results/mebane_gates/G1/round1"


def sha(path):
    with path.open("rb") as handle:
        return hashlib.file_digest(handle, "sha256").hexdigest()


before = json.loads((ROUND / "round1_tree_before.json").read_text())
mapping = json.loads((ROUND / "previous_candidate_sources_map.json").read_text())
snapshots = {item["original_path"]: item for item in mapping["files"]}
for item in before["files"]:
    path = ROOT / item["path"]
    if sha(path) != item["sha256"] or path.stat().st_size != item["bytes"]:
        raise RuntimeError(f"Preserved round1 file changed: {item['path']}")
manifest = json.loads((OLD / "candidate_manifest.json").read_text())
if sha(OLD / "candidate_manifest.json") != mapping["reviewed_manifest_sha256"]:
    raise RuntimeError("Reviewed manifest changed")
recoverable = []
for item in manifest["files"]:
    source = item["path"]
    resolved = snapshots.get(source, {}).get("snapshot_path", source)
    if sha(ROOT / resolved) != item["sha256"]:
        raise RuntimeError(f"Reviewed bytes not recoverable: {source}")
    recoverable.append({"reviewed_path": source, "preserved_at": resolved,
                        "sha256": item["sha256"],
                        "current_source_changed": sha(ROOT / source) != item["sha256"]})
previous_paths = {item["path"] for item in before["files"]}
additions = [{"path": str(path.relative_to(ROOT)), "sha256": sha(path),
              "bytes": path.stat().st_size}
             for path in sorted(OLD.rglob("*")) if path.is_file()
             and str(path.relative_to(ROOT)) not in previous_paths]
result = {"previous_round_tree_unchanged": True, "reviewed_bytes_recoverable": True,
          "previous_round_file_count": len(before["files"]),
          "reviewed_manifest_files": recoverable,
          "coordinator_additions_since_initial_snapshot": additions}
(ROUND / "checks" / "round1_preservation.json").write_text(
    json.dumps(result, ensure_ascii=False, indent=2) + "\n")
print(f"Round1 tree unchanged; {len(recoverable)} reviewed entries recoverable; {len(additions)} coordinator additions recorded.")
