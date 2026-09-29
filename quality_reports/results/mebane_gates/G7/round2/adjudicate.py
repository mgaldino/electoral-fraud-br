"""Verify frozen evidence and record the coordinator's scoped G7 approval."""
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[5]
HERE = Path(__file__).resolve().parent
BASE = HERE.relative_to(ROOT).as_posix()
COORD = "quality_reports/results/mebane_gates/coordination"


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


identities = {
    "candidate_manifest.json": "2593c78b5687c883aff6441f09b5d2e67cd319c1ceae723d043dee44a36e62a6",
    "review/review.json": "9fb58b9afb0d4aac73a56989a232ac005d4f3ff4f415504d4cb11b58a815f6b7",
    "review/review_manifest.json": "ac267cf285ce751c53b37bea838659058451b2cb4a8bb0df97790e7c711479c1",
}
for relative, expected in identities.items():
    assert sha(HERE / relative) == expected, relative
verified = {}
for relative in ("candidate_manifest.json", "review/review_manifest.json"):
    manifest = json.loads((HERE / relative).read_text())
    entries = manifest["files"]
    assert len({x["path"] for x in entries}) == len(entries)
    for entry in entries:
        path = ROOT / entry["path"]
        assert sha(path) == entry["sha256"] and path.stat().st_size == entry["bytes"], entry["path"]
    verified[relative] = len(entries)
checks = []
for suffix in ("C", "UTF8"):
    path = ROOT / COORD / f"g7_round2_coordinator_{suffix}.json"
    check = json.loads(path.read_text())
    assert check["all_passed"] and len(check["tests"]) == 8
    assert check["code_sha256"] == sha(ROOT / "R/lib/mebane_2026_intake.R")
    assert check["script_sha256"] == sha(ROOT / COORD / "verify_g7_repairs.R")
    checks.append({"path": str(path.relative_to(ROOT)), "sha256": sha(path), "locale": check["locale"]})
review = json.loads((HERE / "review/review.json").read_text())
assert review["status"] == "pass" and review["manifest_complete"] and not review["findings"]
assert review["executor_id"] != review["reviewer_id"]
expected_findings = {"G7-R1-COORD-F03", "G7-R1-QA-F01", "G7-R1-QA-F02"}
assert {x["id"] for x in review["resolved_prior_findings"]} == expected_findings
resolved = []
for item in review["resolved_prior_findings"]:
    assert item["closed"] and item["resolved"] and item["prior_status"] == "CONFIRMED"
    resolved.append({"id": item["id"], "status": "CONFIRMED", "resolved": True,
                     "source_review": "QA-G7-R1/R2", "resolution": item["resolution"],
                     "source_locations": item["locations"],
                     "evidence": [f"{BASE}/review/review.json", f"{BASE}/review/verification.json"] +
                                 [x["path"] for x in checks]})
integrity = {"identities": identities, "verified_files": verified, "coordinator_checks": checks}
(HERE / "adjudication_integrity.json").write_text(json.dumps(integrity, indent=2) + "\n")
record = {
    "schema_version": "1.0", "adjudication_id": "mebane-G7:2593c78b5687:round2",
    "gate_id": "G7", "round": "round2", "contract_sha256": review["contract_sha256"],
    "candidate_manifest_sha256": identities["candidate_manifest.json"],
    "review_sha256": identities["review/review.json"], "status": "pass",
    "unresolved_material_findings": 0,
    "source": {"reviewed_artifact": f"{BASE}/candidate_manifest.json",
               "sha256": identities["candidate_manifest.json"], "artifact_intact": True},
    "contract": {"required": False, "path": None, "sha256": None, "contract_id": None,
                 "artifact_sha256": None, "status": None, "stale": False},
    "contract_scope_note": "Aprovação de código/dados sob contrato operacional G7; não é revisão de argumento de manuscrito nem aprovação de inferência.",
    "review_sources": [{"review_id": "QA-G7-R2", "path": f"{BASE}/review/review.json",
                        "sha256": identities["review/review.json"]}],
    "findings": [], "resolved_prior_findings": resolved,
    "summary": {"total": 0, "confirmed": 0, "partial": 0, "refuted": 0, "unresolved": 0, "held_decisions": 0},
    "summary_note": "Três defeitos anteriores continuam CONFIRMED, agora reparados e independentemente verificados; nenhum novo finding.",
    "adjudication": {"verdict": "NO_CONFIRMED_DEFECTS", "checked_at": datetime.now(timezone.utc).isoformat(),
                     "reasons": ["Os três reparos foram rechecados por QA independente e oito testes próprios em cada um de dois locales.",
                                 "A coordenação verificou todos os 1859 arquivos do candidato e 1173 da QA e leu os reparos, o parecer e os limites.",
                                 "A QA passou 69 casos por locale, oito probes do DAG e suítes afetadas; 25 recibos são byte-idênticos entre locales.",
                                 "G7-T1 a T4 atendidos para prontidão ensaiada. G8/G9 permanecem dependentes de publicação oficial e G6; G2 permanece changes_requested."]},
    "limits": review["limits"],
}
(HERE / "adjudication.json").write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
lines = ["# Adjudicação G7 round2", "", "**G7 aprovado para prontidão operacional ensaiada.** Nenhum novo defeito encontrado; os três findings anteriores foram reparados e verificados, sem reclassificá-los como refutados.", ""]
for item in resolved:
    lines.extend(["## " + item["id"], "", item["resolution"], ""])
lines.extend(["## Evidência e limites", "", "A coordenação leu o código e o parecer, verificou 1.859 arquivos do candidato e 1.173 da QA e executou oito testes próprios em C e pt_BR.UTF-8. A QA executou 69 casos próprios em cada locale, oito casos do DAG e as suítes afetadas; 25 recibos foram byte-idênticos. Os 1.066 arquivos de round1 estão preservados e as fontes antigas são recuperáveis pelo mapa de 1.094 cópias.", "", "A aprovação abrange CSV normalizado por seção/candidato, referências, controles, snapshots e roteiro. Não atesta voto real, cobertura nacional ou convergência. Falta conversor auditado dos arquivos oficiais brutos. Todos os recibos continuam data_ready=false, inference_ready=false e national_coverage_attested=false. Ingestão serial ou lock externo; escala/memória ainda não testadas nacionalmente.", "", "G0/G1 permanecem aprovados; G2 continua changes_requested por escolhas metodológicas. Nenhum MCMC, instalação ou aquisição de votos de 2026 ocorreu neste reparo. G8/G9 não foram liberados.", ""])
(HERE / "adjudication.md").write_text("\n".join(lines))
print(json.dumps({"verified": verified, "status": "pass", "adjudication_sha256": sha(HERE / "adjudication.json")}, indent=2))
