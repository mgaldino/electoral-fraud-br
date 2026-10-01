"""Seal completed independent checks and manual visual observations without editing inputs."""
import csv
import hashlib
import json
import re
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path.cwd().resolve()
NEW = Path("quality_reports/results/mebane_gates/coordination/2026-10-01_ad_long_stan")
OLD = Path("quality_reports/results/mebane_gates/coordination/2026-09-30_ad_study")
SCOPE = NEW / "review_stan_results"
ATTEMPT = SCOPE / "attempt02"
REVIEWER = "01a0f717-7535-72e3-baf8-4db20da81abb"
assert Path(__file__).resolve().parent == ROOT / SCOPE


def read(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def sha(path):
    digest = hashlib.sha256()
    with (ROOT / path).open("rb") as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def write(path, value):
    assert (ROOT / path).resolve().is_relative_to(ROOT / SCOPE)
    with (ROOT / path).open("x", encoding="utf-8") as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2, allow_nan=False)
        stream.write("\n")


def rows(path):
    with (ROOT / path).open(newline="", encoding="utf-8") as stream:
        return list(csv.DictReader(stream))


binding = read(ATTEMPT / "input_binding.json")
outcome = read(ATTEMPT / "run_outcome.json")
assert outcome["numerical_checks_completed"] and outcome["delivery_checks_completed"]
assert binding["execution_window_released"] and binding["reviewer_id"] == REVIEWER
assert sha(NEW / "results_candidate_manifest.json") == "d4479f0c060e0cf757bada81c916c852b639fbbed86be73a857211b295ce45f8"
assert len(read(NEW / "results_candidate_manifest.json")["files"]) == 45
for path, record in binding["input_files"].items():
    assert sha(Path(path)) == record["sha256"], path
for entry in read(ATTEMPT / "review_artifacts.json")["files"]:
    assert sha(Path(entry["path"])) == entry["sha256"], entry["path"]

source_preservation = []
for model, source, expected in (
    ("A", Path("quality_reports/results/mebane_gates/G0/round1/qbl_installed_3017de5.jags"),
     "f8360126424b7a463f76a1c99efc89a8a5cb81339213bd4931559f14595fbab6"),
    ("D", Path("models/experimental/mebane_ad/d_multinomial.jags"),
     "6ddb9624f60b15e196cc27ed9694852c40b6553a684a9962003168da4ecfaf5b")):
    paths = [source, OLD / "pilot01" / model / "consumed_sources" / source,
             NEW / "jags20k01" / model / "consumed_sources" / source]
    assert all(sha(path) == expected for path in paths)
    source_preservation.append({"model": model, "sha256": expected,
                                "paths": [str(path) for path in paths], "all_identical": True})

adjudication_path = NEW / "diagnostic_repair_adjudication.json"
adjudication = read(adjudication_path)
assert adjudication["status"] == "accepted_representation_repair_only"
assert adjudication["review_sha256"] == sha(SCOPE / "repair_review.json")
assert adjudication["candidate_manifest_sha256"] == sha(NEW / "stan_diagnostic_repair_candidate.json")

csv_settings = []
for chain in range(1, 5):
    path = NEW / "stan2k01/csv" / f"D_Stan-{chain}.csv"
    header = []
    with (ROOT / path).open() as stream:
        for line in stream:
            if not line.startswith("#"):
                break
            header.append(line.rstrip())
    values = {}
    for key, expected in {"id": str(chain), "num_samples": "2000", "num_warmup": "2000",
                          "thin": "1", "seed": "1001261", "save_warmup": "true",
                          "delta": "0.99", "max_depth": "12", "num_threads": "1",
                          "sig_figs": "17"}.items():
        matches = [re.match(r"^#\s*" + key + r"\s*=\s*(\S+)", line) for line in header]
        selected = [match.group(1) for match in matches if match]
        assert selected == [expected], (path, key, selected)
        values[key] = selected[0]
    init = [line for line in header if re.match(r"^# init = ", line)]
    expected_init = ROOT / NEW / "stan_impl/run-20261001T105406Z-attempt03-01a0f4b5/preparation" / f"init_chain{chain}.json"
    assert init == [f"# init = {expected_init}"]
    csv_settings.append({"path": str(path), "settings": values, "init": str(expected_init)})

