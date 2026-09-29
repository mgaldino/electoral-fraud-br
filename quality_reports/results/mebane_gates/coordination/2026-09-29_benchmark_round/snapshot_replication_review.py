"""Preserve mutable inputs before changing any independently reviewed source."""

import hashlib
import json
import shutil
from pathlib import Path


ROOT = Path(__file__).resolve().parents[5]
HERE = Path(__file__).resolve().parent
REVIEW = ROOT / "quality_reports/results/mebane_gates/coordination/authors_replication_discovery_review/review_manifest.json"
MUTABLE = {
    "quality_reports/plans/mebane_2022_2026_gates.json",
    "R/05_eforensics_umeforensics_qbl.R",
    "R/07_brasil_full_qbl.R",
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


manifest = json.loads(REVIEW.read_text(encoding="utf-8"))
rows = []
for item in manifest["inputs"]:
    original = ROOT / item["path"]
    if item["path"] in MUTABLE:
        frozen = HERE / "replication_review_inputs" / item["path"]
        if not frozen.exists():
            assert sha(original) == item["sha256"], item["path"]
            frozen.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(original, frozen)
    else:
        frozen = original
    assert sha(frozen) == item["sha256"], item["path"]
    assert frozen.stat().st_size == item["bytes"], item["path"]
    rows.append({
        "reviewed_path": item["path"], "preserved_path": str(frozen.relative_to(ROOT)),
        "sha256": item["sha256"], "bytes": item["bytes"],
    })

result = {
    "review_manifest": str(REVIEW.relative_to(ROOT)), "review_manifest_sha256": sha(REVIEW),
    "verified_input_count": len(rows), "mutable_inputs_preserved": len(MUTABLE),
    "files": rows,
}
(HERE / "replication_review_recovery.json").write_text(
    json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8",
)
print(json.dumps({"inputs_verified": len(rows), "mutable_inputs_preserved": len(MUTABLE)}))
