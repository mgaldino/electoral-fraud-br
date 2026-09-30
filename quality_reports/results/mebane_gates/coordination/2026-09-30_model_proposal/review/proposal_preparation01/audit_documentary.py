"""Independent hash inventory and in-memory replay of raw historical edit events."""
import datetime
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT = Path('/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud')
BASE = ROOT / 'quality_reports/results/mebane_gates/coordination/2026-09-30_model_proposal'
PACKAGE = BASE / 'provenance_repair'
QA = BASE / 'review'
OLD = ROOT / 'quality_reports/results/mebane_gates/G3/round1/review'
OUT = QA / sys.argv[1]
assert OUT.is_relative_to(QA) and not OUT.exists()
OUT.mkdir(parents=True)
digest = lambda data: hashlib.sha256(data).hexdigest()
sha = lambda p: digest(p.read_bytes())
read = lambda p: json.loads(p.read_bytes())
records = []
inputs = set()

def save(name, data):
    with (OUT / name).open('x', encoding='utf-8') as stream:
        json.dump(data, stream, ensure_ascii=False, indent=2, allow_nan=False)
        stream.write('\n')

def check(name, condition):
    records.append({'id': name, 'pass': bool(condition)})

def verify_manifest(path, base, count):
    inputs.add(path)
    manifest = read(path)
    files = manifest['files']
    check(str(path.relative_to(ROOT)) + ':count', len(files) == count)
    check(str(path.relative_to(ROOT)) + ':unique', len({r['path'] for r in files}) == len(files))
    for row in files:
        p = (base / row['path']).resolve()
        inputs.add(p)
        check(str(p.relative_to(ROOT)), p.is_file() and p.stat().st_size == row['bytes'] and sha(p) == row['sha256'])
    return manifest

manifest_path = PACKAGE / 'closure_manifest.json'
check('frozen_supplement_sha', sha(manifest_path) == 'b6b56b80a7b40863d34f5f48b1de6641c1c54572121d949e9e6052ec46723965')
manifest = verify_manifest(manifest_path, PACKAGE, 42)
actual = {str(p.relative_to(PACKAGE)) for p in PACKAGE.rglob('*') if p.is_file()
          and p != manifest_path and not p.is_relative_to(PACKAGE / 'runs/final_verification')}
check('no_unlisted_package_file_except_declared_detached_verification', actual == {r['path'] for r in manifest['files']})
parent = ROOT / manifest['parent_manifest_path']
check('original_revision3_sha', sha(parent) == '63855471a88dbfc3840b1172aef71118f7cffbdfe425e0241f1d689bf5e67966')
verify_manifest(parent, ROOT, 350)
verify_manifest(OLD / 'review_manifest.json', ROOT, 419)
delivery = PACKAGE / 'delivery'
for label in ['input_manifest.json','historical_logs_manifest.json']:
    for row in read(delivery / label)['files']:
        original, copy = ROOT / row['source_path'], delivery / row['path']
        inputs.update([original, copy])
        check('copy_identical:' + row['path'], original.read_bytes() == copy.read_bytes() and sha(copy) == row['sha256'])

# Reconstruct from old QA raw events, not executor reconstruction functions.
events_path = OLD / 'executor_event_sequence.json'
inputs.add(events_path)
event_document = read(events_path)
check('raw_trace_unpaginated', event_document['has_more'] is False)
expected = read(OLD / 'input_closure_revision2.json')['historical_preservation']['missing_effective_code_versions']
targets = {(row['path'],row['sha256']): row for row in expected}
saved_map = read(delivery / 'command_source_map.json')
saved_runs = {r['id']: r for r in saved_map['commands']}
saved_edits = read(delivery / 'reconstruction_trace.json')['file_change_states']
state, history, recovered, executions = {}, [], [], []

def patch_exact(old, diff):
    lines = diff.splitlines(keepends=True)
    starts = [i for i,line in enumerate(lines) if line.startswith('@@ ')] + [len(lines)]
    assert starts and starts[0] == 0
    original = old.splitlines(keepends=True)
    output, cursor = [], 0
    for a,b in zip(starts[:-1], starts[1:]):
        header = re.fullmatch(r'@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@[^\n]*\n?', lines[a])
        assert header
        oldpos, oldcount, newpos, newcount = [int(x) if x is not None else 1 for x in header.groups()]
        body = lines[a+1:b]
        assert all(line[0] in ' +-' for line in body)
        before = [line[1:] for line in body if line[0] in ' -']
        after = [line[1:] for line in body if line[0] in ' +']
        assert len(before) == oldcount and len(after) == newcount
        start = oldpos - (oldcount != 0)
        assert cursor <= start <= len(original)
        assert original[start:start+oldcount] == before
        output += original[cursor:start]
        assert len(output) == newpos - (newcount != 0)
        output += after
        cursor = start+oldcount
    return ''.join(output+original[cursor:])

