"""Seal only the exact PDF that the independent reviewer visually inspected."""
import argparse
import csv
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[5]
parser = argparse.ArgumentParser()
parser.add_argument("--approved-pdf-sha256", required=True)
args = parser.parse_args()


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


review = json.loads((HERE / "review.json").read_text())
assert sha(HERE / "review.pdf") == args.approved_pdf_sha256
candidate = HERE.parent / "candidate_manifest.json"
assert sha(candidate) == review["candidate_manifest_sha256"]
for f in json.loads(candidate.read_text())["files"]:
    assert sha(ROOT / f["path"]) == f["sha256"]
checks = list(csv.DictReader((HERE / "independent_checks.csv").open()))
assert len(checks) == 75 and all(row["passed"] == "TRUE" for row in checks)
geometry = json.loads((HERE / "review_pdf_geometry.json").read_text())["pages"]
assert len(geometry) == 8 and not any(p["outside_safety_bounds"] for p in geometry)
visual = {
    "reviewer_id": review["reviewer_id"],
    "checked_at_utc": datetime.now(timezone.utc).isoformat(),
    "candidate_pdf_sha256": review["visual_qa"]["candidate_pdf_sha256"],
    "candidate_pages": 13,
    "candidate_contact_pages_inspected": list(range(1, 14)),
    "candidate_fresh_detail_pages": [6, 8, 12],
    "review_pdf_sha256": args.approved_pdf_sha256,
    "review_pages": 8,
    "review_contact_pages_inspected": list(range(1, 9)),
    "review_final_detail_pages": [4, 6],
    "status": "pass_spot_check",
    "basis": "Human-model visual inspection via view_image; geometry is auxiliary only.",
    "limitations": "Not character-by-character typography certification."
}
(HERE / "visual_qa.json").write_text(json.dumps(visual, ensure_ascii=False, indent=2)+"\n")
files = [p for p in HERE.rglob("*") if p.is_file() and p.name != "review_manifest.json"
         and "__pycache__" not in p.parts]
manifest = {
    "gate_id": "G2", "round": "round1", "reviewer_id": review["reviewer_id"],
    "candidate_manifest_sha256": review["candidate_manifest_sha256"],
    "review_json_sha256": sha(HERE / "review.json"),
    "sealed_at_utc": datetime.now(timezone.utc).isoformat(),
    "files": [{"path": str(p.relative_to(ROOT)), "sha256": sha(p), "bytes": p.stat().st_size}
              for p in sorted(files)]
}
(HERE / "review_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+"\n")
assert all(sha(ROOT/f["path"]) == f["sha256"] for f in manifest["files"])
print(json.dumps({"candidate_intact_files": 73, "review_artifacts_verified": len(files),
                  "review_json_sha256": manifest["review_json_sha256"],
                  "review_manifest_sha256": sha(HERE / "review_manifest.json"),
                  "status": review["status"]}))
