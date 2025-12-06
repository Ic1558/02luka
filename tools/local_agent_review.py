from __future__ import annotations

import argparse
import json
import logging
import os
import sys
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional, Sequence
import subprocess

import yaml

from tools.lib.local_review_engine import ReviewEngine, ReviewResult, build_offline_result
from tools.lib.local_review_git import DiffResult, GitDiffError, GitInterface
from tools.lib.local_review_llm import LLMClient, LLMConfig, LLMError
from tools.lib.privacy_guard import PrivacyGuard


DEFAULT_CONFIG = Path("g/config/local_agent_review.yaml")


@dataclass
class AppConfig:
    api: Dict[str, Any]
    review: Dict[str, Any]
    output: Dict[str, Any]
    safety: Dict[str, Any]

    @classmethod
    def load(cls, path: Path) -> "AppConfig":
        if not path.exists():
            raise FileNotFoundError(f"Config not found: {path}")
        with path.open("r", encoding="utf-8") as f:
            data = yaml.safe_load(f) or {}
        return cls(
            api=data.get("api", {}),
            review=data.get("review", {}),
            output=data.get("output", {}),
            safety=data.get("safety", {}),
        )


class ReportGenerator:
    def __init__(self, *, default_dir: Path, retention_count: int) -> None:
        self.default_dir = default_dir
        self.retention_count = retention_count

    def render_markdown(
        self,
        result: ReviewResult,
        diff: DiffResult,
        mode: str,
        truncated: bool,
        context: str,
    ) -> str:
        lines: List[str] = []
        lines.append("# Local Agent Review Report")
        lines.append(f"**Date:** {datetime.utcnow().isoformat()}Z")
        lines.append(f"**Mode:** {mode}")
        lines.append(f"**Files Analyzed:** {len(diff.files_included)}")
        if diff.files_excluded:
            lines.append(f"**Files Excluded:** {len(diff.files_excluded)}")
        if truncated:
            excluded_list = ", ".join(diff.files_excluded) if diff.files_excluded else "unspecified"
            lines.append(f"**⚠️ PARTIAL REVIEW:** Input truncated. Excluded: {excluded_list}")
        lines.append("")
        lines.append("## Summary")
        lines.append(result.summary or "No summary provided")
        counts = result.counts
        lines.append("")
        lines.append("## Issue Counts")
        lines.append(f"- Critical: {counts['critical']}")
        lines.append(f"- Warning: {counts['warning']}")
        lines.append(f"- Suggestion: {counts['suggestion']}")
        lines.append(f"- Info: {counts['info']}")
        lines.append("")
        lines.append("## Issues")
        if not result.issues:
            lines.append("No issues found.")
        else:
            for idx, issue in enumerate(result.issues, start=1):
                lines.append(f"### {idx}. {issue.severity.upper()} — {issue.file}:{issue.line}")
                lines.append(f"- **Category:** {issue.category}")
                lines.append(f"- **Description:** {issue.description}")
                if issue.suggestion:
                    lines.append(f"- **Suggestion:** {issue.suggestion}")
                lines.append("")
        if context:
            lines.append("## Context")
            lines.append(context)
        return "\n".join(lines) + "\n"

    def render_json(
        self,
        result: ReviewResult,
        diff: DiffResult,
        mode: str,
        truncated: bool,
        context: str,
    ) -> str:
        payload = {
            "mode": mode,
            "summary": result.summary,
            "issues": [issue.__dict__ for issue in result.issues],
            "metrics": result.metrics,
            "counts": result.counts,
            "diff": {
                "files_included": diff.files_included,
                "files_excluded": diff.files_excluded,
                "truncated": truncated,
                "stats": diff.stats,
            },
            "context": context,
            "ts": datetime.utcnow().isoformat() + "Z",
        }
        return json.dumps(payload, indent=2)

    def render_console(
        self,
        result: ReviewResult,
        diff: DiffResult,
        mode: str,
        truncated: bool,
        context: str,
    ) -> str:
        lines = [f"Mode: {mode}", f"Summary: {result.summary}"]
        counts = result.counts
        lines.append(
            f"Issues — critical: {counts['critical']}, warning: {counts['warning']}, "
            f"suggestion: {counts['suggestion']}, info: {counts['info']}"
        )
        if truncated:
            lines.append(f"⚠️ PARTIAL REVIEW: excluded {len(diff.files_excluded)} files")
        if result.issues:
            lines.append("Issues:")
            for issue in result.issues:
                lines.append(
                    f" - [{issue.severity}] {issue.file}:{issue.line} — {issue.description}"
                )
        else:
            lines.append("No issues found.")
        return "\n".join(lines) + "\n"

    def write_report(self, content: str, output_path: Optional[Path], fmt: str) -> Optional[Path]:
        if output_path is None:
            return None

        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(content, encoding="utf-8")
        if self._is_under_default_dir(output_path):
            self._rotate_reports()
        return output_path

    def _is_under_default_dir(self, path: Path) -> bool:
        try:
            return path.resolve().is_relative_to(self.default_dir.resolve())
        except AttributeError:
            # Python <3.9 fallback
            try:
                path.resolve().relative_to(self.default_dir.resolve())
                return True
            except ValueError:
                return False

    def _rotate_reports(self) -> None:
        files = sorted(self.default_dir.glob("*"), key=lambda p: p.stat().st_mtime, reverse=True)
        for idx, path in enumerate(files):
            if idx >= self.retention_count:
                try:
                    path.unlink()
                except OSError:
                    continue


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Local Agent Review CLI")
    parser.add_argument(
        "mode",
        nargs="?",
        default="staged",
        choices=["staged", "unstaged", "last-commit", "branch", "range"],
        help="What to review (default: staged)",
    )
    parser.add_argument(
        "--target",
        help="Target branch for branch/range mode",
    )
    parser.add_argument("--base", help="Base ref for range mode or custom base")
    parser.add_argument(
        "--format",
        dest="fmt",
        choices=["markdown", "json", "console"],
        default="markdown",
        help="Report format",
    )
    parser.add_argument("--output", help="Path to save report")
    parser.add_argument("--quiet", action="store_true", help="Suppress stdout")
    parser.add_argument("--verbose", action="store_true", help="Enable debug logging")
    parser.add_argument("--dry-run", "--offline", dest="offline", action="store_true", help="Run without LLM call")
    parser.add_argument("--no-interactive", action="store_true", help="Disable prompts (no-op, safety)")
    parser.add_argument("--strict", action="store_true", help="Treat warnings as failures")
    parser.add_argument("--config", help="Path to config file")
    return parser


