import hashlib
import json
from pathlib import Path
import re

root=Path('/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud')
base=root/'quality_reports/results/mebane_gates/G3/round1/review'
events=json.loads((base/'executor_event_sequence.json').read_text())['events']
manifest=json.loads((root/'quality_reports/results/mebane_gates/G3/round1/revision2/candidate_manifest.json').read_text())
known_hashes={x['sha256'] for x in manifest['files']}

def hash_text(s):return hashlib.sha256(s.encode()).hexdigest()

def apply_diff(old,diff):
    original=old.splitlines(keepends=True);lines=diff.splitlines(keepends=True)
    result=[];cursor=0;i=0
    while i<len(lines):
        match=re.match(r'@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@',lines[i])
        assert match,lines[i]
        start=int(match.group(1))-1
        result.extend(original[cursor:start]);cursor=start;i+=1
        while i<len(lines) and not lines[i].startswith('@@ '):
            line=lines[i];prefix=line[0];content=line[1:]
            if prefix in ' -':
                assert original[cursor]==content,(original[cursor],content)
                cursor+=1
            if prefix in ' +':result.append(content)
            assert prefix in ' +-'
            i+=1
    result.extend(original[cursor:]);return ''.join(result)

state={};runs=[];protocols=[];edits=[]
for order,event in enumerate(events):
    if event['type']=='fileChange':
        for change in event['changes']:
            p=str(Path(change['path']).relative_to(root))
            if change['kind']['type']=='add':state[p]=change['diff']['text']
            elif change['kind']['type']=='update':state[p]=apply_diff(state[p],change['diff']['text'])
            else:raise ValueError(change['kind'])
            row=dict(order=order,id=event['id'],path=p,sha256=hash_text(state[p]),
                     included_as_bytes_in_candidate=hash_text(state[p]) in known_hashes)
            edits.append(row)
            if Path(p).name in ['protocol.json','protocol_v2.json','replay_plan.json']:protocols.append(row)
    else:
        cmd=event['command']
        match=re.search(r'/usr/bin/time -p timeout 120 Rscript --vanilla (tests/mebane/likelihood/[^ ]+\.R)',cmd)
        if not match:continue
        script=match.group(1)
        refs=[script]
        if 'source("R/lib/mebane_model.R")' in state.get(script,''):refs.append('R/lib/mebane_model.R')
        runs.append(dict(order=order,id=event['id'],command=cmd,exit_code=event['exit_code'],
            source_states=[dict(path=p,sha256=hash_text(state[p]),included_as_bytes_in_candidate=hash_text(state[p]) in known_hashes)
              if p in state else dict(path=p,state_from_trace_unavailable=True) for p in refs]))
final_matches=[dict(path=p,matches_current=(root/p).is_file() and (root/p).read_bytes()==s.encode()) for p,s in state.items()]
v2=next(x for x in protocols if x['path'].endswith('protocol_v2.json'))
result=dict(protocol_events=protocols,executions=runs,source_edits=edits,
    protocol_v2_precedes_every_test=all(v2['order']<r['order'] for r in runs),
    final_trace_states_match_files=final_matches,
    earlier_source_versions_absent_from_candidate=[r for r in runs if any(s.get('included_as_bytes_in_candidate') is False for s in r['source_states'])],
    limit="Order comes from raw tool events; no agent conclusion or filesystem mtime used as proof of chronological ordering")
out=base/'history_audit.json'
with out.open('x') as f:json.dump(result,f,indent=2,ensure_ascii=False);f.write('\n')
print(json.dumps(dict(tests=len(runs),v2_precedes=result['protocol_v2_precedes_every_test'],
  final_states_match=all(x['matches_current'] for x in final_matches),
  executions_with_missing_source_bytes=len(result['earlier_source_versions_absent_from_candidate']))))
