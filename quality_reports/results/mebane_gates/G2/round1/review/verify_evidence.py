"""Independent G2 integrity/provenance checks. Writes only inside review/."""
import hashlib
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[5]
ROUND = HERE.parent
EXPECTED_MANIFEST = "783cfb036f8f26bf894c36782df4fb94e20351e4df015ca6e24330021d04a5a9"
EXPECTED_CONTRACT = "f834bc1d12d88b4bc82fb2ada95120a838451c5809332630a75cd9abf03cf4d1"
REVIEWER = "01a0eb0d-15b5-7c51-8e6f-c5b5b93f6011"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text())


manifest = read(ROUND / "candidate_manifest.json")
contract = read(ROUND / "gate_contract.json")
run = read(ROUND / "run.json")
canonical = hashlib.sha256(json.dumps(contract, sort_keys=True, ensure_ascii=False,
                                     separators=(",", ":")).encode()).hexdigest()
assert sha(ROUND / "candidate_manifest.json") == EXPECTED_MANIFEST
assert canonical == EXPECTED_CONTRACT
listed = {x["path"]: x for x in manifest["files"]}
assert len(listed) == len(manifest["files"])
rows = []
for path, entry in listed.items():
    actual = ROOT / path
    rows.append({"path": path, "sha256": sha(actual), "bytes": actual.stat().st_size,
                 "pass": sha(actual) == entry["sha256"] and actual.stat().st_size == entry["bytes"]})
assert all(x["pass"] for x in rows)
declared = {p for k in ("inputs", "code", "configuration", "outputs") for p in run[k]}
assert not declared - set(listed)
dep = ROOT / "quality_reports/results/mebane_gates/G0/round2"
expected = {"candidate_manifest.json": "f71333db477385fc78dad8a7a1a7ca78e48479226dcdbde80ce97d724409fec7",
            "review/review.json": "ef624cb4b2d8ad098b87e196d87add358ce1eba93165d44fcc1939ff303f5376",
            "adjudication.json": "ea1b4905fdfa14f6e3f36c41974ea948ba0c39d1f81f87d6eaf479782216267b"}
assert all(sha(dep / p) == h for p, h in expected.items())
for p in ("review/review.json", "adjudication.json"):
    record = read(dep / p)
    assert record["status"] == "pass"
    assert record["candidate_manifest_sha256"] == expected["candidate_manifest.json"]
assert read(dep / "adjudication.json")["review_sha256"] == expected["review/review.json"]
assert run["dependency_manifests"]["G0"] == expected["candidate_manifest.json"]
assert run["contract_sha256"] == manifest["contract_sha256"] == canonical
assert run["executor_id"] == manifest["executor_id"] != REVIEWER
copies = read(ROUND / "source_provenance.json")["copies"]
copy_checks = []
for c in copies:
    h = sha(ROOT / c["snapshot"])
    assert h == c["sha256"] == sha(ROOT / c["original"])
    assert c["snapshot"] in listed
    copy_checks.append({"original": c["original"], "frozen_snapshot": c["snapshot"], "sha256": h})
out = {"checked_at_utc": datetime.now(timezone.utc).isoformat(), "reviewer_id": REVIEWER,
       "candidate_manifest_sha256": EXPECTED_MANIFEST, "contract_sha256": canonical,
       "raw_contract_sha256": sha(ROUND / "gate_contract.json"), "files_verified": len(rows),
       "hash_mismatches": [], "declared_paths_missing": sorted(declared - set(listed)),
       "snapshot_aliases_checked": copy_checks, "files": rows,
       "scope": "Structural integrity only; manifest completeness requires the separate code/source read audit."}
(HERE / "integrity.json").write_text(json.dumps(out, ensure_ascii=False, indent=2) + "\n")

# Independent text extraction from the original frozen PDFs, not executor TXT.
pdfs = {
    "candidate": ROUND / "mebane_model_contract.pdf",
    "p22": ROOT / "quality_reports/results/mebane_gates/coordination/measfrauds_2022-03-06.pdf",
    "p23": ROOT / "quality_reports/results/mebane_gates/coordination/pm23_2023-07-02.pdf",
    "jags_manual": ROUND / "sources/jags_user_manual_4.3.0.pdf",
}
for name, path in pdfs.items():
    subprocess.run(["pdftotext", "-layout", str(path), str(HERE / f"{name}.txt")], check=True)
    info = subprocess.run(["pdfinfo", str(path)], capture_output=True, text=True, check=True)
    (HERE / f"{name}_pdfinfo.txt").write_text(info.stdout)
print(json.dumps({"files_verified": len(rows), "manifest": EXPECTED_MANIFEST,
                  "canonical_contract": canonical, "snapshot_aliases_verified": len(copy_checks)}))
