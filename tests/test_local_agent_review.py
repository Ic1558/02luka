from __future__ import annotations

import os
import subprocess
from pathlib import Path

import yaml

from tools.lib.local_review_git import GitInterface
from tools.lib.privacy_guard import PrivacyGuard, SecretAllowlist
from tools.local_agent_review import main, load_env_local


def _git(repo: Path, *args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=repo, text=True)


def _init_repo(tmp_path: Path) -> Path:
    repo = tmp_path / "repo"
    repo.mkdir()
    _git(repo, "init", "-b", "main")
    _git(repo, "config", "user.email", "test@example.com")
    _git(repo, "config", "user.name", "Test User")
    return repo


def _write_config(repo: Path) -> Path:
    cfg = {
        "api": {
            "provider": "anthropic",
            "model": "claude-3-5-sonnet-20241022",
            "max_tokens": 4000,
            "temperature": 0.2,
            "max_review_calls_per_run": 1,
        },
        "review": {
            "focus_areas": ["bugs"],
            "ignore_patterns": [],
            "exclude_files": [],
            "redact_secrets": True,
            "context_lines": 3,
            "soft_limit_kb": 1,  # tiny to force truncation in tests
            "hard_limit_kb": 2,
            "priority_extensions": [".py"],
            "deprioritize_extensions": [".json"],
            "drop_files": ["package-lock.json"],
        },
        "output": {
            "format": "console",
            "save_dir": str(repo / "reports" / "reviews"),
            "retention_count": 5,
        },
        "safety": {
            "require_ack_env": "LOCAL_REVIEW_ACK",
            "telemetry_file": str(repo / "telemetry" / "local_agent_review.jsonl"),
        },
    }
    path = repo / "local_agent_review.yaml"
    path.write_text(yaml.safe_dump(cfg), encoding="utf-8")
    return path


def test_privacy_guard_detects_secret() -> None:
    guard = PrivacyGuard(ignore_patterns=[], exclude_files=[], redact_secrets=True)
    warnings = guard.scan_diff("api key: sk-TESTSECRET1234567890")
    assert warnings
    assert warnings[0].kind in {"generic_secret", "openai_key"}


def test_truncation_drops_low_priority(tmp_path: Path, monkeypatch) -> None:
    repo = _init_repo(tmp_path)
    config_path = _write_config(repo)
    (repo / "main.py").write_text("print('hello')\n", encoding="utf-8")
    (repo / "package-lock.json").write_text("x" * 5000, encoding="utf-8")
    _git(repo, "add", ".")
    _git(repo, "commit", "-m", "init")
    # modify both files to create diff
    (repo / "main.py").write_text("print('hello world')\n", encoding="utf-8")
    (repo / "package-lock.json").write_text("y" * 8000, encoding="utf-8")

    os.environ["LOCAL_REVIEW_CONFIG"] = str(config_path)
    gi = GitInterface(repo_root=repo)
    diff = gi.get_filtered_diff(
        "unstaged",
        target=None,
        base=None,
        ignore_patterns=[],
        exclude_files=[],
        drop_files=["package-lock.json"],
        priority_ext=[".py"],
        deprioritize_ext=[".json"],
        soft_limit_kb=1,
        hard_limit_kb=2,
        context_lines=3,
    )
    assert "package-lock.json" in diff.files_excluded
    assert diff.truncated


def test_cli_empty_diff_returns_zero(tmp_path: Path, monkeypatch) -> None:
    repo = _init_repo(tmp_path)
    config_path = _write_config(repo)
    monkeypatch.chdir(repo)
    (repo / "README.md").write_text("test\n", encoding="utf-8")
    _git(repo, "add", "README.md")
    _git(repo, "commit", "-m", "init")
    os.environ["LOCAL_REVIEW_CONFIG"] = str(config_path)
    # No changes yet -> empty diff
    rc = main(["staged", "--offline"])
    assert rc == 0


def test_cli_offline_truncation_message(tmp_path: Path, capsys, monkeypatch) -> None:
    repo = _init_repo(tmp_path)
    config_path = _write_config(repo)
    (repo / "main.py").write_text("print('hello')\n", encoding="utf-8")
    _git(repo, "add", ".")
    _git(repo, "commit", "-m", "init")
    (repo / "main.py").write_text("print('hello world')\n", encoding="utf-8")

    os.environ["LOCAL_REVIEW_CONFIG"] = str(config_path)
    # Switch to repo for git commands
    monkeypatch.chdir(repo)
    rc = main(["unstaged", "--offline", "--format", "console"])
    captured = capsys.readouterr()
    assert rc == 0
    assert "Mode: unstaged" in captured.out


def test_load_env_local_reads_dotenv(tmp_path: Path, monkeypatch) -> None:
    repo = _init_repo(tmp_path)
    dotenv = repo / ".env.local"
    dotenv.write_text("ANTHROPIC_API_KEY=abc123\nLOCAL_REVIEW_ACK=1\n", encoding="utf-8")
    monkeypatch.chdir(repo)
    monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
    monkeypatch.delenv("LOCAL_REVIEW_ACK", raising=False)

    load_env_local()

    assert os.getenv("ANTHROPIC_API_KEY") == "abc123"
    assert os.getenv("LOCAL_REVIEW_ACK") == "1"


