#!/usr/bin/env python3
"""Read-only candidate audit. Outputs are confined to this review directory.

Uses a fresh Poppler raw-order extraction, not the executor parser or CSV
to derive expected numeric values. No author code is imported or executed.
"""
import csv
from decimal import Decimal as D
import hashlib
import io
import json
from pathlib import Path
import re
import subprocess

HERE = Path(__file__).resolve().parent
B = HERE.parent
ROOT = next(p for p in B.parents if (p / "CLAUDE.md").exists())
MANIFEST_SHA = "afa7b901b85b97b5c369023d75d3e68a88679a487fef37cdb873796644ccf729"
PDF_SHA = "ddcdb42bebf8160abf80b6c189db37951db8ead7f0f763d5469423778f870fb7"
CSV_SHA = "d4b15199b6191a22fde1bae8609db7c2a9a13a143b2e966c1b9c9f82d3021fdd"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def emit(name, text):
    path = HERE / name
    assert path.parent == HERE
    data = text.encode("utf-8")
    if path.exists():
        assert path.read_bytes() == data, f"Preserved output differs: {name}"
    else:
        with path.open("xb") as stream:
            stream.write(data)


def jsonout(name, value):
    emit(name, json.dumps(value, indent=2, ensure_ascii=False) + "\n")


assert sha(B / "candidate_manifest.json") == MANIFEST_SHA
manifest = json.loads((B / "candidate_manifest.json").read_text())
hashes = {name: {"expected": expected, "observed": sha(B / name)}
          for name, expected in manifest["files_sha256"].items()}
assert all(x["expected"] == x["observed"] for x in hashes.values())
assert sha(B / "archive/Bolivia2019.pdf") == PDF_SHA
assert sha(B / "reference_values.csv") == CSV_SHA
original = ROOT / "quality_reports/results/mebane_gates/coordination/authors_replication_discovery/archive/Bolivia2019.pdf"
assert sha(original) == PDF_SHA
raw = subprocess.check_output(["pdftotext", "-raw", str(B / "archive/Bolivia2019.pdf"), "-"], text=True)
emit("pdf_raw.txt", raw)
emit("pdfinfo.txt", subprocess.check_output(["pdfinfo", str(B / "archive/Bolivia2019.pdf")], text=True))
pages = raw.split("\f")
assert len(pages) == 37 and not pages[-1].strip()
for page in [2, 3, *range(25, 37)]:
    assert pages[page - 1].strip().splitlines()[-1] == str(page - 1)
assert "November 13, 2019" in pages[0]

# Headers carry state across the page break: Chain 3's label is on PDF 31.
rows = []
chain = None
upper = False
block = {}
for page in [31, 32, 35]:
    for line_no, line in enumerate(pages[page - 1].splitlines(), 1):
        label = re.search(r"Chain ([1-4])", line)
        if label:
            chain = label.group(1)
        if "summary(efout, join.chains=TRUE)" in line:
            chain = "combined"
        if line.strip() == "Parameter Covariate Mean SD HPD.lower":
            upper = False
            block = {}
        elif line.strip() == "HPD.upper":
            upper = True
        elif re.match(r"^[1-9] (pi\[|beta\.)", line):
            pieces = line.split()
            idx, parameter = pieces[:2]
            row = dict(record_id=f"global_{chain}_{idx}", chain=chain,
                       parameter=parameter, covariate=" ".join(pieces[2:-3]),
                       estimate=pieces[-3], sd=pieces[-2], interval_lower=pieces[-1],
                       interval_type="HPD", interval_level="0.95", unit="parameter",
                       statistic="posterior_mean", pdf_page=str(page), printed_page=str(page-1),
                       phase="postprocessing_joined_chains" if chain == "combined" else "final_draws_summary",
                       source_section="wrkef2a Bolivia2019Clean 4c.Rout" if chain == "combined" else "runef4 Bolivia2019Clean 4c.Rout",
                       independent_locator=f"raw PDF {page}, line {line_no}, row {idx}",
                       interval_level_evidence="inferred_only_from_candidate_summary_and_coda_default; Bolivia_commit_unknown")
            block[idx] = row
            rows.append(row)
        elif upper and re.fullmatch(r"[1-9] [-+0-9.eE]+", line):
            idx, value = line.split()
            block[idx]["interval_upper"] = value