numerical = read(ATTEMPT / "recompute_checks.json")
delivery = read(ATTEMPT / "delivery_checks.json")
assert numerical["outcome"]["status"] == "checks_completed"
assert all(check["pass"] for check in numerical["checks"])
assert all(check["pass"] for check in delivery["checks"])
assert delivery["PDF_pages"] == 4 and delivery["PDF_rendered"]
assert all(row["found_in_reading_order"] for row in delivery["PDF_text_rows"])
globals_rows = rows(ATTEMPT / "globals_recomputed.csv")
differences = {}
for prefix in ("CSV:", "mu:", "global:", "NCP:", "joint:", "RB:", "HMC:"):
    differences[prefix] = max([check.get("evidence", {}).get("max_abs_difference", 0)
                               for check in numerical["checks"] if check["id"].startswith(prefix)] + [0])
timing = rows(NEW / "comparison_final01/timings_diagnostics.csv")[-1]
failed_time = read(NEW / "stan_diagnostics01_supervisor.json")["elapsed_seconds"]
productive_total = float(timing["total_compute_including_compilation_seconds"])

visual = {
    "status": "pass", "reviewer_id": REVIEWER,
    "method": "Manual inspection of all four 130-dpi page renders, plus enlarged footer crops on pages 2/3 and a full-page-3 alternate render.",
    "pdf": str(NEW / "comparison_JAGS20k_Stan2k_DC2010_v1.pdf"),
    "pdf_sha256": sha(NEW / "comparison_JAGS20k_Stan2k_DC2010_v1.pdf"),
    "pages_inspected": [1, 2, 3, 4], "findings": [],
    "page_observations": [
        {"page": 1, "observation": "Protocol, model distinction, compilation scope, title and footer legible. Table 1 caption begins here and table follows on page 2 without content loss."},
        {"page": 2, "observation": "Repair and failed-time exclusion disclosed; all five timing rows and five diagnostic-count rows present, aligned and numerically consistent. Group counts and footer complete."},
        {"page": 3, "observation": "All four HMC rows, all five selected engine-difference rows and first five chain-mean rows present. No clipping or footer collision; signs and decimals legible."},
        {"page": 4, "observation": "Final D/Stan S_total row continues Table 5 with repeated column headings. Scope limitations, scientific caveats, references and footer complete."}
    ],
    "all_markdown_numeric_rows_found_in_pdf_text": True,
    "all_numeric_rows_visually_checked": True,
    "layout_clipping_overlap_missing_rows": False,
    "PDF_recompiled_or_modified": False
}
write(SCOPE / "visual_checks01/visual_review.json", visual)

evidence_paths = [ATTEMPT / name for name in (
    "input_binding.json", "run_outcome.json", "review_artifacts.json", "recomputed_summary.json",
    "recompute_checks.json", "globals_recomputed.csv", "NCP_recomputed.csv", "HMC_recomputed.csv",
    "RB_recomputed.csv", "common_decisions.csv", "delivery_checks.json")]
evidence_paths += [SCOPE / name for name in ("repair_review.json", "repair_review.md", "checker_corrections.md",
                                            "release.json", "seal_evidence.py", "visual_checks01/visual_review.json")]
evidence_paths += [adjudication_path]
evidence_paths += sorted((ROOT / SCOPE / "visual_checks01").glob("*.png"))
evidence = [{"path": str((ROOT / path).relative_to(ROOT)), "sha256": sha(path)} for path in evidence_paths]
write(SCOPE / "final_evidence.json", {
    "status": "pass", "reviewer_id": REVIEWER, "issued_utc": datetime.now(timezone.utc).isoformat(),
    "candidate_sha256": sha(NEW / "results_candidate_manifest.json"),
    "candidate_explicit_files": 45, "bound_input_files_unchanged": len(binding["input_files"]),
    "numerical_assertions": len(numerical["checks"]), "delivery_named_checks": len(delivery["checks"]),
    "PDF_numeric_data_rows_checked": len(delivery["PDF_text_rows"]),
    "CSV_settings_and_initialization_bindings": csv_settings,
    "JAGS_source_preservation": source_preservation,
    "repair_adjudication_sha256": sha(adjudication_path),
    "global_extremes": {"max_rhat": max(float(row["rhat"]) for row in globals_rows),
                        "min_ess_bulk": min(float(row["ess_bulk"]) for row in globals_rows),
                        "min_ess_tail": min(float(row["ess_tail"]) for row in globals_rows)},
    "max_absolute_differences_by_check_prefix": differences,
    "productive_Stan_total_seconds": productive_total,
    "failed_diagnostic_seconds_excluded": failed_time,
    "productive_plus_failed_diagnostic_seconds_for_transparency": productive_total + failed_time,
    "all_automated_and_visual_checks_passed": True,
    "independent_scientific_precision_approval": False, "evidence": evidence
})
print(json.dumps({"status": "pass", "final_evidence_sha256": sha(SCOPE / "final_evidence.json"),
                  "PDF_pages_inspected": 4, "bound_inputs_unchanged": len(binding["input_files"])}))
