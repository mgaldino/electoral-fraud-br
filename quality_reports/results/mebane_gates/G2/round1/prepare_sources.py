"""Freeze contextual/historical copies; verify G0 bytes before copying.

Infrastructure only: all mathematical computation is in the R tests.
Run from the project root. Existing frozen copies must be byte-identical.
"""
import datetime
import hashlib
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[5]
ROUND = Path(__file__).resolve().parent
G0 = ROOT / "quality_reports/results/mebane_gates/G0/round2"

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

assert sha(G0 / "candidate_manifest.json") == "f71333db477385fc78dad8a7a1a7ca78e48479226dcdbde80ce97d724409fec7"
baseline = {x["path"]: x["sha256"] for x in json.loads((G0 / "candidate_manifest.json").read_text())["files"]}
historical = [
    "05_eforensics_qbl_brasilia_fresh_v2_summary.txt",
    "05_jags_qbl_zone_fe_summary.txt",
    "05_stan_qbl_brasilia_log_n2000.md",
    "05_stan_qbl_brasilia_timings_n2000.csv",
]
entries = []
for name in historical + ["2026-09-28_mebane_denominadores_brancos_nulos.md"]:
    relative = "quality_reports/results/" + name
    source = ROOT / relative
    context = name not in historical
    if not context:
        assert sha(source) == baseline[relative], relative
    dest = ROUND / "sources" / ("denominadores_contexto.md" if context else name)
    if dest.exists():
        assert sha(dest) == sha(source), "Refuse to overwrite changed frozen source"
    else:
        shutil.copyfile(source, dest)
    entries.append({"original": relative, "snapshot": str(dest.relative_to(ROOT)),
                    "sha256": sha(dest), "bytes": dest.stat().st_size,
                    "basis": "inspected" if context else "historical",
                    "G0_approved_baseline": not context})
provenance = {
    "frozen_at_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "copies": entries,
    "manual": {
        "author": "Martyn Plummer", "version": "4.3.0", "date": "2017-06-28",
        "consulted_url": "https://webhomes.maths.ed.ac.uk/~swood34/TOI/jags_user_manual.pdf",
        "download_url": "https://mfasiolo.github.io/TOI/jags_user_manual.pdf",
        "download_status": "complete; curl exit 0; pdfinfo 74 pages, 429729 bytes",
        "download_sha256": sha(ROUND / "sources/jags_user_manual_4.3.0.pdf"),
        "earlier_attempts": "Edinburgh curl failed in sandbox DNS; escalated 40s and 240s attempts timed out. Partial bytes replaced by complete academic mirror copy.",
        "consulted_pages_printed": [45, 47, 50, 53],
        "scope": "Primary author manual mirrored at academic hosts; parameter semantics only, not empirical validation"
    }
}
(ROUND / "source_provenance.json").write_text(json.dumps(provenance, ensure_ascii=False, indent=2) + "\n")
print(json.dumps(provenance, ensure_ascii=False, indent=2))
