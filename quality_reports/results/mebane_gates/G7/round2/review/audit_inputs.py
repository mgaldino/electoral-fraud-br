#!/usr/bin/env python3
"""Independent inventory/recovery audit. No candidate writes or executor imports."""
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[6]
REVIEW = Path(__file__).resolve().parent
ROUND = REVIEW.parent
OLD = ROUND.parent / "round1"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def matches(path, item):
    return path.is_file() and sha(path) == item["sha256"] and path.stat().st_size == item["bytes"]


output = Path(sys.argv[1]).resolve()
assert output.is_relative_to(REVIEW) and not output.exists()
expected = {
    "candidate_manifest.json": "2593c78b5687c883aff6441f09b5d2e67cd319c1ceae723d043dee44a36e62a6",
    "run.json": "795304f2422dfff2f34a923c4500cdf6df7247edd804f6ab1059494730ae7a1a",
    "recovery_map.json": "31be6643a62ffacb19ad64c796c4373110491bd916aecfa1a5af161d235a91db",
}
run = read(ROUND / "run.json")
manifest = read(ROUND / "candidate_manifest.json")
mapping = read(ROUND / "recovery_map.json")["files"]
mapped = {x["original_path"]: x for x in mapping}
checks = []


def check(name, ok, detail=None):
    checks.append({"id": name, "pass": bool(ok), "detail": detail})


for name, digest in expected.items():
    check("hash_" + name, sha(ROUND / name) == digest, sha(ROUND / name))
listed = [x["path"] for x in manifest["files"]]
check("candidate_count_unique", len(listed) == len(set(listed)) == 1859)
bad = [x["path"] for x in manifest["files"] if not matches(ROOT / x["path"], x)]
check("candidate_bytes", not bad, bad)
declared = [p for field in ("inputs", "code", "configuration", "outputs") for p in run[field]]
declared.append(str((ROUND / "run.json").relative_to(ROOT)))
check("declared_inventory_closure", len(declared) == len(set(declared)) and set(declared) == set(listed))
actual_round = {str(p.relative_to(ROOT)) for p in ROUND.rglob("*") if p.is_file()
                and REVIEW not in p.parents and p.name != "candidate_manifest.json"}
check("round_output_inventory", actual_round <= set(listed), sorted(actual_round - set(listed)))
check("recovery_map_count_unique", len(mapping) == len(mapped) == 1094)
check("all_snapshots_in_manifest", all(x["snapshot_path"] in listed for x in mapping))
bad_snapshots = [x["snapshot_path"] for x in mapping if not matches(ROOT / x["snapshot_path"], x)]
check("recovery_snapshot_bytes", not bad_snapshots, bad_snapshots)
for name, path, count in (("candidate", OLD / "candidate_manifest.json", 275),
                          ("qa", OLD / "review/review_manifest.json", 809)):
    previous = read(path)["files"]
    broken = [x["path"] for x in previous if x["path"] not in mapped or
              mapped[x["path"]]["sha256"] != x["sha256"] or
              not matches(ROOT / mapped[x["path"]]["snapshot_path"], x)]
    check(name + "_round1_recoverable", len(previous) == count and not broken, broken)
old_files = {str(p.relative_to(ROOT)) for p in OLD.rglob("*") if p.is_file()}
old_entries = [x for x in mapping if x["round1_member"]]
broken_old = [x["original_path"] for x in old_entries if not matches(ROOT / x["original_path"], x)]
check("round1_originals_intact", len(old_entries) == len(old_files) == 1066 and
      old_files == {x["original_path"] for x in old_entries} and not broken_old, broken_old)
check("previous_round1_inventory_matches", read(ROUND / "previous_round1_inventory.json")["files"] == old_entries)
canonical = hashlib.sha256(json.dumps(read(ROUND / "gate_contract.json"), ensure_ascii=False,
                                      sort_keys=True, separators=(",", ":")).encode()).hexdigest()
check("contract_unchanged", canonical == run["contract_sha256"] ==
      "fc071a8664d04ba6a0a4ca91298d333ee1ca89868a26b23e705946fef1c2f94d")
check("adjudication_bound", sha(OLD / "adjudication.json") ==
      "882d1b4081df7d4443983e5b5709942076030b34f0edf1f18b68d45a6edc122a")
check("dag_snapshot_static", sha(ROUND / "ledger_dag_snapshot.json") == sha(OLD / "ledger_dag_snapshot.json"))
g1 = ROOT / "quality_reports/results/mebane_gates/G1/round2"
g1_expected = {"candidate_manifest.json": "517c17c724cca82a820519c476981d47c8892c7383dd2c3dded9373eba6d31e8",
               "review/review.json": "727f6b234e3a580c329cc5e898018bb68c02063717c292b6d91e4fbe12d86941",
               "adjudication.json": "fe21ce5ebaf107027b6cf64f72eb06f9f2549df8f65ccbbd3eeee2067807735e"}
for path, digest in g1_expected.items():
    check("G1_" + path, sha(g1 / path) == digest)
check("G1_pass", read(g1 / "review/review.json")["status"] ==
      read(g1 / "adjudication.json")["status"] == "pass")
check("execution_hashes_current", all(sha(ROOT / p) == h for p, h in run["executed_code_input_sha256"].items()))
check("execution_inputs_declared", set(run["executed_code_input_sha256"]) <= set(listed))
ledger_path = ROOT / "quality_reports/plans/mebane_2022_2026_gates.json"
ledger = read(ledger_path)  # Explicit preservation check by QA, never fed to candidate tests.
report = {"checks": checks, "pass": all(x["pass"] for x in checks),
          "candidate_files": len(listed), "recovery_copies": len(mapping),
          "round1_intact_files": len(old_files), "previous_candidate_entries": 275,
          "previous_qa_entries": 809, "contract_sha256": canonical,
          "ledger_sha256": sha(ledger_path), "ledger_states": {g["id"]: g["status"] for g in ledger["gates"]},
          "G1_hashes": g1_expected,
          "source_changes": [x["original_path"] for x in mapping if not matches(ROOT / x["original_path"], x)]}
output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps({k: report[k] for k in ("pass", "candidate_files", "recovery_copies", "round1_intact_files", "ledger_sha256")}))
if not report["pass"]:
    print(json.dumps([x for x in checks if not x["pass"]]))
    raise SystemExit(1)
