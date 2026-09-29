"""Read-only source checks and synthetic gate counterexamples for this review."""

import hashlib
import importlib.util
import json
import os
import tarfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[5]
DISCOVERY = ROOT / "quality_reports/results/mebane_gates/coordination/authors_replication_discovery"
HERE = Path(__file__).resolve().parent
REVIEWER_ID = "01a0ed3f-7e0a-7dc2-be9c-6831e6924991"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_fixture():
    path = ROOT / "tests/test_mebane_gates.py"
    spec = importlib.util.spec_from_file_location("independent_gate_fixture", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def gate_counterexamples():
    module = load_fixture()
    cases = {}

    fixture = module.GateTests()
    fixture.setUp()
    try:
        fixture.gate("G10")["status"] = "running"
        errors = module.GATES.validate(fixture.plan, fixture.root)
        cases["g10_running_without_g3"] = any("G10: prerequisite G3 has not passed" in e for e in errors)
    finally:
        fixture.doCleanups()

    fixture = module.GateTests()
    fixture.setUp()
    try:
        for key in ("G0", "G1", "G2", "G3"):
            fixture.approval(key)
        fixture.gate("G4")["status"] = "running"
        errors = module.GATES.validate(fixture.plan, fixture.root)
        cases["g4_running_without_g10"] = any("G4: prerequisite G10 has not passed" in e for e in errors)
        fixture.gate("G10")["status"] = "under_review"
        errors = module.GATES.validate(fixture.plan, fixture.root)
        cases["g4_running_with_unreviewed_g10"] = any("G4: prerequisite G10 has not passed" in e for e in errors)

        fixture.gate("G4")["status"] = "queued"
        fixture.approval("G10")
        # Synthetic approval records contain no T2/T3 timestamps. This probes
        # the checker's scope, not the legitimacy of a real G10 approval.
        errors = module.GATES.validate(fixture.plan, fixture.root)
        cases["synthetic_pass_without_t2_t3_timestamps_accepted"] = errors == []
    finally:
        fixture.doCleanups()
    return cases


def verify_sources():
    manifest = json.loads((DISCOVERY / "source_manifest.json").read_text())
    checked = []
    for record in manifest["sources"] + manifest["pertinent_extracted_members"]:
        path = DISCOVERY / record["path"]
        checked.append({
            "path": record["path"],
            "bytes_match": path.stat().st_size == record["bytes"],
            "sha256_match": digest(path) == record["sha256"],
        })

    source = next(r for r in manifest["sources"] if r["id"] == "authors_github_commit")
    with tarfile.open(DISCOVERY / source["path"], "r:gz") as archive:
        members = [m for m in archive.getmembers() if m.isfile()]
        extracted_match = all(
            (DISCOVERY / "archive" / m.name).is_file()
            and hashlib.sha256(archive.extractfile(m).read()).hexdigest()
            == digest(DISCOVERY / "archive" / m.name)
            for m in members
        )
    return checked, len(members), extracted_match


def write_manifest():
    paths = [
        "quality_reports/results/mebane_gates/coordination/2026-09-29_benchmark_round/authorization.md",
        "quality_reports/plans/mebane_2022_2026_gates.json",
        "quality_reports/plans/mebane_gate_agent_prompts.md",
        "scripts/mebane_gates.py",
        "tests/test_mebane_gates.py",
        "tests/test_mebane_author_replication_gate.py",
        "R/05_eforensics_umeforensics_qbl.R",
        "R/07_brasil_full_qbl.R",
        "R/05_eforensics_qbl_fresh_diagnostic.R",
        "R/05_jags_qbl_zone_fe.R",
    ]
    paths += [
        str(p.relative_to(ROOT))
        for p in sorted(DISCOVERY.glob("*.md"))
        + sorted(DISCOVERY.glob("*.csv"))
        + sorted(DISCOVERY.glob("*.json"))
    ]
    source_manifest = json.loads((DISCOVERY / "source_manifest.json").read_text())
    paths += [str((DISCOVERY / r["path"]).relative_to(ROOT)) for r in source_manifest["sources"]]
    paths += [str((DISCOVERY / r["path"]).relative_to(ROOT)) for r in source_manifest["pertinent_extracted_members"]]
    paths += [
        str((DISCOVERY / "archive/UMeforensics-eforensics_public-3017de5/R/ef_summary.R").relative_to(ROOT)),
        str((DISCOVERY / "archive/UMeforensics-eforensics_public-3017de5/man/eforensics.Rd").relative_to(ROOT)),
    ]
    inputs = [{"path": p, "bytes": (ROOT / p).stat().st_size, "sha256": digest(ROOT / p)} for p in dict.fromkeys(paths)]
    outputs = [{"path": p.name, "bytes": p.stat().st_size, "sha256": digest(p)} for p in
               (HERE / "review.md", HERE / "review.json", HERE / "review_checks.py", HERE / "review_checks_results.json")]
    result = {"reviewer_id": REVIEWER_ID, "hash_algorithm": "SHA-256", "root": str(ROOT),
              "inputs": inputs, "review_artifacts": outputs, "note": "Manifest excludes itself; hashes bind exact archived bytes inspected, not remote persistence."}
    (HERE / "review_manifest.json").write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    os.environ["PYTHONDONTWRITEBYTECODE"] = "1"
    checks, n_members, extracted_match = verify_sources()
    gates = gate_counterexamples()
    result = {"reviewer_id": REVIEWER_ID, "source_records_checked": len(checks),
              "all_sizes_match": all(c["bytes_match"] for c in checks),
              "all_hashes_match": all(c["sha256_match"] for c in checks),
              "tar_file_members": n_members, "all_extracted_files_match_tar": extracted_match,
              "gate_counterexamples": gates,
              "scope": "No inference, package installation, or changes to source or ledger."}
    (HERE / "review_checks_results.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))
    if not all((result["all_sizes_match"], result["all_hashes_match"], extracted_match, *gates.values())):
        raise SystemExit(1)
    if (HERE / "review.md").exists() and (HERE / "review.json").exists():
        write_manifest()
