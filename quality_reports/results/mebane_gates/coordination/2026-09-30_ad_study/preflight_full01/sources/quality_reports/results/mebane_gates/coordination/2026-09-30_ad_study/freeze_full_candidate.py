"""Bind common execution code and the completed D candidate for preflight QA."""

import argparse
import hashlib
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("label")
    args = parser.parse_args()
    assert "/" not in args.label and args.label not in ("", ".", "..")
    target = HERE / args.label
    assert not target.exists()
    common_path = HERE / "preflight_common01/candidate_manifest.json"
    d_path = HERE / "implementation_d/attempt-20261001T001549Z-01a0f4b5/manifest.json"
    d_sources_path = ROOT / read(d_path)["source_snapshot_manifest"]["path"]
    assert sha(d_sources_path) == read(d_path)["source_snapshot_manifest"]["sha256"]
    files = set()
    for manifest_path in (common_path, d_sources_path):
        for record in read(manifest_path)["files"]:
            assert sha(ROOT / record["path"]) == record["sha256"], record["path"]
            assert sha(ROOT / record["snapshot"]) == record["sha256"], record["snapshot"]
            files.update([record["path"], record["snapshot"]])
    files.update(str(x.relative_to(ROOT)) for x in
                 [common_path, d_path, d_sources_path, d_path.parent / "test.log", Path(__file__)])
    for directory in (HERE / "runner_checks02", HERE / "supervisor_checks01"):
        files.update(str(x.relative_to(ROOT)) for x in directory.rglob("*") if x.is_file())
    target.mkdir()
    records = []
    for relative in sorted(files):
        source = ROOT / relative
        snapshot = target / "sources" / relative
        snapshot.parent.mkdir(parents=True, exist_ok=True)
        assert not snapshot.exists()
        shutil.copyfile(source, snapshot)
        assert sha(source) == sha(snapshot)
        records.append({"path": relative, "sha256": sha(source),
                        "bytes": source.stat().st_size,
                        "snapshot": str(snapshot.relative_to(ROOT))})
    result = {"candidate": args.label, "created_utc": datetime.now(timezone.utc).isoformat(),
              "contract_sha256": sha(HERE / "contract_v2.json"),
              "executor_ids": ["019d795a-acfa-72c2-a210-d55a46c606c2",
                               "01a0f4b5-4434-7b83-91b9-69ced11b40ba"],
              "D_implementation_included": True, "MCMC_empirical": False,
              "files": records, "scope": "Complete preflight candidate; no approval inferred"}
    path = target / "candidate_manifest.json"
    with path.open("x", encoding="utf-8") as stream:
        json.dump(result, stream, ensure_ascii=False, indent=2)
        stream.write("\n")
    print(json.dumps({"path": str(path.relative_to(ROOT)), "sha256": sha(path),
                      "files": len(records)}))


if __name__ == "__main__":
    main()
