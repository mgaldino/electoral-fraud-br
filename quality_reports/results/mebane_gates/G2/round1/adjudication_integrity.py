"""Bind coordinator adjudication to the exact mathematical candidate and QA."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[5]
HERE = Path(__file__).resolve().parent


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


expected = {
    "candidate_manifest.json": "783cfb036f8f26bf894c36782df4fb94e20351e4df015ca6e24330021d04a5a9",
    "review/review.json": "a027cd5ad0875ffbb92e3b983c2907700fe6e8b4dbfc776df141ef9f5f80ba7c",
}
for relative, checksum in expected.items():
    assert sha(HERE / relative) == checksum
verified = {}
for name in ("candidate_manifest.json", "review/review_manifest.json"):
    manifest = json.loads((HERE / name).read_text())
    for entry in manifest["files"]:
        path = ROOT / entry["path"]
        assert sha(path) == entry["sha256"] and path.stat().st_size == entry["bytes"], entry["path"]
    verified[name] = {"sha256": sha(HERE / name), "files_verified": len(manifest["files"])}
record = {"exact_identities": expected, "verified_manifests": verified,
          "scope": "Integrity, not mathematical completeness or runtime semantics"}
(HERE / "adjudication_integrity.json").write_text(json.dumps(record, indent=2) + "\n")
print(json.dumps(record, indent=2))
