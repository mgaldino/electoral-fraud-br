#!/usr/bin/env python3
"""Extract the printed Bolivia 2019 reference cells from a fixed author PDF.

Requires only Python's standard library and Poppler's pdftotext. It does not
execute author R code, read election data, or calculate posterior quantities.
"""

import csv
import hashlib
import io
import re
import subprocess
from pathlib import Path


HERE = Path(__file__).resolve().parent
PDF = HERE / "archive" / "Bolivia2019.pdf"
OUTPUT = HERE / "reference_values.csv"
EXPECTED_SHA256 = "ddcdb42bebf8160abf80b6c189db37951db8ead7f0f763d5469423778f870fb7"
NUMBER = r"[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?"
PARAMETER = re.compile(
    rf"^\s*([1-9])\s+(pi\[[123]\]|beta\.(?:tau|nu|iota\.m|iota\.s|chi\.m|chi\.s))"
    rf"\s+(.+?)\s+({NUMBER})\s+({NUMBER})\s+({NUMBER})\s*$"
)
UPPER = re.compile(rf"^\s*([1-9])\s+({NUMBER})\s*$")
CHAIN = re.compile(r"Chain\s+([1-4])")
FIELDS = [
    "record_id", "phase", "source_section", "chain", "parameter", "covariate",
    "statistic", "estimate", "sd", "interval_lower", "interval_upper",
    "interval_level", "interval_type", "unit", "pdf_page", "printed_page",
    "source_locator", "definition_status", "notes",
]


def page_text(page):
    result = subprocess.run(
        ["pdftotext", "-f", str(page), "-l", str(page), "-layout", str(PDF), "-"],
        capture_output=True, text=True, check=True,
    )
    return result.stdout


def parse_global(lines_and_pages, combined=False):
    records = {}
    uppers = {}
    chain = "combined" if combined else None
    in_upper = False
    for page, line in lines_and_pages:
        match = CHAIN.search(line) if not combined else None
        if match:
            chain = match.group(1)
            in_upper = False
            continue
        if line.strip() == "HPD.upper":
            in_upper = True
            continue
        match = PARAMETER.match(line)
        if match:
            if chain is None or in_upper:
                raise ValueError(f"Unexpected parameter row on PDF page {page}: {line}")
            row, parameter, covariate, mean, sd, lower = match.groups()
            key = (chain, int(row))
            if key in records:
                raise ValueError(f"Duplicate summary row {key}")
            records[key] = (parameter, covariate, mean, sd, lower, page)
            continue
        match = UPPER.match(line)
        if match and in_upper and chain is not None:
            row, upper = match.groups()
            key = (chain, int(row))
            if key in uppers:
                raise ValueError(f"Duplicate upper endpoint {key}")
            uppers[key] = upper

    expected = {(str(chain), row) for chain in range(1, 5) for row in range(1, 10)}
    if combined:
        expected = {("combined", row) for row in range(1, 10)}
    if set(records) != expected or set(uppers) != expected:
        raise ValueError(
            f"Incomplete global table: rows={sorted(set(records) ^ expected)}, "
            f"uppers={sorted(set(uppers) ^ expected)}"
        )

    output = []
    for key in sorted(expected, key=lambda x: (x[0], x[1])):
        chain, row = key
        parameter, covariate, mean, sd, lower, page = records[key]
        section = "wrkef2a Bolivia2019Clean 4c.Rout" if combined else "runef4 Bolivia2019Clean 4c.Rout"
        output.append(dict(
            record_id=f"global_{chain}_{row}",
            phase="postprocessing_joined_chains" if combined else "final_draws_summary",
            source_section=section, chain=chain, parameter=parameter,
            covariate=covariate, statistic="posterior_mean", estimate=mean, sd=sd,
            interval_lower=lower, interval_upper=uppers[key], interval_level="0.95",
            interval_type="HPD", unit="parameter", pdf_page=str(page),
            printed_page=str(page - 1),
            source_locator=f"summary(efout{', join.chains=TRUE' if combined else ''}), "
                           f"{'combined' if combined else 'Chain ' + chain}, row {row}",
            definition_status="identified_from_summary_and_archived_wrapper",
            notes="HPD level follows coda::HPDinterval default in archived summary.eforensics",
        ))
    return output


