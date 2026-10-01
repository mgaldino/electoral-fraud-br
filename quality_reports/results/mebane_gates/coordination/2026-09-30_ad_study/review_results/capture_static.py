"""Small static-source snapshot only; no tests, diagnostics, or pilot-file reads."""
import hashlib
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path('/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud')
OUT = ROOT / 'quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/review_results'
paths = ['R/experimental/mebane_ad/compare_runs.R', 'tests/mebane/ad_study/test_comparison.R']
records = []
for path in paths:
    source = ROOT / path
    target = OUT / 'initial_static_sources' / path
    target.parent.mkdir(parents=True, exist_ok=True)
    assert not target.exists()
    data = source.read_bytes()
    shutil.copyfile(source, target)
    assert target.read_bytes() == data
    records.append(dict(path=path, snapshot=str(target.relative_to(ROOT)),
                        bytes=len(data), sha256=hashlib.sha256(data).hexdigest()))
record = dict(status='static_only_awaiting_final_artifacts',
              created_utc=datetime.now(timezone.utc).isoformat(),
              reviewer_id='01a0f4b8-962b-77a3-a418-6247c6219e8b',
              executor_id='019d795a-acfa-72c2-a210-d55a46c606c2',
              goal='AD-4', goal_complete=False, files=records,
              tests_executed=False, raw_draws_read=False, empirical_MCMC=False,
              final_review_issued=False,
              waiting_for='User notice that sampling/execution/comparison and final artifacts are persisted')
with (OUT / 'static_read.json').open('x') as stream:
    json.dump(record,stream,indent=2)
print(json.dumps(record))
