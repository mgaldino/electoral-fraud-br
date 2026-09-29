"""Copy small mutable canonical sources into the immutable G0 candidate."""

import hashlib
import json
import shutil
from pathlib import Path


ROOT = Path(__file__).resolve().parents[5]
ROUND = Path(__file__).resolve().parent
SOURCES = [
    "README.md", "CLAUDE.md", "R/00_setup.R", "R/01_load_tse.R",
    "R/02_build_vars.R", "R/05_eforensics_umeforensics_qbl.R",
    "R/05_eforensics_qbl_fresh_diagnostic.R", "R/05_jags_qbl_zone_fe.R",
    "R/05_stan_eforensics_qbl_calibrate.R", "R/05_compare_fits.R",
    "R/05_dip_test_diagnostics.R", "R/06_sp_linearity_check.R",
    "R/07_brasil_full_qbl.R", "stan/eforensics_qbl.stan",
]


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


records = []
for relative in SOURCES:
    source = ROOT / relative
    destination = ROUND / "snapshots" / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, destination)
    records.append({"canonical": relative, "snapshot": destination.relative_to(ROOT).as_posix(),
                    "sha256": sha256(destination), "bytes": destination.stat().st_size})
(ROUND / "snapshot_map.json").write_text(json.dumps(records, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"Snapshotted {len(records)} mutable sources")
