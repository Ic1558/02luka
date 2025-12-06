from __future__ import annotations

import os
import subprocess
from pathlib import Path

import yaml

from tools.lib.local_review_git import GitInterface
from tools.lib.privacy_guard import PrivacyGuard
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
