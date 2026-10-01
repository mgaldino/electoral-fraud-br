"""Keep the first PDF check; use reading-order extraction for a wrapped table cell."""
import json
from pathlib import Path

OUT = Path('/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud/quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/review_results')
old = (OUT/'check_report.py').read_text()
start = old.index('logs = []\n')
end = old.index('checks = []\n')
replacement = '''logs = []
for name, command in commands:
    log = OUT/(name+'.log')
    assert log.exists()
    logs.append(dict(name=name,command=command,exit_code=0,
                     evidence='Completed in initial attempt before text-order assertion; not rerun',
                     log=str(log.relative_to(OUT)),log_sha256=sha(log)))
raw_command = ['pdftotext','-raw',str(BASE/'comparison_A_D_DC2010_v1.pdf'),str(OUT/'pdf_text_reading_order.txt')]
with (OUT/'pdf_reading_order.log').open('x') as stream:
    value = subprocess.run(raw_command,cwd=ROOT,env=env,stdout=stream,stderr=subprocess.STDOUT,timeout=30)
assert value.returncode==0
logs.append(dict(name='pdf_reading_order',command=raw_command,exit_code=value.returncode))

'''
new = old[:start]+replacement+old[end:]
new = new.replace("pdf = (OUT/'pdf_text.txt').read_text()", "pdf = (OUT/'pdf_text_reading_order.txt').read_text()")
with (OUT/'check_report_attempt2.py').open('x') as stream:
    stream.write(new)
with (OUT/'report_attempt1_explanation.json').open('x') as stream:
    json.dump(dict(status='extraction_order_artifact_not_candidate_finding',
                   unmatched_markdown_line=33,
                   text='Alvos com diagnóstico obrigatório indefinido | 432 | 392',
                   cause='pdftotext -layout interleaves 432/392 before the wrapped word indefinido. Visual inspection shows the complete label in its cell.',
                   correction='Read-only pdftotext -raw extraction; retain original layout text and check source. No PDF or report edited.',
                   completed_before_failure='Four synthetic reporter cases, byte-identical actual reproduction, PDF/MD hashes and 3 pages all passed.',
                   candidate_modified=False),stream,indent=2,ensure_ascii=False)
