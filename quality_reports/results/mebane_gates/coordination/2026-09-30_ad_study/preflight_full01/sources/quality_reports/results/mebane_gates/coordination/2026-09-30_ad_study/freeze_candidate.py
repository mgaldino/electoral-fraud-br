"""Freeze a named preflight candidate without overwriting any earlier snapshot."""

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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("label")
    parser.add_argument("--include-d", action="store_true")
    args = parser.parse_args()
    assert "/" not in args.label and args.label not in ("", ".", "..")
    target = HERE / args.label
    assert not target.exists()
    target.mkdir()
    relative_base = HERE.relative_to(ROOT)
    files = ["R/experimental/mebane_ad/io.R", "R/experimental/mebane_ad/run_jags.R",
             "R/experimental/mebane_ad/diagnostics.R", "R/experimental/mebane_ad/prepare_dc2010.R",
             "R/experimental/mebane_ad/run_pair.py", "tests/mebane/ad_study/test_runner.R",
             "tests/mebane/ad_study/test_supervisor.py", "tests/mebane/ad_study/test_dc2010.R",
             "quality_reports/results/mebane_gates/G0/round1/qbl_installed_3017de5.jags",
             "quality_reports/results/mebane_gates/G2/round2/benchmark_contract.json",
             str(relative_base / "contract_v2.json"),
             str(relative_base / "contract_adjudication_v2.json"),
             str(relative_base / "review_contract/review_v2.json"),
             str(relative_base / "data/run-20260930T235038Z-pid61600/dc2010_ad_data.rds"),
             str(relative_base / "data/run-20260930T235038Z-pid61600/dc2010_common.csv"),
             str(relative_base / "data/run-20260930T235038Z-pid61600/manifest.json"),
             str(relative_base / "runner_checks02/result.json"),
             str(relative_base / "supervisor_checks01/result.json"),
             str(Path(__file__).relative_to(ROOT))]
    if args.include_d:
        files += ["models/experimental/mebane_ad/d_multinomial.jags",
                  "R/experimental/mebane_ad/model_d.R", "tests/mebane/ad_study/test_model_d.R"]
    records = []
    for relative in files:
        source = ROOT / relative
        assert source.is_file(), relative
        snapshot = target / "sources" / relative
        snapshot.parent.mkdir(parents=True, exist_ok=True)
        assert not snapshot.exists()
        shutil.copyfile(source, snapshot)
        assert sha(source) == sha(snapshot)
        records.append({"path": relative, "sha256": sha(source),
                        "bytes": source.stat().st_size,
                        "snapshot": str(snapshot.relative_to(ROOT))})
    manifest = {"candidate": args.label, "created_utc": datetime.now(timezone.utc).isoformat(),
                "contract_sha256": sha(HERE / "contract_v2.json"),
                "D_implementation_included": args.include_d,
                "scope": "preflight code candidate, not approval or empirical results",
                "files": records}
    path = target / "candidate_manifest.json"
    with path.open("x", encoding="utf-8") as stream:
        json.dump(manifest, stream, ensure_ascii=False, indent=2)
        stream.write("\n")
    print(json.dumps({"path": str(path.relative_to(ROOT)), "sha256": sha(path),
                      "files": len(records), "includes_D": args.include_d}))


if __name__ == "__main__":
    main()
