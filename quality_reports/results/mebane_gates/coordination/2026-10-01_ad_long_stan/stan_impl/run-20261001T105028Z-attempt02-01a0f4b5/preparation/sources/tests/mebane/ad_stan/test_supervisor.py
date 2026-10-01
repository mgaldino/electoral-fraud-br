"""Regression tests for the external supervisor; no Stan process is started."""
import importlib.util
from pathlib import Path
import signal
import subprocess
import sys
import unittest
from unittest.mock import MagicMock, patch


SOURCE = Path(sys.argv.pop(1)).resolve(strict=True)
OUTPUT = Path(sys.argv.pop(1)).resolve(strict=True)
spec = importlib.util.spec_from_file_location("ad_stan_supervisor", SOURCE)
supervisor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(supervisor)


class SupervisorTests(unittest.TestCase):
    def test_leader_exits_but_descendant_is_still_killed(self):
        process = MagicMock(pid=123456)
        process.wait.side_effect = [subprocess.TimeoutExpired("synthetic", 1), 0, 0]
        log = OUTPUT / "mock_leader_exits.log"
        with patch.object(supervisor.subprocess, "Popen", return_value=process), \
                patch.object(supervisor.os, "killpg") as kill:
            result = supervisor.run_command(["not-executed"], log, 1)
        self.assertEqual(kill.call_args_list,
                         [unittest.mock.call(123456, signal.SIGTERM),
                          unittest.mock.call(123456, signal.SIGKILL)])
        self.assertTrue(result["timed_out"])
        self.assertTrue(log.exists())

    def test_leader_survives_grace(self):
        process = MagicMock(pid=123457)
        process.wait.side_effect = [subprocess.TimeoutExpired("synthetic", 1),
                                    subprocess.TimeoutExpired("synthetic", 10), -9]
        with patch.object(supervisor.subprocess, "Popen", return_value=process), \
                patch.object(supervisor.os, "killpg") as kill:
            result = supervisor.run_command(["not-executed"], OUTPUT / "mock_grace.log", 1)
        self.assertEqual(kill.call_count, 2)
        self.assertEqual(result["exit_code"], -9)

    def test_disappeared_group_is_not_an_error(self):
        process = MagicMock(pid=123458)
        process.wait.side_effect = [subprocess.TimeoutExpired("synthetic", 1), 0, 0]
        with patch.object(supervisor.subprocess, "Popen", return_value=process), \
                patch.object(supervisor.os, "killpg", side_effect=ProcessLookupError):
            result = supervisor.run_command(["not-executed"], OUTPUT / "mock_gone.log", 1)
        self.assertTrue(result["timed_out"])

    def test_success_keeps_log_and_never_kills(self):
        process = MagicMock(pid=123459)
        process.wait.return_value = 0
        log = OUTPUT / "mock_success.log"
        with patch.object(supervisor.subprocess, "Popen", return_value=process), \
                patch.object(supervisor.os, "killpg") as kill:
            result = supervisor.run_command(["not-executed"], log, 1)
        kill.assert_not_called()
        self.assertFalse(result["timed_out"])
        self.assertEqual(result["console_sha256"], supervisor.sha(log))
        with self.assertRaises(FileExistsError):
            supervisor.run_command(["not-executed"], log, 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
