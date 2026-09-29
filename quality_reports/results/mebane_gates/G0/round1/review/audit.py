"""Read-only independent G0 inventory and lock audit."""

import hashlib
import json
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[6]
ROUND = ROOT / "quality_reports/results/mebane_gates/G0/round1"


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


manifest = load(ROUND / "candidate_manifest.json")
run = load(ROUND / "run.json")
contract = load(ROUND / "gate_contract.json")
canonical = json.dumps(contract, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
assert hashlib.sha256(canonical.encode()).hexdigest() == run["contract_sha256"]
assert sha256(ROUND / "candidate_manifest.json") == "61649af333a6d2ef6bea20e4ed5e38671bb6d6d5f2b867fbe1d9acdc195169ab"
assert run["executor_id"] == "01a0eaba-2cec-74f3-bca0-8c27b736567e"

declared = set(run["inputs"] + run["code"] + run["configuration"] + run["outputs"] +
               ["quality_reports/results/mebane_gates/G0/round1/run.json"])
entries = manifest["files"]
paths = {item["path"] for item in entries}
bad = []
for item in entries:
    path = ROOT / item["path"]
    if not path.is_file():
        bad.append([item["path"], "missing"])
    elif path.stat().st_size != item["bytes"] or sha256(path) != item["sha256"]:
        bad.append([item["path"], "size_or_sha_mismatch"])

snapshot_bad = []
for item in run["baseline_snapshots"]:
    path = ROOT / item["snapshot"]
    if not path.is_file() or sha256(path) != item["sha256"] or path.stat().st_size != item["bytes"]:
        snapshot_bad.append(item["snapshot"])

before = load(ROUND / "renv_before.lock")
after = load(ROUND / "final_state/renv.lock")
added = set(after["Packages"]) - set(before["Packages"])
removed = set(before["Packages"]) - set(after["Packages"])
changed = [name for name in before["Packages"] if name in after["Packages"] and
           before["Packages"][name] != after["Packages"][name]]
reconciliation = load(ROUND / "lock_reconciliation.json")

expected_material = [
    "research_note.md",
    "output/tables/tab_beber_scacco_last_digit.csv",
    "output/tables/tab_benford_2bl.csv",
    "output/tables/tab_kobak_integer_pct.csv",
    "output/tables/tab_spikes_rozenas.csv",
]

archive = ROOT / "replication_authors/original_zip/fingerprint_brazil.zip"
zip_matches = []
with zipfile.ZipFile(archive) as bundle:
    for name in bundle.namelist():
        if not name.startswith("fingerprint_brazil/raw-data/") or name.endswith("/"):
            continue
        digest = hashlib.sha256()
        with bundle.open(name) as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(chunk)
        extracted = ROOT / "replication_authors/extracted" / name
        zip_matches.append({"member": name, "match": extracted.is_file() and
                            digest.hexdigest() == sha256(extracted)})

result = {
    "manifest_files": len(entries),
    "declared_not_manifested": sorted(declared - paths),
    "manifested_not_declared": sorted(paths - declared),
    "manifest_bad": bad,
    "snapshot_count": len(run["baseline_snapshots"]),
    "snapshot_bad": snapshot_bad,
    "before_package_count": len(before["Packages"]),
    "after_package_count": len(after["Packages"]),
    "added_count": len(added),
    "added_matches_report": added == set(reconciliation["missing"]),
    "removed": sorted(removed),
    "changed": changed,
    "lock_r_same": before["R"] == after["R"],
    "material_omissions": [p for p in expected_material if (ROOT / p).is_file() and p not in paths],
    "zip_matches": zip_matches,
}
print(json.dumps(result, indent=2, ensure_ascii=False))
