"""Verify preservation, approved dependencies and executed round2 evidence."""
import datetime as dt
import hashlib
import json
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[5]
ROUND = Path(__file__).resolve().parent

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def read(path):
    return json.loads(path.read_text(encoding="utf-8"))

def canonical(value):
    return hashlib.sha256(json.dumps(value, ensure_ascii=False, sort_keys=True,
                                    separators=(",", ":")).encode()).hexdigest()

def audit():
    mapping = read(ROUND / "recovery_map.json")["files"]
    changes = []
    for item in mapping:
        snapshot = ROOT / item["snapshot_path"]
        assert sha(snapshot) == item["sha256"] and snapshot.stat().st_size == item["bytes"], item
        current = sha(ROOT / item["original_path"])
        if current != item["sha256"]:
            assert item["mutable_in_round2"], item["original_path"]
            changes.append({"path": item["original_path"], "before_sha256": item["sha256"],
                            "after_sha256": current})
    mapped = {item["original_path"]: item for item in mapping}
    old = ROUND.parent / "round1"
    for manifest in (old / "candidate_manifest.json", old / "review/review_manifest.json"):
        for item in read(manifest)["files"]:
            assert mapped[item["path"]]["sha256"] == item["sha256"], item["path"]
    expected_old = {item["original_path"] for item in mapping if item["round1_member"]}
    actual_old = {str(path.relative_to(ROOT)) for path in old.rglob("*") if path.is_file()}
    assert expected_old == actual_old, "Round1 inventory changed"
    g1 = ROOT / "quality_reports/results/mebane_gates/G1/round2"
    dependencies = {
        "candidate_manifest.json": "517c17c724cca82a820519c476981d47c8892c7383dd2c3dded9373eba6d31e8",
        "review/review.json": "727f6b234e3a580c329cc5e898018bb68c02063717c292b6d91e4fbe12d86941",
        "adjudication.json": "fe21ce5ebaf107027b6cf64f72eb06f9f2549df8f65ccbbd3eeee2067807735e",
    }
    for path, digest in dependencies.items():
        assert sha(g1 / path) == digest, path
    assert canonical(read(g1 / "gate_contract.json")) == "f985ab97469aa66755b977a09781b30608afa6e245896d9d9788b4461190975d"
    contract = canonical(read(ROUND / "gate_contract.json"))
    assert contract == "fc071a8664d04ba6a0a4ca91298d333ee1ca89868a26b23e705946fef1c2f94d"
    assert sha(old / "adjudication.json") == "882d1b4081df7d4443983e5b5709942076030b34f0edf1f18b68d45a6edc122a"
    assert sha(ROUND / "ledger_dag_snapshot.json") == sha(old / "ledger_dag_snapshot.json")
    execution = read(ROUND / "executions/final1/execution.json")
    assert execution["status"] == "PASS"
    assert execution["test_inputs_unchanged"]
    assert all(sha(ROOT / path) == digest for path, digest in execution["code_input_sha256"].items())
    assert all(command["exit_code"] == 0 for command in execution["commands"])
    locales = []
    for mode in ("C", "default", "UTF8"):
        result = read(ROUND / f"executions/final1/{mode}_repairs/repair_results.json")
        assert result["status"] == "PASS" and all(case["passed"] for case in result["cases"])
        assert result["locale_before"] == result["locale_after"]
        assert result["candidate_utf8_hex"] == "4a4f53c38920444120434f4e434549c387c3834f"
        assert read(ROUND / f"executions/final1/{mode}_legacy/test_summary.json")["status"] == "PASS"
        locales.append({"mode": mode, "effective_ctype": result["locale_ctype"], "cases": len(result["cases"])})
    receipts = list((ROUND / "executions/final1").rglob("receipt.json"))
    for path in receipts:
        receipt = read(path)
        assert receipt["data_ready"] is False and receipt["inference_ready"] is False
        validation = receipt["validation"]
        assert validation["national_coverage_attested"] is False and "complete" not in validation
        assert sum(row["reference_sections"] for row in validation["by_uf"]) == validation["expected_sections"]
        assert sum(row["observed_sections"] for row in validation["by_uf"]) == validation["observed_sections"]
    return {"status": "PASS", "preserved_files": len(mapping), "unchanged_round1_files": len(actual_old),
            "source_changes": changes, "contract_sha256": contract,
            "dependency_hashes": dependencies, "locales": locales, "new_receipts_checked": len(receipts)}

if __name__ == "__main__":
    start = time.monotonic()
    result = audit()
    if sys.argv[1:] == ["--verify-manifest"]:
        manifest_path = ROUND / "candidate_manifest.json"
        manifest = read(manifest_path)
        paths = set()
        for item in manifest["files"]:
            assert item["path"] not in paths
            paths.add(item["path"])
            path = ROOT / item["path"]
            assert sha(path) == item["sha256"] and path.stat().st_size == item["bytes"], item["path"]
        run = read(ROUND / "run.json")
        assert all(path in paths for field in ("inputs", "code", "configuration", "outputs") for path in run[field])
        assert all(evidence["path"] in paths for todo in read(ROUND / "todo_evidence.json")["todos"]
                   for evidence in todo["evidence"])
        result.update(manifest_files=len(paths), manifest_sha256=sha(manifest_path))
    else:
        result.update(command="python3 quality_reports/results/mebane_gates/G7/round2/audit_integrity.py",
                      exit_code=0, wall_seconds=time.monotonic() - start,
                      checked_at_utc=dt.datetime.now(dt.timezone.utc).isoformat())
        target = ROUND / "integrity_final.json"
        assert not target.exists()
        target.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False))
