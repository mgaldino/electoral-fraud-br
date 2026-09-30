"""Independent byte/header/dependency audit; never self-attests input closure."""
import datetime
import hashlib
import json
from pathlib import Path
import re
import sys
import time

ROOT=Path('/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud')
REVIEW=ROOT/'quality_reports/results/mebane_gates/G3/round1/review'


def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda:stream.read(1024*1024),b''):
            h.update(block)
    return h.hexdigest()


def write(path,obj):
    with path.open('x',encoding='utf-8') as stream:
        json.dump(obj,stream,ensure_ascii=False,indent=2)
        stream.write('\n')


def canonical(obj):
    return hashlib.sha256(json.dumps(obj,sort_keys=True,ensure_ascii=False,separators=(',',':')).encode()).hexdigest()


def static(gate):
    answer={k:v for k,v in gate.items() if k not in {'status','records'}}
    answer['todos']=[{k:v for k,v in t.items() if k not in {'status','evidence'}} for t in gate['todos']]
    return answer


def safe_path(value):
    if not isinstance(value,str) or not value or Path(value).is_absolute():
        raise ValueError('invalid relative path')
    path=(ROOT/value).resolve()
    if not path.is_relative_to(ROOT):
        raise ValueError('path escapes root')
    return path


def main():
    manifest_path=safe_path(sys.argv[1]); expected=sys.argv[2]
    out=safe_path(sys.argv[3])
    assert out.is_relative_to(REVIEW) and not out.exists()
    assert sha(manifest_path)==expected,'user-provided candidate hash mismatch'
    out.mkdir(parents=True)
    start=time.monotonic()
    m=json.loads(manifest_path.read_text())
    run_path=manifest_path.parent/'run.json'
    run=json.loads(run_path.read_text())
    ledger_path=ROOT/'quality_reports/plans/mebane_2022_2026_gates.json'
    ledger=json.loads(ledger_path.read_text())
    gates={g['id']:g for g in ledger['gates']}
    contract=canonical(static(gates['G3']))
    errors=[]; rows=[]; indexed={}; candidates_by_hash={}
    for entry in m['files']:
        value=entry.get('path')
        try:
            p=safe_path(value)
            duplicate=str(p) in indexed
            indexed[str(p)]=entry
            present=p.is_file()
            actual_sha=sha(p) if present else None
            actual_size=p.stat().st_size if present else None
            valid=present and actual_sha==entry.get('sha256') and actual_size==entry.get('bytes') and not duplicate and p!=manifest_path
            row=dict(path=value,present=present,expected_sha256=entry.get('sha256'),actual_sha256=actual_sha,
                     expected_bytes=entry.get('bytes'),actual_bytes=actual_size,duplicate=duplicate,valid=valid)
            if not valid:errors.append(row)
            if present:candidates_by_hash.setdefault((actual_sha,actual_size),[]).append(value)
        except (ValueError,OSError) as exc:
            row=dict(path=value,valid=False,error=str(exc));errors.append(row)
        rows.append(row)
    headers=[]
    for name,obj in [('manifest',m),('run',run)]:
        valid=(obj.get('gate_id'),obj.get('round'),obj.get('contract_sha256'))==('G3','round1',contract)
        headers.append(dict(artifact=name,valid=valid,gate_id=obj.get('gate_id'),round=obj.get('round'),contract=obj.get('contract_sha256')))
    headers.append(dict(artifact='run_in_manifest',valid=str(run_path.resolve()) in indexed))
    groups=[]
    for group in ('inputs','code','configuration','outputs'):
        for value in run[group]:
            p=safe_path(value)
            groups.append(dict(group=group,path=value,in_manifest=str(p) in indexed))
    dependencies=[]
    for dep in gates['G3']['depends_on']:
        parent=gates[dep]
        for field,expected_dep in [('candidate_manifest',run['dependency_manifests'][dep]),
              ('review',run['dependency_approvals'][dep]['review_sha256']),
              ('adjudication',run['dependency_approvals'][dep]['adjudication_sha256'])]:
            p=safe_path(parent['records'][field])
            dependencies.append(dict(gate=dep,field=field,path=parent['records'][field],
                actual_sha256=sha(p),expected_sha256=expected_dep,valid=sha(p)==expected_dep,parent_status=parent['status']))
    prior=[]
    for value in run.get('inputs',[]):
        if Path(value).name!='candidate_manifest.json' or '/G3/round1/' not in value:
            continue
        pm_path=safe_path(value)
        pm=json.loads(pm_path.read_text())
        for old in pm['files']:
            p=safe_path(old['path'])
            direct=p.is_file() and sha(p)==old['sha256'] and p.stat().st_size==old['bytes']
            recoveries=candidates_by_hash.get((old['sha256'],old['bytes']),[])
            prior.append(dict(prior_manifest=value,original_path=old['path'],original_sha256=old['sha256'],
                original_bytes=old['bytes'],original_path_intact=direct,matching_candidate_paths=recoveries,
                bytes_recoverable=direct or bool(recoveries)))
    source_refs=[]
    for value in run.get('code',[]):
        p=safe_path(value)
        if p.suffix not in {'.R','.py','.sh'} or not p.is_file():continue
        for lineno,line in enumerate(p.read_text().splitlines(),1):
            if re.search(r'\b(source|readRDS|read[._]csv|readLines|read_text|read_bytes|jags.model|open|system2|load)\s*\(',line):
                source_refs.append(dict(code_path=value,line=lineno,text=line.strip(),requires_manual_closure=True))
    write(out/'all_entries.json',rows)
    write(out/'declared_paths.json',groups)
    write(out/'historical_preservation.json',prior)
    write(out/'source_read_sites.json',source_refs)
    result=dict(candidate_manifest_sha256=expected,gate_id='G3',round='round1',
        reviewer_id='01a0ee05-aeaf-7492-a8ea-fa731dd6214a',executor_id=run['executor_id'],
        distinct_id=run['executor_id']!='01a0ee05-aeaf-7492-a8ea-fa731dd6214a',
        entries=len(rows),total_bytes=sum(r.get('actual_bytes') or 0 for r in rows),entry_errors=errors,
        headers=headers,dependencies=dependencies,missing_declared_paths=[g for g in groups if not g['in_manifest']],
        unrecoverable_historical_entries=[p for p in prior if not p['bytes_recoverable']],
        qa_artifacts_misclassified_as_executor_outputs=[g['path'] for g in groups if g['group']=='outputs' and '/round1/review/' in g['path']],
        contract_sha256=contract,manual_actual_input_closure_pending=True,manifest_complete=False,
        elapsed_seconds=time.monotonic()-start,checked_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),
        ledger_observed_sha256=sha(ledger_path),verifier_sha256=sha(Path(__file__)))
    write(out/'integrity.json',result)
    print(json.dumps({k:result[k] for k in ['entries','total_bytes','entry_errors','missing_declared_paths','unrecoverable_historical_entries']}))


if __name__=='__main__':main()
