import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from claude_traffic import ClaudeSession, strongest_session_per_window


def tmux_session(pid, status, window="@1", parked=""):
    return ClaudeSession(pid, status, "work", window, parked_job_id=parked)


def bg_job(pid, status, job):
    return ClaudeSession(pid, status, "", "", job_id=job)


class ParkedJobTests(unittest.TestCase):
    def test_busy_parked_job_overrides_idle_parent(self):
        result = strongest_session_per_window([tmux_session(1, "idle", parked="j"), bg_job(2, "busy", "j")])
        self.assertEqual(result["@1"].status, "busy")

    def test_idle_job_does_not_lower_parent(self):
        result = strongest_session_per_window([tmux_session(1, "busy", parked="j"), bg_job(2, "idle", "j")])
        self.assertEqual(result["@1"].status, "busy")

    def test_unrelated_job_is_ignored(self):
        result = strongest_session_per_window([tmux_session(1, "idle", parked="j"), bg_job(2, "busy", "other")])
        self.assertEqual(result["@1"].status, "idle")

    def test_job_without_parent_makes_no_window(self):
        self.assertEqual(strongest_session_per_window([bg_job(2, "busy", "j")]), {})


if __name__ == "__main__":
    unittest.main()