def parse_aggregate(text):
    lines = text.splitlines()
    groups = [
        ("Ntfraudtotalmean", "Nttotal95.lo", "manufactured_fraud_votes"),
        ("Nfraudtotalmean", "Ntotal95.lo", "total_fraud_votes"),
    ]
    output = []
    for label, second_label, parameter in groups:
        candidates = [i for i, line in enumerate(lines) if label in line and second_label in line]
        if len(candidates) != 1:
            raise ValueError(f"Expected one printed aggregate header for {label}")
        values = re.findall(NUMBER, lines[candidates[0] + 1])
        if len(values) != 5:
            raise ValueError(f"Expected five printed values for {label}: {values}")
        for level, lo, hi in (("0.95", values[1], values[2]),
                              ("0.995", values[3], values[4])):
            output.append(dict(
                record_id=f"aggregate_{parameter}_{level}", phase="postprocessing_fraud_functional",
                source_section="wrkef2a Bolivia2019Clean 4c.Rout", chain="combined",
                parameter=parameter, covariate="", statistic="posterior_mean",
                estimate=values[0], sd="", interval_lower=lo, interval_upper=hi,
                interval_level=level, interval_type="credible_unspecified",
                unit="votes", pdf_page="36", printed_page="35",
                source_locator=f"COMBO evec, {label}, {second_label.replace('95.lo', '95/995.lo-hi')}",
                definition_status="partially_identified_external_script_unavailable",
                notes="Ntfraud is manufactured; Nfraud is total. Exact interval algorithm is not published here.",
            ))
    header = "no fraud     fraud"
    if header not in text:
        raise ValueError("Missing fraud classification count header")
    count_line = lines[lines.index(header) + 1]
    counts = re.findall(r"\d+", count_line)
    if len(counts) != 2 or sum(map(int, counts)) != 34551:
        raise ValueError(f"Unexpected classified mesa counts: {counts}")
    for label, count in zip(("no_fraud", "fraud"), counts):
        output.append(dict(
            record_id=f"classified_mesas_{label}", phase="postprocessing_fraud_functional",
            source_section="wrkef2a Bolivia2019Clean 4c.Rout", chain="combined",
            parameter=label, covariate="", statistic="classified_mesas_count",
            estimate=count, sd="", interval_lower="", interval_upper="",
            interval_level="", interval_type="not_applicable", unit="mesas",
            pdf_page="36", printed_page="35", source_locator=f"COMBO print(v), {label.replace('_', ' ')}",
            definition_status="partially_identified_external_script_unavailable",
            notes="Count uses elist$CIcombo[['all']][['Nfraud95']]; classification rule needs missing external script.",
        ))
    return output


def main():
    digest = hashlib.sha256(PDF.read_bytes()).hexdigest()
    if digest != EXPECTED_SHA256:
        raise ValueError(f"PDF SHA-256 mismatch: {digest}")
    chain_lines = [(page, line) for page in (31, 32)
                   for line in page_text(page).splitlines()]
    combined_lines = [(35, line) for line in page_text(35).splitlines()]
    rows = parse_global(chain_lines)
    rows.extend(parse_global(combined_lines, combined=True))
    rows.extend(parse_aggregate(page_text(36)))
    if len(rows) != 51:
        raise ValueError(f"Expected 51 reference rows, got {len(rows)}")
    buffer = io.StringIO(newline="")
    writer = csv.DictWriter(buffer, fieldnames=FIELDS, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
    content = buffer.getvalue().encode("utf-8")
    if OUTPUT.exists():
        if OUTPUT.read_bytes() != content:
            raise ValueError("Existing CSV differs; refusing to overwrite")
        print(f"Verified unchanged {OUTPUT}: {len(rows)} rows")
    else:
        OUTPUT.write_bytes(content)
        print(f"Created {OUTPUT}: {len(rows)} rows")


if __name__ == "__main__":
    main()
