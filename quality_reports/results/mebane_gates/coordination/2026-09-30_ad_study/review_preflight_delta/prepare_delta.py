"""Bind the bounded delta to its frozen bytes and reuse prior synthetic evidence."""
import difflib
import hashlib
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path('/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud')
BASE = ROOT / 'quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study'
OUT = BASE / 'review_preflight_delta'
TREE = OUT / 'tree'
TREE.mkdir()
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
old_path = BASE / 'preflight_full01/candidate_manifest.json'
new_path = BASE / 'preflight_full02/candidate_manifest.json'
old = json.loads(old_path.read_text())
new = json.loads(new_path.read_text())
assert sha(new_path) == '7875d46b09301906dc3e7211b8319e53c43f3f19c21e141687d55a65cb65a337'
assert sha(old_path) == new['previous_candidate_sha256']
old_map = {x['path']: x for x in old['files']}
new_map = {x['path']: x for x in new['files']}
assert len(new_map) == len(new['files']) and set(old_map) <= set(new_map)
changed = sorted(k for k in old_map if old_map[k]['sha256'] != new_map[k]['sha256'])
assert changed == sorted(new['changed_existing_paths']) == sorted([
    'R/experimental/mebane_ad/diagnostics.R', 'R/experimental/mebane_ad/run_jags.R',
    'R/experimental/mebane_ad/run_pair.py', 'tests/mebane/ad_study/test_supervisor.py'])
records = []
for item in new['files']:
    src = ROOT / item['snapshot']
    live = ROOT / item['path']
    assert sha(src) == sha(live) == item['sha256']
    assert src.stat().st_size == item['bytes']
    target = TREE / item['path']
    target.parent.mkdir(parents=True, exist_ok=True)
    assert not target.exists()
    shutil.copyfile(src, target)
    records.append(dict(path=item['path'], snapshot=item['snapshot'], sha256=sha(src)))
for item in old['files']:
    assert sha(ROOT / item['snapshot']) == item['sha256']
for path in changed:
    lines = difflib.unified_diff((ROOT / old_map[path]['snapshot']).read_text().splitlines(True),
                                (ROOT / new_map[path]['snapshot']).read_text().splitlines(True),
                                fromfile='full01/' + path, tofile='full02/' + path)
    with (OUT / (Path(path).name + '.diff')).open('x') as stream:
        stream.writelines(lines)
previous = BASE / 'review_preflight'
prior_manifest = json.loads((previous / 'evidence_manifest.json').read_text())
for item in prior_manifest['files']:
    assert sha(previous / item['path']) == item['sha256']
reuse = TREE / 'prior_synthetic'
reuse.mkdir()
for model in ('A', 'D'):
    source = previous / f'common01_tree/synthetic_review_fixtures/{model}_SYNTHETIC'
    shutil.copytree(source, reuse / (model + '_raw'))
    source = previous / f'common01_tree/synthetic_review_fixtures/{model}_SYNTHETIC_processed'
    shutil.copytree(source, reuse / (model + '_processed'))
for name in ('checks_common01.json', 'checks_d_frozen.json', 'review.json'):
    shutil.copyfile(previous / name, OUT / ('prior_' + name))
# Reuse the exact previous adversarial fixture, changing only its output root.
script = (previous / 'check_supervisor.py').read_text()
script = script.replace('OUT = ROOT / BASE / "review_preflight"',
                        'OUT = ROOT / BASE / "review_preflight_delta"')
script = script.replace('TREE = OUT / "common01_tree"', 'TREE = OUT / "tree"')
with (OUT / 'check_supervisor_reused.py').open('x') as stream:
    stream.write(script)
record = dict(created_utc=datetime.now(timezone.utc).isoformat(),
              reviewer_id='01a0f4b8-962b-77a3-a418-6247c6219e8b',
              manifest_sha256=sha(new_path), contract_sha256=new['contract_sha256'],
              previous_manifest_sha256=sha(old_path), changed=changed,
              added=sorted(set(new_map) - set(old_map)), removed=[],
              frozen_records=records, previous_review_artifacts_verified=len(prior_manifest['files']),
              preserved_previous_paths=len(old_map)-len(changed), empirical_MCMC=False)
with (OUT / 'source_delta.json').open('x') as stream:
    json.dump(record, stream, indent=2)
print(json.dumps({k:record[k] for k in ['manifest_sha256','changed','preserved_previous_paths','previous_review_artifacts_verified']}))
print('Full02 frozen files verified:', len(records))
