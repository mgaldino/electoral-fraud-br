"""Preserve round1 bytes before any mutable G7 source is edited."""
import datetime as dt
import hashlib
import json
import shutil
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[5]
OUT = Path(__file__).resolve().parent
OLD = OUT.parent / "round1"

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def dump(name, value):
    (OUT / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

start = time.monotonic()
assert not (OUT / "recovery_map.json").exists(), "Preservation already exists"
assert sha(OLD / "adjudication.json") == "882d1b4081df7d4443983e5b5709942076030b34f0edf1f18b68d45a6edc122a"
assert sha(OLD / "candidate_manifest.json") == "62f7a5c4907c9d39b75fe5cd88224bddb4796e015f69f004469e51df7ae493c8"
candidate = json.loads((OLD / "candidate_manifest.json").read_text())
qa = json.loads((OLD / "review/review_manifest.json").read_text())
for manifest in (candidate, qa):
    for item in manifest["files"]:
        path = ROOT / item["path"]
        assert sha(path) == item["sha256"], item["path"]
        assert path.stat().st_size == item["bytes"], item["path"]
candidate_paths = {item["path"] for item in candidate["files"]}
qa_paths = {item["path"] for item in qa["files"]}
old_paths = {str(path.relative_to(ROOT)) for path in OLD.rglob("*") if path.is_file()}
paths = sorted(candidate_paths | qa_paths | old_paths)
entries = []
for relative in paths:
    source = ROOT / relative
    destination = OUT / "previous_sources" / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    assert not destination.exists(), relative
    shutil.copyfile(source, destination)
    digest = sha(source)
    assert sha(destination) == digest, relative
    entries.append({"original_path": relative, "snapshot_path": str(destination.relative_to(ROOT)),
                    "sha256": digest, "bytes": source.stat().st_size,
                    "candidate_member": relative in candidate_paths,
                    "qa_member": relative in qa_paths, "round1_member": relative in old_paths,
                    "mutable_in_round2": relative == "R/lib/mebane_2026_intake.R" or
                    relative.startswith(("config/mebane/2026/", "tests/mebane/2026/"))})
dump("recovery_map.json", {"preserved_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
                          "method": "byte copies before source/fixture edits; restore by snapshot_path",
                          "files": entries})
dump("previous_round1_inventory.json", {"files": [entry for entry in entries if entry["round1_member"]]})
for name in ("gate_contract.json", "ledger_dag_snapshot.json"):
    shutil.copyfile(OLD / name, OUT / name)
dump("preparation_log.json", {"command": "python3 quality_reports/results/mebane_gates/G7/round2/prepare_round.py",
                              "exit_code": 0, "wall_seconds": time.monotonic() - start,
                              "candidate_files": len(candidate_paths), "qa_files": len(qa_paths),
                              "round1_files": len(old_paths), "preserved_files": len(entries)})
print(f"Preserved {len(entries)} files; candidate={len(candidate_paths)}, QA={len(qa_paths)}")
