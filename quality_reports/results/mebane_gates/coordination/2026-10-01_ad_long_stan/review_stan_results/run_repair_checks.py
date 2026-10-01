"""Source-bound, read-only diagnostic-representation repair QA. No final-results QA."""
import argparse
import difflib
import hashlib
import json
import os
from pathlib import Path
import subprocess
from datetime import datetime, timezone

REVIEWER = "01a0f717-7535-72e3-baf8-4db20da81abb"
NEW = Path("quality_reports/results/mebane_gates/coordination/2026-10-01_ad_long_stan")
SCOPE = NEW / "review_stan_results"
REPAIR_SHA = "cd9540e5df61933740a61c65800b63030163c045f539e593c73f8f2c96abf78b"
ADAPTER_SHA = "3562d593731cec1fe156ee52266a975cd0cbf6d6fe8666c26b15652298bb08b0"
PREP_SHA = "2ad3246c3b1a5b5e0c676a85434824644b440cc75c386bc45feeabc34b789bfb"
PREP = NEW / "stan_impl/run-20261001T105406Z-attempt03-01a0f4b5/preparation"
INSERTION = '''  representation <- list(draws_class=class(draws),sampler_class=class(sampler),
                         draws_shape=dim(draws),sampler_shape=dim(sampler))
  # posterior's as.matrix() merges chains; the reviewed adapter expects base arrays.
  draws <- unclass(draws)
  sampler <- unclass(sampler)
  stopifnot(is.array(draws),is.array(sampler),
            identical(dim(draws),representation$draws_shape),
            identical(dim(sampler),representation$sampler_shape))
  ad_json(representation,file.path(out,"input_representation.json"))
'''


