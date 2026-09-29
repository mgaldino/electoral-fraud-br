"""Source-bound coordinator adjudication of three independently reproduced defects."""
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[5]
HERE = Path(__file__).resolve().parent
BASE = HERE.relative_to(ROOT).as_posix()


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


identities = {
    "candidate_manifest.json": "62f7a5c4907c9d39b75fe5cd88224bddb4796e015f69f004469e51df7ae493c8",
    "review/review.json": "a0232205b424c747f354fa5c950c7286370bd168070c51858945e0ff33886297",
    "review/review_manifest.json": "b8192cd30f8decf6f7be761f0dfd5f809dc6bc43cf1f67464769dffd725dd10f",
}
for path, expected in identities.items():
    assert sha(HERE / path) == expected, path
verified = {}
for name in ("candidate_manifest.json", "review/review_manifest.json"):
    entries = json.loads((HERE / name).read_text())["files"]
    assert len({item["path"] for item in entries}) == len(entries)
    for item in entries:
        path = ROOT / item["path"]
        assert sha(path) == item["sha256"], item["path"]
        assert path.stat().st_size == item["bytes"], item["path"]
    verified[name] = len(entries)
integrity = {"identities": identities, "verified_files": verified}
(HERE / "adjudication_integrity.json").write_text(json.dumps(integrity, indent=2) + "\n")
review = json.loads((HERE / "review/review.json").read_text())
checks = json.loads((HERE / "adjudication_checks.json").read_text())
encoding = json.loads((HERE / "review/encoding_probe_02/result.json").read_text())
assert checks["wrong_date_defect_confirmed"] and not checks["national_approval_claimed"]
assert encoding["defect_confirmed"] and encoding["utf8_valid"] and encoding["ascii"]["ok"]
reasoning = {
    "G7-R1-COORD-F03": "A coordenação reproduziu a rejeição do UTF-8 válido e a QA confirmou com arquivos próprios, controle ASCII e comparação de bytes. read.csv(fileEncoding='UTF-8') converte para o locale C. O contrato promete CSV UTF-8, portanto a falha é material. Reparar a leitura sem alterar locale global, preservar o nome exato e rejeitar bytes inválidos.",
    "G7-R1-QA-F01": "Código e contraprova própria confirmam que 03/10/2022 é aceito como T1, embora a data correta do fixture seja 02/10/2022. A data deve ser ancorada por turno. O calendário TSE arquivado documenta 04/10/2026 e eventual 25/10/2026; fixar a data condicional de T2 não presume sua ocorrência nem seu código de eleição.",
    "G7-R1-QA-F02": "O recibo omite abrangência e chama complete à completude relativa aos EA16 fornecidos. Uma única seção recebe complete=true. Isso não é aprovação nacional: ambas as flags de liberação continuam falsas. Confirmado somente como omissão de escopo/denominador; corrigir nomes/metadados e declarar UFs esperadas, sem fingir que presença de UFs prova cobertura nacional.",
}
findings = []
for finding in review["findings"]:
    fid = finding["id"]
    evidence = [f"{BASE}/review/review.json", f"{BASE}/adjudication_checks.json"]
    if fid == "G7-R1-COORD-F03":
        evidence = [f"{BASE}/adjudication_encoding.json", f"{BASE}/review/encoding_probe_02/result.json"]
    findings.append({
        "id": fid, "finding_id": fid, "source_review": "QA-G7-R1",
        "quoted_finding": finding["title"] + ": " + finding["counterexample"],
        "type": "scope_or_consistency" if fid.endswith("F02") else "artifact",
        "severity": finding["severity"], "scientific_dimension": "reprodutibilidade e escopo de validação de dados",
        "held_decision": False, "status": "CONFIRMED", "source_locations": finding["locations"],
        "defect_evidence": evidence, "refuting_evidence": [],
        "mechanical_checks": ["275 arquivos do candidato e 809 arquivos da QA verificados por SHA-256 e tamanho.",
                              "Contraprovas executadas pela coordenação e reprodução independente da QA."],
        "reasoning": reasoning[fid], "proposed_fix_assessment": "safe",
        "disposition": "Reparar em round2 e submeter novo hash à QA independente; preservar bytes anteriores.",
        "resolved": False, "resolution": None,
    })
record = {
    "schema_version": "1.0", "adjudication_id": "mebane-G7:62f7a5c4907c:round1",
    "gate_id": "G7", "round": "round1", "contract_sha256": review["contract_sha256"],
    "candidate_manifest_sha256": identities["candidate_manifest.json"],
    "review_sha256": identities["review/review.json"], "status": "changes_requested",
    "unresolved_material_findings": 2,
    "source": {"reviewed_artifact": f"{BASE}/candidate_manifest.json",
               "sha256": identities["candidate_manifest.json"], "artifact_intact": True},
    "contract": {"required": False, "path": None, "sha256": None, "contract_id": None,
                 "artifact_sha256": None, "status": None, "stale": False},
    "contract_scope_note": "Código/dados sob contrato operacional G7 canônico, não revisão de argumento de manuscrito.",
    "review_sources": [{"review_id": "QA-G7-R1", "path": f"{BASE}/review/review.json",
                        "sha256": identities["review/review.json"]}],
    "findings": findings,
    "summary": {"total": 3, "confirmed": 3, "partial": 0, "refuted": 0, "unresolved": 0, "held_decisions": 0},
    "adjudication": {"verdict": "READY_FOR_IMPLEMENTATION", "checked_at": datetime.now(timezone.utc).isoformat(),
                     "reasons": ["Os três defeitos foram confirmados contra o candidato exato e têm reparo seguro autorizado pelo pedido atual.",
                                 "Dois defeitos materiais e uma omissão de escopo permanecem abertos; este veredicto autoriza encaminhamento de reparo, não aprovação de G7.",
                                 "A escolha do modelo em G2 é independente; este reparo não decide priors, engines ou estimandos."]},
    "limits": ["Nenhum dado real de votos de 2026 foi adquirido.",
               "Falta conversor auditado de arquivos brutos oficiais para o CSV normalizado.",
               "Ingestão serial ou lock externo; não há garantia concorrente. Flags de liberação permanecem falsas."],
}
(HERE / "adjudication.json").write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
lines = ["# Adjudicação G7 round1", "", "**changes_requested; READY_FOR_IMPLEMENTATION para reparos seguros.**", "",
         "Candidato e QA íntegros: 275 + 809 arquivos conferidos. Dois defeitos materiais e uma omissão de escopo confirmados.", ""]
for finding in findings:
    lines.extend(["## " + finding["id"], "", finding["reasoning"], ""])
lines.extend(["## Encaminhamento", "", "Preservar fontes e fixtures anteriores; reparar somente UTF-8, data ancorada por turno e escopo territorial/completude. Criar round2, repetir regressões afetadas e obter revisão independente. G7 não é data-ready/inference-ready real. Não alterar G1/G2 ou seu alvo.", ""])
(HERE / "adjudication.md").write_text("\n".join(lines))
print(json.dumps({"integrity": verified, "status": record["status"], "adjudication_sha256": sha(HERE / "adjudication.json")}, indent=2))
