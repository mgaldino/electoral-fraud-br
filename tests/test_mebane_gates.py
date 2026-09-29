"""Adversarial checks for premature or stale gate approval."""

import copy
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

SOURCE = Path(__file__).resolve().parents[1] / "scripts/mebane_gates.py"
SPEC = importlib.util.spec_from_file_location("mebane_gates", SOURCE)
GATES = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GATES)


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
        (self.root / name).write_text(json.dumps(value), encoding="utf-8")

    def approve_g0(self):
        gate = self.plan["gates"][0]
        (self.root / "candidate.txt").write_text("verified fixture\n", encoding="utf-8")
        self.write_json("manifest.json", {"files": [{
            "path": "candidate.txt", "sha256": GATES.sha256(self.root / "candidate.txt")
        }]})
        fingerprint = GATES.sha256(self.root / "manifest.json")
        self.write_json("review.json", {
            "candidate_manifest_sha256": fingerprint, "status": "pass",
            "executor_id": "executor", "reviewer_id": "reviewer"
        })
        self.write_json("adjudication.json", {
            "candidate_manifest_sha256": fingerprint, "status": "pass",
            "unresolved_material_findings": 0
        })
        gate["status"] = "pass"
        gate["records"] = {
            "executor_id": "executor", "reviewer_id": "reviewer",
            "candidate_manifest": "manifest.json", "review": "review.json",
            "adjudication": "adjudication.json"
        }
        for todo in gate["todos"]:
            todo["status"] = "done"
            todo["evidence"] = [{"path": "candidate.txt", "basis": "executed"}]
        return gate

    def test_queued_plan_is_valid(self):
        self.assertEqual([], GATES.validate(self.plan, self.root))

    def test_cycle_is_rejected(self):
        self.plan["gates"][0]["depends_on"] = ["G1"]
        self.assertTrue(any("cycle" in error for error in GATES.validate(self.plan, self.root)))

    def test_unknown_dependency_is_rejected(self):
        self.plan["gates"][0]["depends_on"] = ["G99"]
        self.assertTrue(any("unknown dependency" in error
                            for error in GATES.validate(self.plan, self.root)))

    def test_execution_cannot_skip_dependency(self):
        self.plan["gates"][1]["status"] = "running"
        self.assertTrue(any("has not passed" in error
                            for error in GATES.validate(self.plan, self.root)))

    def test_pass_without_evidence_is_rejected(self):
        self.plan["gates"][0]["status"] = "pass"
        errors = GATES.validate(self.plan, self.root)
        self.assertTrue(any("every todo done" in error for error in errors))
        self.assertTrue(any("approval records" in error for error in errors))

    def test_complete_independent_records_are_accepted(self):
        self.approve_g0()
        self.assertEqual([], GATES.validate(self.plan, self.root))

    def test_self_review_is_rejected(self):
        gate = self.approve_g0()
        gate["records"]["reviewer_id"] = "executor"
        self.assertTrue(any("distinct" in error for error in GATES.validate(self.plan, self.root)))

    def test_changed_candidate_is_rejected(self):
        self.approve_g0()
        (self.root / "candidate.txt").write_text("unreviewed change", encoding="utf-8")
        self.assertTrue(any("stale candidate" in error
                            for error in GATES.validate(self.plan, self.root)))

    def test_review_of_old_manifest_is_rejected(self):
        self.approve_g0()
        review = GATES.read_json(self.root / "review.json")
        review["candidate_manifest_sha256"] = "0" * 64
        self.write_json("review.json", review)
        self.assertTrue(any("another candidate" in error
                            for error in GATES.validate(self.plan, self.root)))

    def test_unresolved_material_finding_is_rejected(self):
        self.approve_g0()
        adjudication = GATES.read_json(self.root / "adjudication.json")
        adjudication["unresolved_material_findings"] = 1
        self.write_json("adjudication.json", adjudication)
        self.assertTrue(any("unresolved" in error for error in GATES.validate(self.plan, self.root)))

    def test_done_todo_needs_real_evidence(self):
        todo = self.plan["gates"][0]["todos"][0]
        todo["status"] = "done"
        self.assertTrue(any("requires evidence" in error
                            for error in GATES.validate(self.plan, self.root)))

    def test_external_requirement_needs_evidence(self):
        gate = self.approve_g0()
        gate["external_prerequisites"] = ["official election data"]
        self.assertTrue(any("external prerequisite" in error
                            for error in GATES.validate(self.plan, self.root)))

    def test_external_requirement_prevents_early_execution(self):
        gate = self.plan["gates"][0]
        gate["external_prerequisites"] = ["official election data"]
        gate["status"] = "running"
        self.assertTrue(any("execution requires external" in error
                            for error in GATES.validate(self.plan, self.root)))

    def test_duplicate_gate_id_is_rejected(self):
        self.plan["gates"].append(copy.deepcopy(self.plan["gates"][0]))
        self.assertIn("duplicate gate ids", GATES.validate(self.plan, self.root))

    def test_manifest_cannot_escape_repository(self):
        with self.assertRaises(ValueError):
            GATES.project_file(self.root, "../outside.txt")

    def test_render_is_deterministic(self):
        first = GATES.render(self.plan)
        self.assertEqual(first, GATES.render(copy.deepcopy(self.plan)))
        self.assertEqual(len(self.plan["gates"]), first.count("**Goal:**"))


if __name__ == "__main__":
    unittest.main()
