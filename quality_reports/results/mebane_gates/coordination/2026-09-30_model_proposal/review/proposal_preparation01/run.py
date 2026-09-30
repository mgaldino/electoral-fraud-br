"""Freeze dependencies, run deterministic checks, preserve every invocation."""
import csv
import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path('/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud')
BASE = ROOT / 'quality_reports/results/mebane_gates/coordination/2026-09-30_model_proposal'
QA = BASE / 'review'
OUT = QA / sys.argv[1]
assert OUT.is_relative_to(QA) and not OUT.exists()
OUT.mkdir(parents=True)
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()

def save(path, obj):
    with path.open('x', encoding='utf-8') as f:
        json.dump(obj, f, indent=2, ensure_ascii=False, allow_nan=False)
        f.write('\n')

protocol = json.loads((QA / 'proposal_preparation01/protocol.json').read_text())
assert sha(BASE / 'proposal_v1.md') == protocol['proposal_sha256']
assert sha(BASE / 'check_proposals.R') == protocol['candidate_script_sha256']
inputs = [BASE / 'proposal_v1.md', BASE / 'check_proposals.R',
          BASE / 'checks01/check_proposals_initial.R', BASE / 'checks02/check_proposals_second.R',
          ROOT / 'R/lib/mebane_model.R',
          ROOT / 'quality_reports/results/mebane_gates/G0/round1/qbl_installed_3017de5.jags',
          QA / 'proposal_preparation01/protocol.json', QA / 'proposal_preparation01/checks.R', Path(__file__)]
freeze = [{'path': str(p.relative_to(ROOT)), 'sha256': sha(p), 'bytes': p.stat().st_size} for p in inputs]
save(OUT / 'freeze.json', {'frozen_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
                         'inputs': freeze, 'before_execution': True})
env = os.environ.copy()
env['LC_ALL'] = 'en_US.UTF-8'
env['R_LIBS_USER'] = str(ROOT / 'renv/library/macos/R-4.4/aarch64-apple-darwin20')
jobs = [('independent', QA / 'proposal_preparation01/checks.R', True),
        ('preserved01', BASE / 'checks01/check_proposals_initial.R', False),
        ('preserved02', BASE / 'checks02/check_proposals_second.R', False),
        ('candidate03', BASE / 'check_proposals.R', False)]
results = []
for name, source, make_dir in jobs:
    dest = OUT / name
    if make_dir:
        dest.mkdir()
    command = ['timeout', '110', 'Rscript', '--vanilla', str(source), str(dest)]
    save(OUT / (name+'_invocation.json'), {'argv': command, 'cwd': str(ROOT),
         'source_sha256': sha(source), 'no_MCMC': True, 'R_LIBS_USER': env['R_LIBS_USER']})
    start = time.monotonic()
    with (OUT / (name+'_stdout.log')).open('x') as stdout, (OUT / (name+'_stderr.log')).open('x') as stderr:
        done = subprocess.run(command, cwd=ROOT, env=env, stdout=stdout, stderr=stderr, timeout=115)
    results.append({'name': name, 'exit_code': done.returncode, 'seconds': time.monotonic()-start})
    save(OUT / (name+'_completion.json'), results[-1])
checks = list(csv.DictReader((OUT / 'independent/checks.csv').open()))
unchanged = all(sha(ROOT / r['path']) == r['sha256'] for r in freeze)
save(OUT / 'result.json', {'jobs': results, 'input_bytes_unchanged': unchanged,
     'independent_checks': len(checks), 'failed_checks': [r for r in checks if r['pass'] != 'TRUE'],
     'expected_failures': ['preserved01', 'preserved02'], 'no_estimation': True})
print(json.dumps(results))
assert unchanged and not [r for r in checks if r['pass'] != 'TRUE']
assert results[0]['exit_code'] == results[3]['exit_code'] == 0
assert results[1]['exit_code'] != 0 and results[2]['exit_code'] != 0
