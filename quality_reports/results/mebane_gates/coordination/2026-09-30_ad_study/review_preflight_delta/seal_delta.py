"""Seal this delta review without touching candidate or previous review artifacts."""
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path('/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud')
BASE = ROOT / 'quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study'
OUT = BASE / 'review_preflight_delta'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
review = json.loads((OUT / 'review.json').read_text())
manifest_path = BASE / 'preflight_full02/candidate_manifest.json'
manifest = json.loads(manifest_path.read_text())
assert sha(manifest_path) == review['candidate_manifest_sha256']
for item in manifest['files']:
    assert sha(ROOT / item['snapshot']) == sha(ROOT / item['path']) == item['sha256']
    assert (ROOT / item['snapshot']).stat().st_size == item['bytes']
for name, count in [('checks_delta.json', 49), ('checks_supervisor.json', 9)]:
    checks = json.loads((OUT / name).read_text())['checks']
    assert len(checks) == count and all(x['pass'] for x in checks)
for group in ('previous_findings', 'verified_delta'):
    for item in review[group]:
        for evidence in item.get('evidence', []):
            path = ROOT / review['frozen_source_prefix'] / evidence['path']
            assert 1 <= evidence['line_start'] <= evidence['line_end'] <= len(path.read_text().splitlines())
assert review['status'] == 'pass' and review['findings'] == []
assert review['reviewer_id'] != review['executor_id']
previous = BASE / 'review_preflight'
old_manifest = json.loads((previous / 'evidence_manifest.json').read_text())
for item in old_manifest['files']:
    assert sha(previous / item['path']) == item['sha256']
with (OUT / 'integrity_final.json').open('x') as stream:
    json.dump(dict(created_utc=datetime.now(timezone.utc).isoformat(),
                   candidate_manifest_sha256=sha(manifest_path), files_verified=len(manifest['files']),
                   previous_review_files_verified=len(old_manifest['files']),
                   reviewer_id=review['reviewer_id'], new_findings=0,
                   checks_passed=58, empirical_MCMC=False), stream, indent=2)
files = [dict(path=str(p.relative_to(OUT)), bytes=p.stat().st_size, sha256=sha(p))
         for p in sorted(OUT.rglob('*')) if p.is_file()]
with (OUT / 'evidence_manifest.json').open('x') as stream:
    json.dump(dict(created_utc=datetime.now(timezone.utc).isoformat(),files=files,
                   excluded='This manifest itself',empirical_MCMC=False),stream,indent=2)
print(json.dumps(dict(status=review['status'],candidate_files=len(manifest['files']),
                      evidence_files=len(files),checks_passed=58,
                      review_json_sha256=sha(OUT/'review.json'),
                      review_md_sha256=sha(OUT/'review.md'))))
