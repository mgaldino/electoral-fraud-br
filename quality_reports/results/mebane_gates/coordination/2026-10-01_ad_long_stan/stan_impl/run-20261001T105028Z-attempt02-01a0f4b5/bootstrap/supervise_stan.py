"""External timeout for a QA-authorized Stan run; retains partial output on failure."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import time


def write_new(path, payload):
    with path.open("x", encoding="utf-8") as stream:
        json.dump(payload, stream, indent=2)
        stream.write("\n")


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def run_command(command, log_path, timeout, *, cwd=None, env=None, grace_seconds=10):
    """Retain logs and kill the process group even if its leader exits first.

    This is the timeout pattern in mebane_ad/run_pair.py, kept independent
    so that the earlier frozen supervisor remains unchanged.
    """
    start = time.monotonic()
    with log_path.open("x", encoding="utf-8") as log:
        process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT,
                                   cwd=cwd, env=env, start_new_session=True)
        timed_out = False
        try:
            code = process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                process.wait(timeout=grace_seconds)
            except subprocess.TimeoutExpired:
                pass
            # The leader may have exited while a descendant ignores SIGTERM.
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            code = process.wait()
    return {"command": command, "exit_code": code, "timed_out": timed_out,
            "wall_seconds": time.monotonic() - start, "console_sha256": sha(log_path),
            "partial_artifacts_retained": True, "automatic_retry": False}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("preparation", type=Path)
    parser.add_argument("qa", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    preparation = args.preparation.resolve(strict=True)
    qa = args.qa.resolve(strict=True)
    manifest_path = preparation / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    review = json.loads(qa.read_text(encoding="utf-8"))
    digest = sha(manifest_path)
    executor_id = os.environ.get("CODEX_THREAD_ID", "")
    if not executor_id:
        raise SystemExit("A real CODEX_THREAD_ID is required")
    if (manifest.get("status") != "prepared_awaiting_independent_QA"
            or review.get("status") != "PASS"
            or not review.get("reviewer_id")
            or review["reviewer_id"] == manifest["executor_id"]
            or review.get("preparation_manifest_sha256") != digest):
        raise SystemExit("Independent PASS bound to the preparation is required")
    for item in manifest["files"]:
        if sha(item["path"]) != item["sha256"]:
            raise SystemExit("Prepared file changed: " + item["path"])
    frozen_supervisor = preparation / "sources/R/experimental/mebane_ad_stan/supervise_stan.py"
    if sha(__file__) != sha(frozen_supervisor):
        raise SystemExit("Use the supervisor from this preparation's source snapshot")
    args.output.mkdir(parents=True, exist_ok=False)
    output = args.output.resolve()
    (output / "tmp").mkdir()
    runner = preparation / "sources/R/experimental/mebane_ad_stan/run_stan.R"
    command = ["Rscript", "--vanilla", str(runner), "sample", str(preparation), str(qa), str(output)]
    env = dict(os.environ, LC_ALL="C", LANG="C", AD_STAN_SUPERVISED="1",
               TMPDIR=str(output / "tmp"), TMP=str(output / "tmp"),
               TEMP=str(output / "tmp"), STAN_NUM_THREADS="1")
    write_new(output / "supervisor_started.json", {
        "command": command, "timeout_seconds": 3600, "preparation_sha256": digest,
        "executor_id": executor_id, "qa_sha256": sha(qa),
        "supervisor_sha256": sha(__file__), "started_epoch": time.time(),
        "cwd": manifest["repository_root"]})
    try:
        result = run_command(command, output / "console.log", 3600,
                             cwd=manifest["repository_root"], env=env)
    except Exception as error:
        write_new(output / "supervisor_error.json", {
            "executor_id": executor_id, "error": repr(error),
            "partial_artifacts_retained": True, "automatic_retry": False})
        raise
    result["executor_id"] = executor_id
    write_new(output / "supervisor_finished.json", result)
    raise SystemExit(124 if result["timed_out"] else result["exit_code"])


if __name__ == "__main__":
    main()
