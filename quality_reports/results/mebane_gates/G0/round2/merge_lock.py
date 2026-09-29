"""Append only the six installed records absent from the 174-entry lockfile."""

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[5]
ROUND = Path(__file__).resolve().parent
target = ROOT / "renv.lock"
original = target.read_text(encoding="utf-8")
old = json.loads(original)
proposal = json.loads((ROUND / "installed_supplement.lock").read_text(encoding="utf-8"))
report = json.loads((ROUND / "lock_reconciliation.json").read_text(encoding="utf-8"))
missing = report["missing"]
assert len(old["Packages"]) == 174
assert set(missing) == {"bbmle", "bdsmatrix", "diptest", "emdbook", "plyr", "spikes"}
assert all(name not in old["Packages"] and name in proposal["Packages"] for name in missing)
anchor = "\n  }\n}\n"
assert original.endswith(anchor), "Unexpected lockfile layout"
(ROUND / "renv_before.lock").write_text(original, encoding="utf-8")
additions = []
for name in sorted(missing):
    encoded = json.dumps({name: proposal["Packages"][name]}, ensure_ascii=False, indent=2)
    additions.append("\n".join("  " + line for line in encoded.splitlines()[1:-1]))
updated = original[: -len(anchor)] + ",\n" + ",\n".join(additions) + anchor
new = json.loads(updated)
assert new["R"] == old["R"]
assert all(new["Packages"][name] == record for name, record in old["Packages"].items())
assert len(new["Packages"]) == 180
target.write_text(updated, encoding="utf-8")
print("Added six records; preserved 174 original records")
