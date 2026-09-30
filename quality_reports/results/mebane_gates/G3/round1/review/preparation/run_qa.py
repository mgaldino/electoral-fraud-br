#!/usr/bin/env python3
"""Freeze independent source-bound checks and preserve every bounded attempt."""
import datetime
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

ROOT = Path('/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud')
BASE = ROOT / 'quality_reports/results/mebane_gates/G3/round1/review'
PREP = BASE / 'preparation'
SOURCE = 'quality_reports/results/mebane_gates/G0/round1/qbl_installed_3017de5.jags'
CONTRACT = 'quality_reports/results/mebane_gates/G2/round2/benchmark_contract.json'
WRAPPER = 'quality_reports/results/mebane_gates/G2/round2/sources/ef_main_3017de5.R'
LEDGER = 'quality_reports/plans/mebane_2022_2026_gates.json'


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def write(path, obj):
    with path.open('x', encoding='utf-8') as stream:
        json.dump(obj, stream, ensure_ascii=False, indent=2)
        stream.write('\n')


def entry(path):
    return dict(path=str(path.relative_to(ROOT)), bytes=path.stat().st_size,
                sha256=hashlib.sha256(path.read_bytes()).hexdigest())


def freeze():
    dest = BASE / 'freeze_01'
    dest.mkdir()
    paths = [SOURCE, CONTRACT, WRAPPER, LEDGER, 'CLAUDE.md',
             'quality_reports/results/mebane_gates/coordination/2026-09-29_g3_runtime/dispatch.md',
             'quality_reports/results/mebane_gates/coordination/2026-09-29_benchmark_round/g3_dispatch_requirements.md',
             'quality_reports/results/mebane_gates/G3/round1/protocol_v2.json']
    records = []
    for i, value in enumerate(paths):
        src = ROOT / value
        snapshot = dest / f'input_{i:02d}_{src.name}'
        with snapshot.open('xb') as output:
            output.write(src.read_bytes())
        records.append(dict(original=entry(src), snapshot=entry(snapshot)))
    gate = next(g for g in json.loads((ROOT / LEDGER).read_text())['gates'] if g['id']=='G3')
    static = {k:v for k,v in gate.items() if k not in {'status','records'}}
    static['todos'] = [{k:v for k,v in todo.items() if k not in {'status','evidence'}} for todo in gate['todos']]
    canonical = json.dumps(static,sort_keys=True,ensure_ascii=False,separators=(',',':')).encode()
    (dest / 'G3_static_contract.json').write_bytes(canonical)
    protocol = json.loads((PREP / 'protocol.json').read_text())
    assert records[0]['original']['sha256'] == protocol['source_sha256']
    assert records[1]['original']['sha256'] == protocol['benchmark_contract_sha256']
    write(dest / 'freeze.json', dict(frozen_at=now(),reviewer_id=protocol['reviewer_id'],
        candidate_received=False, candidate_manifest_sha256=None,
        contract_sha256=hashlib.sha256(canonical).hexdigest(),
        inputs=records, preparation_files=[entry(p) for p in sorted(PREP.iterdir()) if p.is_file()],
        pre_freeze_parse_note='R wrapper draft extra parenthesis repaired before tests/freeze; no numerical output observed',
        unrestricted_manifest_complete=False))
    print(json.dumps(entry(dest / 'freeze.json')))


def run(kind, case_index=None):
    frozen = json.loads((BASE / 'freeze_01/freeze.json').read_text())
    for record in frozen['preparation_files']:
        assert entry(ROOT / record['path']) == record, 'Frozen preparation changed'
    for record in frozen['inputs']:
        assert entry(ROOT / record['snapshot']['path']) == record['snapshot']
    protocol = json.loads((PREP / 'protocol.json').read_text())
    compute = 0.0
    for p in BASE.glob('attempt_*/execution.json'):
        compute += json.loads(p.read_text())['elapsed_seconds']
    limit = min(protocol['limits']['process_seconds'],protocol['limits']['cumulative_compute_seconds']-compute)
    if limit <= 0:
        raise SystemExit('Compute budget exhausted; no run started')
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    name = f'attempt_{stamp}_{kind}' + (f'_{case_index:02d}' if case_index else '')
    out = BASE / name
    out.mkdir()
    temp = out / 'tmp'
    temp.mkdir()
    env = os.environ.copy()
    env.update(LC_ALL='en_US.UTF-8',R_LIBS_USER=str(ROOT/'renv/library/macos/R-4.4/aarch64-apple-darwin20'),TMPDIR=str(temp))
    command = ['/usr/local/bin/Rscript','--vanilla',str(PREP/f'qa_{kind}.R'),str(PREP/'protocol.json'),str(out)]
    if kind=='wrapper':
        command.append(str(ROOT/WRAPPER))
    elif kind=='runtime':
        if not case_index:
            raise ValueError('runtime requires a case index')
        successes = list(BASE.glob('attempt_*_wrapper/wrapper_checks.json'))
        assert successes and any(all(item['pass'] for item in json.loads(p.read_text())) for p in successes), 'wrapper preflight not passed'
        command += [str(ROOT/SOURCE),str(case_index)]
    write(out/'invocation.json',dict(started=now(),command=command,timeout_seconds=limit,
        prior_compute_seconds=compute,freeze=entry(BASE/'freeze_01/freeze.json'),
        environment={k:env[k] for k in ['LC_ALL','R_LIBS_USER','TMPDIR']}))
    start = time.monotonic()
    timed_out = False
    with (out/'stdout.log').open('xb') as stdout, (out/'stderr.log').open('xb') as stderr:
        process = subprocess.Popen(command,cwd=ROOT,env=env,stdout=stdout,stderr=stderr,start_new_session=True)
        try:
            code = process.wait(timeout=limit)
        except subprocess.TimeoutExpired:
            timed_out = True
            os.killpg(process.pid,signal.SIGKILL)
            code = process.wait()
    elapsed = time.monotonic()-start
    write(out/'execution.json',dict(finished=now(),pid=process.pid,exit_code=code,
        elapsed_seconds=elapsed,timed_out=timed_out,command=command,
        total_compute_seconds=compute+elapsed,outputs=[entry(p) for p in sorted(out.rglob('*')) if p.is_file()]))
    print(json.dumps(dict(attempt=str(out.relative_to(ROOT)),exit_code=code,seconds=elapsed,timed_out=timed_out)))


if __name__=='__main__':
    if sys.argv[1]=='freeze':
        freeze()
    else:
        run(sys.argv[1],int(sys.argv[2]) if len(sys.argv)>2 else None)
