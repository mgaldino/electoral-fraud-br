"""Record the source-bound dependency incident without reverting user changes."""

import hashlib
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[5]
G2 = ROOT / "quality_reports/results/mebane_gates/G2/round2"
REVIEW = G2 / "review/review.json"
MANIFEST = G2 / "candidate_manifest.json"
MISSING = "ssrn-4073770.pdf.download/ssrn-4073770.pdf"
EXPECTED = "524dc82c59612ec91b3a6ab475dd34f0607546a37823c9a9b1fd652677a8acdf"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


review = json.loads(REVIEW.read_text(encoding="utf-8"))
assert sha(REVIEW) == "ff6d0d2ea29edde8083491a971269fd19094d7140e4f366e95b1910c400f64c7"
assert sha(MANIFEST) == review["candidate_manifest_sha256"]
files = json.loads(MANIFEST.read_text(encoding="utf-8"))["files"]
for item in files:
    assert sha(ROOT / item["path"]) == item["sha256"], item["path"]
assert not (ROOT / MISSING).exists(), "Incident state changed; inspect before adjudicating"
commit = subprocess.check_output(["git", "rev-parse", "eabe93a"], cwd=ROOT, text=True).strip()
blob = subprocess.check_output(["git", "show", f"{commit}:{MISSING}"], cwd=ROOT)
assert hashlib.sha256(blob).hexdigest() == EXPECTED
now = datetime.now(timezone.utc).isoformat()
record = {
    "schema_version": "1.0", "adjudication_id": "mebane-G2:5c4b39aaa1c2:round2-initial",
    "gate_id": "G2", "round": "round2", "contract_sha256": review["contract_sha256"],
    "candidate_manifest_sha256": sha(MANIFEST), "review_sha256": sha(REVIEW),
    "status": "inconclusive", "unresolved_material_findings": 1,
    "source": {"reviewed_artifact": str(MANIFEST.relative_to(ROOT)),
               "sha256": sha(MANIFEST), "artifact_intact": True},
    "contract": {"required": False, "path": None, "sha256": None, "contract_id": None,
                 "artifact_sha256": None, "status": None, "stale": False},
    "contract_scope_note": "Contrato de código e método, não transformação de argumento. Decisões D1-D3 aprovadas no escopo metodológico pela QA; assinatura geral depende da integridade G0.",
    "review_sources": [{"review_id": "QA-G2-R2", "path": str(REVIEW.relative_to(ROOT)), "sha256": sha(REVIEW)}],
    "findings": [{
        "finding_id": "G2-R2-QA-I1", "id": "G2-R2-QA-I1", "source_review": "QA-G2-R2",
        "quoted_finding": "Dependência congelada G0 perdeu um arquivo durante a QA",
        "type": "artifact", "severity": "major", "scientific_dimension": "frozen_dependency_integrity",
        "held_decision": False, "status": "CONFIRMED", "resolved": False,
        "source_locations": ["quality_reports/results/mebane_gates/G0/round2/candidate_manifest.json:792", MISSING,
                             "quality_reports/results/mebane_gates/G2/round2/review/integrity_final.json"],
        "defect_evidence": ["O caminho esperado está ausente e o checker geral retorna missing file em G0.",
                            "A QA confirmou o arquivo no início e sua ausência no fim. A coordenação confirmou duas deleções concorrentes em git status, sem atribuir autoria."],
        "refuting_evidence": [],
        "mechanical_checks": ["Todos os 163 hashes diretos do candidato G2 reconferidos pela coordenação.",
                              f"git show {commit}:{MISSING}: 1360 bytes, SHA256 {EXPECTED}; nenhum arquivo restaurado.",
                              "python3 -B scripts/mebane_gates.py check: exit 1, missing file em G0."],
        "reasoning": "A integridade formal da dependência mudou; isso não altera o conteúdo do modelo nem refuta os 59 checks metodológicos. O arquivo já era inválido/incompleto e não é fonte científica. O Git preserva os bytes, mas o checker exige o arquivo no caminho do manifesto. Não desfazer uma mudança concorrente sem escolha do usuário.",
        "proposed_fix_assessment": "owner_decision",
        "disposition": "Usuário consultado: recuperar apenas o arquivo inventariado ou manter a exclusão e rever os vínculos do inventário. Depois, rechecagem delimitada, sem repetir a auditoria matemática.",
        "resolution": "Aguardando resposta. G3 completo não iniciado; reparo independente AR-02 pode prosseguir sob sua adjudicação própria."
    }],
    "resolved_prior_findings": [
        {"id": d["id"], "status": "CONFIRMED", "resolved": True,
         "resolution": d["scope"], "scientific_defect_refuted": False}
        for d in review["decision_closure"]
    ],
    "summary": {"total": 1, "confirmed": 1, "partial": 0, "refuted": 0, "unresolved": 0, "held_decisions": 0},
    "adjudication": {"verdict": "BLOCKED", "checked_at": now,
                     "reasons": ["Pendência formal de integridade G0, não erro das decisões D1-D3.",
                                 "Não restauração de alteração concorrente sem autorização; pergunta enviada ao usuário.",
                                 "BLOCKED é veredicto desta assinatura, não estado do goal nativo nem veto a reparo independente."]},
    "evidence": {"direct_candidate_files_verified": len(files), "independent_checks_passed": 59,
                 "preserved_git_commit": commit, "missing_sha256": EXPECTED, "missing_bytes": len(blob),
                 "restored": False, "review_manifest_sha256": sha(G2 / "review/review_manifest.json")},
}
(G2 / "adjudication_initial.json").write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"status": "inconclusive", "candidate_files_verified": len(files),
                  "git_bytes_match": True, "restored": False, "checked_at": now}))
