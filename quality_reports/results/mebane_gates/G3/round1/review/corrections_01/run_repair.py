import importlib.util
import json
import os
import signal
import subprocess
import time

path = 'quality_reports/results/mebane_gates/G3/round1/review/preparation/run_qa.py'
spec = importlib.util.spec_from_file_location('qa',path)
qa = importlib.util.module_from_spec(spec)
spec.loader.exec_module(qa)
base = qa.BASE / 'corrections_01'
qa.write(base/'freeze.json',dict(frozen_at=qa.now(),files=[qa.entry(p) for p in sorted(base.iterdir()) if p.is_file()],
    inputs=[qa.entry(p) for p in sorted((qa.BASE/'attempt_20260929T164413891477Z_wrapper').glob('*.rds'))]+
           [qa.entry(qa.BASE/'attempt_20260929T164404110482Z_math/v2_conditioned_exact_states.csv')],
    original_freeze=qa.entry(qa.BASE/'freeze_01/freeze.json')))
out = qa.BASE/'attempt_correction01_wrapper'
out.mkdir()
env=os.environ.copy()
env.update(LC_ALL='en_US.UTF-8',R_LIBS_USER=str(qa.ROOT/'renv/library/macos/R-4.4/aarch64-apple-darwin20'))
cmd=['/usr/local/bin/Rscript','--vanilla',str(base/'verify_repairs.R'),str(out)]
qa.write(out/'invocation.json',dict(started=qa.now(),command=cmd,timeout_seconds=110,freeze=qa.entry(base/'freeze.json')))
start=time.monotonic()
timed_out=False
with (out/'stdout.log').open('xb') as stdout,(out/'stderr.log').open('xb') as stderr:
    p=subprocess.Popen(cmd,cwd=qa.ROOT,env=env,stdout=stdout,stderr=stderr,start_new_session=True)
    try:
        code=p.wait(timeout=110)
    except subprocess.TimeoutExpired:
        timed_out=True
        os.killpg(p.pid,signal.SIGKILL)
        code=p.wait()
elapsed=time.monotonic()-start
qa.write(out/'execution.json',dict(finished=qa.now(),exit_code=code,pid=p.pid,elapsed_seconds=elapsed,timed_out=timed_out,
    outputs=[qa.entry(p) for p in sorted(out.rglob('*')) if p.is_file()]))
print(json.dumps(dict(path=str(out),exit_code=code,seconds=elapsed)))
