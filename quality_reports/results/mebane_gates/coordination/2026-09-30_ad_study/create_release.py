"""Bind a completed independent delta review to one bounded empirical release."""
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream,"sha256").hexdigest()
def read(path):
    return json.loads(path.read_text())
def write(path,value):
    with path.open("x") as stream:
        json.dump(value,stream,indent=2);stream.write("\n")
def relative(path):
    return str(path.relative_to(ROOT))

candidate_path=HERE/"preflight_full02/candidate_manifest.json"
review_path=HERE/"review_preflight_delta/review.json"
contract_path=HERE/"contract_v2.json"
candidate=read(candidate_path);review=read(review_path)
assert review["status"].lower()=="pass", "Independent approval absent"
assert review["candidate_manifest_sha256"]==sha(candidate_path)
assert review["contract_sha256"]==sha(contract_path)
assert not review.get("blocking_findings",[])
for item in candidate["files"]:
    assert sha(ROOT/item["path"])==item["sha256"],item["path"]
    assert sha(ROOT/item["snapshot"])==item["sha256"],item["snapshot"]
adjudication=dict(schema_version="1.0",adjudication_id="AD-DC2010:preflight-full02",
    source=dict(reviewed_artifact=relative(candidate_path),sha256=sha(candidate_path),artifact_intact=True),
    contract=dict(required=False,path=None,sha256=None,contract_id=None,artifact_sha256=None,status=None,stale=False),
    review_sources=[dict(review_id="AD-PREFLIGHT-DELTA",path=relative(review_path),sha256=sha(review_path))],
    findings=[],summary=dict(total=0,confirmed=0,partial=0,refuted=0,unresolved=0,held_decisions=0),
    adjudication=dict(verdict="NO_CONFIRMED_DEFECTS",checked_at=datetime.now(timezone.utc).isoformat(),
      reasons=["Prior findings remain historically confirmed; independently checked repairs address them.",
               "The coordinator checked exact candidate/review hashes and scoped evidence. Only the already authorized bounded pilot is released; no model or production approval."]))
adjudication_path=HERE/"preflight_adjudication_v2.json"
write(adjudication_path,adjudication)
files=[dict(path=item["path"],sha256=item["sha256"]) for item in candidate["files"]]
for path in (candidate_path,review_path,adjudication_path,Path(__file__)):
    files.append(dict(path=relative(path),sha256=sha(path)))
release=dict(status="approved_for_bounded_experiment",created_utc=datetime.now(timezone.utc).isoformat(),
    scope="One attempt per model, A then D, DC2010, contract v2. Not G10 or national production.",
    contract_path=relative(contract_path),contract_sha256=sha(contract_path),
    data_path=relative(HERE/"data/run-20260930T235038Z-pid61600/dc2010_ad_data.rds"),
    candidate_manifest_sha256=sha(candidate_path),review_sha256=sha(review_path),
    coordinator_id="019d795a-acfa-72c2-a210-d55a46c606c2",
    reviewer_id="01a0f4b8-962b-77a3-a418-6247c6219e8b",files=files,
    production_approved=False,G10_approved=False)
write(HERE/"release_v1.json",release)
print(json.dumps(dict(release=relative(HERE/"release_v1.json"),sha256=sha(HERE/"release_v1.json"))))
