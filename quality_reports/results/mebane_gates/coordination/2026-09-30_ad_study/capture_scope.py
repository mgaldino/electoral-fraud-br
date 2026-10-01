"""Preserve current coordination docs and verify that historical A stays intact."""

import argparse
import hashlib
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
DOCS = ["README.md", "CLAUDE.md", "quality_reports/plans/mebane_2022_2026_gates.json",
        "quality_reports/plans/2026-09-28_mebane_2022_2026_gates.md"]
HELD = ["appendices/mebane_model_contract.md", "R/lib/mebane_model.R",
        "quality_reports/results/mebane_gates/G0/round1/qbl_installed_3017de5.jags",
        "quality_reports/results/mebane_gates/G2/round2/benchmark_contract.json",
        "quality_reports/results/mebane_gates/G3/round1/adjudication.json",
        "quality_reports/results/mebane_gates/G3/round1/revision3/candidate_manifest.json",
        "quality_reports/results/mebane_gates/coordination/2026-09-30_model_proposal/delivery_manifest.json",
        "quality_reports/results/mebane_gates/coordination/authors_replication_discovery/archive/UMeforensics-eforensics_public-3017de5/data/dc2010.rda"]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_new(path, value):
    with path.open("x", encoding="utf-8") as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write("\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["before", "verify"])
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    baseline = HERE / "scope_before.json"
    if args.mode == "before":
        assert not baseline.exists(), "Baseline already captured"
        records = []
        for name in DOCS + HELD:
            source = ROOT / name
            target = HERE / "before" / name
            target.parent.mkdir(parents=True, exist_ok=True)
            with target.open("xb") as stream:
                stream.write(source.read_bytes())
            records.append({"path": name, "snapshot": str(target.relative_to(ROOT)),
                            "sha256": sha(source), "held_unchanged": name in HELD})
        write_new(baseline, {"created_utc": datetime.now(timezone.utc).isoformat(),
                             "records": records})
        print(f"Preserved {len(records)} sources/documents")
        return
    assert args.output is not None and not args.output.exists()
    records = json.loads(baseline.read_text(encoding="utf-8"))["records"]
    for record in records:
        assert sha(ROOT / record["snapshot"]) == record["sha256"], record
        if record["held_unchanged"]:
            assert sha(ROOT / record["path"]) == record["sha256"], record
    old_plan = json.loads((HERE / "before" / DOCS[2]).read_text(encoding="utf-8"))
    new_plan = json.loads((ROOT / DOCS[2]).read_text(encoding="utf-8"))
    assert old_plan["gates"] == new_plan["gates"], "Historical gate object changed"
    deleted = subprocess.check_output(["git", "ls-files", "--deleted"], cwd=ROOT, text=True)
    assert not deleted.strip(), f"Unexpected missing tracked files: {deleted}"
    record = {"verified_utc": datetime.now(timezone.utc).isoformat(),
              "held_sources_unchanged": len(HELD), "all_gate_objects_unchanged": True,
              "tracked_deletions": [], "baseline_sha256": sha(baseline),
              "script_sha256": sha(Path(__file__))}
    write_new(args.output, record)
    print(json.dumps(record))


if __name__ == "__main__":
    main()
