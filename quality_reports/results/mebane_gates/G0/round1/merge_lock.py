"""Append only missing installed dependency records, preserving all old records."""

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[5]
ROUND = Path(__file__).resolve().parent
target = ROOT / "renv.lock"
original = target.read_text(encoding="utf-8")
old = json.loads(original)
proposal = json.loads((ROUND / "installed_records.lock").read_text(encoding="utf-8"))
report = json.loads((ROUND / "lock_reconciliation.json").read_text(encoding="utf-8"))
missing = report["missing"]
assert set(missing) == set(proposal["Packages"]) - set(old["Packages"])
assert not report["proposal_entries_unavailable"]
anchor = "\n  }\n}\n"
assert original.endswith(anchor), "Unexpected lockfile layout; do not rewrite"

(ROUND / "renv_before.lock").write_text(original, encoding="utf-8")
additions = []
for name in sorted(missing):
    encoded = json.dumps({name: proposal["Packages"][name]}, ensure_ascii=False, indent=2)
    inner = encoded.splitlines()[1:-1]
    additions.append("\n".join("  " + line for line in inner))
replacement = ",\n" + ",\n".join(additions) + anchor
updated = original[: -len(anchor)] + replacement
new = json.loads(updated)
assert new["R"] == old["R"]
assert all(new["Packages"][name] == record for name, record in old["Packages"].items())
assert set(new["Packages"]) == set(old["Packages"]) | set(missing)
target.write_text(updated, encoding="utf-8")
print(f"Added {len(missing)} records; preserved {len(old['Packages'])} old records")