def load_config(path_arg: Optional[str]) -> AppConfig:
    config_path = Path(path_arg) if path_arg else DEFAULT_CONFIG
    env_override = os.getenv("LOCAL_REVIEW_CONFIG")
    if env_override:
        config_path = Path(env_override)
    return AppConfig.load(config_path)


def _load_env_file(path: Path) -> None:
    if not path.exists():
        return
    try:
        content = path.read_text(encoding="utf-8")
    except OSError:
        return
    for raw_line in content.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip("'").strip('"')
        if key and key not in os.environ:
            os.environ[key] = value


def load_env_local() -> None:
    """Load env vars from .env.local in cwd and repo root (if available)."""
    candidates = []
    cwd = Path.cwd()
    candidates.append(cwd / ".env.local")
    try:
        root = Path(
            subprocess.check_output(
                ["git", "rev-parse", "--show-toplevel"], cwd=cwd, text=True
            ).strip()
        )
        if root != cwd:
            candidates.append(root / ".env.local")
    except Exception:
        pass

    seen = set()
    for path in candidates:
        if path in seen:
            continue
        seen.add(path)
        _load_env_file(path)


def ensure_ack(config: AppConfig, *, offline: bool) -> None:
    required_env = config.safety.get("require_ack_env")
    if offline:
        return
    if required_env and not os.getenv(required_env):
        raise RuntimeError(
            f"{required_env} is required to send code to external API. "
            "Set it to 1 to acknowledge."
        )


def maybe_output_path(args: argparse.Namespace, config: AppConfig) -> Optional[Path]:
    if args.output:
        return Path(args.output)
    default_dir = Path(config.output.get("save_dir", "g/reports/reviews"))
    default_dir.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
    ext = "md" if args.fmt == "markdown" else "json"
    return default_dir / f"review_{timestamp}.{ext}"


def build_llm(config: AppConfig) -> LLMClient:
    api_cfg = config.api
    llm_config = LLMConfig(
        provider=api_cfg.get("provider", "anthropic"),
        model=api_cfg.get("model", "claude-3-5-sonnet-20241022"),
        max_tokens=int(api_cfg.get("max_tokens", 4000)),
        temperature=float(api_cfg.get("temperature", 0.2)),
        max_calls=int(api_cfg.get("max_review_calls_per_run", 1)),
    )
    return LLMClient(llm_config)


def build_privacy_guard(config: AppConfig) -> PrivacyGuard:
    review_cfg = config.review
    return PrivacyGuard(
        ignore_patterns=review_cfg.get("ignore_patterns", []),
        exclude_files=review_cfg.get("exclude_files", []),
        redact_secrets=bool(review_cfg.get("redact_secrets", True)),
    )


