"""Adjudicate the independently checked interface fix, never approve G3."""

import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[5]
HERE = Path(__file__).resolve().parent
review_path = HERE / "interface_repair_review/review.json"
manifest_path = HERE / "interface_repair_review/review_manifest.json"
candidate_path = HERE / "interface_repair/candidate_manifest.json"
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
review = json.loads(review_path.read_text(encoding="utf-8"))
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
assert review["status"] == "pass" and not review["blocking_findings"]
assert not review["G3_pass"] and not review["inferential_approval"]
assert review["reviewer_uuid"] != review["executor_uuid"]
assert sha(candidate_path) == review["candidate_manifest_sha256"]
entries = manifest["inputs_read"] + manifest["outputs_generated"]
for entry in entries:
    assert sha(ROOT / entry["path"]) == entry["sha256"], entry["path"]
candidate = json.loads(candidate_path.read_text(encoding="utf-8"))
for entry in candidate["changed_files"]:
    assert sha(ROOT / entry["path"]) == entry["after_sha256"]
    for original in entry["preserved_before"]:
        assert sha(ROOT / original) == entry["before_sha256"]
record = {
    "schema_version": "1.0", "adjudication_id": "AR-02:4e08a91ba47e:closure1",
    "source": {"reviewed_artifact": str(candidate_path.relative_to(ROOT)),
               "sha256": sha(candidate_path), "artifact_intact": True},
    "contract": {"required": False, "path": None, "sha256": None, "contract_id": None,
                 "artifact_sha256": None, "status": None, "stale": False},
    "contract_scope_note": "Reparo de código/interface pré-G3. Não exige contrato de argumento; a especificação de interface é o commit fixado e a adjudicação AR-02.",
    "review_sources": [{"review_id": review["review_id"], "path": str(review_path.relative_to(ROOT)), "sha256": sha(review_path)}],
    "findings": [],
    "verified_observations": [item["id"] for item in review["findings"]],
    "resolved_prior_findings": [{
        "id": "AR-02", "status": "CONFIRMED", "resolved": True,
        "source_adjudication": str((HERE / "interface_repair_adjudication.json").relative_to(ROOT)),
        "resolution": "Quatro pares formula1/formula2 reparados, covariáveis preservadas, fontes anteriores íntegras. QA executou as chamadas reais até stub de amostragem, controles de respostas invertidas e probe independente com apenas covariáveis trocadas.",
        "scope": "Não estende o achado às listas fresh_v2/zoneFE nem reinterpreta fits como reestimados."
    }],
    "summary": {"total": 0, "confirmed": 0, "partial": 0, "refuted": 0, "unresolved": 0, "held_decisions": 0},
    "adjudication": {
        "verdict": "NO_CONFIRMED_DEFECTS", "checked_at": datetime.now(timezone.utc).isoformat(),
        "reasons": [
            "Nenhum novo defeito no reparo delimitado; AR-02 permanece confirmado, agora resolvido.",
            "Coordenação inspecionou o diff, os stubs instalados antes de eval, restauração de namespaces, probe independente e logs finais. Recalculou os 20 hashes da QA e hashes before/after dos dois scripts.",
            "Observações info/verified da QA são verificações positivas, não findings de defeito artificialmente reclassificados.",
            "Aceitação somente da interface; G3 não executado nem aprovado, G10 não replicado, inferência não liberada.",
            "Pendência de integridade G0 continua aguardando escolha do usuário; nada foi restaurado ou excluído por este reparo."
        ]
    },
    "scope": "AR-02 interface only, pre-G3", "G3_pass": False, "inferential_approval": False,
    "evidence": {"qa_manifest_sha256": sha(manifest_path), "qa_hashes_verified": len(entries),
                 "candidate_sha256": sha(candidate_path), "MCMC_executed": False,
                 "independent_wrapper_stub_captures": 8, "independent_covariate_stub_captures": 2,
                 "compiler_entries": 0},
}
(HERE / "interface_repair_closure.json").write_text(
    json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8",
)
print(json.dumps({"status": "interface_repair_accepted", "qa_hashes_verified": len(entries), "G3_pass": False}))
