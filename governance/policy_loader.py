# 02luka V4 - Governance Policy Loader
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import List, Dict, Any

import yaml


DEFAULT_POLICY_PATH = Path("context/safety/gm_policy_v4.yaml")


@dataclass
class GMPolicy:
    files_changed_threshold: int
    sensitive_paths: List[str]
    file_extensions: List[str]
    critical_keywords: List[str]
    shell_keywords: List[str]


class PolicyLoader:
    def __init__(self, path: Path | str | None = None) -> None:
        self.path = Path(path) if path is not None else DEFAULT_POLICY_PATH
        # Resolve relative paths from project root
        if not self.path.is_absolute():
            # Assume we're in ~/02luka or use env var
            import os
            project_root = Path(os.getenv("LUKA_SOT", os.path.expanduser("~/02luka")))
            self.path = project_root / self.path
        self.version: str | None = None
        self.policy: GMPolicy | None = None
        self._load()

    def _load(self) -> None:
        raw = yaml.safe_load(self.path.read_text(encoding="utf-8"))
        self.version = str(raw.get("version", "unknown"))
        cfg: Dict[str, Any] = raw.get("gm_trigger_policy", {})

        self.policy = GMPolicy(
            files_changed_threshold=int(cfg.get("files_changed_threshold", 2)),
            sensitive_paths=list(cfg.get("sensitive_paths", [])),
            file_extensions=list(cfg.get("file_extensions", [])),
            critical_keywords=list(cfg.get("critical_keywords", [])),
            shell_keywords=list(cfg.get("shell_keywords", [])),
        )

    # ---- public API for Overseer ----

    def should_trigger_for_patch(
        self,
        file_paths: List[str],
        file_content_diff: str,
    ) -> bool:
        """Return True if GM advisor should be consulted for this patch."""
        p = self.policy
        if p is None:
            return False

        # multi-file threshold
        if len(file_paths) >= p.files_changed_threshold:
            return True

        # sensitive paths
        for path in file_paths:
            for sp in p.sensitive_paths:
                if sp in path:
                    return True

        # critical extensions
        for path in file_paths:
            for ext in p.file_extensions:
                if path.endswith(ext):
                    return True

        diff_lower = file_content_diff.lower()

        # critical keywords in diff
        for kw in p.critical_keywords:
            if kw.lower() in diff_lower:
                return True

        return False

    def should_trigger_for_shell(self, command: str) -> bool:
        """Return True if GM advisor should be consulted for this shell command."""
        p = self.policy
        if p is None:
            return False

        cmd_lower = command.lower()
        for kw in p.shell_keywords:
            if kw.lower() in cmd_lower:
                return True
        return False


# Legacy compatibility: Keep SafeZones and functions for backward compatibility
import os
from functools import lru_cache

CONTEXT_BASE = os.getenv("LUKA_CONTEXT_BASE", os.path.expanduser("~/02luka/context"))


@dataclass
class SafeZones:
    root_project: str
    write_allowed: List[str]
    write_denied: List[str]
    allowlist_subdirs: List[str]


@lru_cache(maxsize=1)
def load_safe_zones() -> SafeZones:
    path = os.path.join(CONTEXT_BASE, "safety", "safe_zones.yaml")
    with open(path, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f)

    return SafeZones(
        root_project=data.get("root_project", ""),
        write_allowed=data.get("write_allowed", []),
        write_denied=data.get("write_denied", []),
        allowlist_subdirs=data.get("allowlist_subdirs", []),
    )


# Legacy function for backward compatibility
@lru_cache(maxsize=1)
def load_gm_policy() -> GMPolicy:
    """Legacy function - use PolicyLoader class instead."""
    loader = PolicyLoader()
    if loader.policy is None:
        raise RuntimeError("Failed to load GM policy")
    return loader.policy
