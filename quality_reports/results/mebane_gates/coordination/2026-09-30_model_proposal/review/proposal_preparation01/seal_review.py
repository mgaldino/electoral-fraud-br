"""Seal QA outputs and verified local inputs; never alter reviewed artifacts."""
import datetime
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path('/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud')
BASE = ROOT / 'quality_reports/results/mebane_gates/coordination/2026-09-30_model_proposal'
QA = BASE / 'review'
OUT = QA / 'final_verification01'
MANIFEST = QA / 'review_manifest.json'
read = lambda p: json.loads(p.read_bytes())
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()

def write(path, obj):
    with path.open('x',encoding='utf-8') as stream:
        json.dump(obj,stream,indent=2,ensure_ascii=False,allow_nan=False)
        stream.write('\n')

def meta(path):
    return {'path':str(path.relative_to(ROOT)),'sha256':sha(path),'bytes':path.stat().st_size}

if sys.argv[1] == 'verify':
    m = read(MANIFEST)
    for row in m['files']:
        assert meta(ROOT / row['path']) == row, row['path']
    actual_qa = {str(p.relative_to(ROOT)) for p in QA.rglob('*') if p.is_file()
                 and p != MANIFEST and p != OUT / 'manifest_verification.json'}
    declared_qa = {r['path'] for r in m['files'] if (ROOT / r['path']).is_relative_to(QA)}
    assert actual_qa == declared_qa
    result = {'review_manifest_sha256':sha(MANIFEST),'entries_reopened_and_verified':len(m['files']),
              'unlisted_QA_files':[],'status':'verified','scoped_manifest_complete':True,
              'universal_historical_runtime_input_closure':False,'G3_status':'inconclusive'}
    write(OUT / 'manifest_verification.json',result)
    print(json.dumps(result))
    sys.exit(0)

assert sys.argv[1] == 'seal' and not OUT.exists() and not MANIFEST.exists()
OUT.mkdir()
inputs = {}
for name in ['attempt01/freeze.json','proposal_attempt01/freeze.json','documentary_attempt01/input_inventory.json']:
    doc = read(QA / name)
    for row in doc.get('inputs',doc.get('files',[])):
        p = ROOT / row['path']
        assert sha(p) == row['sha256'] and p.stat().st_size == row['bytes'], row['path']
        inputs[p] = meta(p)
bindings = {
    BASE / 'proposal_v1.md':'7fe462ed99561dee68d49fe1c5595845664249060459d018b4d01829fd61153c',
    BASE / 'check_proposals.R':'f8bb9da0b73216c6422d3292c90de66515631e26bb774170a3482dfb05318083',
    BASE / 'provenance_repair/closure_manifest.json':'b6b56b80a7b40863d34f5f48b1de6641c1c54572121d949e9e6052ec46723965',
    BASE / 'mebane_model_proposal_v1.pdf':'1ba3644476e788327e7378a0cff0499b8f1a497bd9f2e70eba204c11043f3847',
}
for p,h in bindings.items():
    assert sha(p) == h
    inputs[p] = meta(p)
extras = [
    BASE / 'boundary_probe.R',BASE / 'checks01/boundary_probe.txt',
    BASE / 'checks01/failure_note.md',BASE / 'checks02/failure_note.md',
    ROOT / 'quality_reports/results/mebane_gates/coordination/measfrauds_2022-03-06.pdf',
    ROOT / 'quality_reports/results/mebane_gates/coordination/pm23_2023-07-02.pdf',
    ROOT / 'quality_reports/results/mebane_gates/G2/round1/sources/measfrauds_2022.txt',
    ROOT / 'quality_reports/results/mebane_gates/G2/round1/sources/pm23_2023.txt',
    ROOT / 'quality_reports/results/mebane_gates/G2/round1/sources/measfrauds_page8.png',
    ROOT / 'quality_reports/results/mebane_gates/G2/round1/sources/pm23_page9.png',
    ROOT / 'quality_reports/results/mebane_gates/coordination/2026-09-29_benchmark_round/replication_adjudication.md',
    ROOT / 'quality_reports/results/mebane_gates/coordination/authors_replication_discovery_review/review.md',
    ROOT / 'quality_reports/results/mebane_gates/G2/round3/review/review.md',
]
for p in extras:
    inputs[p] = meta(p)
comparisons = []
for name in ['result.json','multinomial_checks.csv','normalization_choices.csv']:
    candidate = BASE / 'checks03' / name
    reproduction = QA / 'proposal_attempt01/candidate03' / name
    same = candidate.read_bytes() == reproduction.read_bytes()
    assert same, name
    comparisons.append({'file':name,'byte_identical':same})
    inputs[candidate] = meta(candidate)
for report in ['review.json','proposal_review_v1.json','provenance_review.json']:
    doc = read(QA / report)
    assert doc.get('production_approved',False) is False
    assert doc.get('inference_approved',False) is False
write(OUT / 'checks.json',{'exact_bindings_checked':len(bindings),'candidate_reproduction':comparisons,
      'original_inputs_rechecked':len(inputs),'reviews_JSON_parsed':3,'no_failed_check':True})
write(OUT / 'online_source_scope.json',{'date':'2026-09-30','role':'Primary reference cross-check only; no local package update',
      'sources':[{'url':'https://mc-stan.org/docs/functions-reference/multivariate_discrete_distributions.html','version':'2.40'},
                 {'url':'https://mc-stan.org/docs/stan-users-guide/finite-mixtures.html','version':'2.40'},
                 {'url':'https://mc-stan.org/posterior/reference/ess_tail.html','version':'1.7.1'}],
      'byte_archive_of_remote_pages':False,'scope_limit':'Not a complete web archive; mathematical evidence is independently derived and local.'})
for p in QA.rglob('*'):
    if p.is_file(): inputs[p] = meta(p)
manifest = {'schema_version':'1.0','reviewer_thread_id':'01a0ee05-aeaf-7492-a8ea-fa731dd6214a',
            'created_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
            'manifest_complete':True,
            'manifest_complete_scope':'Listed QA artifacts and local input byte identities, checked before sealing; not universal historical runtime closure.',
            'universal_historical_runtime_input_closure':False,'G3_status':'inconclusive',
            'files':[inputs[p] for p in sorted(inputs)],
            'exclusions':['review_manifest.json','final_verification01/manifest_verification.json'],
            'remote_references':'URLs/version/read scope documented in final_verification01/online_source_scope.json; not byte-archived sources.',
            'frozen_proposal_sha256':bindings[BASE / 'proposal_v1.md'],
            'frozen_provenance_manifest_sha256':bindings[BASE / 'provenance_repair/closure_manifest.json']}
write(MANIFEST,manifest)
print(json.dumps({'manifest_sha256':sha(MANIFEST),'entries':len(manifest['files'])}))
