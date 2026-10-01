"""Seal the finite experimental delivery, without upgrading any scientific gate."""
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[4]
def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream,"sha256").hexdigest()
def read(path):
    return json.loads(path.read_text())
def write(path,value):
    with path.open("x",encoding="utf-8") as stream:
        json.dump(value,stream,ensure_ascii=False,indent=2);stream.write("\n")
def record(path):
    return dict(path=str(path.relative_to(ROOT)),bytes=path.stat().st_size,sha256=sha(path))

assert not (HERE/"completion.json").exists()
assert not (HERE/"final_manifest.json").exists()
state=read(HERE/"study_state.json")
review=read(HERE/"review_results/review.json")
outcome=read(HERE/"comparison01/comparison_result.json")
preservation=read(HERE/"preservation_check04.json")
assert state["status"]=="completed_with_inconclusive_pilot"
assert all(todo["status"]=="done" for todo in state["todos"])
assert review["status"]=="pass" and review["findings"]==[]
assert outcome["status"]==review["pilot_verdict_independently_confirmed"]=="computationally_inconclusive"
assert review["binding"]["comparison_manifest_sha256"]==sha(HERE/"comparison01/manifest.json")
assert review["binding"]["pdf_sha256"]==sha(HERE/"comparison_A_D_DC2010_v1.pdf")
assert preservation["all_gate_objects_unchanged"] and not preservation["tracked_deletions"]
for item in read(HERE/"release_v1.json")["files"]:
    assert sha(ROOT/item["path"])==item["sha256"],item["path"]
for relative in ("pilot01/A/manifest.json","pilot01/D/manifest.json",
                 "pilot01/A_diagnostics/manifest.json","pilot01/D_diagnostics/manifest.json",
                 "comparison01/manifest.json"):
    for item in read(HERE/relative)["files"]:
        assert sha(ROOT/item["path"])==item["sha256"],item["path"]
key_paths=[HERE/p for p in ("study_state.json","decision.md","contract_v2.json",
    "release_v1.json","pilot01/execution.json","comparison01/manifest.json",
    "comparison_A_D_DC2010_v1.pdf","visual_qa_v1.json","review_results/review.json",
    "results_adjudication.json","handoff.md","preservation_check04.json")]
completion=dict(status="experimental_delivery_complete",created_utc=datetime.now(timezone.utc).isoformat(),
    study_id="AD-DC2010",pilot_verdict="computationally_inconclusive",
    independent_review="pass_for_quantitative_documentary_fidelity_only",
    raw_runs_complete=True,attempts_per_model=1,chains_per_model=4,retained_iterations_per_chain=2000,
    models_still_running=False,posterior_precision_approved=False,production_approved=False,
    G3_status="inconclusive",G10_status="queued",Brazil_new_fit=False,
    A_source_unchanged=True,historical_gates_unchanged=True,deletions=False,installs=False,
    next_investigation="Diagnose current chains and plan an exact D/Stan engine comparison before identification validation and Brazilian scaling; not run in this lot",
    native_historical_goal="Unfinished production-engine goal is not completed by this experimental delivery",
    checks=dict(central_raw_targets_independently_recomputed=46,mandatory_decisions_rechecked=3913,
                result_checks=91,report_pdf_checks=22,all_local_ESS_independently_recomputed=False),
    artifacts=[record(p) for p in key_paths],full_manifest="final_manifest.json")
write(HERE/"completion.json",completion)
paths=set(p for p in HERE.rglob("*") if p.is_file())
for relative in ("R/experimental/mebane_ad","models/experimental/mebane_ad","tests/mebane/ad_study"):
    paths.update(p for p in (ROOT/relative).rglob("*") if p.is_file())
paths.update(ROOT/p for p in ("README.md","CLAUDE.md","quality_reports/plans/mebane_2022_2026_gates.json",
                            "quality_reports/plans/2026-09-28_mebane_2022_2026_gates.md"))
write(HERE/"final_manifest.json",dict(created_utc=datetime.now(timezone.utc).isoformat(),
    scope="Current experimental tree, all preserved attempts/QA, code/tests and live handoff docs; synthetic directories are not empirical results",
    excluded="This manifest itself; its hash is printed at sealing time",files=[record(p) for p in sorted(paths)]))
print(json.dumps(dict(status=completion["status"],pilot_verdict=completion["pilot_verdict"],
    files=len(paths),manifest_sha256=sha(HERE/"final_manifest.json"),completion_sha256=sha(HERE/"completion.json"))))
