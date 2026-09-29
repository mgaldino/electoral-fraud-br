"""Check exact candidate and independent QA bytes before the G1 decision."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[5]
HERE = Path(__file__).resolve().parent


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


expected = {
    "candidate_manifest.json": "517c17c724cca82a820519c476981d47c8892c7383dd2c3dded9373eba6d31e8",
    "review/review.json": "727f6b234e3a580c329cc5e898018bb68c02063717c292b6d91e4fbe12d86941",
    "review/qa_manifest.json": "694664f05d53c7d2bf839d19e074beb0736ee72d3be268c3cf091134e2eb5b0f",
}
for relative, checksum in expected.items():
    assert sha(HERE / relative) == checksum, relative
verified = {}
for name in ("candidate_manifest.json", "review/qa_manifest.json"):
    manifest = json.loads((HERE / name).read_text())
    groups = {key: manifest[key] for key in ("inputs", "files") if key in manifest}
    for entries in groups.values():
        for entry in entries:
            path = ROOT / entry["path"]
            assert sha(path) == entry["sha256"] and path.stat().st_size == entry["bytes"], entry["path"]
    verified[name] = {key: len(entries) for key, entries in groups.items()}
review = json.loads((HERE / "review/review.json").read_text())
assert review["status"] == "pass" and review["manifest_complete"] is True
assert not review["findings"]
assert review["executor_id"] != review["reviewer_id"]
assert {item["id"] for item in review["resolved_prior_findings"]} == {
    "G1-R1-QAD-F01", "G1-R1-QAD-F02", "G1-R1-COORD-F03"}
assert all(item["resolved"] for item in review["resolved_prior_findings"])
record = {"exact_identities": expected, "verified_manifests": verified,
          "review_and_prior_closure_consistent": True,
          "scope": "Integrity and review binding; substantive judgment recorded separately"}
(HERE / "adjudication_integrity.json").write_text(json.dumps(record, indent=2) + "\n")
print(json.dumps(record, indent=2))
