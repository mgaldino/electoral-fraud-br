"""Freeze a handoff snapshot without restoring, staging or committing files."""

import hashlib
import json
import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[5]
HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "batch_manifest.json"
assert not OUTPUT.exists(), "Batch already frozen; create a new batch for later changes"


def paths(*args):
    value = subprocess.check_output(["git", *args, "-z"], cwd=ROOT)
    return [entry.decode("utf-8") for entry in value.split(b"\0") if entry]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


tracked = paths("diff", "--name-only", "--diff-filter=ACMRT")
untracked = paths("ls-files", "--others", "--exclude-standard")
deleted = paths("diff", "--name-only", "--diff-filter=D")
entries = []
for name in tracked:
    original = ROOT / name
    frozen = HERE / "final_state" / name
    assert not frozen.exists(), str(frozen)
    frozen.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(original, frozen)
    assert sha(frozen) == sha(original)
    entries.append({"original_path": name, "path": str(frozen.relative_to(ROOT)),
                    "sha256": sha(frozen), "bytes": frozen.stat().st_size})
for name in untracked:
    path = ROOT / name
    if path.is_file() and path != OUTPUT:
        entries.append({"path": name, "sha256": sha(path), "bytes": path.stat().st_size})
record = {
    "batch": "2026-09-29-benchmark-and-author-replication-preparation",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "coordinator": "019d795a-acfa-72c2-a210-d55a46c606c2",
    "outcome": "methodological_choices_reviewed_interface_repaired_external_replication_prepared_integrity_choice_pending",
    "root_goal": "active; batch objective not completed because G3 has not executed",
    "MCMC_executed": False, "G3_pass": False, "G10_pass": False,
    "unrelated_concurrent_deletions_preserved": deleted,
    "source_note": "Tracked files use copies under final_state; new batch files are retained at their declared paths. This is a handoff freeze, not gate approval.",
    "agents": [
        {"id": "01a0eaee-01df-7773-bd63-d321db26a47c", "role": "G2 executor", "requested_model": "inherit", "effort": "xhigh", "state": "completed_and_closed"},
        {"id": "01a0ed49-99a4-7892-af77-e62f82667860", "role": "G2 independent reviewer", "requested_model": "inherit", "effort": "xhigh", "state": "completed_and_closed"},
        {"id": "01a0ed31-f6ec-78d2-92b7-2090210c2207", "role": "author-source discovery", "requested_model": "gpt-6-sol", "effort": "high", "state": "completed_and_closed"},
        {"id": "01a0ed3f-7e0a-7dc2-be9c-6831e6924991", "role": "author-source independent reviewer", "requested_model": "gpt-6-sol", "effort": "high", "state": "completed_and_closed"},
        {"id": "01a0ed5a-1a40-7f33-bde3-b7b398c25b0a", "role": "interface repair executor", "requested_model": "gpt-6-sol", "effort": "xhigh", "state": "completed_and_closed"},
        {"id": "01a0ed65-c901-7761-b666-8edd67efe4a8", "role": "interface independent reviewer", "requested_model": "gpt-6-sol", "effort": "high", "state": "completed_and_closed"}
    ],
    "files": sorted(entries, key=lambda entry: entry["path"]),
}
OUTPUT.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"files_frozen": len(entries), "tracked_snapshots": len(tracked),
                  "concurrent_deletions_preserved": deleted, "manifest_sha256": sha(OUTPUT)}))