for order,event in enumerate(event_document['events']):
    if event['type'] == 'fileChange':
        assert event['status'] == 'completed'
        for change in event['changes']:
            path = str(Path(change['path']).relative_to(ROOT))
            assert not change['diff']['truncated']
            if change['kind']['type'] == 'add':
                assert path not in state
                state[path] = change['diff']['text']
            else:
                assert change['kind']['type'] == 'update' and path in state
                state[path] = patch_exact(state[path],change['diff']['text'])
            history.append({'order':order,'id':event['id'],'path':path,'sha256':digest(state[path].encode())})
        continue
    match = re.search(r'/usr/bin/time -p timeout 120 Rscript --vanilla (tests/mebane/likelihood/[^ ]+\.R)', event['command'])
    if match is None:
        continue
    script = match.group(1)
    refs = [script] + (['R/lib/mebane_model.R'] if 'source("R/lib/mebane_model.R")' in state.get(script,'') else [])
    run = saved_runs[event['id']]
    check('command_literal:'+event['id'], all(run[k] == event[k] for k in ['command','exit_code','status','turn_id','item_order']))
    check('command_order:'+event['id'], run['order'] == order)
    source_states = []
    for p in refs:
        claimed = next(row for row in run['source_states'] if row['path'] == p)
        if p not in state:
            check('absent_base_explicit:'+p, claimed['state_from_trace_unavailable'] is True)
            source_states.append({'path':p,'state_unavailable':True})
            continue
        data = state[p].encode('utf-8')
        h = digest(data)
        check('effective_source:'+event['id']+':'+p, claimed['sha256'] == h)
        source_states.append({'path':p,'sha256':h})
        lineage = [r for r in history if r['path'] == p]
        check('edit_lineage:'+event['id']+':'+p,
              [{k:r[k] for k in ['order','id','path','sha256']} for r in claimed['lineage']] == lineage)
        if (p,h) in targets:
            target = targets[p,h]
            snapshot = delivery / 'snapshots' / target['attempt'] / p
            check('recovered_byte_identity:'+target['attempt']+':'+p, snapshot.read_bytes() == data)
            recovered.append({**target,'snapshot':str(snapshot.relative_to(ROOT)),
                              'event_id':event['id'],'order':order,'exit_code':event['exit_code'],'bytes':len(data)})
    executions.append({'id':event['id'],'order':order,'sources':source_states})
check('all_seven_exact_recovered',len(recovered) == 7 and {(r['path'],r['sha256']) for r in recovered} == set(targets))
check('five_affected_commands',len({r['event_id'] for r in recovered}) == 5)
check('twelve_timed_commands',len(executions) == len(saved_runs) == 12)
check('twenty_one_edit_states',len(history) == len(saved_edits) == 21)
check('full_edit_trace_matches',history == [{k:r[k] for k in ['order','id','path','sha256']} for r in saved_edits])
save('recovered_sources.json',recovered)
save('replayed_event_history.json',{'executions':executions,'edits':history})

command = ['timeout','110',sys.executable,'-B',str(PACKAGE / 'reconstruct_sources.py'),'verify-seal']
save('executor_verify_invocation.json',{'argv':command,'cwd':str(ROOT),'source_execution':'documentary verifier only; no R sources executed'})
start = time.monotonic()
with (OUT / 'executor_verify_stdout.log').open('x') as stdout, (OUT / 'executor_verify_stderr.log').open('x') as stderr:
    done = subprocess.run(command,cwd=ROOT,stdout=stdout,stderr=stderr,timeout=115)
elapsed = time.monotonic()-start
check('executor_documentary_replay_exit_zero',done.returncode == 0)
reported = read(OUT / 'executor_verify_stdout.log')
check('executor_bound_exact_seal',reported['closure_manifest_sha256'] == sha(manifest_path))
check('detached_seal_hash',read(PACKAGE / 'runs/final_verification/stdout.log')['closure_manifest_sha256'] == sha(manifest_path))
for p in (PACKAGE / 'runs/final_verification').rglob('*'):
    if p.is_file(): inputs.add(p)
check('seven_only_not_universal_closure',any(r['sources'][0].get('state_unavailable') for r in executions))
save('checks.json',records)
inputs.add(Path(__file__))
save('input_inventory.json',{'files':[{'path':str(p.relative_to(ROOT)),'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted(inputs)]})
summary = {'status':'scoped_documentary_checks_pass' if all(r['pass'] for r in records) else 'failed',
           'checks':len(records),'failed':[r for r in records if not r['pass']],
           'package_sha256':sha(manifest_path),'package_entries_verified':42,
           'revision3_entries_verified':350,'old_QA_entries_verified':419,
           'seven_recovered_sources':len(recovered),'affected_commands':len({r['event_id'] for r in recovered}),
           'event_commands_compared':len(executions),'edit_states_compared':len(history),
           'documentary_replay_seconds':elapsed,'universal_historical_input_closure':False,
           'new_MCMC':False,'gate_G3':'inconclusive','adjudication_reserved_to_coordination':True}
save('result.json',summary)
print(json.dumps(summary,ensure_ascii=False))
assert not summary['failed']
