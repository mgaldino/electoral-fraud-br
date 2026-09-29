#!/usr/bin/env python3
"""Adjudicate the bounded build-input finding before its documentary repair."""

import datetime
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[5]
BASE = Path(__file__).resolve().parent
G0 = ROOT / "quality_reports/results/mebane_gates/G0/round3"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def rel(path):
    return path.relative_to(ROOT).as_posix()


source = G0 / "review/source_checks.json"
counterexample = G0 / "review/run01/ledger_counterexample.json"
manifest = G0 / "candidate_manifest.json"
checks = json.loads(source.read_text())
probe = json.loads(counterexample.read_text())
assert checks["function_AST_equal"]
assert checks["current_checker_sha256"] == checks["frozen_checker_sha256"]
assert probe["same_static_contract_accepted"] and probe["todo_output_changed"]
assert probe["baseline_matches_frozen_todo"] and probe["synthetic_in_memory_only"]
current = json.loads((ROOT / "quality_reports/plans/mebane_2022_2026_gates.json").read_text())
snapshot = BASE / "before/quality_reports/plans/mebane_2022_2026_gates.json"
previous = json.loads(snapshot.read_text())
select = lambda value: next(gate for gate in value["gates"] if gate["id"] == "G0")
assert select(current) == select(previous)
record = {
    "schema_version": "1.0", "adjudication_id": "G0-round3-build-input-repair",
    "source": {"reviewed_artifact": rel(manifest), "sha256": sha(manifest), "artifact_intact": True},
    "contract": {"required": False, "path": None, "sha256": None, "contract_id": None,
                 "artifact_sha256": None, "status": None, "stale": False},
    "review_sources": [{"review_id": "QA-G0-R3-source-checks", "path": rel(source), "sha256": sha(source)},
                       {"review_id": "QA-G0-R3-counterexample", "path": rel(counterexample), "sha256": sha(counterexample)}],
    "findings": [{
        "finding_id": "G0-R3-COORD-F01", "source_review": "QA-G0-R3-source-checks",
        "quoted_finding": checks["narrow_finding"], "type": "artifact", "severity": "major",
        "scientific_dimension": "construction_metadata_provenance", "held_decision": False,
        "status": "CONFIRMED", "source_locations": [rel(G0 / "build_candidate.py"), rel(counterexample)],
        "defect_evidence": ["O construtor consome status/evidence do ledger vivo, que o contrato estático não fixa.",
                            "A contraprova independente muda o output de evidências sem mudar o contrato aceito."],
        "refuting_evidence": [],
        "mechanical_checks": ["Contraprova sintética em memória inspecionada; baseline reproduz todo_evidence congelado.",
                              "G0 completo do ledger atual é igual ao snapshot before preservado pela coordenação.",
                              "Checker atual e snapshot têm o mesmo SHA-256; não é um segundo defeito material."],
        "reasoning": "O inventário e seus 157 arquivos presentes permanecem corretos. A lacuna está na reprodução dos metadados da construção, não na matemática ou nos dados. O snapshot existente fornece a entrada exata sem nova escolha do usuário.",
        "proposed_fix_assessment": "safe",
        "disposition": "Construir G0 round4 com snapshot vinculado dos metadados efetivamente consumidos, ler esse snapshot e preservá-lo no manifesto. Preservar round3 integralmente; não repetir análise científica, excluir ou restaurar arquivos. Rechecagem independente limitada do reparo."
    }],
    "summary": {"total": 1, "confirmed": 1, "partial": 0, "refuted": 0, "unresolved": 0, "held_decisions": 0},
    "adjudication": {"verdict": "READY_FOR_IMPLEMENTATION",
                     "checked_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
                     "reasons": ["Reparo documental delimitado, já coberto pela autorização para atualizar o inventário.",
                                 "Parecer parcial independente e fonte diretamente conferidos; nenhuma conclusão científica nova."]}
}
with (BASE / "adjudication_build_input.json").open("x", encoding="utf-8") as stream:
    json.dump(record, stream, ensure_ascii=False, indent=2)
    stream.write("\n")
with (BASE / "adjudication_build_input.md").open("x", encoding="utf-8") as stream:
    stream.write("# Reparo limitado da proveniência do construtor\n\n"
                 "G0-R3-COORD-F01: **CONFIRMED**. O inventário está correto, mas seu construtor "
                 "lê status e evidências do ledger vivo sem fixá-los como entrada. A contraprova "
                 "independente altera a saída sem alterar o contrato estático.\n\n"
                 "**READY_FOR_IMPLEMENTATION**: usar o snapshot exato já preservado em nova round4, "
                 "vinculá-lo no manifesto e ler a entrada congelada. Preservar round3; nenhuma "
                 "exclusão, restauração, análise científica ou instalação. A QA final de round3 "
                 "continua separada; esta adjudicação usa os registros parciais identificados no JSON.\n")
print("Adjudicação limitada criada; nenhum candidato alterado.")
