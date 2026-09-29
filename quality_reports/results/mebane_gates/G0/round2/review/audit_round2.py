"""Independent, read-only checks of G0 round2; output stays in review/."""

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[6]
REVIEW = Path(__file__).resolve().parent
ROUND = REVIEW.parent
PRIOR = ROUND.parent / "round1"
EXPECTED_MANIFEST = "f71333db477385fc78dad8a7a1a7ca78e48479226dcdbde80ce97d724409fec7"
EXPECTED_PRIOR = "61649af333a6d2ef6bea20e4ed5e38671bb6d6d5f2b867fbe1d9acdc195169ab"
EXPECTED_CONTRACT = "e5ba78d6f8d314c2bf94738df85fce0a31d8e9986ef974f6c69ee9e30ee06ca3"


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


def sha(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def canonical_sha(value):
    return hashlib.sha256(json.dumps(value, ensure_ascii=False, sort_keys=True,
                                     separators=(",", ":")).encode()).hexdigest()


manifest = load(ROUND / "candidate_manifest.json")
prior = load(PRIOR / "candidate_manifest.json")
run = load(ROUND / "run.json")
old_run = load(PRIOR / "run.json")
contract = load(ROUND / "gate_contract.json")
adjudication = load(PRIOR / "adjudication.json")
checks = {
    "manifest_identity": sha(ROUND / "candidate_manifest.json") == EXPECTED_MANIFEST,
    "prior_identity": sha(PRIOR / "candidate_manifest.json") == EXPECTED_PRIOR,
    "contract_identity": canonical_sha(contract) == EXPECTED_CONTRACT,
    "run_identity": (run["gate_id"], run["round"], run["contract_sha256"], run["executor_id"]) ==
                    ("G0", "round2", EXPECTED_CONTRACT, "01a0eaba-2cec-74f3-bca0-8c27b736567e"),
    "manifest_metadata": (manifest["gate_id"], manifest["round"], manifest["contract_sha256"]) ==
                         ("G0", "round2", EXPECTED_CONTRACT),
    "adjudication_binding": run["binding_adjudication_sha256"] == sha(PRIOR / "adjudication.json"),
    "review_binding": adjudication["review_sha256"] == sha(PRIOR / "review/review.json"),
    "prior_manifest_binding": run["repaired_from_manifest_sha256"] == EXPECTED_PRIOR,
}
files = {item["path"]: item for item in manifest["files"]}
old_files = {item["path"]: item for item in prior["files"]}
checks["unique_paths"] = len(files) == len(manifest["files"])
bad = []
for path, entry in files.items():
    actual = ROOT / path
    if not actual.is_file() or actual.stat().st_size != entry["bytes"] or sha(actual) != entry["sha256"]:
        bad.append(path)
checks["all_manifest_bytes_match"] = not bad
declared = set().union(*(run[key] for key in ("inputs", "code", "configuration", "outputs")))
declared.add((ROUND / "run.json").relative_to(ROOT).as_posix())
evidence = load(ROUND / "todo_evidence.json")
todo_paths = {item["path"] for todo in evidence["todos"] for item in todo["evidence"]}
checks["declared_and_todo_covered"] = (declared | todo_paths) <= files.keys()
checks["old_inputs_and_code_retained"] = set(old_run["inputs"] + old_run["code"]) <= files.keys()
changed_prior = sorted(path for path in files.keys() & old_files.keys() if files[path] != old_files[path])
checks["inherited_records_unchanged"] = not changed_prior
prior_only_bad = []
for path in old_files.keys() - files.keys():
    actual = ROOT / path
    entry = old_files[path]
    if not actual.is_file() or actual.stat().st_size != entry["bytes"] or sha(actual) != entry["sha256"]:
        prior_only_bad.append(path)
checks["transitive_prior_artifacts_unchanged"] = not prior_only_bad

snapshots = load(ROUND / "final_state_map.json")
checks["run_snapshot_map_identical"] = run["baseline_snapshots"] == snapshots
bad_snapshots = []
for entry in snapshots:
    recorded = files.get(entry["snapshot"])
    if not recorded or any(recorded[k] != entry[k] for k in ("sha256", "bytes")):
        bad_snapshots.append(entry["original"])
checks["snapshot_map_covered"] = not bad_snapshots
mutable = {item["original"] for item in snapshots}
checks["mutable_canonical_paths_not_bound"] = not (mutable & files.keys())
ledger_path = next(item["snapshot"] for item in snapshots
                   if item["original"] == "quality_reports/plans/mebane_2022_2026_gates.json")
gate = next(item for item in load(ROOT / ledger_path)["gates"] if item["id"] == "G0")
frozen_contract = {k: v for k, v in gate.items() if k not in ("status", "records")}
frozen_contract["todos"] = [{k: v for k, v in item.items() if k not in ("status", "evidence")}
                             for item in gate["todos"]]
checks["frozen_ledger_contract_matches"] = canonical_sha(frozen_contract) == EXPECTED_CONTRACT

additions = load(ROUND / "inventory_additions.json")["added_files"]
expected_f1 = {"research_note.md"} | {p.relative_to(ROOT).as_posix() for p in (ROOT / "output/tables").glob("*.csv")}
checks["five_f1_snapshots"] = len(additions) == 5 and {item["original"] for item in additions} == expected_f1
checks["f1_originals_match_snapshots"] = all(
    sha(ROOT / item["original"]) == item["sha256"] == files[item["snapshot"]]["sha256"]
    and (ROOT / item["original"]).stat().st_size == item["bytes"]
    and item["snapshot"] in run["inputs"] and bool(item["role"])
    for item in additions
)

before = load(ROUND / "renv_before.lock")
after = load(ROUND / "final_state/renv.lock")
added_packages = sorted(set(after["Packages"]) - set(before["Packages"]))
checks["before_is_round1_lock"] = sha(ROUND / "renv_before.lock") == sha(PRIOR / "final_state/renv.lock")
checks["lock_174_to_180"] = len(before["Packages"]) == 174 and len(after["Packages"]) == 180
checks["all_174_preserved"] = all(after["Packages"].get(name) == record for name, record in before["Packages"].items())
checks["only_six_expected_added"] = added_packages == ["bbmle", "bdsmatrix", "diptest", "emdbook", "plyr", "spikes"]
checks["lock_other_metadata_unchanged"] = {k: v for k, v in before.items() if k != "Packages"} == {k: v for k, v in after.items() if k != "Packages"}
checks["lock_matches_live_final"] = sha(ROUND / "final_state/renv.lock") == sha(ROOT / "renv.lock")

readme = (ROUND / "final_state/README.md").read_text(encoding="utf-8")
canonical_observations = {
    "readme_matches_snapshot": sha(ROUND / "final_state/README.md") == sha(ROOT / "README.md"),
    "readme_live_sha256": sha(ROOT / "README.md"),
    "readme_snapshot_sha256": sha(ROUND / "final_state/README.md"),
    "note": "Canonical files can change after submission; candidate validity uses frozen paths.",
}
checks["f3_limit_explicit"] = all(text in readme for text in (
    "URL, data original e método de obtenção são desconhecidos",
    "sua disponibilidade fora deste checkout não foi verificada",
    "não restaura por si só este baseline",
    "88857251458aceecf6a8fdb2501a1e38d4f0f9aeda7c6693bb986464521c4422",
))

result = {
    "checks": checks,
    "failed_checks": [name for name, passed in checks.items() if not passed],
    "manifest_file_count": len(files),
    "manifest_bad": bad,
    "inherited_same_path_count": len(files.keys() & old_files.keys()),
    "inherited_changed": changed_prior,
    "prior_only_bad": prior_only_bad,
    "new_paths": sorted(files.keys() - old_files.keys()),
    "omitted_round1_paths": sorted(old_files.keys() - files.keys()),
    "snapshot_count": len(snapshots),
    "f1_snapshots": additions,
    "added_packages": added_packages,
    "canonical_observations": canonical_observations,
    "manifest_extra_to_run_and_todo": sorted(files.keys() - (declared | todo_paths)),
}
(REVIEW / "audit_results.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps(result, ensure_ascii=False, indent=2))
raise SystemExit(bool(result["failed_checks"]))
