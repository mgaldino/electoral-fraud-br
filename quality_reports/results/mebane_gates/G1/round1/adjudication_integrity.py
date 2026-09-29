"""Check the exact G1 candidate and reproduce the missing-ledger finding."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[5]
ROUND = ROOT / "quality_reports/results/mebane_gates/G1/round1"


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


manifest_path = ROUND / "candidate_manifest.json"
manifest = json.loads(manifest_path.read_text())
run = json.loads((ROUND / "run.json").read_text())
assert sha(manifest_path) == "009e0fd39f8ab495e52fcb214476fcc7b6095f895381006a924df6a2ffbd7003"
assert sha(ROUND / "review/review.json") == "5702f2bf4dd306bdfb7af86e81477faceecd54a4b3b4024cdfdf1d048b5d2c5f"
for entry in manifest["files"]:
    path = ROOT / entry["path"]
    assert path.stat().st_size == entry["bytes"] and sha(path) == entry["sha256"], entry["path"]
ledger = "quality_reports/plans/mebane_2022_2026_gates.json"
code = (ROUND / "freeze_candidate.py").read_text()
assert ledger in code
assert ledger not in run["inputs"]
assert ledger not in {entry["path"] for entry in manifest["files"]}
result = {
    "manifest_sha256": sha(manifest_path),
    "review_sha256": sha(ROUND / "review/review.json"),
    "declared_files_verified": len(manifest["files"]),
    "undeclared_ledger_read_confirmed": True,
    "finding": "G1-R1-QAD-F02",
}
(ROUND / "adjudication_integrity.json").write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps(result, indent=2))
