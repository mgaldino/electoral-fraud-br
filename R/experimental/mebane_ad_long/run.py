"""Run one independently released JAGS20k pair, retaining all outputs."""
import argparse
import importlib.util
import json
from pathlib import Path

spec=importlib.util.spec_from_file_location("old_supervisor","R/experimental/mebane_ad/run_pair.py")
supervisor=importlib.util.module_from_spec(spec)
spec.loader.exec_module(supervisor)

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("release",type=Path);p.add_argument("output",type=Path)
    args=p.parse_args()
    release=json.loads(args.release.read_text())
    assert release["status"]=="approved_for_JAGS20k"
    for item in release["files"]:
        assert supervisor.sha(item["path"])==item["sha256"],item["path"]
    contract_path=release["contract_path"];data_path=release["data_path"]
    c=json.loads(Path(contract_path).read_text())
    assert c["contract_id"]=="AD-DC2010-LONG-v1" and c["paired_design"]["post_iterations"]==20000
    assert not args.output.exists()
    args.output.mkdir(parents=True)
    supervisor.write_new(args.output/"release_consumed.json",release)
    records=[]
    for kind in ("generation","diagnostics"):
        for model in ("A","D"):
            for item in release["files"]:
                assert supervisor.sha(item["path"])==item["sha256"]
            if kind=="generation":
                cmd=["Rscript","--vanilla","R/experimental/mebane_ad_long/run_jags.R",model,
                     contract_path,data_path,str(args.output/model)]
                stem=f"{model}_supervisor";log=f"{model}_sampling.log"
                timeout=c["paired_design"]["max_elapsed_seconds_per_model"]
            else:
                if not (args.output/model/"run_result.json").exists():continue
                if not (args.output/model/"raw_chains.rds").exists():continue
                cmd=["Rscript","--vanilla","R/experimental/mebane_ad_long/diagnostics.R",
                     str(args.output/model),data_path,contract_path,str(args.output/f"{model}_diagnostics")]
                stem=f"{model}_diagnostics_supervisor";log=f"{model}_diagnostics.log"
                timeout=c["paired_design"]["max_postprocess_seconds_per_model"]
            record=supervisor.run_command(cmd,args.output/log,timeout)
            record.update(model=model,kind=kind)
            supervisor.write_new(args.output/f"{stem}.json",record)
            records.append(record);print(json.dumps(record),flush=True)
    supervisor.write_new(args.output/"execution.json",dict(records=records,retries=0,
        release_sha256=supervisor.sha(args.release),production_approved=False))

if __name__=="__main__":main()
