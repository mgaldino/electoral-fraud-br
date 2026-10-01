"""Freeze the bounded preflight instrumentation repair; preserve full01."""
import hashlib
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
def sha(p):
    with p.open("rb") as stream:
        return hashlib.file_digest(stream,"sha256").hexdigest()
target = HERE / "preflight_full02"
assert not target.exists()
old = HERE / "preflight_full01/candidate_manifest.json"
records = json.loads(old.read_text())["files"]
changed = {"R/experimental/mebane_ad/run_jags.R", "R/experimental/mebane_ad/diagnostics.R",
           "R/experimental/mebane_ad/run_pair.py", "tests/mebane/ad_study/test_supervisor.py"}
paths = set()
for item in records:
    assert sha(ROOT/item["snapshot"]) == item["sha256"]
    if item["path"] not in changed:
        assert sha(ROOT/item["path"]) == item["sha256"],item["path"]
    paths.add(item["path"])
paths.update(["R/experimental/mebane_ad/timing.md", "tests/mebane/ad_study/test_timing.R"])
paths.update(str(p.relative_to(ROOT)) for p in [old,Path(__file__),HERE/"preflight_adjudication_v1.json",
             HERE/"review_preflight/review.json",HERE/"review_preflight/delivery_manifest.json"] if p.exists())
for directory in ("runner_checks03","timing_checks01","supervisor_checks02"):
    paths.update(str(p.relative_to(ROOT)) for p in (HERE/directory).rglob("*") if p.is_file())
target.mkdir()
files=[]
for path in sorted(paths):
    src=ROOT/path; dest=target/"sources"/path
    dest.parent.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(src,dest)
    assert sha(src)==sha(dest)
    files.append(dict(path=path,sha256=sha(src),bytes=src.stat().st_size,snapshot=str(dest.relative_to(ROOT))))
result=dict(candidate="preflight_full02",created_utc=datetime.now(timezone.utc).isoformat(),
            previous_candidate_sha256=sha(old),contract_sha256=sha(HERE/"contract_v2.json"),
            changed_existing_paths=sorted(changed),files=files,MCMC_empirical=False,
            scope="Bounded timing and timeout repair; requires independent delta review")
with (target/"candidate_manifest.json").open("x") as stream:
    json.dump(result,stream,indent=2);stream.write("\n")
print(json.dumps(dict(path=str(target.relative_to(ROOT)),sha256=sha(target/"candidate_manifest.json"),files=len(files))))
