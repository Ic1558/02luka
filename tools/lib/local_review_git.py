from __future__ import annotations

import fnmatch
import logging
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Sequence, Tuple


class GitDiffError(RuntimeError):
    """Raised when git diff operations fail."""


@dataclass
class DiffResult:
    text: str
    files_included: List[str]
    files_excluded: List[str]
    truncated: bool
    stats: Dict[str, int]


class GitInterface:
    """Lightweight wrapper around git diff operations."""

    def __init__(self, repo_root: Optional[Path] = None) -> None:
        self.repo_root = repo_root or self._detect_repo_root()

    def _detect_repo_root(self) -> Path:
        cmd = ["git", "rev-parse", "--show-toplevel"]
        try:
            out = subprocess.check_output(cmd, cwd=Path.cwd(), text=True).strip()
            return Path(out)
        except subprocess.CalledProcessError as exc:
            raise GitDiffError("Not a git repository or git not available") from exc

    def _run_git(self, args: Sequence[str]) -> str:
        try:
            logging.debug("Running git command: %s", " ".join(args))
            return subprocess.check_output(["git", *args], cwd=self.repo_root, text=True)
        except subprocess.CalledProcessError as exc:
            raise GitDiffError(exc.stderr or str(exc)) from exc

    def _diff_scope_args(self, mode: str, target: Optional[str], base: Optional[str]) -> List[str]:
        if mode == "staged":
            return ["--cached"]
        if mode == "unstaged":
            return []
        if mode == "last-commit":
            return ["HEAD~1..HEAD"]
        if mode == "branch":
            branch = target or self._current_branch()
            base_branch = base or self._discover_base_branch()
            return [f"{base_branch}..{branch}"]
        if mode == "range":
            if not target or not base:
                raise GitDiffError("range mode requires both base and target")
            return [f"{base}..{target}"]
        raise GitDiffError(f"Unsupported mode: {mode}")

    def _current_branch(self) -> str:
        out = self._run_git(["rev-parse", "--abbrev-ref", "HEAD"]).strip()
        if out == "HEAD":
            raise GitDiffError("Detached HEAD: specify branch explicitly")
        return out

    def _discover_base_branch(self) -> str:
        candidates = ["origin/main", "main", "master"]
        for candidate in candidates:
            try:
                self._run_git(["rev-parse", "--verify", candidate])
                return candidate
            except GitDiffError:
                continue
        raise GitDiffError("No base branch found (checked origin/main, main, master)")

    def _numstat(self, scope_args: Sequence[str]) -> Dict[str, bool]:
        """Return mapping file -> is_binary using git numstat."""
        out = self._run_git(["diff", *scope_args, "--numstat"])
        mapping: Dict[str, bool] = {}
        for line in out.splitlines():
            parts = line.split("\t")
            if len(parts) < 3:
                continue
            add, delete, filename = parts[0], parts[1], parts[2]
            mapping[filename] = add == "-" or delete == "-"
        return mapping

    def _file_diff(self, scope_args: Sequence[str], filename: str, context_lines: int) -> str:
        return self._run_git(
            ["diff", *scope_args, f"-U{context_lines}", "--", filename]
        )

    @staticmethod
    def _is_match(patterns: Sequence[str], path: str) -> bool:
        return any(fnmatch.fnmatch(path, pat) for pat in patterns)

    def get_filtered_diff(
        self,
        mode: str,
        *,
        target: Optional[str],
        base: Optional[str],
        ignore_patterns: Sequence[str],
        exclude_files: Sequence[str],
        drop_files: Sequence[str],
        priority_ext: Sequence[str],
        deprioritize_ext: Sequence[str],
        soft_limit_kb: int,
        hard_limit_kb: int,
        context_lines: int = 3,
    ) -> DiffResult:
        scope_args = self._diff_scope_args(mode, target, base)
        name_only_args = ["diff", *scope_args, "--name-only"]
        names_out = self._run_git(name_only_args)
        filenames = [line.strip() for line in names_out.splitlines() if line.strip()]

        binary_map = self._numstat(scope_args)

        included: List[str] = []
        excluded: List[str] = []
        file_blobs: List[Tuple[str, str, int, int]] = []
        total_bytes = 0

        for filename in filenames:
            if self._is_match(ignore_patterns, filename) or self._is_match(exclude_files, filename):
                excluded.append(filename)
                continue
            if binary_map.get(filename):
                excluded.append(filename)
                continue

            try:
                diff_text = self._file_diff(scope_args, filename, context_lines)
            except GitDiffError as exc:
                logging.warning("Skipping %s due to git diff error: %s", filename, exc)
                excluded.append(filename)
                continue

            size_bytes = len(diff_text.encode("utf-8"))
            priority = self._priority_for_file(
                filename, priority_ext, deprioritize_ext, drop_files
            )

            file_blobs.append((filename, diff_text, size_bytes, priority))
            included.append(filename)
            total_bytes += size_bytes

        # Early exit: nothing to review
        if not file_blobs:
            return DiffResult(text="", files_included=[], files_excluded=excluded, truncated=False, stats={"files": 0, "bytes": 0})

        # Smart truncation if over soft limit or hard limit
        truncated = False
        if total_bytes > soft_limit_kb * 1024 or total_bytes > hard_limit_kb * 1024:
            truncated = True
            # First drop explicit drop_files and deprioritized extensions
            file_blobs, dropped = self._trim_to_limit(
                file_blobs,
                soft_limit_kb * 1024,
                drop_files=drop_files,
                deprioritize_ext=deprioritize_ext,
            )
            excluded.extend(dropped)
            included = [f for f, *_ in file_blobs]

        # Build combined diff
        combined_parts: List[str] = []
        for filename, diff_text, *_ in file_blobs:
            combined_parts.append(diff_text.rstrip("\n"))
        combined = "\n\n".join(combined_parts) + ("\n" if combined_parts else "")

        stats = {
            "files": len(file_blobs),
            "bytes": sum(item[2] for item in file_blobs),
        }

        return DiffResult(
            text=combined,
            files_included=included,
            files_excluded=excluded,
            truncated=truncated,
            stats=stats,
        )

    def _priority_for_file(
        self,
        filename: str,
        priority_ext: Sequence[str],
        deprioritize_ext: Sequence[str],
        drop_files: Sequence[str],
    ) -> int:
        path = Path(filename)
        name = path.name
        ext = path.suffix.lower()

        if name in drop_files:
            return 100  # drop first
        if ext in priority_ext:
            return 0
        if ext in deprioritize_ext or name.endswith(".svg") or name.endswith(".json"):
            return 2
        return 1

    def _trim_to_limit(
        self,
        file_blobs: List[Tuple[str, str, int, int]],
        soft_limit_bytes: int,
        drop_files: Sequence[str],
        deprioritize_ext: Sequence[str],
    ) -> Tuple[List[Tuple[str, str, int, int]], List[str]]:
        # Sort with lowest priority last so they get dropped first
        sorted_blobs = sorted(file_blobs, key=lambda item: item[3])
        kept: List[Tuple[str, str, int, int]] = []
        dropped: List[str] = []
        running = 0

        for filename, diff_text, size_bytes, priority in sorted_blobs:
            if running + size_bytes <= soft_limit_bytes:
                kept.append((filename, diff_text, size_bytes, priority))
                running += size_bytes
                continue

            # Decide drop based on priority
            keep_anyway = priority == 0  # high-priority source
            if keep_anyway and running + size_bytes <= soft_limit_bytes * 1.2:
                kept.append((filename, diff_text, size_bytes, priority))
                running += size_bytes
            else:
                dropped.append(filename)

        return kept, dropped
