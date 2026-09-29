"""Independent read-only candidate audit; all outputs confined to this review."""
import csv
import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[5]
ROUND = HERE.parent
GATES = ROUND.parents[1]
PIN = {
    "candidate_manifest.json": "5c4b39aaa1c2a273b1c7f4e9370291172d35d0f4a5a17afd079396c3a1984170",
    "benchmark_contract.json": "63b61fb0594d0302a03d999bcff6c62967b6e999f37b4c9a8821f0f8e9ed18d2",
    "run.json": "a549043d82fa34856e56148d233037e761ca8f0c57a0b1f1af9d955ec959d359",
}
STATIC = "f834bc1d12d88b4bc82fb2ada95120a838451c5809332630a75cd9abf03cf4d1"
checks, verified = [], {}


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical(value):
    return hashlib.sha256(json.dumps(value, ensure_ascii=False, sort_keys=True,
                                     separators=(",", ":")).encode()).hexdigest()


def check(name, condition, detail):
    checks.append({"id": name, "pass": bool(condition), "detail": detail})


def entry_check(item, group, aliases=None):
    path = (aliases or {}).get(item["path"], ROOT / item["path"])
    actual = sha(path) if path.is_file() else None
    size = path.stat().st_size if path.is_file() else None
    okay = actual == item["sha256"] and ("bytes" not in item or item["bytes"] == size)
    check(group + ":" + item["path"], okay,
          {"resolved_path": str(path.relative_to(ROOT)), "expected": item["sha256"],
           "actual": actual, "bytes": size})
    if actual:
        verified[str(path.relative_to(ROOT))] = {"path": str(path.relative_to(ROOT)),
                                               "sha256": actual, "bytes": size}


for name, expected in PIN.items():
    entry_check({"path": str((ROUND / name).relative_to(ROOT)), "sha256": expected}, "user_pin")
manifest = read(ROUND / "candidate_manifest.json")
run = read(ROUND / "run.json")
contract = read(ROUND / "gate_contract.json")
check("G2_static_contract", canonical(contract) == STATIC == run["contract_sha256"] ==
      manifest["contract_sha256"], "Canonical UTF-8 JSON SHA256, not file-byte hash")
check("G2_static_inherited", contract == read(GATES / "G2/round1/gate_contract.json"),
      "Exact JSON equality with original operational contract; mutable ledger not read")
check("identity", manifest["gate_id"] == run["gate_id"] == "G2" and
      manifest["round"] == run["round"] == "round2" and
      manifest["executor_id"] == run["executor_id"] == "01a0eaee-01df-7773-bd63-d321db26a47c",
      "Gate, round and executor")
paths = [item["path"] for item in manifest["files"]]
check("candidate_unique_paths", len(paths) == len(set(paths)), len(paths))
for item in manifest["files"]:
    entry_check(item, "candidate")
for field in ("inputs", "code", "configuration", "outputs", "executed_code"):
    missing = sorted(set(run[field]) - set(paths))
    check("run_coverage_" + field, not missing, {"count": len(run[field]), "missing": missing})
check("benchmark_canonical", canonical(read(ROUND / "benchmark_contract.json")) ==
      run["benchmark_contract_canonical_sha256"], run["benchmark_contract_canonical_sha256"])

g0 = GATES / "G0/round2"
g0_manifest = read(g0 / "candidate_manifest.json")
g0_review = read(g0 / "review/review.json")
g0_adjudication = read(g0 / "adjudication.json")
check("G0_dependency", contract["depends_on"] == ["G0"] and
      sha(g0 / "candidate_manifest.json") == run["dependency_manifests"]["G0"],
      run["dependency_manifests"])
check("G0_review_adjudication", g0_review["status"] == g0_adjudication["status"] == "pass" and
      g0_review["candidate_manifest_sha256"] == g0_adjudication["candidate_manifest_sha256"] ==
      sha(g0 / "candidate_manifest.json") and
      sha(g0 / "review/review.json") == run["dependency_approvals"]["G0"]["review_sha256"] ==
      g0_adjudication["review_sha256"] and
      sha(g0 / "adjudication.json") == run["dependency_approvals"]["G0"]["adjudication_sha256"],
      "Frozen G0 approval chain, not live ledger status")
check("G0_static_contract", canonical(read(g0 / "gate_contract.json")) ==
      g0_manifest["contract_sha256"] == g0_review["contract_sha256"] ==
      g0_adjudication["contract_sha256"], "Full G0 static contract binding")
for item in g0_manifest["files"]:
    entry_check(item, "G0_dependency_manifest")

