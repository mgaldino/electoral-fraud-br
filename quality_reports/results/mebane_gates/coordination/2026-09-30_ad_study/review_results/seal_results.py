"""Final immutable-input audit and seal of the completed result review."""
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path('/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud')
BASE = ROOT/'quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study'
OUT = BASE/'review_results'
def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream,'sha256').hexdigest()

review = json.loads((OUT/'review.json').read_text())
binding = json.loads((OUT/'input_binding.json').read_text())
for item in binding['files']:
    assert sha(ROOT/item['path']) == item['sha256'],item['path']
for model in ('A','D'):
    metadata = json.loads((BASE/'pilot01'/model/'sampling_metadata.json').read_text())
    contract = json.loads((BASE/'contract_v2.json').read_text())
    model_path = contract['A']['source'] if model=='A' else 'models/experimental/mebane_ad/d_multinomial.jags'
    assert metadata['model_sha256']==sha(ROOT/model_path)
    assert metadata['sampling']==contract['paired_design']
results = json.loads((OUT/'checks_results.json').read_text())
reports = json.loads((OUT/'report_checks.json').read_text())
assert len(results['checks'])==91 and all(x['pass'] for x in results['checks'])
assert len(reports['checks'])==22 and all(x['passed'] for x in reports['checks'])
assert sha(BASE/'comparison01/manifest.json')==review['binding']['comparison_manifest_sha256']
assert sha(BASE/'comparison_A_D_DC2010_v1.pdf')==review['binding']['pdf_sha256']
assert review['findings']==[] and review['status']=='pass'
for item in review['checks']:
    for evidence in item.get('evidence',[]):
        path = ROOT/evidence['path']
        assert path.exists()
        if 'line_start' in evidence:
            assert 1<=evidence['line_start']<=evidence['line_end']<=len(path.read_text().splitlines())
pdf_files = ['comparison_A_D_DC2010_v1.pdf','comparison_A_D_DC2010_v1.manifest.json',
             'visual_qa_v1.json','render_report.py']+[f'comparison_A_D_DC2010_v1_page-{n}.png' for n in (1,2,3)]
with (OUT/'integrity_final.json').open('x') as stream:
    json.dump(dict(created_utc=datetime.now(timezone.utc).isoformat(),
                   pilot_comparison_inputs_unchanged=len(binding['files']),
                   pdf_inputs=[dict(path=str((BASE/p).relative_to(ROOT)),sha256=sha(BASE/p)) for p in pdf_files],
                   actual_result_checks=91,report_pdf_checks=22,findings=0,new_MCMC=False),stream,indent=2)
files = [dict(path=str(p.relative_to(OUT)),bytes=p.stat().st_size,sha256=sha(p))
         for p in sorted(OUT.rglob('*')) if p.is_file()]
with (OUT/'evidence_manifest.json').open('x') as stream:
    json.dump(dict(created_utc=datetime.now(timezone.utc).isoformat(),files=files,
                   excluded='This manifest itself',new_MCMC=False),stream,indent=2)
print(json.dumps(dict(status='pass_fidelity_only',pilot_status='computationally_inconclusive',
                      inputs_unchanged=len(binding['files']),evidence_files=len(files),
                      review_json_sha256=sha(OUT/'review.json'),review_md_sha256=sha(OUT/'review.md'))))
