"""Freeze the documentary baseline and verify the exact reviewed G3 candidate."""

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[5]
OUT = Path(__file__).resolve().parent
BASE = ROOT / "quality_reports/results/mebane_gates/G3/round1"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    candidate_path = BASE / "revision3/candidate_manifest.json"
    review_path = BASE / "review/review.json"
    candidate = json.loads(candidate_path.read_text())
    review = json.loads(review_path.read_text())
    assert sha(candidate_path) == review["candidate_manifest_sha256"]
    checks = []
    for entry in candidate["files"]:
        path = ROOT / entry["path"]
        checks.append({"path": entry["path"], "ok": path.is_file()
                       and path.stat().st_size == entry["bytes"]
                       and sha(path) == entry["sha256"]})
    assert all(item["ok"] for item in checks)
    historical = json.loads((BASE / "review/input_closure_revision2.json").read_text())
    missing = historical["historical_preservation"]["missing_effective_code_versions"]
    declared_hashes = {entry["sha256"] for entry in candidate["files"]}
    assert len(missing) == 7
    assert all(item["sha256"] not in declared_hashes for item in missing)
    snapshots = []
    for relative in ["README.md", "CLAUDE.md", "quality_reports/plans/mebane_2022_2026_gates.json",
                     "quality_reports/plans/2026-09-28_mebane_2022_2026_gates.md"]:
        original = ROOT / relative
        target = OUT / "before" / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        with target.open("xb") as stream:
            stream.write(original.read_bytes())
        snapshots.append({"original_path": relative, "snapshot": str(target.relative_to(ROOT)),
                          "sha256": sha(target)})
    record = {"candidate": str(candidate_path.relative_to(ROOT)), "candidate_sha256": sha(candidate_path),
              "review": str(review_path.relative_to(ROOT)), "review_sha256": sha(review_path),
              "verified_entries": len(checks), "entry_checks": checks,
              "seven_historical_versions_absent": True, "missing_versions": missing,
              "before_snapshots": snapshots, "scope": "Identity and documentary gap, no new estimation."}
    with (OUT / "input_audit.json").open("x") as stream:
        json.dump(record, stream, indent=2, ensure_ascii=False)
        stream.write("\n")
    print(json.dumps({"verified_entries": len(checks), "missing_versions": len(missing),
                      "candidate_sha256": sha(candidate_path)}))


if __name__ == "__main__":
    main()
