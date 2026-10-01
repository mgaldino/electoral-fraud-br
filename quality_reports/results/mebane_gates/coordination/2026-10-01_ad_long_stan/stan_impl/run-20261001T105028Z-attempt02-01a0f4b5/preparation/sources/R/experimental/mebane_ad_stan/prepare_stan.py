"""Compile/preflight D in a new scoped directory; never run an empirical fit."""
import argparse
import importlib.util
import os
from pathlib import Path
import shutil
import sys
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("preflight", "prepare"))
    parser.add_argument("repository", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    repo = args.repository.resolve(strict=True)
    output = args.output.resolve()
    scope = repo / "quality_reports/results/mebane_gates/coordination/2026-10-01_ad_long_stan/stan_impl"
    if scope.resolve() not in output.parents:
        raise SystemExit("Output must be a new directory below stan_impl")
    executor_id = os.environ.get("CODEX_THREAD_ID", "")
    if not executor_id:
        raise SystemExit("A real CODEX_THREAD_ID is required")
    output.mkdir(parents=True, exist_ok=False)
    temp = output / "tmp"
    temp.mkdir()
    bootstrap = output / "bootstrap"
    bootstrap.mkdir()
    # These are the Python sources actually executed before the R snapshot.
    this_source = Path(__file__).resolve(strict=True)
    supervisor_source = this_source.with_name("supervise_stan.py")
    for source in (this_source, supervisor_source):
        shutil.copyfile(source, bootstrap / source.name)
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location("stan_supervisor", bootstrap / supervisor_source.name)
    supervisor = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(supervisor)
    prepared = output / "preparation"
    if args.mode == "preflight":
        script = repo / "tests/mebane/ad_stan/run_preflight.R"
        command = ["Rscript", "--vanilla", str(script), str(repo), str(prepared)]
    else:
        script = repo / "R/experimental/mebane_ad_stan/run_stan.R"
        command = ["Rscript", "--vanilla", str(script), "prepare", str(repo), str(prepared)]
    supervisor.write_new(output / "launcher_started.json", {
        "executor_id": executor_id, "command": command, "mode": args.mode,
        "started_epoch": time.time(), "empirical_sampling": False,
        "script_sha256_before_launch": supervisor.sha(script),
        "bootstrap_sources": [{"path": str(p), "sha256": supervisor.sha(p)}
                              for p in sorted(bootstrap.iterdir())]})
    env = dict(os.environ, LC_ALL="C", LANG="C", TMPDIR=str(temp), TMP=str(temp),
               TEMP=str(temp), STAN_NUM_THREADS="1")
    try:
        result = supervisor.run_command(command, output / "launcher.log", 1800, cwd=repo, env=env)
    except Exception as error:
        supervisor.write_new(output / "launcher_error.json", {
            "executor_id": executor_id, "error": repr(error),
            "empirical_sampling": False, "partial_artifacts_retained": True})
        raise
    result["executor_id"] = executor_id
    result["empirical_sampling"] = False
    result["preparation"] = str(prepared)
    supervisor.write_new(output / "launcher_finished.json", result)
    # R has exited: this inventory cannot include still-open logs.
    paths = sorted(p for p in output.rglob("*") if p.is_file())
    supervisor.write_new(output / "launcher_manifest.json", {
        "executor_id": executor_id, "empirical_sampling": False,
        "files": [{"path": str(p), "sha256": supervisor.sha(p)} for p in paths]})
    raise SystemExit(124 if result["timed_out"] else result["exit_code"])


if __name__ == "__main__":
    main()
