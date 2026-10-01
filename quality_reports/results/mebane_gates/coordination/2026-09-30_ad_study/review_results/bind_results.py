"""Read-only hash binding of the completed pilot and comparison; no raw copies."""
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path('/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud')
BASE = ROOT / 'quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study'
OUT = BASE / 'review_results'
cache = {}
def sha(path):
    path = path.resolve()
    if path not in cache:
        with path.open('rb') as stream:
            cache[path] = hashlib.file_digest(stream, 'sha256').hexdigest()
    return cache[path]

release_path = BASE / 'release_v1.json'
release = json.loads(release_path.read_text())
assert release['status'] == 'approved_for_bounded_experiment'
assert release['contract_sha256'] == 'd17b7f508a7ce87eec3ca71ed7df67666b528c755e005ec9e1299e5ff9deb509'
assert json.loads((BASE/'pilot01/release_consumed.json').read_text()) == release
for item in release['files']:
    assert sha(ROOT/item['path']) == item['sha256'], item['path']
assert sha(ROOT/'R/experimental/mebane_ad/compare_runs.R') == 'ba835f6244341f26e425a4173f53edb1457162820dc0deed0649ea1cf2bae81f'
records = []
for directory in ('pilot01','comparison01'):
    for path in sorted((BASE/directory).rglob('*')):
        if not path.is_file():
            continue
        records.append(dict(path=str(path.relative_to(ROOT)), bytes=path.stat().st_size, sha256=sha(path)))
        if path.name == 'manifest.json':
            manifest = json.loads(path.read_text())
            for item in manifest['files']:
                original = ROOT/item['path']
                assert sha(original) == item['sha256'], str(original)
                if 'snapshot' in item:
                    assert sha(ROOT/item['snapshot']) == item['sha256'], item['snapshot']
execution = json.loads((BASE/'pilot01/execution.json').read_text())
assert execution['release_sha256'] == sha(release_path)
assert execution['retries'] == 0 and [x['model'] for x in execution['runs']] == ['A','D']
for model in ('A','D'):
    for suffix in ('_supervisor.json','_diagnostics_supervisor.json'):
        record = json.loads((BASE/'pilot01'/(model+suffix)).read_text())
        assert sha(ROOT/record['log']) == record['log_sha256']
        assert record['returncode'] == 0 and record['timed_out'] is False
    run = json.loads((BASE/'pilot01'/model/'run_result.json').read_text())
    assert sha(BASE/'pilot01'/model/'raw_chains.rds') == run['raw_sha256']
result = dict(status='pass_hash_binding', created_utc=datetime.now(timezone.utc).isoformat(),
              reviewer_id='01a0f4b8-962b-77a3-a418-6247c6219e8b',
              comparison_manifest_sha256=sha(BASE/'comparison01/manifest.json'),
              comparison_report_sha256=sha(BASE/'comparison01/comparison_report.md'),
              execution_sha256=sha(BASE/'pilot01/execution.json'),release_sha256=sha(release_path),
              contract_sha256=release['contract_sha256'],files=records,
              release_files_verified=len(release['files']),raw_copied=False,new_MCMC=False)
with (OUT/'input_binding.json').open('x') as stream:
    json.dump(result,stream,indent=2)
print(json.dumps({k:v for k,v in result.items() if k!='files'}))
print('Bound pilot/comparison files:', len(records))