assert len(rows) == 45
assert all("interval_upper" in r for r in rows)

lines = pages[35].splitlines()
for label, parameter in [("Ntfraudtotalmean", "manufactured_fraud_votes"),
                         ("Nfraudtotalmean", "total_fraud_votes")]:
    i = next(i for i, x in enumerate(lines) if x.startswith(label + " "))
    names = lines[i].split()
    values = lines[i + 1].split()
    assert len(names) == len(values) == 5
    for level, offset in [("0.95", 1), ("0.995", 3)]:
        rows.append(dict(record_id=f"aggregate_{parameter}_{level}", chain="combined",
                         parameter=parameter, covariate="", estimate=values[0], sd="",
                         interval_lower=values[offset], interval_upper=values[offset+1],
                         interval_level=level, interval_type="credible_unspecified", unit="votes",
                         statistic="posterior_mean", pdf_page="36", printed_page="35",
                         phase="postprocessing_fraud_functional", source_section="wrkef2a Bolivia2019Clean 4c.Rout",
                         independent_locator=f"PDF 36 COMBO {label}; {names[offset]} / {names[offset+1]}",
                         interval_level_evidence="95/995 output labels; 99.5% corroborated by printed page 1"))
i = lines.index("no fraud fraud")
for label, count in zip(["no_fraud", "fraud"], lines[i + 1].split(), strict=True):
    rows.append(dict(record_id=f"classified_mesas_{label}", chain="combined", parameter=label,
                     covariate="", estimate=count, sd="", interval_lower="", interval_upper="",
                     interval_level="", interval_type="not_applicable", unit="mesas",
                     statistic="classified_mesas_count", pdf_page="36", printed_page="35",
                     phase="postprocessing_fraud_functional", source_section="wrkef2a Bolivia2019Clean 4c.Rout",
                     independent_locator=f"PDF 36 COMBO print(v), {label}",
                     interval_level_evidence="not_applicable"))
assert len(rows) == 51
candidate = list(csv.DictReader((B / "reference_values.csv").open()))
assert len(candidate) == 51
expected = {r["record_id"]: r for r in rows}
observed = {r["record_id"]: r for r in candidate}
assert len(expected) == len(observed) == 51
assert expected.keys() == observed.keys()
fields = ["chain", "parameter", "covariate", "statistic", "estimate", "sd",
          "interval_lower", "interval_upper", "interval_level", "interval_type",
          "unit", "pdf_page", "printed_page", "phase", "source_section"]
comparisons = []
for key, row in expected.items():
    comparisons.append({"record_id": key, "fields_compared": len(fields),
                        "differences": {f: {"pdf_derived": row[f], "candidate": observed[key][f]}
                                        for f in fields if row[f] != observed[key][f]}})
assert not any(r["differences"] for r in comparisons)
numeric_cells = sum(bool(r.get(f)) for r in rows for f in ["estimate", "sd", "interval_lower", "interval_upper"])
assert numeric_cells == 194
for r in rows:
    if r["interval_lower"]:
        assert D(r["interval_lower"]) <= D(r["estimate"]) <= D(r["interval_upper"])
buf = io.StringIO()
w = csv.DictWriter(buf, fieldnames=list(rows[0]), lineterminator="\n")
w.writeheader()
w.writerows(rows)
emit("independent_reference.csv", buf.getvalue())
jsonout("cell_comparison.json", {"rows": 51, "numeric_cells_excluding_levels": numeric_cells,
        "field_comparisons": len(fields)*51, "differences": 0,
        "level_validation": "Global .95 is conditional inference, not certified historical level.",
        "rows_detail": comparisons})

# Independent decimal arithmetic; source imprecision is not silently repaired.
arithmetic = {"pi_sums": {}, "combined_means": {}}
for c in ["1", "2", "3", "4", "combined"]:
    s = sum(D(expected[f"global_{c}_{i}"]["estimate"]) for i in [1, 2, 3])
    arithmetic["pi_sums"][c] = {"sum": str(s), "deviation_from_one": str(s-D(1))}
for i in range(1, 10):
    m = sum(D(expected[f"global_{c}_{i}"]["estimate"]) for c in [1, 2, 3, 4])/4
    published = D(expected[f"global_combined_{i}"]["estimate"])
    delta = published - m
    assert abs(delta) <= D("0.0000000001")
    arithmetic["combined_means"][expected[f"global_combined_{i}"]["parameter"]] = {
        "equal_chain_mean": str(m), "published": str(published), "difference": str(delta)}
