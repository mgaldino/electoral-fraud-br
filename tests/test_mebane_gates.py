"""Adversarial checks for premature or stale gate approval."""

import copy
import datetime
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SOURCE = Path(__file__).resolve().parents[1] / "scripts/mebane_gates.py"
SPEC = importlib.util.spec_from_file_location("mebane_gates", SOURCE)
GATES = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GATES)
EXECUTOR = "11111111-1111-4111-8111-111111111111"
REVIEWER = "22222222-2222-4222-8222-222222222222"


class GateTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.plan = GATES.read_json(GATES.LEDGER)
        for gate in self.plan["gates"]:
            gate["status"] = "queued"
            gate["records"] = None
            for todo in gate["todos"]:
                todo["status"] = "todo"
                todo["evidence"] = []

    def write_json(self, name, value):
        (self.root / name).write_text(json.dumps(value, ensure_ascii=False), encoding="utf-8")

    def write_file(self, name, content="verified fixture\n"):
        (self.root / name).write_text(content, encoding="utf-8")

    def gate(self, key):
        return next(gate for gate in self.plan["gates"] if gate["id"] == key)

    def approval(self, key="G0", extra_paths=()):
        gate = self.gate(key)
        self.write_file(f"{key}-input.txt")
        self.write_file(f"{key}-output.txt")
        run = {
            "gate_id": key, "round": "round1", "contract_sha256": GATES.contract_sha256(gate),
            "executor_id": EXECUTOR, "inputs": [f"{key}-input.txt"], "code": [],
            "configuration": [], "outputs": [f"{key}-output.txt"],
            "dependency_manifests": {
                dep: GATES.sha256(self.root / self.gate(dep)["records"]["candidate_manifest"])
                for dep in gate["depends_on"]
            },
        }
        self.write_json(f"{key}-run.json", run)
        paths = [f"{key}-input.txt", f"{key}-output.txt", f"{key}-run.json", *extra_paths]
        self.write_json(f"{key}-manifest.json", {
            "gate_id": key, "round": "round1", "contract_sha256": GATES.contract_sha256(gate),
            "files": [{"path": path, "sha256": GATES.sha256(self.root / path)} for path in paths],
        })
        fingerprint = GATES.sha256(self.root / f"{key}-manifest.json")
        self.write_json(f"{key}-review.json", {
            "gate_id": key, "round": "round1", "contract_sha256": GATES.contract_sha256(gate),
            "candidate_manifest_sha256": fingerprint, "status": "pass",
            "executor_id": EXECUTOR, "reviewer_id": REVIEWER,
            "manifest_complete": True, "findings": [],
        })
        self.write_json(f"{key}-adjudication.json", {
            "gate_id": key, "round": "round1", "contract_sha256": GATES.contract_sha256(gate),
            "candidate_manifest_sha256": fingerprint,
            "review_sha256": GATES.sha256(self.root / f"{key}-review.json"),
            "status": "pass", "findings": [], "unresolved_material_findings": 0,
        })
        gate["status"] = "pass"
        gate["records"] = {
            "executor_id": EXECUTOR, "reviewer_id": REVIEWER, "run": f"{key}-run.json",
            "candidate_manifest": f"{key}-manifest.json", "review": f"{key}-review.json",
            "adjudication": f"{key}-adjudication.json",
        }
        for todo in gate["todos"]:
            todo["status"] = "done"
            todo["evidence"] = [{"path": f"{key}-output.txt", "basis": "executed"}]
        return gate

    def external_attestation(self, key, requirement, turn, applicability=False):
        snapshot = f"{key}-T{turn}-snapshot.dat"
        path = f"{key}-T{turn}-attestation.json"
        self.write_file(snapshot, "synthetic snapshot; semantic QA required\n")
        value = {
            "gate_id": key, "requirement": "turn_not_held" if applicability else requirement,
            "source_url": "https://www.tse.jus.br/eleicoes/2026/resultados",
            "publication_date": datetime.date.today().isoformat(),
            "election_year": 2026, "turn": turn,
            "snapshot_path": snapshot, "snapshot_sha256": GATES.sha256(self.root / snapshot),
            "reviewer_id": REVIEWER,
            "checked_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        }
        if applicability:
            value["occurrence"] = "not_held"
        else:
            value["coverage_pass"] = True
        self.write_json(path, value)
        return path, snapshot

    def assert_rejected(self, needle):
        errors = GATES.validate(self.plan, self.root)
        self.assertTrue(any(needle in error for error in errors), errors)

    def two_turn_plan(self):
        first = self.gate("G8")
        first["election_scope"] = {"year": 2026, "turn": 1}
        first["depends_on"] = []
        if any(gate["id"] == "G9" for gate in self.plan["gates"]):
            second = self.gate("G9")
        else:
            second = copy.deepcopy(first)
            second["id"] = "G9"
            for todo in second["todos"]:
                todo["id"] = todo["id"].replace("G8-", "G9-")
            self.plan["gates"].append(second)
        second["depends_on"] = []
        second["election_scope"] = {"year": 2026, "turn": 2}
        second["allow_not_applicable"] = True
        return first, second

    def test_current_ledger_migrates_without_records(self):
        self.assertEqual([], GATES.validate(GATES.read_json(GATES.LEDGER), GATES.ROOT))

    def test_queued_plan_is_valid(self):
        self.assertEqual([], GATES.validate(self.plan, self.root))

    def test_cycle_and_unknown_dependency_are_rejected(self):
        self.gate("G0")["depends_on"] = ["G1"]
        self.assert_rejected("cycle")
        self.gate("G0")["depends_on"] = ["G99"]
        self.assert_rejected("unknown dependency")

    def test_execution_cannot_skip_dependency(self):
        self.gate("G1")["status"] = "running"
        self.assert_rejected("has not passed")

    def test_pass_without_evidence_is_rejected(self):
        self.gate("G0")["status"] = "pass"
        self.assert_rejected("every todo done")
        self.assert_rejected("approval records")

    def test_complete_independent_records_are_accepted(self):
        self.approval()
        self.assertEqual([], GATES.validate(self.plan, self.root))

    def test_cross_gate_round_and_contract_are_rejected(self):
        self.approval("G0")
        self.approval("G1")
        review = GATES.read_json(self.root / "G1-review.json")
        review.update(gate_id="G0", round="round2", contract_sha256="0" * 64)
        self.write_json("G1-review.json", review)
        adjudication = GATES.read_json(self.root / "G1-adjudication.json")
        adjudication["review_sha256"] = GATES.sha256(self.root / "G1-review.json")
        self.write_json("G1-adjudication.json", adjudication)
        self.assert_rejected("another gate, round or contract")

    def test_static_contract_ignores_status_but_detects_scope_change(self):
        gate = self.approval()
        self.assertEqual([], GATES.validate(self.plan, self.root))
        gate["acceptance"].append("New criterion")
        self.assert_rejected("another gate, round or contract")

    def test_alias_ids_and_self_review_are_rejected(self):
        gate = self.approval()
        gate["records"]["reviewer_id"] = EXECUTOR + " "
        self.assert_rejected("canonical UUID")
        gate["records"]["reviewer_id"] = EXECUTOR
        self.assert_rejected("distinct")

    def test_changed_candidate_and_old_review_are_rejected(self):
        self.approval()
        self.write_file("G0-output.txt", "unreviewed change")
        self.assert_rejected("stale candidate")
        self.write_file("G0-output.txt")
        review = GATES.read_json(self.root / "G0-review.json")
        review["candidate_manifest_sha256"] = "0" * 64
        self.write_json("G0-review.json", review)
        self.assert_rejected("another candidate")

    def test_run_files_and_manifest_complete_are_required(self):
        self.approval()
        run = GATES.read_json(self.root / "G0-run.json")
        run["code"] = ["unlisted.py"]
        self.write_file("unlisted.py", "code")
        self.write_json("G0-run.json", run)
        self.assert_rejected("not in the frozen manifest")
        self.approval()
        review = GATES.read_json(self.root / "G0-review.json")
        review["manifest_complete"] = False
        self.write_json("G0-review.json", review)
        self.assert_rejected("manifest_complete")

    def test_run_cannot_count_itself_as_an_input(self):
        self.approval()
        run = GATES.read_json(self.root / "G0-run.json")
        run["inputs"] = ["G0-run.json"]
        self.write_json("G0-run.json", run)
        self.assert_rejected("run cannot declare itself")

    def test_run_and_dependency_manifest_staleness(self):
        self.approval("G0")
        self.approval("G1")
        self.assertEqual([], GATES.validate(self.plan, self.root))
        manifest = GATES.read_json(self.root / "G0-manifest.json")
        manifest["note"] = "new approval snapshot"
        self.write_json("G0-manifest.json", manifest)
        self.assert_rejected("stale dependency manifest G0")

    def test_changed_review_and_unresolved_finding(self):
        self.approval()
        review = GATES.read_json(self.root / "G0-review.json")
        review["findings"] = [{"id": "C-RED", "severity": "critical"}]
        self.write_json("G0-review.json", review)
        self.assert_rejected("another review")
        adjudication = GATES.read_json(self.root / "G0-adjudication.json")
        adjudication["review_sha256"] = GATES.sha256(self.root / "G0-review.json")
        adjudication["findings"] = [{"id": "C-RED", "status": "UNRESOLVED", "resolution": "Pending", "resolved": False}]
        self.write_json("G0-adjudication.json", adjudication)
        self.assert_rejected("unresolved material")
        adjudication["findings"][0].update(status="CONFIRMED", resolved=True, resolution="Fixed and rechecked")
        self.write_json("G0-adjudication.json", adjudication)
        self.assertEqual([], GATES.validate(self.plan, self.root))

    def test_missing_finding_reconciliation_is_rejected(self):
        self.approval()
        review = GATES.read_json(self.root / "G0-review.json")
        review["findings"] = [{"id": "F1", "severity": "minor"}]
        self.write_json("G0-review.json", review)
        adjudication = GATES.read_json(self.root / "G0-adjudication.json")
        adjudication["review_sha256"] = GATES.sha256(self.root / "G0-review.json")
        self.write_json("G0-adjudication.json", adjudication)
        self.assert_rejected("reconcile every review finding")

    def test_done_todo_needs_real_evidence(self):
        self.gate("G0")["todos"][0]["status"] = "done"
        self.assert_rejected("requires evidence")

    def test_external_requires_attestation_before_execution(self):
        gate = self.gate("G0")
        gate["external_prerequisites"] = ["Official publication"]
        gate["election_scope"] = {"year": 2026, "turn": 1}
        gate["status"] = "running"
        self.assert_rejected("external_evidence requires")
        path, snapshot = self.external_attestation("G0", "Official publication", 1)
        gate["records"] = {"executor_id": EXECUTOR, "reviewer_id": REVIEWER, "external_evidence": [path]}
        self.assertEqual([], GATES.validate(self.plan, self.root))
        value = GATES.read_json(self.root / path)
        value["source_url"] = "https://tse.jus.br.evil.example/resultados"
        self.write_json(path, value)
        self.assert_rejected("official source_url")
        value["source_url"] = "https://www.tse.jus.br/eleicoes/2026/resultados"
        value["turn"] = True
        self.write_json(path, value)
        self.assert_rejected("requirement or turn")
        value["turn"] = 1
        self.write_json(path, value)
        self.write_file(snapshot, "changed snapshot")
        self.assert_rejected("stale external snapshot")
        self.write_file(snapshot, "verified fixture\n")
        value["requirement"] = "Different official publication"
        self.write_json(path, value)
        self.assert_rejected("requirement or turn")

    def test_external_temporal_and_exact_types(self):
        gate = self.gate("G0")
        gate["external_prerequisites"] = ["Official publication"]
        gate["election_scope"] = {"year": 2026, "turn": 1}
        gate["status"] = "running"
        path, _ = self.external_attestation("G0", "Official publication", 1)
        gate["records"] = {"executor_id": EXECUTOR, "reviewer_id": REVIEWER, "external_evidence": [path]}
        base = GATES.read_json(self.root / path)
        changes = [
            ("publication_date", "2999-01-01", "publication_date"),
            ("checked_at", "2000-01-01T00:00:00+00:00", "checked_at"),
            ("checked_at", "2026-09-28T00:00:00", "checked_at"),
            ("election_year", True, "election_year"),
            ("coverage_pass", 1, "coverage_pass"),
        ]
        for field, value, needle in changes:
            with self.subTest(field=field, value=value):
                self.write_json(path, {**base, field: value})
                self.assert_rejected(needle)

    def test_external_pass_requires_attestation_and_snapshot_in_manifest(self):
        gate = self.gate("G0")
        gate["external_prerequisites"] = ["Official publication"]
        gate["election_scope"] = {"year": 2026, "turn": 1}
        path, snapshot = self.external_attestation("G0", "Official publication", 1)
        self.approval(extra_paths=[path, snapshot])
        gate["records"]["external_evidence"] = [path]
        self.assertEqual([], GATES.validate(self.plan, self.root))
        manifest = GATES.read_json(self.root / "G0-manifest.json")
        manifest["files"] = [item for item in manifest["files"] if item["path"] != snapshot]
        self.write_json("G0-manifest.json", manifest)
        self.assert_rejected("external snapshot is not in the manifest")

    def test_t1_pass_t2_waiting_and_inconclusive(self):
        first, second = self.two_turn_plan()
        path, snapshot = self.external_attestation("G8", first["external_prerequisites"][0], 1)
        self.approval("G8", extra_paths=[path, snapshot])["records"]["external_evidence"] = [path]
        second["status"] = "waiting_external"
        self.assertEqual([], GATES.validate(self.plan, self.root))
        second["status"] = "inconclusive"
        self.assertEqual([], GATES.validate(self.plan, self.root))

    def test_t2_not_applicable_requires_official_nonoccurrence(self):
        first, second = self.two_turn_plan()
        path, snapshot = self.external_attestation("G8", first["external_prerequisites"][0], 1)
        self.approval("G8", extra_paths=[path, snapshot])["records"]["external_evidence"] = [path]
        path, _ = self.external_attestation("G9", "turn_not_held", 2, applicability=True)
        second["status"] = "not_applicable"
        second["records"] = {"executor_id": EXECUTOR, "reviewer_id": REVIEWER, "applicability_evidence": [path]}
        self.assertEqual([], GATES.validate(self.plan, self.root))
        second["allow_not_applicable"] = False
        self.assert_rejected("not_applicable is only allowed")
        second["allow_not_applicable"] = True
        value = GATES.read_json(self.root / path)
        value["coverage_pass"] = True
        self.write_json(path, value)
        self.assert_rejected("without coverage_pass")

    def test_schema_and_mermaid_title_fail_without_traceback(self):
        malformed = [
            (lambda plan: plan.pop("date"), "date"),
            (lambda plan: plan.update(routing=[]), "routing"),
            (lambda plan: plan["gates"][0].update(write_scope=[42]), "write_scope"),
            (lambda plan: plan["gates"][0].update(status=[]), "status"),
            (lambda plan: plan["gates"][8].update(status=[]), "status"),
            (lambda plan: plan["gates"][0].update(title='Title"]\nG8 --> G0\nx["extra'), "Mermaid"),
            (lambda plan: plan["gates"][0]["todos"][0].update(evidence=[{"path": "x", "basis": []}]), "evidence"),
        ]
        for index, (mutate, needle) in enumerate(malformed):
            with self.subTest(index=index):
                plan = copy.deepcopy(self.plan)
                mutate(plan)
                errors = GATES.validate(plan, self.root)
                self.assertTrue(any(needle in error for error in errors), errors)
                ledger = self.root / f"malformed-{index}.json"
                ledger.write_text(json.dumps(plan), encoding="utf-8")
                output = self.root / f"render-{index}.md"
                result = subprocess.run(
                    [sys.executable, str(SOURCE), "render", "--ledger", str(ledger), "--output", str(output)],
                    capture_output=True, text=True, check=False,
                )
                self.assertEqual(1, result.returncode)
                self.assertIn("FAIL:", result.stdout)
                self.assertNotIn("Traceback", result.stderr)
                self.assertFalse(output.exists())

    def test_duplicate_gate_id_and_path_escape(self):
        self.plan["gates"].append(copy.deepcopy(self.plan["gates"][0]))
        self.assertIn("duplicate gate ids", GATES.validate(self.plan, self.root))
        with self.assertRaises(ValueError):
            GATES.project_file(self.root, "../outside.txt")

    def test_render_is_deterministic(self):
        first = GATES.render(self.plan)
        self.assertEqual(first, GATES.render(copy.deepcopy(self.plan)))
        self.assertEqual(len(self.plan["gates"]), first.count("**Goal:**"))


if __name__ == "__main__":
    unittest.main()
