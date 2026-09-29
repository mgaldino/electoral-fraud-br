#!/usr/bin/env python3
"""Verify QA outputs and cross-locale invariance before writing the opinion."""
import datetime as dt
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[6]
REVIEW = Path(__file__).resolve().parent


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


results = [read(REVIEW / "run01" / (m + "_independent/results.json")) for m in ("C", "UTF8")]
assert all(x["status"] == "PASS" and x["count"] == x["passed"] == 69 and
           x["locale_before"] == x["locale_after"] for x in results)
assert results[0]["locale_ctype"] == "C" and results[1]["locale_ctype"] == "pt_BR.UTF-8"
assert all(x["expected_error"] == x["observed_error"] for r in results for x in r["cases"])
for r in results:
    for turn in (1, 2):
        case = next(x for x in r["cases"] if x["id"] == "F01_null2026_coherent_T" + str(turn))
        assert case["observed_error"] == "Candidate selection unresolved for turn"
left = REVIEW / "run01/C_independent"
right = REVIEW / "run01/UTF8_independent"
receipt_comparisons = []
for path in sorted(left.rglob("receipt.json")):
    counterpart = right / path.relative_to(left)
    r = read(path)
    equal = counterpart.exists() and path.read_bytes() == counterpart.read_bytes()
    receipt_comparisons.append({"path": str(path.relative_to(left)), "identical_bytes": equal})
    assert equal
    assert r["data_ready"] is False and r["inference_ready"] is False
    assert r["validation"]["national_coverage_attested"] is False
    assert "complete" not in r["validation"]
    assert sum(x["reference_sections"] for x in r["validation"]["by_uf"]) == r["validation"]["expected_sections"]
    assert sum(x["observed_sections"] for x in r["validation"]["by_uf"]) == r["validation"]["observed_sections"]
run = read(REVIEW / "run01/execution.json")
assert run["status"] == "PASS" and run["ledger_unchanged"]
trace = read(REVIEW / "integrity_read_trace_final.json")
assert trace["status"] == "PASS" and not trace["mutable_ledger_read"] and not trace["uncovered_reads"]
assert read(REVIEW / "dag_probes/results.json")["status"] == "PASS"
assert read(REVIEW / "run01/integrity_after.json")["pass"]
ledger_sha = hashlib.sha256((ROOT / "quality_reports/plans/mebane_2022_2026_gates.json").read_bytes()).hexdigest()
assert ledger_sha == read(REVIEW / "run01/integrity_before.json")["ledger_sha256"]
report = {"status": "PASS", "verified_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
          "independent_cases_per_locale": 69, "independent_case_executions": 138,
          "dag_independent_cases": 8, "cross_locale_identical_receipts": len(receipt_comparisons),
          "receipt_comparisons": receipt_comparisons, "mutable_ledger_sha256": ledger_sha,
          "candidate_sha256": hashlib.sha256((REVIEW.parent / "candidate_manifest.json").read_bytes()).hexdigest(),
          "executor_repair_cases_per_locale": 20, "checker_suite_tests": 26,
          "execution_wall_seconds_sum": sum(x["wall_seconds"] for x in run["commands"]),
          "initial_trace_caveat": "Initial trace logged an unsuccessful open of an absent Python cache as uncovered. Final trace distinguishes absent attempts from bytes read. Both reports retained."}
target = REVIEW / "verification.json"
assert not target.exists()
target.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
print(json.dumps({k: v for k, v in report.items() if k != "receipt_comparisons"}))