party_totals = [2240920, 23725, 76827, 25283, 2889359, 260316, 539081, 42334, 39826]
assert all(str(n) in pages[25] and str(n) in pages[33] for n in party_totals)
assert sum(party_totals) == 6137671
arithmetic["printed_party_totals"] = {
    "inputs_pdf_26_and_34": party_totals, "sum_NValid_party_columns": sum(party_totals),
    "printed_Votos_Validos": 6137778, "difference": sum(party_totals)-6137778,
    "Inscritos": 7314446, "derived_NAbst_from_party_sum": 7314446-sum(party_totals),
    "Blancos": 93507, "Nulos": 229337,
    "registered_minus_valid_minus_blank_minus_null": 7314446-sum(party_totals)-93507-229337,
    "limitation": "Printed aggregate arithmetic only. NValid is reconstructed from party columns, not Votos.Validos. No row-level B2 validation or correction inferred."}
arithmetic["class_count_sum"] = {"no_fraud": 34277, "fraud": 274, "total": 34277+274}
assert arithmetic["class_count_sum"]["total"] == 34551
arithmetic["fraud_mean_difference"] = str(D("22519.818")-D("5295.798"))
arithmetic["rounding_to_printed_page_1"] = {
    s: str(D(s).quantize(D("0.1")))
    for s in ["22519.818", "20479.794", "24663.779", "5295.798", "4751.090", "5880.218"]}
assert all(value in pages[1] for value in arithmetic["rounding_to_printed_page_1"].values())
arithmetic["beta_chi_m"] = {
    "chain_means": [expected[f"global_{c}_8"]["estimate"] for c in [1, 2, 3, 4]],
    "range": str(D("-0.1868573970")-D("-1.5187331400")),
    "combined_mean": expected["global_combined_8"]["estimate"],
    "combined_SD": expected["global_combined_8"]["sd"],
    "interpretation": "Visible chain disagreement, not a convergence certificate or recomputed R-hat."}
jsonout("arithmetic_checks.json", arithmetic)

commit = json.loads((B / "archive/eforensics_commit_3017de5.json").read_text())
assert commit["sha"] == "3017de537450f97a01872d0157462a68bea348ee"
assert commit["commit"]["author"]["date"] == "2019-10-27T04:11:09Z"
assert "Mon Oct 28" in pages[26] and "Tue Oct 29" in pages[28]
source = (B / "archive/ef_models_3017de5.R").read_text()
qbl = source.split("qbl <- function()", 1)[1].split('"', 2)[1]
installed_snapshot = ROOT / "quality_reports/results/mebane_gates/G0/round1/qbl_installed_3017de5.jags"
assert sha(installed_snapshot) == "f8360126424b7a463f76a1c99efc89a8a5cb81339213bd4931559f14595fbab6"
assert qbl.strip() == installed_snapshot.read_text().strip()
for var in ["imb", "isb", "cmb", "csb", "nb", "tb"]:
    assert f"{var} ~ dexp(5)" in qbl
summary = (B / "archive/ef_summary_3017de5.R").read_text()
summary_function = summary.split("summary.eforensics <-", 1)[1].split("summary.eforensics_sim_data", 1)[0]
assert summary_function.count("coda::HPDinterval(.)") == 2
assert "prob=" not in summary_function and "prob =" not in summary_function
jsonout("integrity_checks.json", {"candidate_manifest_sha256": MANIFEST_SHA,
        "files": hashes, "original_pdf_sha256": sha(original),
        "qbl_snapshot_sha256": sha(installed_snapshot),
        "qbl_text_equal_ignoring_outer_whitespace": True,
        "commit_author_date_utc": commit["commit"]["author"]["date"],
        "commit_committer_date_utc": commit["commit"]["committer"]["date"],
        "installed_Bolivia_commit": "UNKNOWN", "remote_current_pdf_byte_equality": "UNKNOWN"})
print(json.dumps({"rows_verified": 51, "numeric_cells": 194, "field_comparisons": 765,
                  "differences": 0, "manifest_files_verified": len(hashes),
                  "party_total_sum": sum(party_totals), "printed_valid_vote_total": 6137778}))