def telemetry_append(path: Path, payload: Dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as f:
        f.write(json.dumps(payload) + "\n")


def determine_exit_code(result: ReviewResult, *, strict: bool) -> int:
    counts = result.counts
    if counts["critical"] > 0:
        return 1
    if strict and (counts["warning"] > 0):
        return 1
    return 0


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = build_arg_parser()
    args = parser.parse_args(argv)

    logging.basicConfig(level=logging.DEBUG if args.verbose else logging.WARNING, format="%(message)s")

    # Load local env defaults before config/env checks
    load_env_local()

    try:
        config = load_config(args.config)
    except Exception as exc:  # noqa: BLE001
        print(f"[local-review] Failed to load config: {exc}", file=sys.stderr)
        return 2

    offline = bool(args.offline)
    try:
        ensure_ack(config, offline=offline)
    except RuntimeError as exc:
        print(f"[local-review] {exc}", file=sys.stderr)
        return 2

    git = GitInterface()

    review_cfg = config.review
    try:
        diff = git.get_filtered_diff(
            args.mode,
            target=args.target,
            base=args.base,
            ignore_patterns=review_cfg.get("ignore_patterns", []),
            exclude_files=review_cfg.get("exclude_files", []),
            drop_files=review_cfg.get("drop_files", []),
            priority_ext=review_cfg.get("priority_extensions", []),
            deprioritize_ext=review_cfg.get("deprioritize_extensions", []),
            soft_limit_kb=int(review_cfg.get("soft_limit_kb", 60)),
            hard_limit_kb=int(review_cfg.get("hard_limit_kb", 100)),
            context_lines=int(review_cfg.get("context_lines", 3)),
        )
    except GitDiffError as exc:
        print(f"[local-review] git error: {exc}", file=sys.stderr)
        return 2

    if not diff.text.strip():
        if not args.quiet:
            print("No changes to review.")
        return 0

    guard = build_privacy_guard(config)
    warnings = guard.scan_diff(diff.text)
    if warnings:
        if not args.quiet:
            print("[local-review] Potential secrets detected; aborting review.", file=sys.stderr)
            for warn in warnings:
                print(f" - {warn.kind}: {warn.match}", file=sys.stderr)
        return 3

    # Run review
    if offline:
        review_result = build_offline_result()
        truncated = diff.truncated
        exit_code = determine_exit_code(review_result, strict=args.strict)
    else:
        try:
            llm = build_llm(config)
            engine = ReviewEngine(llm, focus_areas=review_cfg.get("focus_areas", []))
            review_result = engine.analyze_diff(diff.text)
        except LLMError as exc:
            print(f"[local-review] LLM error: {exc}", file=sys.stderr)
            return 2
        truncated = diff.truncated
        exit_code = determine_exit_code(review_result, strict=args.strict)

    report_gen = ReportGenerator(
        default_dir=Path(config.output.get("save_dir", "g/reports/reviews")),
        retention_count=int(config.output.get("retention_count", 20)),
    )

    fmt = args.fmt or config.output.get("format", "markdown")
    context = ""
    if fmt == "markdown":
        content = report_gen.render_markdown(review_result, diff, args.mode, truncated, context)
    elif fmt == "json":
        content = report_gen.render_json(review_result, diff, args.mode, truncated, context)
    else:
        content = report_gen.render_console(review_result, diff, args.mode, truncated, context)

    output_path = None
    if args.output or fmt != "console":
        output_path = maybe_output_path(args, config)
        report_gen.write_report(content, output_path, fmt)

    if not args.quiet and fmt == "console":
        sys.stdout.write(content)
    elif not args.quiet and fmt != "console":
        print(f"Report written to {output_path}")

    # Telemetry
    telemetry_path = Path(config.safety.get("telemetry_file", "g/telemetry/local_agent_review.jsonl"))
    telemetry_payload = {
        "ts": datetime.utcnow().isoformat() + "Z",
        "mode": args.mode,
        "exit_code": exit_code,
        "issues_critical": review_result.counts["critical"],
        "issues_warning": review_result.counts["warning"],
        "model": config.api.get("model", ""),
        "truncated": truncated,
        "files_included": len(diff.files_included),
        "files_excluded": len(diff.files_excluded),
    }
    try:
        telemetry_append(telemetry_path, telemetry_payload)
    except Exception:
        logging.warning("Failed to write telemetry", exc_info=args.verbose)

    return exit_code


if __name__ == "__main__":
    sys.exit(main())
