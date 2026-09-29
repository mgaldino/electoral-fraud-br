#!/usr/bin/env python3
"""Hash every QA-owned file without modifying the frozen candidate."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[6]
REVIEW = Path(__file__).resolve().parent
OUTPUT = REVIEW / "review_manifest.json"
files = sorted(p for p in REVIEW.rglob("*") if p.is_file() and p != OUTPUT)
entries = [{"path": str(path.relative_to(ROOT)),
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "bytes": path.stat().st_size} for path in files]
manifest = {
    "gate_id": "G7", "round": "round1",
    "contract_sha256": "fc071a8664d04ba6a0a4ca91298d333ee1ca89868a26b23e705946fef1c2f94d",
    "candidate_manifest_sha256": "62f7a5c4907c9d39b75fe5cd88224bddb4796e015f69f004469e51df7ae493c8",
    "reviewer_id": "01a0eb4a-fa6d-7463-9d5a-bad4dd08b3c0",
    "excluded_self": str(OUTPUT.relative_to(ROOT)),
    "files": entries,
}
OUTPUT.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
assert len(entries) == len({entry["path"] for entry in entries})
print(f"QA manifest: {len(entries)} files; SHA-256 {hashlib.sha256(OUTPUT.read_bytes()).hexdigest()}")
