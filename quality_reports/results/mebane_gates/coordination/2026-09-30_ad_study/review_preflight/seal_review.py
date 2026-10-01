"""Validate the review and seal immutable-source and output evidence."""
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path('/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud')
BASE = ROOT / 'quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study'
OUT = BASE / 'review_preflight'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
review = json.loads((OUT / 'review.json').read_text())
manifest_path = BASE / 'preflight_full01/candidate_manifest.json'
manifest = json.loads(manifest_path.read_text())
assert sha(manifest_path) == review['candidate_manifest_sha256']
records = []
for item in manifest['files']:
    snapshot = ROOT / item['snapshot']
    assert sha(snapshot) == item['sha256']
    assert snapshot.stat().st_size == item['bytes']
    current_sha = sha(ROOT / item['path'])
    records.append(dict(path=item['path'], snapshot_sha256=sha(snapshot),
                        current_sha256=current_sha,
                        current_matches_frozen=current_sha == item['sha256']))
for group in ('blocking_findings', 'nonblocking_findings', 'checks'):
    for record in review[group]:
        for evidence in record.get('evidence', []):
            path = ROOT / review['frozen_source_prefix'] / evidence['path']
            assert 1 <= evidence['line_start'] <= evidence['line_end'] <= len(path.read_text().splitlines())
assert review['reviewer_id'] != review['executor_id']
assert review['status'] == 'changes_requested'
assert len(review['blocking_findings']) == len(review['nonblocking_findings']) == 1
for name, expected in [('checks_common01.json', 67), ('checks_d_frozen.json', 27)]:
    checks = json.loads((OUT / name).read_text())['checks']
    assert len(checks) == expected and all(x['pass'] for x in checks)
checks = json.loads((OUT / 'checks_supervisor.json').read_text())['checks']
assert len(checks) == 9 and sum(x['pass'] for x in checks) == 8
assert all(x['returncode'] == 0 for x in json.loads((OUT / 'frozen_fixture_reruns.json').read_text())['records'])
integrity = dict(created_utc=datetime.now(timezone.utc).isoformat(),
                 frozen_snapshots_verified=len(records),
                 current_matches=sum(x['current_matches_frozen'] for x in records),
                 candidate_manifest_sha256=sha(manifest_path),
                 reviewer_id=review['reviewer_id'], records=records)
with (OUT / 'integrity_final.json').open('x') as stream:
    json.dump(integrity, stream, indent=2)
files = [dict(path=str(p.relative_to(OUT)), bytes=p.stat().st_size, sha256=sha(p))
         for p in sorted(OUT.rglob('*')) if p.is_file()]
with (OUT / 'evidence_manifest.json').open('x') as stream:
    json.dump(dict(created_utc=datetime.now(timezone.utc).isoformat(), files=files,
                   excluded='This evidence manifest itself', empirical_MCMC=False), stream, indent=2)
print(json.dumps(dict(status='sealed', frozen_sources=len(records),
                      current_matches=integrity['current_matches'], files=len(files),
                      review_json_sha256=sha(OUT / 'review.json'),
                      review_md_sha256=sha(OUT / 'review.md'))))
