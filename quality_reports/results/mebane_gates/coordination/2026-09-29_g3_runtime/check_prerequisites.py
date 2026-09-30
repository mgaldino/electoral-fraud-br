"""Check the current G2 approval and the already incorporated G10 protocol."""

import argparse
import datetime
import hashlib
import importlib.util
import json
from pathlib import Path


BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[4]
GATES = ROOT / "quality_reports/results/mebane_gates"
DISCOVERY = GATES / "coordination/authors_replication_discovery"


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def main(output):
    ledger_path = ROOT / "quality_reports/plans/mebane_2022_2026_gates.json"
    ledger = read(ledger_path)
    gates = {gate["id"]: gate for gate in ledger["gates"]}
    checks = []

    def check(name, condition):
        checks.append({"id": name, "passed": bool(condition)})
        if not condition:
            raise AssertionError(name)

    spec = importlib.util.spec_from_file_location("checker", ROOT / "scripts/mebane_gates.py")
    checker = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(checker)
    check("ledger_valid", not checker.validate(ledger, ROOT))
    check("G2_current_approval", gates["G2"]["status"] == "pass" and
          not checker.check_records(gates["G2"], ROOT, gates))
    check("inventory_hold_resolved", ledger["integrity_hold"]["status"] ==
          "resolved_by_authorized_rebaseline")
    contract_path = GATES / "G2/round2/benchmark_contract.json"
    check("exact_approved_benchmark", sha256(contract_path) ==
          "63b61fb0594d0302a03d999bcff6c62967b6e999f37b4c9a8821f0f8e9ed18d2")
    contract = read(contract_path)
    check("literal_software_not_generator", contract["target_kind"] ==
          "literal_software_benchmark_not_certified_data_generator")
    check("no_silent_support_repair", not any(contract["likelihood"][key] for key in
          ("clamp_allowed", "latent_mean_plugin_allowed", "F1_F2_repair_allowed",
           "silent_normalization_or_truncation_allowed")))
    check("G3_requires_G2", gates["G3"]["depends_on"] == ["G2"])
    check("G10_requires_G3", gates["G10"]["depends_on"] == ["G3"])
    check("G4_requires_G10", "G10" in gates["G4"]["depends_on"])
    check("external_replication_not_approved", gates["G10"]["status"] == "queued"
          and gates["G10"]["records"] is None)
    prompts = " ".join((ROOT / "quality_reports/plans/mebane_gate_agent_prompts.md").read_text(
        encoding="utf-8").split())
    check("external_contract_review_precedes_fit", all(term in prompts for term in
          ("Antes de G10-T3", "revisão independente", "conferir o hash aprovado",
           "Esse checkpoint de G10-T2 fixa caso", "Critérios não podem ser escolhidos depois")))

    sources = read(DISCOVERY / "source_manifest.json")
    verified = []
    for entry in sources["sources"] + sources["pertinent_extracted_members"]:
        path = DISCOVERY / entry["path"]
        check("source:" + entry["path"], path.is_file() and
              path.stat().st_size == entry["bytes"] and sha256(path) == entry["sha256"])
        verified.append({"path": path.relative_to(ROOT).as_posix(),
                         "sha256": entry["sha256"], "bytes": entry["bytes"]})
    proposal = read(DISCOVERY / "replication_contract.json")
    check("DC_numeric_gap_preserved", proposal["status"] == "PROPOSED_NOT_FROZEN" and
          proposal["bibliographic_target"]["numeric_reference_values_found"] is False)
    check("author_call_concrete", proposal["case_id"] == "dc2010" and
          proposal["inputs"]["n"] == 143 and proposal["model"]["formula_w"] == "Votes ~ 1"
          and proposal["model"]["formula_a"] == "a ~ 1")
    check("comparison_criteria_present_not_frozen", all(key in
          proposal["proposed_comparison_before_new_execution"] for key in
          ("structural", "numeric", "monte_carlo_proposal_not_frozen", "freeze_required_before_execution")))
    adjudication = read(GATES / "coordination/2026-09-29_benchmark_round/replication_adjudication.json")
    findings = {item["finding_id"]: item for item in adjudication["findings"]}
    check("missing_numeric_reference_not_hidden", findings["AR-01"]["status"] == "CONFIRMED"
          and findings["AR-01"]["resolved"] is False)
    check("Bolivia_locator_erratum_retained", findings["AR-03"]["resolved"] is True and
          "página impressa 30" in findings["AR-03"]["resolution"])
    result = {
        "checked_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "scope": "Current prerequisite and incorporation audit, not G3/G10 scientific validation",
        "checks": checks, "sources_verified": verified,
        "ledger_sha256_at_check": sha256(ledger_path),
        "G2_records": gates["G2"]["records"],
        "G10_requirement_incorporated": True, "G10_executed_or_approved": False,
        "external_comparison_contract_frozen": False,
        "external_remaining_inputs": ["DC immutable numeric output, or another fully documented case",
                                      "Same cleaned input as any alternative published output"],
        "new_remote_search": False, "new_statistical_analysis": False,
        "script_sha256": sha256(Path(__file__).resolve())
    }
    with output.open("x", encoding="utf-8") as stream:
        json.dump(result, stream, ensure_ascii=False, indent=2)
        stream.write("\n")
    print(f"PASS: {len(checks)} checks; {len(verified)} archived sources; no new fit")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    main(parser.parse_args().output)