mapping = read(ROUND / "round1_recovery_map.json")
aliases = {x["original_path"]: ROOT / x["snapshot_path"] for x in mapping["replacements"]}
for old_manifest in mapping["original_manifest_files"]:
    entry_check(old_manifest, "round1_manifest_pin")
    for item in read(ROOT / old_manifest["path"])["files"]:
        entry_check(item, "round1_recovered", aliases)
for name in ("inherited_evidence.json", "protected_round1_inventory.json", "interface_sources.json"):
    for item in read(ROUND / name)["files"]:
        entry_check(item, name)
entry_check(mapping["old_adjudication"], "round1_adjudication")
old_review = read(GATES / "G2/round1/review/review.json")
old_checks = list(csv.DictReader((GATES / "G2/round1/review/independent_checks.csv").open()))
old_enum = list(csv.DictReader((GATES / "G2/round1/review/independent_enumeration.csv").open()))
check("inherited_75_checks", len(old_checks) == 75 and all(x["passed"] == "TRUE" for x in old_checks),
      "Inspected preserved CSV; not rerun")
check("inherited_162_enumerations", len(old_enum) == 162, "Inspected preserved CSV; not rerun")
old_adjudication_checks = list(csv.DictReader((GATES / "G2/round1/adjudication_checks.csv").open()))
check("inherited_nine_adjudication_checks", len(old_adjudication_checks) == 9 and
      all(x["pass"] == "TRUE" for x in old_adjudication_checks), "Inspected preserved CSV; not rerun")
check("inherited_T5", any(t["id"] == "G2-T5" and
      t["review_result"] == "independent_rederivation_completed" for t in old_review["todos"]),
      "Preserved independent round1 rederivation")
check("old_decisions_not_reclassified", old_review["status"] == "changes_requested" and
      {f["id"] for f in old_review["findings"]} == {"G2-QA-D1", "G2-QA-D2", "G2-QA-D3"},
      "Historical findings retained; current closure is a separate review")
original = (ROUND / "inherited/appendix_round1.md").read_text()
current = (ROOT / "appendices/mebane_model_contract.md").read_text()
section5 = lambda text: text[text.index("# 5."):text.index("# 6.")]
check("T5_derivation_byte_identical", section5(original) == section5(current),
      "Section 5 exact conditional marginalization unchanged")
comment = "A hipótese “JAGS rodou direito, então não acho que seja prioris; HMC deveria ser melhor” permanece hipótese, não resultado."
check("user_JAGS_comment_preserved", comment in original and comment in current, comment)

# Freeze contextual authorization and governance; no live ledger is consumed.
context = [GATES / "coordination/2026-09-29_benchmark_round/authorization.md",
           ROOT / "CLAUDE.md", ROOT.parent / "CLAUDE.md"]
(HERE / "snapshots").mkdir(exist_ok=True)
for source, name in zip(context, ("authorization.md", "project_CLAUDE.md", "parent_CLAUDE.md")):
    target = HERE / "snapshots" / name
    if not target.exists():
        target.write_bytes(source.read_bytes())
    check("snapshot_" + name, sha(source) == sha(target), str(source))
    verified[str(target.relative_to(ROOT))] = {"path": str(target.relative_to(ROOT)),
        "sha256": sha(target), "bytes": target.stat().st_size, "source": str(source)}
authorization = (HERE / "snapshots/authorization.md").read_text()
quote = read(ROUND / "benchmark_contract.json")["authorization"]["quote"]
check("authorization_quote", " ".join(quote.split()) in " ".join(authorization.split()),
      "Review freezes documentary authorization; current user request separately confirms it")

output = {"checked_at_utc": datetime.now(timezone.utc).isoformat(),
          "status": "pass" if all(x["pass"] for x in checks) else "fail",
          "candidate_files": len(paths), "checks": checks,
          "verified_inputs": sorted(verified.values(), key=lambda x: x["path"]),
          "inherited_counts": {"checks": len(old_checks), "enumerations": len(old_enum)},
          "candidate_authorization_file_in_run": any("authorization.md" in p for p in run["inputs"]),
          "mutable_ledger_read": False}
name = sys.argv[1] if len(sys.argv) == 2 else "integrity_initial.json"
assert Path(name).name == name and name.endswith(".json")
(HERE / name).write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n")
print(json.dumps({"status": output["status"], "passed": sum(x["pass"] for x in checks),
                  "total": len(checks), "candidate_files": len(paths),
                  "failures": [x for x in checks if not x["pass"]]}, ensure_ascii=False, indent=2))
sys.exit(0 if output["status"] == "pass" else 1)
