import csv
from fractions import Fraction as F
import hashlib
import importlib.util
import json
import time

spec=importlib.util.spec_from_file_location('qa','quality_reports/results/mebane_gates/G3/round1/review/preparation/run_qa.py')
qa=importlib.util.module_from_spec(spec)
spec.loader.exec_module(qa)
base=qa.BASE/'supplement_01'
qa.write(base/'freeze.json',dict(frozen_at=qa.now(),files=[qa.entry(p) for p in sorted(base.iterdir()) if p.is_file()],source=qa.entry(qa.ROOT/qa.SOURCE)))
out=qa.BASE/'attempt_supplement01'
out.mkdir()
start=time.monotonic()
protocol=json.loads((base/'protocol.json').read_text())
rows=[]
for N in protocol['source_grid']['N']:
    for A in range(N+1):
        for rm in range(N+1):
            for rs in range(N+1):
                x=F(A,N)
                m=F('0.999') if rm==N else F(rm,N)
                s=F(rs,N)
                for nu_text in protocol['source_grid']['nu']:
                    nu=F(nu_text)
                    exact=nu*(1-s)/(1-m)*(1-m-x)+x*(m-s)/(1-m)+s
                    xf,mf,sf,nf=map(float,[x,m,s,nu])
                    literal=nf*((1-sf)/(1-mf))*(1-mf-xf)+xf*((mf-sf)/(1-mf))+sf
                    exact_valid=0<=exact<=1
                    numeric_valid=0<=literal<=1
                    rows.append(dict(N=N,A=A,rm=rm,rs=rs,nu=nu_text,exact_fraction=str(exact),
                        exact_float=float(exact),literal_binary64=literal,
                        exact_probability_valid=exact_valid,numeric_probability_valid=numeric_valid,
                        disagreement=exact_valid!=numeric_valid,
                        note='diagnostic only; literal source not changed'))
with (out/'numeric_support.csv').open('x',newline='') as stream:
    writer=csv.DictWriter(stream,fieldnames=rows[0].keys())
    writer.writeheader();writer.writerows(rows)
source=(qa.ROOT/qa.SOURCE).read_text()
code='\n'.join(line.split('#',1)[0] for line in source.splitlines())
compact=''.join(code.split())
blocks=[('tau','tb','th','omt','Xa'),('nu','nb','nh','omn','Xw'),
        ('iota.m','imb','imh','oim','X.iota.m'),('iota.s','isb','ish','ois','X.iota.s'),
        ('chi.m','cmb','cmh','ocm','X.chi.m'),('chi.s','csb','csh','ocs','X.chi.s')]
checks=[]
for b,v,h,o,X in blocks:
    expressions=[f'{v}~dexp(5)',f'{b}.beta<-1/{v}',f'{b}.alpha~dnorm(0,1)',
        f'{h}[j]~dnorm({b}.alpha,{b}.beta)',f'{o}[j]<-inprod({X}[j,],beta.{b}1)',
        f'beta.{b}[i]<-ifelse(i==1,{b}.alpha,beta.{b}1[i])',
        f'sigma.beta.{b}[i,j]<-ifelse(i==j,ifelse(i==1,10000,1),0)',
        f'beta.{b}1~dmnorm(mu.beta.{b},sigma.beta.{b})']
    checks.extend(dict(id=f'{b}:{expr}',pass_check=expr in compact) for expr in expressions)
for b in ['iota.m','iota.s','chi.m','chi.s']:
    expr=f'N.{b}[j]~dbin(mu.{b}[j],N[j])'
    checks.append(dict(id=expr,pass_check=expr in compact))
for expr in ['pi.aux1~dunif(0,1)','pi.aux2~dunif(0,pi.aux1)','pi.aux3~dunif(0,pi.aux1)',
             'a[j]~dbin(p.a[j],N[j])','w[j]~dbin(p.w[j],N[j])']:
    checks.append(dict(id=expr,pass_check=expr in compact))
qa.write(out/'source_checks.json',checks)
qa.write(out/'audit.json',dict(numeric_cases=len(rows),strict_support_disagreements=[r for r in rows if r['disagreement']],
    exact_invalid_states=sum(not r['exact_probability_valid'] for r in rows),
    source_checks_passed=sum(c['pass_check'] for c in checks),source_checks_total=len(checks),
    source_sha256=hashlib.sha256((qa.ROOT/qa.SOURCE).read_bytes()).hexdigest(),
    limitation='Python binary64 is diagnostic, not an assertion of operation ordering in R/JAGS; no source repair or clamp'))
qa.write(out/'execution.json',dict(finished=qa.now(),elapsed_seconds=time.monotonic()-start,exit_code=0,
    input_freeze=qa.entry(base/'freeze.json'),outputs=[qa.entry(p) for p in sorted(out.iterdir()) if p.is_file()]))
print(json.dumps(dict(rows=len(rows),disagreements=sum(r['disagreement'] for r in rows),source_pass=sum(c['pass_check'] for c in checks))))
