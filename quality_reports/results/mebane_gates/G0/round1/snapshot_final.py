"""Freeze the reconciled state of mutable baseline code and configuration."""

import hashlib
import json
import shutil
from pathlib import Path


ROOT = Path(__file__).resolve().parents[5]
ROUND = Path(__file__).resolve().parent
inventory = json.loads((ROUND / "inventory.json").read_text(encoding="utf-8"))
sources = sorted({item["path"] for item in inventory["items"]
                  if item["category"] in ("code", "configuration")})
sources += ["quality_reports/results/2026-09-28_gate_design/implementation_checker_round2.md",
            "quality_reports/results/2026-09-28_gate_design/implementation_checker_round3.md",
            "quality_reports/results/mebane_gates/coordination/method_sources_download.md"]
records = []
for relative in sources:
    source = ROOT / relative
    destination = ROUND / "final_state" / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, destination)
    original_hash = hashlib.sha256(source.read_bytes()).hexdigest()
    snapshot_hash = hashlib.sha256(destination.read_bytes()).hexdigest()
    assert original_hash == snapshot_hash
    records.append({"original": relative, "snapshot": destination.relative_to(ROOT).as_posix(),
                    "sha256": snapshot_hash, "bytes": destination.stat().st_size})
(ROUND / "final_state_map.json").write_text(json.dumps(records, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"Frozen {len(records)} mutable code/configuration files")
