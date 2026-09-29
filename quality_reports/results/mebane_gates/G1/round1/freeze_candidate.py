"""Freeze the G1 candidate without touching the mutable gate ledger."""

from __future__ import annotations

import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[5]
ROUND = "quality_reports/results/mebane_gates/G1/round1"
ROUND_DIR = ROOT / ROUND
EXECUTOR_ID = "01a0eaee-0164-7530-884d-adec564a8327"
G0_MANIFEST_SHA = "f71333db477385fc78dad8a7a1a7ca78e48479226dcdbde80ce97d724409fec7"
G0_REVIEW_SHA = "ef624cb4b2d8ad098b87e196d87add358ce1eba93165d44fcc1939ff303f5376"
G0_ADJUDICATION_SHA = "ea1b4905fdfa14f6e3f36c41974ea948ba0c39d1f81f87d6eaf479782216267b"


def sha256(path: str) -> str:
    digest = hashlib.sha256()
    with (ROOT / path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def canonical_hash(value: object) -> str:
    payload = json.dumps(value, sort_keys=True, ensure_ascii=False,
                         separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def main() -> None:
    ledger = json.loads((ROOT / "quality_reports/plans/mebane_2022_2026_gates.json").read_text())
    gate = next(item for item in ledger["gates"] if item["id"] == "G1")
    contract = {key: value for key, value in gate.items() if key not in {"status", "records"}}
    contract["todos"] = [
        {key: value for key, value in todo.items() if key not in {"status", "evidence"}}
        for todo in gate["todos"]
    ]
    contract_sha = canonical_hash(contract)
    write_json(ROUND_DIR / "gate_contract.json", contract)

    dependency_paths = {
        "manifest": "quality_reports/results/mebane_gates/G0/round2/candidate_manifest.json",
        "review": "quality_reports/results/mebane_gates/G0/round2/review/review.json",
        "adjudication": "quality_reports/results/mebane_gates/G0/round2/adjudication.json",
    }
    expected = {
        "manifest": G0_MANIFEST_SHA,
        "review": G0_REVIEW_SHA,
        "adjudication": G0_ADJUDICATION_SHA,
    }
    for key, path in dependency_paths.items():
        if sha256(path) != expected[key]:
            raise RuntimeError(f"G0 {key} hash differs from approved dependency")

    inputs = [
        "replication_authors/extracted/fingerprint_brazil/raw-data/votacao_secao_2022_BR.csv",
        "replication_authors/extracted/fingerprint_brazil/raw-data/detalhe_votacao_secao_2022_BR.csv",
        "quality_reports/results/mebane_gates/coordination/Historico_Totalizacao_Presidente_BR_1T_2022.zip",
        "quality_reports/results/mebane_gates/coordination/Historico_Totalizacao_Presidente_BR_2T_2022.zip",
        "quality_reports/results/mebane_gates/coordination/detalhe_votacao_munzona_2022.zip",
        "quality_reports/results/mebane_gates/coordination/votacao_candidato_munzona_2022.zip",
        "quality_reports/results/mebane_gates/coordination/tse2022_control_sources.md",
        "quality_reports/results/mebane_gates/coordination/pm23_2023-07-02.pdf",
        "quality_reports/results/2026-09-28_mebane_denominadores_brancos_nulos.md",
        "quality_reports/results/mebane_gates/G0/round1/snapshots/R/01_load_tse.R",
        "quality_reports/results/mebane_gates/G0/round1/snapshots/R/02_build_vars.R",
        *dependency_paths.values(),
    ]
    code = [
        "R/01_load_tse.R", "R/02_build_vars.R", "R/lib/mebane_data.R",
        "tests/mebane/data/test_g1.R",
        "tests/mebane/data/check_official_histories.R",
        "tests/mebane/data/check_official_munzona.R",
        "tests/mebane/data/check_replay.R",
        f"{ROUND}/freeze_candidate.py",
    ]
    configuration = ["config/mebane/2022.json", f"{ROUND}/gate_contract.json"]
    final = f"{ROUND}/outputs/2022_final"
    replay = f"{ROUND}/outputs/2022_replay"
    final_names = [
        "sections_validated.parquet", "votes_validated.parquet",
        "abstention_exceptions.csv", "source_metadata.csv", "load_config_sha256.txt",
        "model_counts.parquet", "uf_turn_reconciliation.csv",
        "candidate_turn_totals.csv", "rule_log.csv", "independent_raw_uf_turn.csv",
        "official_history_reconciliation.csv", "official_munzona_uf_turn_reconciliation.csv",
        "official_munzona_candidate_uf_turn.csv", "candidate_coalition_metadata.csv",
        "official_noninstalled_zone.csv", "deterministic_replay.csv",
    ]
    replay_names = [
        "sections_validated.parquet", "votes_validated.parquet",
        "abstention_exceptions.csv", "source_metadata.csv", "load_config_sha256.txt",
        "model_counts.parquet", "uf_turn_reconciliation.csv",
        "candidate_turn_totals.csv", "rule_log.csv",
    ]
    outputs = [
        *(f"{final}/{name}" for name in final_names),
        *(f"{replay}/{name}" for name in replay_names),
        f"{ROUND}/implementation.md", f"{ROUND}/todo_evidence.json",
        f"{ROUND}/outputs/2022_primary/SUPERSEDED.md",
    ]
    grouped = {"inputs": inputs, "code": code, "configuration": configuration,
               "outputs": outputs}
    for field, paths in grouped.items():
        if len(paths) != len(set(paths)):
            raise RuntimeError(f"Duplicate path in {field}")
        for path in paths:
            if not (ROOT / path).is_file():
                raise RuntimeError(f"Missing {field} path: {path}")

    run = {
        "gate_id": "G1", "round": "round1", "contract_sha256": contract_sha,
        "executor_id": EXECUTOR_ID,
        "goal_id": EXECUTOR_ID,
        "goal_objective": "Entregar candidato revisável G1 do pipeline TSE parametrizado, com implementação, testes, execução completa 2022 e evidências delimitadas, sem aprovar o gate.",
        "requested_model": "gpt-6-sol", "requested_effort": "high",
        "effective_model": None, "effective_effort": None,
        "recorded_at_utc": datetime.now(timezone.utc).isoformat(),
        "dependency_manifests": {"G0": G0_MANIFEST_SHA},
        "dependency_approvals": {"G0": {
            "review_sha256": G0_REVIEW_SHA,
            "adjudication_sha256": G0_ADJUDICATION_SHA,
        }},
        **grouped,
        "component_sha256": {field: {path: sha256(path) for path in paths}
                              for field, paths in grouped.items()},
        "commands": [
            {"command": "Rscript --vanilla tests/mebane/data/test_g1.R", "exit_code": 0, "scope": "adversarial fixtures"},
            {"command": f"Rscript --vanilla R/01_load_tse.R config/mebane/2022.json {final}", "exit_code": 0, "scope": "full 2022 load"},
            {"command": f"Rscript --vanilla R/02_build_vars.R config/mebane/2022.json {final}", "exit_code": 0, "scope": "full 2022 build"},
            {"command": f"Rscript --vanilla tests/mebane/data/test_g1.R --full {final}", "exit_code": 0, "scope": "independent raw aggregation"},
            {"command": f"Rscript --vanilla tests/mebane/data/check_official_histories.R {final}", "exit_code": 0, "scope": "official historical national controls"},
            {"command": f"Rscript --vanilla tests/mebane/data/check_official_munzona.R {final}", "exit_code": 0, "scope": "official 2026-generation UF and candidate controls"},
            {"command": f"Rscript --vanilla R/01_load_tse.R config/mebane/2022.json {replay}", "exit_code": 0, "scope": "replay load"},
            {"command": f"Rscript --vanilla R/02_build_vars.R config/mebane/2022.json {replay}", "exit_code": 0, "scope": "replay build"},
            {"command": f"Rscript --vanilla tests/mebane/data/check_replay.R {final} {replay}", "exit_code": 0, "scope": "byte determinism"},
        ],
        "versions": {"R": "4.4.2", "data.table": "1.17.0", "arrow": "22.0.0",
                     "jsonlite": "2.0.0", "digest": "0.6.37"},
        "seeds": None,
        "execution_notes": [
            "An initial fail-closed run detected the AM non-installed section; the final explicit exception is flagged and not model-eligible.",
            "The superseded exploratory output is not a model input; only 2022_final is the candidate and 2022_replay is the deterministic replay.",
            "The historical TSE ZIPs do not provide abstention fields or UF controls; the separately versioned 2026 munzona ZIPs provide UF controls.",
            "No installation, update, or MCMC was run.",
        ],
    }
    write_json(ROUND_DIR / "run.json", run)
    manifest_paths = sorted(set(inputs + code + configuration + outputs + [f"{ROUND}/run.json"]))
    manifest = {
        "gate_id": "G1", "round": "round1", "contract_sha256": contract_sha,
        "files": [{"path": path, "sha256": sha256(path),
                   "bytes": (ROOT / path).stat().st_size} for path in manifest_paths],
    }
    write_json(ROUND_DIR / "candidate_manifest.json", manifest)
    print(f"G1 contract_sha256={contract_sha}")
    print(f"G1 candidate_manifest_sha256={sha256(f'{ROUND}/candidate_manifest.json')}")
    print(f"files={len(manifest_paths)}")


if __name__ == "__main__":
    main()
