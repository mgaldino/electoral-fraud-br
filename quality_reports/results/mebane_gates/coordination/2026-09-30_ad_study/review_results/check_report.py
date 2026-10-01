"""Reproduce the report from frozen outputs and check PDF/text/numeric fidelity."""
import csv
import hashlib
import json
import os
import re
import subprocess
import unicodedata
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path('/Users/manoelgaldino/Documents/DCP/Papers/electoralFraud')
S = Path('quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study')
BASE = ROOT/S
OUT = BASE/'review_results'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
env = dict(os.environ, LC_ALL='C',LANG='C',PYTHONDONTWRITEBYTECODE='1')
contract = str(S/'contract_v2.json')
data = str(S/'data/run-20260930T235038Z-pid61600/dc2010_ad_data.rds')
commands = [
    ('comparison_fixtures', ['Rscript','--vanilla','tests/mebane/ad_study/test_comparison.R',
                              contract,data,str(OUT/'comparison_fixtures')]),
    ('comparison_recomputed', ['Rscript','--vanilla','R/experimental/mebane_ad/compare_runs.R',
                                 str(S/'pilot01'),contract,data,str(OUT/'comparison_recomputed')]),
    ('pdf_text', ['pdftotext','-layout',str(BASE/'comparison_A_D_DC2010_v1.pdf'),str(OUT/'pdf_text.txt')]),
    ('pdf_info', ['pdfinfo',str(BASE/'comparison_A_D_DC2010_v1.pdf')])
]
logs = []
for name, command in commands:
    log = OUT/(name+'.log')
    with log.open('x') as stream:
        started = datetime.now(timezone.utc).isoformat()
        result = subprocess.run(command,cwd=ROOT,env=env,stdout=stream,stderr=subprocess.STDOUT,timeout=90)
    logs.append(dict(name=name,command=command,started_utc=started,
                     finished_utc=datetime.now(timezone.utc).isoformat(),exit_code=result.returncode,
                     log=str(log.relative_to(OUT)),log_sha256=sha(log)))
    assert result.returncode==0, name

checks = []
def check(name, passed, detail=None):
    checks.append(dict(check=name,passed=bool(passed),detail=detail))
    print(name,bool(passed),flush=True)
    assert passed,name

for file in ['timings_diagnostics.csv','common_functionals.csv','class_probabilities_compared.csv',
             'comparison_result.json','comparison_report.md']:
    check('reproduced-byte-identical-'+file,sha(OUT/'comparison_recomputed'/file)==sha(BASE/'comparison01'/file))
check('pdf-fixed-sha',sha(BASE/'comparison_A_D_DC2010_v1.pdf')=='7d518b6a641b9793497264ec9eef261517c927f5610f858111f6610ee8389d6b')
check('markdown-fixed-sha',sha(BASE/'comparison01/comparison_report.md')=='7ce47502798661813f976c0bf975af30e7a10237c70d23afd44baad01e682f50')
check('three-pdf-pages',bool(re.search(r'^Pages:\s+3\s*$',(OUT/'pdf_info.log').read_text(),re.M)))
pdf = (OUT/'pdf_text.txt').read_text()
pdf = '\n'.join(line for line in pdf.splitlines() if not line.strip().startswith('Estudo A/D')
                and not re.fullmatch(r'\s*[123]\s*',line))
compact = lambda s: re.sub(r'\W+','',unicodedata.normalize('NFKC',s).casefold())
pdf_compact = compact(pdf)
md = (BASE/'comparison01/comparison_report.md').read_text()
units = []
for line in md.splitlines():
    if not line.strip() or re.fullmatch(r'[|:\- ]+',line):
        continue
    text = re.sub(r'\[([^]]+)\]\([^)]+\)',r'\1',line)
    text = re.sub(r'^#+\s*','',text).replace('**','').replace('`','')
    units.append(dict(text=text,present=compact(text) in pdf_compact))
check('all-markdown-paragraphs-headings-table-rows-in-PDF',all(x['present'] for x in units),len(units))
check('table-one-header-repeated',pdf.count('A: qbl literal')==2)

with (OUT/'globals_recomputed.csv').open() as stream:
    globals_ = list(csv.DictReader(stream))
with (BASE/'comparison01/timings_diagnostics.csv').open() as stream:
    timing = {r['model']:r for r in csv.DictReader(stream)}
def pt(value,digits):
    return f'{float(value):,.{digits}f}'.replace(',','X').replace('.',',').replace('X','.')
rows = {cells[0]:cells[1:] for line in md.splitlines() if line.startswith('|')
        for cells in [[x.strip() for x in line.strip('|').split('|')]]}
fields = {
    'Geração: processo completo (s)':('total_process_seconds',2),
    'Preparação interna (s)':('setup_seconds',2),
    'Amostragem (s)':('sample_seconds',2),
    'Persistência dos draws (s)':('persistence_seconds',2),
    'Pós-processamento: processo (s)':('postprocess_seconds',2),
    'Geração + pós-processamento (s)':('end_to_end_compute_seconds',2),
    'R-hat máximo, globais':('global_rhat_max',3),
    'ESS bulk mínimo, globais':('global_bulk_ESS_min',2),
    'ESS cauda mínimo, globais':('global_tail_ESS_min',2),
    'Alvos obrigatórios reprovados':('failed_targets',0),
    'Alvos com diagnóstico obrigatório indefinido':('undefined_targets',0)}
check('all-table-one-values-and-rounding',all(rows[label]==[pt(timing[m][field],digits) for m in ('A','D')]
      for label,(field,digits) in fields.items()))
for target in ('pi[1]','pi[2]','pi[3]','M_total','S_total'):
    expected = [pt(next(r['mean'] for r in globals_ if r['model']==m and r['target']==target),
                   4 if target.startswith('pi') else 1) for m in ('A','D')]
    check('table-two-independent-raw-'+target,rows[target]==expected)
for phrase in ('computacionalmente inconclusiva','não estimativas validadas de fraude',
               'não certifica reprodução de uma tabela publicada pelos autores',
               'não aprova G10','G3 histórico permanece inconclusivo',
               'esses valores não estabelecem superioridade de uma alternativa'):
    check('scope-'+phrase,phrase in md)

with (OUT/'report_checks.json').open('x') as stream:
    json.dump(dict(status='pass',created_utc=datetime.now(timezone.utc).isoformat(),
                   checks=checks,commands=logs,pdf_text_units=units,
                   visual_inspection='All three provided PNG pages independently viewed; no clipping/overlap; continued table header repeated.',
                   source_pdf_sha256=sha(BASE/'comparison_A_D_DC2010_v1.pdf'),
                   empirical_MCMC=False),stream,indent=2,ensure_ascii=False)
print('PASS',len(checks),'report/PDF checks; no MCMC')
