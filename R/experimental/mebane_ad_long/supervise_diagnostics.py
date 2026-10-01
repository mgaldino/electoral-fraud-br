"""Apply the previously reviewed timeout to the Stan diagnostic adapter."""
import argparse
import importlib.util
from pathlib import Path

spec = importlib.util.spec_from_file_location("ad_supervisor", "R/experimental/mebane_ad/run_pair.py")
supervisor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(supervisor)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("run", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    assert not args.output.exists()
    log = args.output.with_name(args.output.name + ".log")
    result = args.output.with_name(args.output.name + "_supervisor.json")
    assert not log.exists() and not result.exists()
    command = ["Rscript", "--vanilla", "R/experimental/mebane_ad_long/postprocess_stan.R",
               str(args.run), str(args.output)]
    record = supervisor.run_command(command, log, 3600)
    supervisor.write_new(result, record)
    print(record)
