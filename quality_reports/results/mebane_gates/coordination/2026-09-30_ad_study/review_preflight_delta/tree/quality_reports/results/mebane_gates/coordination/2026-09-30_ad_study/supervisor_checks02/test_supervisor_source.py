"""Exercise only subprocess failure/timeout handling; never invoke either model."""

import argparse
import importlib.util
import json
import shutil
import sys
import time
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    assert not args.output.exists()
    args.output.mkdir(parents=True)
    source = Path("R/experimental/mebane_ad/run_pair.py")
    spec = importlib.util.spec_from_file_location("ad_supervisor", source)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    shutil.copyfile(source, args.output / "run_pair_source.py")
    shutil.copyfile(__file__, args.output / "test_supervisor_source.py")
    records = []
    for name, script, timeout in [
            ("success", "print('one successful invocation')", 5),
            ("failure", "raise SystemExit(7)", 5),
            ("timeout", "import time; time.sleep(30)", 0.2)]:
        record = module.run_command([sys.executable, "-c", script],
                                    args.output / f"{name}.log", timeout)
        record["fixture"] = name
        records.append(record)
    assert records[0]["returncode"] == 0 and not records[0]["timed_out"]
    assert records[1]["returncode"] == 7 and not records[1]["timed_out"]
    assert records[2]["returncode"] != 0 and records[2]["timed_out"]
    assert records[2]["elapsed_seconds"] < 12
    child = "import signal,time; signal.signal(signal.SIGTERM,signal.SIG_IGN); print('child-ready',flush=True); time.sleep(.5); print('late-write',flush=True)"
    parent = f"import subprocess,sys,time; subprocess.Popen([sys.executable,'-c',{child!r}]); time.sleep(30)"
    record = module.run_command([sys.executable, "-c", parent],
                                args.output / "descendant.log", .2)
    time.sleep(.7)
    assert record["timed_out"] and record["log_sha256"] == module.sha(args.output / "descendant.log")
    assert "late-write" not in (args.output / "descendant.log").read_text()
    record["fixture"] = "descendant_ignores_SIGTERM"
    records.append(record)
    try:
        module.run_command([sys.executable, "-c", "raise SystemExit(99)"],
                            args.output / "success.log", 5)
    except FileExistsError:
        overwrite_refused = True
    else:
        overwrite_refused = False
    assert overwrite_refused
    module.write_new(args.output / "result.json", {
        "status": "pass", "fixtures": records, "overwrite_refused": True,
        "MCMC": False, "supervisor_sha256": module.sha(source),
        "test_sha256": module.sha(__file__)})
    print(json.dumps({"status": "pass", "fixtures": len(records),
                      "overwrite_refused": overwrite_refused, "MCMC": False}))


if __name__ == "__main__":
    main()
