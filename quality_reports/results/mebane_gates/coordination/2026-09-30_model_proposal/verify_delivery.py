"""Verify the bounded delivery, preserve final docs, and seal new artifacts."""

import argparse
import hashlib
import importlib.util
import json
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def verify_entries(manifest, base):
    entries = read(manifest)["files"]
    for entry in entries:
        path = base / entry["path"]
        assert path.is_file(), path
        assert path.stat().st_size == entry["bytes"], path
        assert sha(path) == entry["sha256"], path
    return len(entries)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--proposal", type=Path, required=True)
    parser.add_argument("--pdf", type=Path, required=True)
    parser.add_argument("--review", type=Path, required=True)
    args = parser.parse_args()
    assert not (HERE / "delivery_manifest.json").exists()
    before = read(HERE / "before/quality_reports/plans/mebane_2022_2026_gates.json")
    after = read(ROOT / "quality_reports/plans/mebane_2022_2026_gates.json")
    spec = importlib.util.spec_from_file_location("gate_checker", ROOT / "scripts/mebane_gates.py")
    checker = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(checker)
    old_gates = {g["id"]: g for g in before["gates"]}
    new_gates = {g["id"]: g for g in after["gates"]}
    assert old_gates.keys() == new_gates.keys()
    for gate_id in old_gates:
        assert checker.contract_sha256(old_gates[gate_id]) == checker.contract_sha256(new_gates[gate_id]), gate_id
        if gate_id != "G3":
            assert old_gates[gate_id] == new_gates[gate_id], gate_id
    assert new_gates["G3"]["status"] == "inconclusive"
    records = new_gates["G3"]["records"]
    candidate = ROOT / records["candidate_manifest"]
    prior_review = ROOT / records["review"]
    adjudication = read(ROOT / records["adjudication"])
    assert sha(candidate) == adjudication["candidate_manifest_sha256"]
    assert sha(prior_review) == adjudication["review_sha256"]
    assert adjudication["status"] == "inconclusive"
    parent_entries = verify_entries(candidate, ROOT)
    supplement = HERE / "provenance_repair/closure_manifest.json"
    supplement_entries = verify_entries(supplement, supplement.parent)
    assert sha(supplement) == "b6b56b80a7b40863d34f5f48b1de6641c1c54572121d949e9e6052ec46723965"
    assert read(HERE / "checks03/result.json")["estimation_performed"] is False
    assert args.review.is_file() and args.proposal.is_file() and args.pdf.is_file()
    independent = read(args.review)
    assert independent["status"] == "complete"
    assert independent["proposal_sha256"] == sha(args.proposal)
    assert independent["provenance_manifest_sha256"] == sha(supplement)
    assert independent["material_findings"] == []
    assert independent["G3_status"] == "inconclusive"
    assert independent["inference_or_production_approved"] is False
    review_manifest = args.review.parent / "review_manifest.json"
    assert sha(review_manifest) == "9cf5b1b5b1aba14458b51b0b83dd5a50c3328188f3b169f3ec60ed698eb9f6d7"
    review_entries = verify_entries(review_manifest, ROOT)
    pdf_manifest = read(args.pdf.with_suffix(".manifest.json"))
    assert sha(args.proposal) == pdf_manifest["source_sha256"]
    assert sha(args.pdf) == pdf_manifest["output_sha256"]
    old_inputs = read(HERE / "input_audit.json")
    for entry in old_inputs["before_snapshots"]:
        assert sha(ROOT / entry["snapshot"]) == entry["sha256"]
    snapshots = []
    for relative in ["README.md", "CLAUDE.md", "quality_reports/plans/mebane_2022_2026_gates.json",
                     "quality_reports/plans/2026-09-28_mebane_2022_2026_gates.md",
                     "quality_reports/results/mebane_gates/G3/round1/adjudication.json",
                     "quality_reports/results/mebane_gates/G3/round1/adjudication.md"]:
        target = HERE / "final_state" / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        with target.open("xb") as stream:
            stream.write((ROOT / relative).read_bytes())
        snapshots.append({"path": str(target.relative_to(ROOT)), "sha256": sha(target)})
    run = subprocess.run([sys.executable, "-B", "scripts/mebane_gates.py", "check"],
                         cwd=ROOT, capture_output=True, text=True, check=True)
    audit = {"status": "verified_bounded_delivery", "parent_entries": parent_entries,
             "supplement_entries": supplement_entries, "review_entries": review_entries,
             "all_gate_contracts_unchanged": True,
             "other_gates_unchanged": True, "G3_status": "inconclusive",
             "proposal_sha256": sha(args.proposal), "pdf_sha256": sha(args.pdf),
             "independent_review_sha256": sha(args.review), "final_state": snapshots,
             "checker_stdout": run.stdout, "checker_stderr": run.stderr,
             "scope": "Artifact identity and stated changes; not production or inferential approval."}
    with (HERE / "delivery_check.json").open("x") as stream:
        json.dump(audit, stream, indent=2, ensure_ascii=False)
        stream.write("\n")
    entries = []
    for path in sorted(HERE.rglob("*")):
        if path.is_file():
            entries.append({"path": str(path.relative_to(ROOT)), "bytes": path.stat().st_size,
                            "sha256": sha(path)})
    manifest = {"scope": "Documentary closure supplement and methodological proposal, no new estimation.",
                "files": entries, "excluded": ["delivery_manifest.json itself"],
                "parent_candidate_manifest": str(candidate.relative_to(ROOT)),
                "parent_candidate_sha256": sha(candidate)}
    with (HERE / "delivery_manifest.json").open("x") as stream:
        json.dump(manifest, stream, indent=2, ensure_ascii=False)
        stream.write("\n")
    print(json.dumps({"status": audit["status"], "files": len(entries),
                      "manifest_sha256": sha(HERE / "delivery_manifest.json")}))


if __name__ == "__main__":
    main()
