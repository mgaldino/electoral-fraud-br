#!/usr/bin/env python3
"""Compare released tables and inspect an existing report; never generates a fit or PDF."""

import argparse
import csv
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import unicodedata

NEW = Path("quality_reports/results/mebane_gates/coordination/2026-10-01_ad_long_stan")


def load_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def load_csv(path):
    with path.open(newline="", encoding="utf-8") as stream:
        return list(csv.DictReader(stream))


def number(value):
    return float(value) if value not in (None, "", "NA") else math.nan


def same_number(a, b, label, tolerance=1e-8):
    a, b = number(a), number(b)
    if math.isnan(a) and math.isnan(b):
        return
    if not (math.isfinite(a) and math.isfinite(b) and math.isclose(a, b, abs_tol=tolerance, rel_tol=1e-10)):
        raise AssertionError(f"{label}: {a} != {b}")


def same_row(actual, expected, label):
    for key, value in expected.items():
        if key not in actual:
            raise AssertionError(f"{label}: missing {key}")
        if actual[key] == value:
            continue
        try:
            same_number(actual[key], value, f"{label}:{key}")
        except (ValueError, TypeError):
            raise AssertionError(f"{label}:{key}: {actual[key]} != {value}") from None


def unique_index(records, keys):
    result = {tuple(row[key] for key in keys): row for row in records}
    if len(result) != len(records):
        raise AssertionError(f"Duplicate rows for {keys}")
    return result


def boolean(value):
    if value not in ("TRUE", "FALSE"):
        raise AssertionError(f"Missing/invalid Boolean: {value}")
    return value == "TRUE"


def markdown_tables(text):
    tables, current = [], []
    for line in text.splitlines() + [""]:
        if line.lstrip().startswith("|"):
            cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
            if not all(re.fullmatch(r":?-+:?", cell) for cell in cells):
                current.append(cells)
        elif current:
            tables.append(current)
            current = []
    return tables


def pt_number(value):
    value = value.strip()
    if value == "NA":
        return math.nan
    return float(value.replace(".", "").replace(",", "."))


def rounded_cell(cell, value, digits, label):
    same_number(pt_number(cell), value, label, tolerance=.500001 * 10 ** (-digits))


def normalize_text(text):
    text = unicodedata.normalize("NFKC", text).replace("\u2212", "-")
    return re.sub(r"\s+", " ", text).strip()


