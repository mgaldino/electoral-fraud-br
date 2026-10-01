"""Reexecute inspected frozen fixtures, never the empirical runner."""
import hashlib
import json
import os
import subprocess
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path('/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud')
BASE = Path('quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study')
OUT = ROOT / BASE / 'review_preflight'
TREE = OUT / 'common01_tree'
LOGS = OUT / 'frozen_fixture_reruns'
LOGS.mkdir()
(LOGS / 'tmp').mkdir()
env = dict(os.environ, LC_ALL='C', LANG='C', PYTHONDONTWRITEBYTECODE='1',
           R_LIBS=str(ROOT / 'renv/library/macos/R-4.4/aarch64-apple-darwin20'),
           TMPDIR=str(LOGS / 'tmp'))
contract = str(BASE / 'contract_v2.json')
data_dir = str(BASE / 'data/run-20260930T235038Z-pid61600')
raw = 'quality_reports/results/mebane_gates/coordination/authors_replication_discovery/archive/UMeforensics-eforensics_public-3017de5/data/dc2010.rda'
commands = [
    ('runner', ['Rscript', '--vanilla', 'tests/mebane/ad_study/test_runner.R', contract,
                data_dir + '/dc2010_ad_data.rds', str(LOGS / 'runner')]),
    ('supervisor', ['python3', 'tests/mebane/ad_study/test_supervisor.py', str(LOGS / 'supervisor')]),
    ('dc2010', ['Rscript', '--vanilla', 'tests/mebane/ad_study/test_dc2010.R', data_dir]),
    ('model_d', ['Rscript', '--vanilla', 'tests/mebane/ad_study/test_model_d.R',
                 'R/experimental/mebane_ad/model_d.R', 'models/experimental/mebane_ad/d_multinomial.jags',
                 'quality_reports/results/mebane_gates/G0/round1/qbl_installed_3017de5.jags',
                 contract, data_dir + '/dc2010_ad_data.rds', raw, 'R/experimental/mebane_ad/io.R'])
]
records = []
for label, command in commands:
    log = LOGS / (label + '.log')
    started = datetime.now(timezone.utc).isoformat()
    with log.open('x') as stream:
        result = subprocess.run(command, cwd=TREE, env=env, stdout=stream,
                                stderr=subprocess.STDOUT, timeout=180)
    record = dict(label=label, command=command, cwd=str(TREE), started_utc=started,
                  finished_utc=datetime.now(timezone.utc).isoformat(), returncode=result.returncode,
                  log=str(log.relative_to(OUT)),
                  log_sha256=hashlib.sha256(log.read_bytes()).hexdigest())
    records.append(record)
    print(json.dumps(record), flush=True)
    print(log.read_text()[-2500:], flush=True)
with (OUT / 'frozen_fixture_reruns.json').open('x') as stream:
    json.dump(dict(records=records, empirical_MCMC=False,
                   D_JAGS='synthetic fixed parents; no unobserved stochastic nodes'), stream, indent=2)
assert all(x['returncode'] == 0 for x in records)
