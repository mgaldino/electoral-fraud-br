#!/usr/bin/env python3
"""Validate and bind the completed review without touching candidate files."""
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
B = HERE.parent
ROOT = next(p for p in B.parents if (p / "CLAUDE.md").exists())


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


review = json.loads((HERE / "review.json").read_text())
candidate = json.loads((B / "candidate_manifest.json").read_text())
assert sha(B / "candidate_manifest.json") == review["candidate"]["candidate_manifest_sha256"]
for name, digest in candidate["files_sha256"].items():
    assert sha(B / name) == digest, name
assert review["verdict"] == "PASS" and not review["gate_pass_recorded"]
assert not review["reviewer"]["implemented_candidate"]
assert all(not f["blocks_B1_preparation_QA"] for f in review["findings"])
assert len({f["id"] for f in review["findings"]}) == 2
assert review["material_candidate_discrepancies"] == 0
comparison = json.loads((HERE / "cell_comparison.json").read_text())
assert comparison["rows"] == 51 and comparison["differences"] == 0
qa = json.loads((HERE / "visual_qa.json").read_text())
assert qa["rendered_pdf_pages"] == qa["visually_inspected_pdf_pages"]
assert len(qa["visually_inspected_pdf_pages"]) == 16
for page in qa["visually_inspected_pdf_pages"]:
    assert (HERE / f"visual/page-{page:02}.png").read_bytes().startswith(b"\x89PNG\r\n\x1a\n")
archive = ROOT / "quality_reports/results/mebane_gates/coordination/authors_replication_discovery/archive"
originals = {
    "archive/Bolivia2019.pdf": archive / "Bolivia2019.pdf",
    "archive/eforensics_commit_3017de5.json": archive / "eforensics_commit_3017de5.json",
    "archive/eforensics_DESCRIPTION_3017de5": archive / "UMeforensics-eforensics_public-3017de5/DESCRIPTION",
    "archive/ef_models_3017de5.R": archive / "UMeforensics-eforensics_public-3017de5/R/ef_models.R",
    "archive/ef_summary_3017de5.R": archive / "UMeforensics-eforensics_public-3017de5/R/ef_summary.R",
}
for copy, original in originals.items():
    assert sha(B / copy) == sha(original)
for path in HERE.glob("*.json"):
    json.loads(path.read_text())
for path in HERE.glob("*.md"):
    assert all(line == line.rstrip() for line in path.read_text().splitlines())
files = sorted(p for p in HERE.rglob("*") if p.is_file() and p.name != "review_manifest.json")
result = {
    "schema_version": "1.0-review-seal",
    "review_id": review["review_id"],
    "reviewer_thread_id": review["reviewer"]["thread_id"],
    "candidate_manifest_sha256": sha(B / "candidate_manifest.json"),
    "candidate_files_still_equal": True,
    "archive_provenance_copies_equal": {copy: str(original.relative_to(ROOT)) for copy, original in originals.items()},
    "files_sha256": {str(p.relative_to(HERE)): sha(p) for p in files},
    "scope": "Only review outputs; this seal is not a gate release, data approval, convergence result or G10 pass.",
}
encoded = (json.dumps(result, indent=2, ensure_ascii=False) + "\n").encode()
output = HERE / "review_manifest.json"
if output.exists():
    assert output.read_bytes() == encoded, "Existing seal differs; do not overwrite"
else:
    with output.open("xb") as stream:
        stream.write(encoded)
print(json.dumps({"status": "PASS", "review_files_bound": len(files), "visual_pages": 16,
                  "candidate_files_verified_unchanged": len(candidate["files_sha256"]),
                  "review_manifest_sha256": sha(output)}))
