import os
from pathlib import Path

import pytest

from shared.policy import apply_patch, check_write_allowed
from agents.clc_local.policy import check_file_allowed


@pytest.fixture(autouse=True)
def set_base_dir(tmp_path, monkeypatch):
    """
    Use an isolated base directory for policy checks to avoid touching the repo.
    """
    monkeypatch.setenv("LAC_BASE_DIR", str(tmp_path))
    return tmp_path


class TestCheckWriteAllowed:
    def test_forbidden_git(self):
        allowed, reason = check_write_allowed(".git/config")
        assert not allowed
        assert "FORBIDDEN" in reason

    def test_forbidden_secrets(self):
        allowed, reason = check_write_allowed("secrets/api_key.txt")
        assert not allowed
        assert "FORBIDDEN" in reason

    def test_allowed_g_src(self):
        allowed, reason = check_write_allowed("g/src/main.py")
        assert allowed
        assert reason == "ALLOWED"

    def test_allowed_tests(self):
        allowed, reason = check_write_allowed("tests/test_foo.py")
        assert allowed
        assert reason == "ALLOWED"

    def test_not_in_allowed_roots(self):
        allowed, reason = check_write_allowed("random/path.py")
        assert not allowed
        assert "NOT_IN_ALLOWED" in reason

    def test_path_traversal_blocked(self):
        allowed, reason = check_write_allowed("../outside.py")
        assert not allowed
        assert "OUTSIDE_BASE" in reason


class TestCLCLocalPolicyWrapper:
    def test_wrapper_allowed(self):
        allowed, reason = check_file_allowed("g/src/demo.py")
        assert allowed
        assert reason == "ALLOWED"

    def test_wrapper_forbidden(self):
        allowed, reason = check_file_allowed(".git/config")
        assert not allowed
        assert "FORBIDDEN" in reason

    def test_prefix_collision_blocked(self):
        """Test that prefix collision attacks are blocked (e.g., g/srcfoo/ should not match g/src/)."""
        # These should be blocked because they use prefix collision
        collision_cases = [
            "g/srcfoo/bar.py",  # Should not match g/src/
            "g/appsfoo/test.py",  # Should not match g/apps/
            "g/toolsfoo/script.py",  # Should not match g/tools/
            "g/docsfoo/readme.md",  # Should not match g/docs/
            "testsfoo/test_foo.py",  # Should not match tests/
        ]
        for path in collision_cases:
            allowed, reason = check_write_allowed(path)
            assert not allowed, f"Prefix collision not blocked: {path}"
            assert "PATH_NOT_IN_ALLOWED_ROOTS" in reason or "NOT_IN_ALLOWED" in reason


class TestApplyPatch:
    def test_blocked_write(self):
        result = apply_patch(".git/config", "content")
        assert result["status"] == "blocked"
        assert "FORBIDDEN" in result["reason"]

    def test_dry_run(self):
        result = apply_patch("g/src/test.py", "content", dry_run=True)
        assert result["status"] == "dry_run"
        assert result["content_length"] == len("content")

    def test_success_write(self, set_base_dir):
        target = "g/src/example.py"
        content = "print('ok')\n"
        result = apply_patch(target, content)
        assert result["status"] == "success"
        assert os.path.exists(result["file"])
        with open(result["file"]) as handle:
            assert handle.read() == content

    def test_sequential_writes_replace_content(self, set_base_dir):
        target = "g/src/seq.py"
        first = "one\n"
        second = "two\n"
        apply_patch(target, first)
        apply_patch(target, second)
        with open(Path(os.getenv("LAC_BASE_DIR")) / target) as handle:
            assert handle.read() == second

    def test_large_content_write(self, set_base_dir):
        target = "tests/big.txt"
        content = "x" * (1024 * 1024)  # 1MB
        result = apply_patch(target, content)
        assert result["status"] == "success"
        assert result["bytes_written"] == len(content)

    def test_error_handling_on_write_failure(self, set_base_dir, monkeypatch):
        target = "g/src/error.py"

        def fake_write_text(self, content, encoding=None):
            raise OSError("disk full")

        monkeypatch.setattr(Path, "write_text", fake_write_text, raising=True)
        result = apply_patch(target, "data")
        assert result["status"] == "error"
        assert "disk full" in result["reason"]

    def test_traversal_blocks(self):
        allowed, reason = check_write_allowed("../../g/src/foo.py")
        assert not allowed
        assert "OUTSIDE_BASE" in reason

    def test_prefix_collision_blocked(self, set_base_dir):
        allowed, reason = check_write_allowed("g/srcfoo/bar.py")
        assert not allowed
        assert "NOT_IN_ALLOWED" in reason or reason == "PATH_NOT_IN_ALLOWED_ROOTS"

    def test_absolute_outside_base_blocked(self, set_base_dir, tmp_path):
        outside = Path("/tmp/outside_base_file.py")
        allowed, reason = check_write_allowed(str(outside))
        assert not allowed
        assert "OUTSIDE_BASE" in reason
