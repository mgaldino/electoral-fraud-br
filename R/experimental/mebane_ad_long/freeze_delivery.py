"""Freeze explicitly named files/directories without changing their contents."""
import argparse
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path


def sha(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    parser.add_argument("inputs", nargs="+", type=Path)
    args = parser.parse_args()
    if args.output.exists():
        raise FileExistsError("Preserve earlier freezes: " + str(args.output))
    paths = set()
    for source in args.inputs:
        if not source.exists():
            raise FileNotFoundError(source)
        if source.is_dir():
            paths.update(p for p in source.rglob("*") if p.is_file())
        else:
            paths.add(source)
    records = [{"path": str(p), "bytes": p.stat().st_size, "sha256": sha(p)}
               for p in sorted(paths, key=str)]
    result = {
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "scope": [str(p) for p in args.inputs],
        "meaning": "Byte integrity of these explicit inputs, not statistical approval or an audit of every historical artifact",
        "files": records,
        "file_count": len(records),
        "bytes_total": sum(item["bytes"] for item in records),
    }
    with args.output.open("x", encoding="utf-8") as stream:
        json.dump(result, stream, ensure_ascii=False, indent=2)
        stream.write("\n")
    print(json.dumps({"manifest": str(args.output), "sha256": sha(args.output),
                      "file_count": len(records), "bytes_total": result["bytes_total"]}))


if __name__ == "__main__":
    main()
