"""Check old scientific artifacts and explicit snapshots of updated live documents."""
import argparse
import hashlib
import json
from pathlib import Path


def sha(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for part in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(part)
    return digest.hexdigest()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    root = Path("quality_reports/results/mebane_gates/coordination")
    old = root / "2026-09-30_ad_study/final_manifest.json"
    new = root / "2026-10-01_ad_long_stan"
    before_path = new / "before_live_docs/manifest.json"
    before = json.loads(before_path.read_text())
    live_docs = {item["path"]: item for item in before["files"]}
    failures, relocated = [], []
    records = json.loads(old.read_text())["files"]
    for item in records:
        path = Path(item["path"])
        if path.is_file() and sha(path) == item["sha256"]:
            continue
        if item["path"] in live_docs:
            preserved = live_docs[item["path"]]
            snapshot = Path(preserved["snapshot"])
            if sha(snapshot) == item["sha256"] == preserved["sha256"]:
                relocated.append({"live_path": str(path), "historical_snapshot": str(snapshot),
                                  "historical_sha256": item["sha256"],
                                  "current_live_sha256": sha(path) if path.is_file() else None})
                continue
        failures.append(item["path"])
    record = {"status": "pass" if not failures else "fail", "old_manifest_sha256": sha(old),
              "before_live_docs_manifest_sha256": sha(before_path),
              "old_entries_checked": len(records), "failures": failures,
              "live_document_handover": relocated,
              "scope": "Old scientific code and outputs unchanged; only the four declared live docs may be updated, with their exact historical bytes preserved separately"}
    with args.output.open("x", encoding="utf-8") as stream:
        json.dump(record, stream, ensure_ascii=False, indent=2)
        stream.write("\n")
    print(json.dumps(record, ensure_ascii=False))
    raise SystemExit(1 if failures else 0)
