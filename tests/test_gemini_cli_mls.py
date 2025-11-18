import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


class GeminiCliMlsTest(unittest.TestCase):
    def test_prompt_includes_mls_lessons(self):
        workdir = tempfile.mkdtemp()
        try:
            source = Path(workdir) / "mls_lessons.jsonl"
            dest = Path(workdir) / "mls_lessons_cli.jsonl"
            entries = [
                {
                    "id": "MLS-TEST-001",
                    "type": "solution",
                    "title": "Validate LaunchAgent paths before patch",
                    "description": "Ensure com.02luka.sync.* changes validate paths.",
                    "context": "Run g/tools/validate_launchagent_paths.zsh before patching launchd entries.",
                    "timestamp": "2025-12-01T01:00:00+00:00",
                    "tags": [],
                    "verified": True,
                    "usefulness_score": 10,
                },
                {
                    "id": "MLS-TEST-002",
                    "type": "pattern",
                    "title": "Bridge handler keeps Redis safe",
                    "description": "Use redis locks before writing to redis_channels.",
                    "context": "Bridge handler should never write without a lock.",
                    "timestamp": "2025-12-01T01:05:00+00:00",
                    "tags": ["bridge"],
                    "verified": True,
                    "usefulness_score": 8,
                },
                {
                    "id": "MLS-TEST-003",
                    "type": "pattern",
                    "title": "Watcher must log filesystem checks",
                    "description": "Filesystem watchers report to the dashboard.",
                    "context": "Writes should always respect file permissions.",
                    "timestamp": "2025-12-01T01:10:00+00:00",
                    "tags": ["watcher"],
                    "verified": False,
                    "usefulness_score": 7,
                },
            ]

            with source.open("w", encoding="utf-8") as handle:
                for entry in entries:
                    handle.write(json.dumps(entry, ensure_ascii=False))
                    handle.write("\n")

            subprocess.run(
                [
                    sys.executable,
                    "g/tools/mls_build_cli_feed.py",
                    "--source",
                    str(source),
                    "--dest",
                    str(dest),
                    "--limit",
                    "3",
                ],
                check=True,
                cwd=REPO_ROOT,
            )

            self.assertTrue(dest.exists(), "CLI feed should be generated")
            lessons = [
                json.loads(line)
                for line in dest.read_text(encoding="utf-8").splitlines()
                if line.strip()
            ]
            self.assertGreaterEqual(len(lessons), 2)
            self.assertTrue(
                any("validate_launchagent_paths.zsh" in lesson["example"] for lesson in lessons),
                "Example must mention the LaunchAgent validator",
            )

            result = subprocess.run(
                [
                    sys.executable,
                    "g/tools/mls_cli_prompt.py",
                    "--feed",
                    str(dest),
                    "--limit",
                    "3",
                ],
                check=True,
                capture_output=True,
                text=True,
                cwd=REPO_ROOT,
            )

            output = result.stdout
            self.assertIn("MLS Recent Lessons (Read-Only)", output)
            self.assertIn("validate_launchagent_paths.zsh", output)
        finally:
            shutil.rmtree(workdir)


if __name__ == "__main__":
    unittest.main()
