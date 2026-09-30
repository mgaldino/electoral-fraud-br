"""Recover the sole drifted byte sequence in the initial G3 candidate."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[6]
HERE = Path(__file__).resolve().parent
ROUND = HERE.parent
old = json.loads((ROUND / "candidate_manifest.json").read_text())
entries = {row["path"]: row for row in old["files"]}
source = "tests/mebane/likelihood/g3_jags.R"
expected = entries[source]
current = (ROOT / source).read_text(encoding="utf-8")
replacements = (
    ('outdir <- "quality_reports/results/mebane_gates/G3/round1/jags_attempt5"',
     'outdir <- "quality_reports/results/mebane_gates/G3/round1/jags_attempt3"'),
    ('  constant <- length(unique(as.vector(x)))==1L &&\n'
     '    length(unique(exact[[nm]][exact$posterior > 0]))==1L',
     '  constant <- length(unique(as.vector(x)))==1L && length(unique(exact[[nm]]))==1L'),
    ('  (!is.na(rhat) & !is.na(ess_bulk) & !is.na(ess_tail) &\n'
     '    rhat < 1.01 & ess_bulk >= 400 & ess_tail >= 400))',
     '  (!is.na(rhat) & rhat < 1.01 & ess_bulk >= 400 & ess_tail >= 400))'),
)
for new, old_text in replacements:
    assert current.count(new) == 1
    current = current.replace(new, old_text)
recovered = current.encode("utf-8")
assert len(recovered) == expected["bytes"]
assert hashlib.sha256(recovered).hexdigest() == expected["sha256"]
dest = HERE / "snapshots/root_candidate_old" / source
assert not dest.exists()
dest.parent.mkdir(parents=True, exist_ok=True)
dest.write_bytes(recovered)

sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
drifted = [row["path"] for row in old["files"] if
           not (ROOT / row["path"]).is_file() or sha(ROOT / row["path"]) != row["sha256"]]
assert drifted == [source], drifted
mapping = {
    "initial_candidate_manifest_sha256": sha(ROUND / "candidate_manifest.json"),
    "drifted_paths": drifted,
    "recovered": [{"original_path": source,
                   "original_sha256": expected["sha256"],
                   "original_bytes": expected["bytes"],
                   "recovered_path": str(dest.relative_to(ROOT)),
                   "recovered_sha256": sha(dest)}],
    "other_initial_manifest_entries": "All other 115 entries still match their original hashes at recovery time",
    "raw_JAGS_draws": "not saved by test harness; only summary and exact-state outputs are recoverable",
}
out = HERE / "old_code_mapping.json"
assert not out.exists()
out.write_text(json.dumps(mapping, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("recovered", source, expected["sha256"])
