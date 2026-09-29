"""Regression checks for the mandatory authors' replication dependency."""

import importlib.util
import unittest
from pathlib import Path


SPEC = importlib.util.spec_from_file_location(
    "gate_fixtures", Path(__file__).with_name("test_mebane_gates.py")
)
FIXTURES = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(FIXTURES)


class AuthorReplicationGateTests(unittest.TestCase):
    def setUp(self):
        self.fixture = FIXTURES.GateTests()
        self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)

    def approve_through_engine(self):
        for key in ("G0", "G1", "G2", "G3"):
            self.fixture.approval(key)

    def test_replication_is_required_before_inference(self):
        self.assertEqual(["G3"], self.fixture.gate("G10")["depends_on"])
        self.assertIn("G10", self.fixture.gate("G4")["depends_on"])
        self.assertEqual(4, len(self.fixture.gate("G10")["todos"]))

    def test_replication_cannot_execute_before_engine_approval(self):
        self.fixture.gate("G10")["status"] = "running"
        self.fixture.assert_rejected("G10: prerequisite G3 has not passed")

    def test_engine_approval_does_not_unlock_inference(self):
        self.approve_through_engine()
        self.fixture.gate("G4")["status"] = "running"
        self.fixture.assert_rejected("G4: prerequisite G10 has not passed")

    def test_completed_but_unreviewed_replication_does_not_unlock_inference(self):
        self.approve_through_engine()
        self.fixture.gate("G10")["status"] = "under_review"
        self.fixture.gate("G4")["status"] = "running"
        self.fixture.assert_rejected("G4: prerequisite G10 has not passed")

    def test_replication_approval_unlocks_inference_execution_only(self):
        self.approve_through_engine()
        self.fixture.approval("G10")
        self.fixture.gate("G4")["status"] = "running"
        self.assertEqual(
            [], FIXTURES.GATES.validate(self.fixture.plan, self.fixture.root)
        )
        self.assertEqual("queued", self.fixture.gate("G6")["status"])

    def test_replication_approval_is_bound_to_engine_artifacts(self):
        self.approve_through_engine()
        self.fixture.approval("G10")
        manifest = FIXTURES.GATES.read_json(self.fixture.root / "G3-manifest.json")
        manifest["note"] = "changed engine after replication approval"
        self.fixture.write_json("G3-manifest.json", manifest)
        self.fixture.assert_rejected("G10: stale dependency manifest G3")


if __name__ == "__main__":
    unittest.main()