def main():
    if os.environ.get("STAN_RESULTS_QA_RELEASED") != "1":
        raise SystemExit("Await the explicit results-QA execution window.")
    parser = argparse.ArgumentParser()
    parser.add_argument("binding", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--render-pdf", action="store_true")
    args = parser.parse_args()
    repo = Path.cwd().resolve()
    out = args.output.resolve(strict=True)
    if not out.is_relative_to(repo / NEW / "review_stan_results"):
        raise SystemExit("Output outside the exclusive review scope.")
    binding = load_json(args.binding)
    if binding.get("execution_window_released") is not True:
        raise SystemExit("Execution window not released in the bound record.")
    numerical_source = Path(binding.get("numerical_evidence_dir", str(out))).resolve(strict=True)
    if not numerical_source.is_relative_to(repo / NEW / "review_stan_results"):
        raise SystemExit("Numerical evidence outside the reviewer scope.")
    final = repo / NEW / "comparison_final01"
    baseline = repo / NEW / "comparison_jags01"
    checks = []

    def checked(label, condition=True):
        checks.append({"id": label, "pass": bool(condition)})
        if not condition:
            raise AssertionError(label)

    timing = load_csv(final / "timings_diagnostics.csv")
    old_timing = load_csv(baseline / "timings_diagnostics.csv")
    checked("comparison:five-distinct-rows", len(timing) == 5 and len({r["id"] for r in timing}) == 5)
    checked("comparison:fixed-row-order", [r["id"] for r in timing] == [r["id"] for r in old_timing])
    for index in range(4):
        same_row(timing[index], old_timing[index], f"JAGS preserved:{index}")
    checked("comparison:four-JAGS-rows-reused")

    common = load_csv(final / "global_functionals.csv")
    old_common = load_csv(baseline / "global_functionals.csv")
    common_index = unique_index(common, ("id", "target"))
    for row in old_common:
        same_row(common_index[(row["id"], row["target"])], row, "JAGS global preserved")
    group_rows = load_csv(final / "diagnostic_groups.csv")
    old_groups = load_csv(baseline / "diagnostic_groups.csv")
    group_index = unique_index(group_rows, ("id", "group"))
    for row in old_groups:
        same_row(group_index[(row["id"], row["group"])], row, "JAGS groups preserved")
    checked("comparison:92-JAGS-globals-and-18-groups-reused")
    status = load_json(final / "result.json")
    checked("comparison:no-adoption", status["status"] == "descriptive_comparison_no_adoption" and
            status["production_approved"] is False and status["G10_approved"] is False and
            status["MCSE_standardized_difference_is_not_equivalence_test"] is True)

    if binding["analysis_mode"] == "completed":
        independent = load_json(numerical_source / "recomputed_summary.json")
        checked("independent:completed", independent["execution_status"] == "checks_completed")
        globals_stan = unique_index(load_csv(numerical_source / "globals_recomputed.csv"), ("target",))
        row = timing[4]
        supervisor = load_json(repo / NEW / "stan2k01/supervisor_finished.json")
        post = load_json(repo / NEW / "stan_diagnostics02_supervisor.json")
        failed_post = load_json(repo / NEW / "stan_diagnostics01_supervisor.json")
        internal_time = load_json(repo / NEW / "stan2k01/timing.json")
        chain_time = load_csv(repo / NEW / "stan2k01/chain_timing.csv")
        compilation = binding["preparation_compile_seconds"]
        same_number(compilation, 43.1641881465912, "compilation:frozen-preparation")
        same_number(internal_time["compilation_seconds_separate"], compilation, "compilation:timing-record")
        same_number(row["compilation_seconds"], compilation, "compilation:comparison")
        same_number(row["generation_process_seconds"], supervisor["wall_seconds"], "Stan:external-supervisor")
        same_number(row["diagnostic_process_seconds"], post["elapsed_seconds"], "Stan:diagnostic-supervisor")
        total = supervisor["wall_seconds"] + post["elapsed_seconds"] + compilation
        same_number(row["total_compute_including_compilation_seconds"], total, "Stan:compilation-added-once")
        checked("Stan:productive-vs-failed-attempts", post["returncode"] == 0 and
                failed_post["returncode"] == 1 and not failed_post["timed_out"])
        same_number(status["failed_diagnostic_attempt_seconds"], failed_post["elapsed_seconds"],
                    "Stan:failed-diagnostic-time-preserved")
        checked("Stan:failed-time-explicitly-excluded", status["failed_diagnostic_attempt_in_productive_total"] is False)
        checked("Stan:repair-described", "S3 class locally" in status["diagnostic_repair"] and
                "no resampling" in status["diagnostic_repair"])
        same_number(row["sampling_seconds"], sum(number(x["sampling"]) for x in chain_time), "Stan:sampling-times")
        same_number(row["warmup_seconds"], sum(number(x["warmup"]) for x in chain_time), "Stan:warmup-times")
        checked("Stan:compilation-scope", row["compilation_is_inside_generation"] == "FALSE" and
                "C++" in internal_time["compile_scope"])
        checked("Stan:completed", boolean(row["completed"]) and len(chain_time) == 4)
        same_number(row["mandatory_targets"], 1742, "Stan:1742-common")
        same_number(row["failed_targets"], independent["common_failed"], "Stan:common-failed")
        same_number(row["undefined_targets"], independent["common_undefined_subset_failed"], "Stan:undefined")
        same_number(row["NCP_failed"], independent["internal_failed"], "Stan:NCP-failed")
        same_number(row["global_failures"], independent["global_failed_count"], "Stan:global-failed")
        checked("Stan:HMC-status", boolean(row["HMC_pass"]) == independent["HMC_pass"])
        checked("Stan:common-status", row["status"] == independent["status_confirmed"])
        checked("Stan:115-common-global-rows", len(common) == 115)
        metrics = ("mean", "sd", "q025", "q50", "q975", "rhat", "ess_bulk", "ess_tail", "mcse_mean",
                   "chain1", "chain2", "chain3", "chain4", "chain_mean_range")
        for (target,), original in globals_stan.items():
            reported = common_index[("D_Stan_2k", target)]
            for metric in metrics:
                same_number(reported[metric], original[metric], f"Stan:{target}:{metric}")
            checked(f"Stan:{target}:pass", reported["diagnostic_pass"] == original["diagnostic_pass"])
            same_number(reported["bulk_ESS_per_total_compute_second"], number(original["ess_bulk"]) / total,
                        f"Stan:{target}:bulkESS/s")
            same_number(reported["tail_ESS_per_total_compute_second"], number(original["ess_tail"]) / total,
                        f"Stan:{target}:tailESS/s")
            same_number(reported["ess_bulk_per_internal_generation_second"],
                        number(original["ess_bulk"]) / internal_time["generation_wall_seconds"],
                        f"Stan:{target}:internal-bulkESS/s")
            same_number(reported["ess_tail_per_internal_generation_second"],
                        number(original["ess_tail"]) / internal_time["generation_wall_seconds"],
                        f"Stan:{target}:internal-tailESS/s")
        for key, metric, function in (("max_global_Rhat", "rhat", max),
                                      ("min_global_bulk_ESS", "ess_bulk", min),
                                      ("min_global_tail_ESS", "ess_tail", min)):
            values = [number(r[metric]) for r in globals_stan.values() if math.isfinite(number(r[metric]))]
            same_number(row[key], function(values) if values else math.nan, key)

        required = [r for r in load_csv(repo / NEW / "stan_diagnostics02/common_diagnostics/diagnostics.csv")
                    if boolean(r["mandatory"])]
        stan_groups = {r["group"] for r in required}
        checked("Stan:four-mandatory-groups", stan_groups == {"global", "local_continuous", "class_count", "class_indicator"})
        checked("comparison:22-groups", len(group_rows) == 22)
        for group in stan_groups:
            values = [r for r in required if r["group"] == group]
            reported = group_index[("D_Stan_2k", group)]
            same_number(reported["targets"], len(values), f"group:{group}:targets")
            same_number(reported["failed"], sum(not boolean(r["diagnostic_pass"]) for r in values), f"group:{group}:failed")
            undefined = sum(any(not math.isfinite(number(r[key])) for key in ("rhat", "ess_bulk", "ess_tail"))
                            for r in values)
            same_number(reported["undefined"], undefined, f"group:{group}:undefined")
            for field, source, function in (("max_Rhat", "rhat", max), ("min_bulk_ESS", "ess_bulk", min),
                                             ("min_tail_ESS", "ess_tail", min)):
                finite = [number(r[source]) for r in values if math.isfinite(number(r[source]))]
                same_number(reported[field], function(finite) if finite else math.nan, f"group:{group}:{field}")

        differences = load_csv(final / "D_engine_differences.csv")
        checked("engine:23-unique-differences", len(unique_index(differences, ("target",))) == 23)
        for reported in differences:
            target = reported["target"]
            jags = common_index[("D_JAGS_20k", target)]
            stan = globals_stan[(target,)]
            delta = number(stan["mean"]) - number(jags["mean"])
            combined = math.hypot(number(stan["mcse_mean"]), number(jags["mcse_mean"]))
            units = delta / combined if math.isfinite(combined) and combined > 0 else math.nan
            for field, expected in (("JAGS_mean", jags["mean"]), ("Stan_mean", stan["mean"]),
                                     ("difference_Stan_minus_JAGS", delta), ("combined_MCSE", combined),
                                     ("descriptive_MCSE_units", units)):
                same_number(reported[field], expected, f"engine:{target}:{field}")
            checked(f"engine:{target}:descriptive-only", reported["posterior_equivalence_demonstrated"] == "FALSE" and
                    reported["JAGS_target_pass"] == jags["diagnostic_pass"] and
                    reported["Stan_target_pass"] == stan["diagnostic_pass"])
        checked("comparison:completion-status", status["all_five_runs_complete"] is True)
        checked("comparison:all-current-precision", status["all_current_common_diagnostics_met"] ==
                all(r["status"] == "diagnostics_met_for_this_model" for r in timing[2:]))
    else:
        checked("failure:Stan-not-completed", not boolean(timing[4]["completed"]))
        checked("failure:no-five-completed", status["all_five_runs_complete"] is False)
        checked("failure:no-all-current-precision", status["all_current_common_diagnostics_met"] is False)

    markdown = (repo / binding["report_markdown"]).read_text(encoding="utf-8")
    if binding["analysis_mode"] == "completed":
        failed_time = re.search(r"falhou em ([0-9.,]+) s", markdown)
        checked("report:failed-diagnostic-time-present", failed_time is not None)
        rounded_cell(failed_time.group(1), failed_post["elapsed_seconds"], 2, "report:failed-diagnostic-time")
        checked("report:productive-vs-failed-disclosure", "stan_diagnostics01" in markdown and
                "stan_diagnostics02" in markdown and "não integra o total produtivo" in markdown and
                "não houve nova amostragem" in markdown)
    tables = markdown_tables(markdown)
    table1 = next(t for t in tables if "Geração (s)" in t[0])
    table2 = next(t for t in tables if "Obrigatórios totais" in t[0])
    checked("report:five-timing-and-count-rows", len(table1) == len(table2) == 6)
    for index, expected in enumerate(timing, start=1):
        cells = table1[index]
        checked(f"report:timing:{index}:id", cells[0] == expected["id"])
        for column, field, digits in ((1, "generation_process_seconds", 2), (2, "diagnostic_process_seconds", 2),
                                      (3, "total_compute_including_compilation_seconds", 2), (4, "max_global_Rhat", 3)):
            rounded_cell(cells[column], expected[field], digits, f"report:{index}:{field}")
        for cell, field in zip(cells[5].split("/"), ("min_global_bulk_ESS", "min_global_tail_ESS")):
            rounded_cell(cell, expected[field], 1, f"report:{index}:{field}")
        cells = table2[index]
        checked(f"report:counts:{index}:id", cells[0] == expected["id"])
        for cell, field in zip(cells[1:], ("global_failures", "failed_targets", "mandatory_targets", "undefined_targets")):
            rounded_cell(cell, expected[field], 0, f"report:{index}:{field}")

    if binding["analysis_mode"] == "completed":
        hmc_table = next(t for t in tables if t[0][0] == "Cadeia")
        hmc = load_csv(numerical_source / "HMC_recomputed.csv")
        checked("report:HMC-four-chains", len(hmc_table) == 5)
        for cells, expected in zip(hmc_table[1:], hmc):
            for cell, key, digits in zip(cells, ("chain", "divergences", "treedepth_hits", "ebfmi"), (0, 0, 0, 3)):
                rounded_cell(cell, expected[key], digits, f"report:HMC:{key}")
        difference_table = next(t for t in tables if t[0][0] == "Funcional")
        difference_index = unique_index(differences, ("target",))
        checked("report:difference-five-targets", len(difference_table) == 6)
        for cells in difference_table[1:]:
            target = cells[0]
            expected = difference_index[(target,)]
            digits = 4 if target.startswith("pi[") else 1
            for cell, field in zip(cells[1:4], ("JAGS_mean", "Stan_mean", "difference_Stan_minus_JAGS")):
                rounded_cell(cell, expected[field], digits, f"report:{target}:{field}")
            rounded_cell(cells[4], expected["descriptive_MCSE_units"], 2, f"report:{target}:MCSE-units")
    chain_table = next(t for t in tables if t[0][0] == "Rodada / funcional")
    for cells in chain_table[1:]:
        run_id, target = cells[0].split(" / ")
        expected = common_index[(run_id, target)]
        for index, cell in enumerate(cells[1:], start=1):
            rounded_cell(cell, expected[f"chain{index}"], 1, f"report:{run_id}:{target}:chain{index}")
    checked("report:numeric-tables")

    pdf = repo / NEW / "comparison_JAGS20k_Stan2k_DC2010_v1.pdf"
    with pdf.open("rb") as stream:
        checked("PDF:header", stream.read(5) == b"%PDF-")
    pdfinfo = shutil.which("pdfinfo")
    pdftotext = shutil.which("pdftotext")
    if not pdfinfo or not pdftotext:
        raise RuntimeError("Locate existing Poppler in the bundled runtime; do not install dependencies.")
    pdf_dir = out / "pdf"
    pdf_dir.mkdir(exist_ok=False)
    info = subprocess.run([pdfinfo, str(pdf)], check=True, text=True, capture_output=True)
    (pdf_dir / "pdfinfo.txt").write_text(info.stdout, encoding="utf-8")
    pages_match = re.search(r"^Pages:\s+(\d+)", info.stdout, flags=re.MULTILINE)
    checked("PDF:page-count", pages_match is not None and int(pages_match.group(1)) == 4)
    subprocess.run([pdftotext, str(pdf), str(pdf_dir / "reading_order.txt")], check=True)
    subprocess.run([pdftotext, "-layout", str(pdf), str(pdf_dir / "layout.txt")], check=True)
    text = normalize_text((pdf_dir / "reading_order.txt").read_text(encoding="utf-8"))
    rows_found = [{"cells": cells, "found_in_reading_order": normalize_text(" ".join(cells)) in text}
                  for table in tables for cells in table[1:]]
    rendered = False
    if args.render_pdf:
        pdftoppm = shutil.which("pdftoppm")
        if not pdftoppm:
            raise RuntimeError("Locate existing pdftoppm in the bundled runtime; do not install it.")
        subprocess.run([pdftoppm, "-r", "130", "-png", str(pdf), str(pdf_dir / "page")], check=True)
        rendered = True
    result = {
        "execution_status": "automated_delivery_checks_completed",
        "checks": checks, "PDF_pages": int(pages_match.group(1)), "PDF_rendered": rendered,
        "PDF_text_rows": rows_found,
        "text_extraction_misses_require_visual_adjudication": True,
        "manual_visual_review": "pending_all_pages",
        "manual_narrative_checks": [
            "Same-target D comparison and A/D model sensitivity are distinguished.",
            "MCSE units remain descriptive; no equivalence or precise posterior claim after failed diagnostics.",
            "Undefined diagnostics remain a subset of failures; RB does not replace common mandatory targets.",
            "Compilation includes the C++ interface exactly once; JAGS compilation is already included.",
            "Timeout or partial postprocessing is reported without invented completed results.",
            "All pages: table completeness, numbers, row alignment, captions, clipping, glyphs, page breaks and references."
        ],
        "final_review_pending": True,
    }
    with (out / "delivery_checks.json").open("x", encoding="utf-8") as stream:
        json.dump(result, stream, ensure_ascii=False, indent=2, allow_nan=False)
        stream.write("\n")


if __name__ == "__main__":
    main()