def test_allowlist_content_and_file_patterns() -> None:
    allowlist = SecretAllowlist(
        file_patterns=["**/tests/**"],
        content_patterns=["sk-test-.*"],
        file_paths=["docs/examples/api_keys.md"],
        safe_patterns=["TEST_.*_KEY"],
    )
    guard = PrivacyGuard(ignore_patterns=[], exclude_files=[], redact_secrets=True, allowlist=allowlist)

    diff = """\
diff --git a/tests/test_api.py b/tests/test_api.py
index 000..111 100644
--- a/tests/test_api.py
+++ b/tests/test_api.py
@@
+api_key = "sk-test-abc123"
"""
    warnings = guard.scan_diff(diff)
    assert warnings == []  # allowed by file pattern and content pattern

    diff_prod = """\
diff --git a/src/api.py b/src/api.py
index 000..111 100644
--- a/src/api.py
+++ b/src/api.py
@@
+api_key = "sk-ABCDEFGHIJKLMNOPQRSTUVWX"
"""
    warnings_prod = guard.scan_diff(diff_prod)
    assert any(w.kind in {"openai_key", "generic_secret"} for w in warnings_prod)


def test_exit_code_mapping_strict_vs_non_strict() -> None:
    """Test exit code mapping for strict vs non-strict mode."""
    from tools.local_agent_review import determine_exit_code
    from tools.lib.local_review_engine import ReviewResult, Issue

    # No issues -> exit 0
    result = ReviewResult(summary="OK", issues=[])
    assert determine_exit_code(result, strict=False) == 0
    assert determine_exit_code(result, strict=True) == 0

    # Warning only -> exit 0 (non-strict), exit 1 (strict)
    result = ReviewResult(
        summary="Has warnings",
        issues=[Issue(file="test.py", line=1, severity="warning", category="style", description="Minor issue")]
    )
    assert determine_exit_code(result, strict=False) == 0
    assert determine_exit_code(result, strict=True) == 1

    # Critical issue -> exit 1 (both modes)
    result = ReviewResult(
        summary="Has critical",
        issues=[Issue(file="test.py", line=1, severity="critical", category="bug", description="Critical bug")]
    )
    assert determine_exit_code(result, strict=False) == 1
    assert determine_exit_code(result, strict=True) == 1

    # Critical + warning -> exit 1 (both modes)
    result = ReviewResult(
        summary="Has both",
        issues=[
            Issue(file="test.py", line=1, severity="critical", category="bug", description="Critical"),
            Issue(file="test.py", line=2, severity="warning", category="style", description="Warning")
        ]
    )
    assert determine_exit_code(result, strict=False) == 1
    assert determine_exit_code(result, strict=True) == 1


def test_branch_range_modes(tmp_path: Path, monkeypatch) -> None:
    """Test branch and range modes."""
    repo = _init_repo(tmp_path)
    config_path = _write_config(repo)
    (repo / "main.py").write_text("print('v1')\n", encoding="utf-8")
    _git(repo, "add", ".")
    _git(repo, "commit", "-m", "v1")
    _git(repo, "checkout", "-b", "feature")
    (repo / "main.py").write_text("print('v2')\n", encoding="utf-8")
    _git(repo, "add", ".")
    _git(repo, "commit", "-m", "v2")

    os.environ["LOCAL_REVIEW_CONFIG"] = str(config_path)
    gi = GitInterface(repo_root=repo)

    # Test branch mode (compare feature branch to main)
    diff = gi.get_filtered_diff(
        "branch",
        target="feature",
        base="main",
        ignore_patterns=[],
        exclude_files=[],
        drop_files=[],
        priority_ext=[],
        deprioritize_ext=[],
        soft_limit_kb=100,
        hard_limit_kb=200,
        context_lines=3,
    )
    assert "main.py" in diff.files_included or diff.text  # Should have diff

    # Test range mode (compare commits)
    commits = _git(repo, "log", "--oneline").split("\n")
    if len(commits) >= 2:
        latest = commits[0].split()[0]
        previous = commits[1].split()[0]
        diff = gi.get_filtered_diff(
            "range",
            target=latest,
            base=previous,
            ignore_patterns=[],
            exclude_files=[],
            drop_files=[],
            priority_ext=[],
            deprioritize_ext=[],
            soft_limit_kb=100,
            hard_limit_kb=200,
            context_lines=3,
        )
        assert diff.text  # Should have diff


def test_truncation_metadata_in_reports(tmp_path: Path, monkeypatch) -> None:
    """Test that truncation metadata appears in reports."""
    repo = _init_repo(tmp_path)
    config_path = _write_config(repo)
    (repo / "file1.py").write_text("print('a')\n", encoding="utf-8")
    (repo / "file2.py").write_text("print('b')\n", encoding="utf-8")
    (repo / "file3.json").write_text("x" * 5000, encoding="utf-8")
    _git(repo, "add", ".")
    _git(repo, "commit", "-m", "init")
    (repo / "file1.py").write_text("print('a2')\n", encoding="utf-8")
    (repo / "file2.py").write_text("print('b2')\n", encoding="utf-8")
    (repo / "file3.json").write_text("y" * 8000, encoding="utf-8")

    os.environ["LOCAL_REVIEW_CONFIG"] = str(config_path)
    monkeypatch.chdir(repo)
    os.environ["LOCAL_REVIEW_ACK"] = "1"

    # Run with offline mode to get report
    from tools.local_agent_review import main
    import tempfile
    with tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False) as f:
        output_path = f.name

    try:
        rc = main(["unstaged", "--offline", "--format", "markdown", "--output", output_path])
        assert rc == 0

        # Check report contains truncation metadata
        report_content = Path(output_path).read_text()
        assert "PARTIAL REVIEW" in report_content or "truncated" in report_content.lower()
        assert "Files Excluded" in report_content or "excluded" in report_content.lower()
    finally:
        Path(output_path).unlink(missing_ok=True)