def sha(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def write_json(path, value):
    with path.open("x", encoding="utf-8") as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write("\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--released-scope", required=True, choices=["diagnostic-repair-only"])
    parser.add_argument("--attempt", required=True)
    args = parser.parse_args()
    if not args.attempt.startswith("repair_checks") or not args.attempt.replace("_", "").isalnum():
        raise ValueError("A new repair_checksNN attempt is required")
    root = Path.cwd().resolve()
    if Path(__file__).resolve().parent != root / SCOPE:
        raise ValueError("Run from the repository root")
    out = root / SCOPE / args.attempt
    out.mkdir()
    bindings = {}
    checks = []

    def path_in_repo(value):
        path = (root / value).resolve()
        path.relative_to(root)
        return path

    def check(name, ok, evidence=None):
        checks.append({"id": name, "pass": bool(ok), "evidence": evidence})
        if not ok:
            raise RuntimeError(name)

    def bind(value, expected=None, authority="frozen_manifest"):
        path = path_in_repo(value)
        actual = sha(path)
        relative = str(path.relative_to(root))
        if expected is not None:
            check("sha256:" + relative, actual == expected, {"expected": expected, "actual": actual})
        if relative in bindings:
            check("repeated_input_unchanged:" + relative, bindings[relative]["sha256"] == actual)
        bindings[relative] = {"path": relative, "sha256": actual, "bytes": path.stat().st_size,
                              "authority": authority if expected else "observed_precheck_baseline"}
        return path

    def read_bound_manifest(path, expected):
        return json.loads(bind(path, expected, "user_provided_sha256").read_text())

    error = None
    r_exit = None
    failed_files_before = []
    try:
        repair = read_bound_manifest(NEW / "stan_diagnostic_repair_candidate.json", REPAIR_SHA)
        for entry in repair["files"]:
            bind(entry["path"], entry["sha256"])
        adapter = read_bound_manifest(NEW / "stan_diagnostic_candidate/manifest.json", ADAPTER_SHA)
        for entry in adapter["files"]:
            bind(entry["path"], entry["sha256"])
            bind(entry["snapshot"], entry["sha256"])
        preparation = read_bound_manifest(PREP / "manifest.json", PREP_SHA)
        for entry in preparation["files"]:
            bind(entry["path"], entry["sha256"])
        for source in ("models/experimental/mebane_ad_stan/d_multinomial.stan",
                       "models/experimental/mebane_ad/d_multinomial.jags",
                       "R/experimental/mebane_ad_stan/run_stan.R"):
            snapshot = str((root / PREP / "sources" / source).resolve())
            entry = next(item for item in preparation["files"] if item["path"] == snapshot)
            bind(source, entry["sha256"])
        sample = json.loads((root / NEW / "stan2k01/manifest.json").read_text())
        check("independent_reviewer", sample["executor_id"] != REVIEWER and preparation["executor_id"] != REVIEWER)
        check("sampling_bound_to_preparation", sample["preparation_manifest_sha256"] == PREP_SHA)
        for name in ("draws_array.rds", "sampler_diagnostics.rds"):
            full = str((root / NEW / "stan2k01" / name).resolve())
            entry = next(item for item in sample["artifacts"] if item["path"] == full)
            bind(entry["path"], entry["sha256"])
        bind(NEW / "review/stan/review.json", sample["qa_sha256"])
        failed_root = root / NEW / "stan_diagnostics01"
        failed_files_before = sorted(str(path.relative_to(root)) for path in failed_root.rglob("*") if path.is_file())
        for path in failed_files_before:
            if path not in bindings:
                bind(path)
        failed_sources = json.loads((failed_root / "sources/manifest.json").read_text())
        for entry in failed_sources["files"]:
            bind(entry["path"], entry["sha256"], "preserved_failure_source_manifest")
            bind(entry["snapshot"], entry["sha256"], "preserved_failure_source_manifest")
        failed_supervisor = json.loads((root / NEW / "stan_diagnostics01_supervisor.json").read_text())
        check("failed_attempt_retained", failed_supervisor["returncode"] == 1 and not failed_supervisor["timed_out"])
        check("failure_log_bound", sha(root / failed_supervisor["log"]) == failed_supervisor["log_sha256"])
        old = root / "R/experimental/mebane_ad_long/postprocess_stan.R"
        revised = root / "R/experimental/mebane_ad_long/postprocess_stan_v2.R"
        old_text, new_text = old.read_text(), revised.read_text()
        check("one_representation_block", new_text.count(INSERTION) == 1)
        restored = new_text.replace(INSERTION, "").replace("postprocess_stan_v2.R", "postprocess_stan.R")
        check("wrapper_diff_only_local_normalization_and_snapshot_path", restored == old_text)
        old_supervisor = root / "R/experimental/mebane_ad_long/supervise_diagnostics.py"
        new_supervisor = root / "R/experimental/mebane_ad_long/supervise_diagnostics_v2.py"
        check("supervisor_diff_only_wrapper_path", new_supervisor.read_text().replace(
            "postprocess_stan_v2.R", "postprocess_stan.R") == old_supervisor.read_text())
        with (out / "scoped_source.diff").open("x") as stream:
            for before, after in ((old, revised), (old_supervisor, new_supervisor)):
                stream.writelines(difflib.unified_diff(before.read_text().splitlines(True),
                    after.read_text().splitlines(True), fromfile=str(before.relative_to(root)),
                    tofile=str(after.relative_to(root))))
        bind(SCOPE / "repair_checks.R", authority="reviewer_source")
        bind(SCOPE / "run_repair_checks.py", authority="reviewer_source")
        write_json(out / "input_binding.json", {"reviewer_id": REVIEWER, "repair_sha256": REPAIR_SHA,
            "created_utc": datetime.now(timezone.utc).isoformat(), "inputs": list(bindings.values()),
            "scope": "diagnostic_representation_repair_only", "final_result_QA_released": False})
        env = dict(os.environ, STAN_REPAIR_QA_RELEASED="diagnostic-repair-only")
        with (out / "R_checks.log").open("x") as stream:
            result = subprocess.run(["Rscript", "--vanilla", str(root / SCOPE / "repair_checks.R"), str(out)],
                cwd=root, env=env, stdout=stream, stderr=subprocess.STDOUT, timeout=180, check=False)
        r_exit = result.returncode
        check("independent_R_representation_checks", r_exit == 0)
    except Exception as exc:
        error = str(exc)
    preservation = []
    for relative, entry in bindings.items():
        path = root / relative
        actual = sha(path) if path.is_file() else None
        preservation.append({"path": relative, "before_sha256": entry["sha256"],
                             "after_sha256": actual, "unchanged": actual == entry["sha256"]})
    files_after = sorted(str(path.relative_to(root)) for path in (root / NEW / "stan_diagnostics01").rglob("*") if path.is_file())
    unchanged = all(item["unchanged"] for item in preservation) and failed_files_before == files_after
    write_json(out / "preservation_checks.json", {"all_inputs_unchanged": unchanged,
        "failed_attempt_file_inventory_unchanged": failed_files_before == files_after,
        "files": preservation})
    status = "pass" if error is None and unchanged else "needs_revision"
    write_json(out / "repair_checks.json", {"status": status, "reviewer_id": REVIEWER,
        "repair_candidate_sha256": REPAIR_SHA, "checks": checks, "error": error, "R_exit_code": r_exit,
        "all_bound_inputs_unchanged": unchanged, "full_postprocessor_executed": False,
        "final_result_QA_executed": False, "goal_complete": False})
    artifacts = [{"path": str(path.relative_to(root)), "sha256": sha(path), "bytes": path.stat().st_size}
                 for path in sorted(out.iterdir()) if path.is_file()]
    write_json(out / "checks_manifest.json", {"reviewer_id": REVIEWER, "files": artifacts})
    print(json.dumps({"status": status, "output": str(out), "checks": len(checks),
        "R_exit_code": r_exit, "inputs": len(bindings), "all_inputs_unchanged": unchanged, "error": error}))
    return 0 if status == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
