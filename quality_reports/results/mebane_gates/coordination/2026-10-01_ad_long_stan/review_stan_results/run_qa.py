#!/usr/bin/env python3
"""Execute only after explicit release; never fits or compiles a model."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

REVIEWER = "01a0f717-7535-72e3-baf8-4db20da81abb"
NEW = Path("quality_reports/results/mebane_gates/coordination/2026-10-01_ad_long_stan")
SCOPE = NEW / "review_stan_results"
PREPARATION = NEW / "stan_impl/run-20261001T105406Z-attempt03-01a0f4b5/preparation/manifest.json"
ADAPTER = NEW / "stan_diagnostic_candidate/manifest.json"
DIAGNOSTICS = NEW / "stan_diagnostics02"
DIAGNOSTIC_SUPERVISOR = NEW / "stan_diagnostics02_supervisor.json"
REPAIR = NEW / "stan_diagnostic_repair_candidate.json"
REPAIR_REVIEW = SCOPE / "repair_review.json"
PINS = {
    PREPARATION: "2ad3246c3b1a5b5e0c676a85434824644b440cc75c386bc45feeabc34b789bfb",
    ADAPTER: "3562d593731cec1fe156ee52266a975cd0cbf6d6fe8666c26b15652298bb08b0",
    REPAIR: "cd9540e5df61933740a61c65800b63030163c045f539e593c73f8f2c96abf78b",
    REPAIR_REVIEW: "daf6cac7ab6fdb5ecd64c199b95c7268cc9c426c961440a5da17988fb4c2c1d6",
    NEW / "contract.json": "fb4a296c9bf0af25812d7d8dd2ab63340fe10d4e73e806e64b5dba3f7dcf481a",
    NEW / "contract_stan_diagnostics.json": "e33a59939f0d55513fea6ae05a2cc90fac617f3385193ec56e4a2a7a9b6df264",
    NEW / "review_jags_results/review.json": "d68a96b2a351d1caf8e7deb3bb84327a885b866ef8df373bc8513ec299fa9ac9",
    NEW / "comparison_jags01/manifest.json": "0ad269a9254a658a469ad5bcd15f9a29f4131de6bd44bc7d71e266ae1c531ccf",
    Path("quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study/data/"
         "run-20260930T235038Z-pid61600/dc2010_ad_data.rds"):
        "b2ef611dabb751f9286acbaae841a23c34948ed0a4b6306364cbe94d9d24903e",
}


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path, value):
    with path.open("x", encoding="utf-8") as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2, allow_nan=False)
        stream.write("\n")


def sha(path):
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--release", required=True, type=Path)
    parser.add_argument("--attempt", required=True, help="Fresh directory name inside review_stan_results")
    parser.add_argument("--stage", choices=("numerical", "delivery", "all"), default="all")
    parser.add_argument("--numerical-attempt", help="Completed earlier attempt to reuse for delivery-only QA")
    parser.add_argument("--render-pdf", action="store_true")
    args = parser.parse_args()
    repo = Path.cwd().resolve()
    scope = (repo / SCOPE).resolve()
    release_path = args.release.resolve(strict=True)
    if not release_path.is_relative_to(scope):
        raise SystemExit("The release record must be in the review write scope.")
    release = read_json(release_path)
    if release.get("execution_window_released") is not True or not release.get("authorization_reference"):
        raise SystemExit("Await the user's execution window and frozen result hashes.")
    if release.get("analysis_mode") not in {"completed", "preserved_failure"}:
        raise SystemExit("Set the observed scope: completed or preserved_failure.")
    if not re.fullmatch(r"attempt[0-9]{2,}", args.attempt):
        raise SystemExit("Use a fresh attemptNN name.")
    attempt = scope / args.attempt
    attempt.mkdir(exist_ok=False)
    verified = {}

    def path_in_repo(path):
        candidate = Path(path)
        candidate = (repo / candidate).resolve() if not candidate.is_absolute() else candidate.resolve()
        if not candidate.is_relative_to(repo):
            raise ValueError(f"Out-of-repository input: {candidate}")
        return candidate

    def verify(path, expected):
        candidate = path_in_repo(path)
        if not isinstance(expected, str) or not re.fullmatch(r"[a-f0-9]{64}", expected):
            raise ValueError(f"Missing frozen SHA256 for {candidate}")
        actual = sha(candidate)
        if actual != expected:
            raise ValueError(f"SHA256 mismatch for {candidate}: {actual}")
        key = str(candidate.relative_to(repo))
        verified[key] = {"sha256": actual, "bytes": candidate.stat().st_size}
        return candidate

    def verify_manifest(path):
        manifest = read_json(path_in_repo(path))
        entries = manifest.get("files", manifest.get("artifacts"))
        if not isinstance(entries, list):
            raise ValueError(f"No files/artifacts array: {path}")
        for entry in entries:
            current = verify(entry["path"], entry["sha256"])
            if "bytes" in entry and current.stat().st_size != entry["bytes"]:
                raise ValueError(f"Size mismatch: {current}")
            if entry.get("snapshot"):
                verify(entry["snapshot"], entry["sha256"])
        return len(entries)

    def execute(command, name):
        environment = dict(os.environ, LC_ALL="C", LANG="C", PYTHONDONTWRITEBYTECODE="1",
                           STAN_RESULTS_QA_RELEASED="1")
        with (attempt / name).open("x", encoding="utf-8") as log:
            process = subprocess.run(command, cwd=repo, env=environment, stdout=log, stderr=subprocess.STDOUT)
        if process.returncode:
            raise RuntimeError(f"Review checker stopped ({process.returncode}); inspect {name}")

    try:
        for path, expected in PINS.items():
            verify(path, expected)
        preparation = read_json(repo / PREPARATION)
        preflight = read_json(repo / NEW / "review/stan/review.json")
        if (preflight.get("status") != "PASS" or
                preflight.get("preparation_manifest_sha256") != PINS[PREPARATION] or
                preflight.get("adapter_manifest_sha256") != PINS[ADAPTER]):
            raise ValueError("Preflight PASS is not bound to the supplied preparation and adapter.")
        if REVIEWER in {preparation.get("executor_id"), preflight.get("coordinator_id"),
                        preflight.get("candidate_executor_id")}:
            raise ValueError("Reviewer and executor identities must differ.")
        counts = {str(PREPARATION): verify_manifest(PREPARATION), str(ADAPTER): verify_manifest(ADAPTER),
                  str(REPAIR): verify_manifest(REPAIR)}
        repair_review = read_json(repo / REPAIR_REVIEW)
        if (repair_review.get("status") != "pass" or repair_review.get("reviewer_id") != REVIEWER or
                repair_review["candidate"]["sha256"] != PINS[REPAIR]):
            raise ValueError("Repair is not bound to the independent scoped PASS.")
        for entry in repair_review["evidence"]:
            verify(SCOPE / entry["path"], entry["sha256"])

        supplied = release.get("input_hashes", {})
        for path, expected in supplied.items():
            verify(path, expected)
        candidate_manifest = NEW / "results_candidate_manifest.json"
        if str(candidate_manifest) not in verified:
            raise ValueError("Bind the user-released final results candidate manifest.")
        counts[str(candidate_manifest)] = verify_manifest(candidate_manifest)
        if counts[str(candidate_manifest)] != 45:
            raise ValueError("The released candidate must contain its 45 explicit files.")
        required = [NEW / "stan2k01/supervisor_finished.json"]
        numerical_requested = args.stage in {"numerical", "all"}
        delivery_requested = args.stage in {"delivery", "all"} and bool(release.get("report_markdown"))
        if args.stage == "delivery" and not delivery_requested:
            raise ValueError("Delivery-only QA needs the frozen Markdown path and PDF.")
        if release["analysis_mode"] == "completed" and args.stage == "all" and not delivery_requested:
            raise ValueError("Complete delivery QA needs the frozen Markdown path and PDF.")
        if args.render_pdf and not delivery_requested:
            raise ValueError("PDF rendering belongs to a released delivery stage.")
        report_pdf = NEW / "comparison_JAGS20k_Stan2k_DC2010_v1.pdf"
        if delivery_requested:
            required.extend([NEW / "comparison_final01/manifest.json", Path(release["report_markdown"]), report_pdf])
        if release["analysis_mode"] == "completed":
            required.extend([NEW / "stan2k01/manifest.json", DIAGNOSTICS / "manifest.json",
                             DIAGNOSTIC_SUPERVISOR, NEW / "stan_diagnostics01_supervisor.json"])
        elif not release.get("failure_manifest"):
            raise ValueError("Preserved-failure scope needs its frozen inventory manifest.")
        else:
            required.append(Path(release["failure_manifest"]))
        for path in required:
            if str(path_in_repo(path).relative_to(repo)) not in verified:
                raise ValueError(f"A released SHA256 is required for {path}")

        for path in [NEW / "stan2k01/manifest.json", DIAGNOSTICS / "manifest.json",
                     NEW / "comparison_final01/manifest.json"]:
            if str(path) in verified:
                counts[str(path)] = verify_manifest(path)
        for path in [DIAGNOSTICS / "sources/manifest.json",
                     DIAGNOSTICS / "common_diagnostics/consumed_sources/manifest.json",
                     NEW / "comparison_final01/sources/manifest.json"]:
            if str(path) in verified:
                counts[str(path)] = verify_manifest(path)
        if delivery_requested:
            pdf_manifest = read_json(repo / NEW / "comparison_JAGS20k_Stan2k_DC2010_v1.manifest.json")
            for key in ("source", "renderer", "pdf"):
                verify(pdf_manifest[key], pdf_manifest[key + "_sha256"])
        if release["analysis_mode"] == "preserved_failure":
            counts[release["failure_manifest"]] = verify_manifest(release["failure_manifest"])

        # Reuse only the already reviewed small JAGS tables; never read JAGS raw RDS.
        baseline = read_json(repo / NEW / "comparison_jags01/manifest.json")
        for name in ("timings_diagnostics.csv", "global_functionals.csv", "diagnostic_groups.csv"):
            path = NEW / "comparison_jags01" / name
            entry = next(item for item in baseline["files"] if Path(item["path"]) == path)
            verify(path, entry["sha256"])

        supervisor = read_json(repo / NEW / "stan2k01/supervisor_finished.json")
        if supervisor.get("executor_id") == REVIEWER:
            raise ValueError("Sampling executor equals results reviewer.")
        sampled = supervisor.get("exit_code") == 0 and supervisor.get("timed_out") is False
        post_path = repo / DIAGNOSTIC_SUPERVISOR
        if post_path.exists() and str(post_path.relative_to(repo)) not in verified:
            raise ValueError("Bind the retained diagnostic supervisor before interpreting it.")
        post = read_json(post_path) if post_path.exists() else None
        if post is not None:
            verify(post["log"], post["log_sha256"])
            if "R/experimental/mebane_ad_long/postprocess_stan_v2.R" not in post["command"]:
                raise ValueError("The completed diagnosis did not use the reviewed v2 wrapper.")
        processed = (post is not None and post.get("returncode") == 0 and post.get("timed_out") is False)
        if release["analysis_mode"] == "completed" and not (sampled and processed):
            raise ValueError("Completed mode conflicts with retained supervisor evidence.")
        if release["analysis_mode"] == "preserved_failure" and sampled and processed:
            raise ValueError("Failure mode conflicts with successful supervisors; inspect the supplied scope.")
        sample_manifest_path = NEW / "stan2k01/manifest.json"
        if str(sample_manifest_path) in verified:
            sample_manifest = read_json(repo / sample_manifest_path)
            if sample_manifest.get("status") != "sampling_completed_precision_not_assessed":
                raise ValueError("Unexpected completed-sampling manifest status.")
            if sample_manifest.get("preparation_manifest_sha256") != PINS[PREPARATION]:
                raise ValueError("Results are not bound to the reviewed Stan preparation.")
            verify(NEW / "review/stan/review.json", sample_manifest["qa_sha256"])
            if sample_manifest.get("executor_id") == REVIEWER:
                raise ValueError("Results executor equals results reviewer.")

        review_code = {name: sha(scope / name) for name in
                       ("run_qa.py", "recompute_stan.R", "check_delivery.py")}
        numerical_evidence = attempt
        if release["analysis_mode"] == "completed" and not numerical_requested:
            if not args.numerical_attempt or not re.fullmatch(r"attempt[0-9]{2,}", args.numerical_attempt):
                raise ValueError("Delivery-only QA requires --numerical-attempt attemptNN.")
            numerical_evidence = scope / args.numerical_attempt
            if numerical_evidence == attempt:
                raise ValueError("Reuse a different completed numerical attempt.")
            prior_outcome = read_json(numerical_evidence / "run_outcome.json")
            prior_binding = read_json(numerical_evidence / "input_binding.json")
            if prior_outcome.get("numerical_checks_completed") is not True:
                raise ValueError("The earlier numerical attempt did not complete.")
            if prior_binding.get("reviewer_id") != REVIEWER:
                raise ValueError("Earlier numerical evidence belongs to another reviewer.")
            artifact_manifest = numerical_evidence / "review_artifacts.json"
            verify(artifact_manifest, release.get("numerical_evidence_manifest_sha256"))
            counts[str(artifact_manifest.relative_to(repo))] = verify_manifest(artifact_manifest)
            for path in (NEW / "stan2k01/manifest.json", NEW / "stan2k01/draws_array.rds",
                         NEW / "stan2k01/sampler_diagnostics.rds", DIAGNOSTICS / "manifest.json"):
                key = str(path)
                if prior_binding["input_files"].get(key) != verified.get(key):
                    raise ValueError(f"Results changed since numerical QA: {path}")
            if prior_binding["review_code_sha256"]["recompute_stan.R"] != review_code["recompute_stan.R"]:
                raise ValueError("The numerical checker changed; adjudicate reuse before proceeding.")
        binding = dict(release, reviewer_id=REVIEWER, repository_root=str(repo),
                       preparation_compile_seconds=preparation["compile_seconds"],
                       input_files=verified, manifest_entries=counts,
                       review_code_sha256=review_code,
                       review_stage=args.stage, numerical_evidence_dir=str(numerical_evidence),
                       productive_diagnostics=str(DIAGNOSTICS),
                       JAGS_raw_reloaded=False, final_review_pending=True)
        write_json(attempt / "input_binding.json", binding)
        code_snapshot = attempt / "reviewer_sources"
        code_snapshot.mkdir()
        for name in review_code:
            with (code_snapshot / name).open("xb") as stream:
                stream.write((scope / name).read_bytes())
        if release["analysis_mode"] == "completed" and numerical_requested:
            for name in ("draws_array.rds", "sampler_diagnostics.rds", "fit.rds", "chain_timing.csv", "timing.json"):
                if str(NEW / "stan2k01" / name) not in verified:
                    raise ValueError(f"Original Stan artifact not bound: {name}")
            execute(["Rscript", "--vanilla", str(scope / "recompute_stan.R"),
                     str(attempt / "input_binding.json"), str(attempt)], "recompute.log")
        elif release["analysis_mode"] == "preserved_failure":
            write_json(attempt / "preserved_failure_scope.json", {
                "sampling_supervisor": supervisor, "diagnostic_supervisor": post,
                "posterior_results_recomputed": False, "no_missing_results_imputed": True,
                "final_review_pending": True})

        if delivery_requested:
            command = [sys.executable, str(scope / "check_delivery.py"),
                       str(attempt / "input_binding.json"), str(attempt)]
            if args.render_pdf:
                command.append("--render-pdf")
            execute(command, "delivery_checks.log")
        for path, record in verified.items():
            if sha(repo / path) != record["sha256"]:
                raise ValueError(f"Input changed during review: {path}")
        for name, expected in review_code.items():
            if sha(scope / name) != expected:
                raise ValueError(f"Reviewer code changed during execution: {name}")
        write_json(attempt / "run_outcome.json", {
            "status": "checkers_completed_final_review_pending",
            "reviewer_id": REVIEWER, "manual_pdf_inspection_required": delivery_requested,
            "final_delivery_present": delivery_requested,
            "review_stage": args.stage,
            "numerical_checks_completed": release["analysis_mode"] == "completed",
            "numerical_evidence_reused": release["analysis_mode"] == "completed" and not numerical_requested,
            "delivery_checks_completed": delivery_requested,
            "MCMC_executed": False, "compilation_executed": False})
        write_json(attempt / "review_artifacts.json", {
            "reviewer_id": REVIEWER, "final_review_pending": True,
            "files": [{"path": str(path.relative_to(repo)), "sha256": sha(path),
                       "bytes": path.stat().st_size}
                      for path in sorted(attempt.rglob("*")) if path.is_file()]})
    except Exception as error:
        write_json(attempt / "checker_failure.json", {
            "status": "checker_stopped_requires_adjudication", "error": repr(error),
            "verified_inputs_before_stop": verified, "artifacts_preserved": True})
        raise


if __name__ == "__main__":
    main()
