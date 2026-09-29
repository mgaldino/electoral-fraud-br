"""Freeze repaired canonical documents and the five omitted F1 artifacts."""

import hashlib
import json
import shutil
from pathlib import Path


ROOT = Path(__file__).resolve().parents[5]
ROUND = Path(__file__).resolve().parent
FIRST = ROOT / "quality_reports/results/mebane_gates/G0/round1"
OLD_MAP = json.loads((FIRST / "final_state_map.json").read_text(encoding="utf-8"))
F1 = ["research_note.md", *sorted(path.relative_to(ROOT).as_posix()
       for path in (ROOT / "output/tables").glob("*.csv"))]
assert len(F1) == 5
REPAIRED = ["README.md", "CLAUDE.md", "renv.lock",
            "quality_reports/plans/mebane_2022_2026_gates.json", *F1]


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


records = {item["original"]: dict(item, origin_round="round1") for item in OLD_MAP}
additions = []
for relative in REPAIRED:
    source = ROOT / relative
    assert source.is_file(), relative
    snapshot = ROUND / "final_state" / relative
    snapshot.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, snapshot)
    assert sha256(source) == sha256(snapshot)
    record = {"original": relative, "snapshot": snapshot.relative_to(ROOT).as_posix(),
              "sha256": sha256(snapshot), "bytes": snapshot.stat().st_size,
              "origin_round": "round2"}
    records[relative] = record
    if relative in F1:
        additions.append(dict(record, role="historical manuscript" if relative == "research_note.md"
                              else "historical supplementary-test table"))
(ROUND / "inventory_additions.json").write_text(
    json.dumps({"base_inventory": (FIRST / "inventory.json").relative_to(ROOT).as_posix(),
                "added_files": additions}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
(ROUND / "final_state_map.json").write_text(
    json.dumps([records[name] for name in sorted(records)], ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8")
print(f"Frozen {len(REPAIRED)} repaired/omitted files; mapped {len(records)} mutable sources")
