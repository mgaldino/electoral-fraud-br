"""Project the independently safe interface repair from the global adjudication."""

import copy
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path


HERE = Path(__file__).resolve().parent
source = HERE / "replication_adjudication.json"
full = json.loads(source.read_text(encoding="utf-8"))
record = copy.deepcopy(full)
record["adjudication_id"] = "authors-replication-interface:AR-02:round1"
record["global_adjudication"] = {
    "path": str(source.relative_to(HERE.parents[4])),
    "sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
    "verdict": full["adjudication"]["verdict"],
}
record["findings"] = [f for f in full["findings"] if f["finding_id"] == "AR-02"]
assert len(record["findings"]) == 1
assert record["findings"][0]["status"] == "CONFIRMED"
record["summary"] = {
    "total": 1, "confirmed": 1, "partial": 0, "refuted": 0,
    "unresolved": 0, "held_decisions": 0,
}
record.pop("unresolved_material_findings")
record["adjudication"] = {
    "verdict": "READY_FOR_IMPLEMENTATION",
    "checked_at": datetime.now(timezone.utc).isoformat(),
    "reasons": [
        "AR-02 é defeito de interface com fonte e reparo inequívocos, independente de localizar valores numéricos externos para G10.",
        "Escopo: somente quatro chamadas invertidas, snapshots prévios e teste sentinela; não rodar scripts históricos nem alterar fits ou modelo.",
        "As demais pendências do registro global permanecem; este encaminhamento não aprova G2, G3, G10 ou inferência.",
        "A autorização já existe no pedido de prosseguir com G2/G3; reparo sujeito à QA independente de G3.",
    ],
}
destination = HERE / "interface_repair_adjudication.json"
destination.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(destination)
