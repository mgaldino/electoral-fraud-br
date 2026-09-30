"""Recheck the exact G3 candidate without rerunning sampling or changing it."""

import argparse
import datetime
import hashlib
import importlib.util
import json
from pathlib import Path


BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[4]
CANDIDATE = ROOT / "quality_reports/results/mebane_gates/G3/round1/revision2"
EXPECTED = "de779221e40964b9729bdd928a814e7e7dfd9738df866b91f6ee97307a14bd0f"


def digest(path):
    out = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            out.update(block)
    return out.hexdigest()


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def main(output):
    manifest_path = CANDIDATE / "candidate_manifest.json"
    assert digest(manifest_path) == EXPECTED
    manifest = read(manifest_path)
    run_path = CANDIDATE / "run.json"
    run = read(run_path)
    included = set()
    total_bytes = 0
    for entry in manifest["files"]:
        path = (ROOT / entry["path"]).resolve()
        assert path.is_relative_to(ROOT) and path not in included and path != manifest_path
        assert path.is_file() and not path.is_symlink()
        assert digest(path) == entry["sha256"], entry["path"]
        assert path.stat().st_size == entry["bytes"], entry["path"]
        included.add(path)
        total_bytes += entry["bytes"]
    assert run_path in included
    for field in ("inputs", "code", "configuration", "outputs"):
        assert all((ROOT / value).resolve() in included for value in run[field]), field
    spec = importlib.util.spec_from_file_location("checker", ROOT / "scripts/mebane_gates.py")
    checker = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(checker)
    ledger = read(ROOT / "quality_reports/plans/mebane_2022_2026_gates.json")
    gates = {gate["id"]: gate for gate in ledger["gates"]}
    contract = checker.contract_sha256(gates["G3"])
    assert all(item["gate_id"] == "G3" and item["round"] == "round1" and
               item["contract_sha256"] == contract for item in (manifest, run))
    assert gates["G2"]["status"] == "pass"
    assert not checker.check_records(gates["G2"], ROOT, gates)
    parent = gates["G2"]["records"]
    assert run["dependency_manifests"] == {"G2": digest(ROOT / parent["candidate_manifest"])}
    assert run["dependency_approvals"] == {"G2": {
        "review_sha256": digest(ROOT / parent["review"]),
        "adjudication_sha256": digest(ROOT / parent["adjudication"])}}
    result = {
        "checked_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "candidate_manifest_sha256": EXPECTED,
        "files_checked": len(included), "bytes_checked": total_bytes,
        "all_hashes_and_sizes_match": True, "all_run_paths_included": True,
        "static_G3_contract_unchanged": True, "G2_approval_current": True,
        "raw_draws_sha256": digest(CANDIDATE / "raw_chains.rds"),
        "scope": "Identity and declared dependencies only; not a scientific PASS or proof of manifest completeness",
        "script_sha256": digest(Path(__file__).resolve())
    }
    with output.open("x", encoding="utf-8") as stream:
        json.dump(result, stream, ensure_ascii=False, indent=2)
        stream.write("\n")
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    main(parser.parse_args().output)
