from __future__ import annotations

import fnmatch
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Sequence


@dataclass
class SecretAllowlist:
    file_patterns: List[str]
    content_patterns: List[str]
    file_paths: List[str]
    safe_patterns: List[str]

    def is_allowed(self, line: str, *, file_path: Optional[str]) -> bool:
        # Safe patterns: always allow
        for pattern in self.safe_patterns:
            if re.search(pattern, line, re.IGNORECASE):
                return True

        # Content patterns
        for pattern in self.content_patterns:
            if re.search(pattern, line, re.IGNORECASE):
                return True

        # File path / pattern checks
        if file_path:
            norm = file_path
            for pattern in self.file_patterns:
                if fnmatch.fnmatch(norm, pattern):
                    return True
            for path in self.file_paths:
                if Path(norm) == Path(path):
                    return True
        return False


@dataclass
class SecurityWarning:
    kind: str
    match: str
    context: str
    file: Optional[str] = None
    line: Optional[int] = None


class PrivacyGuard:
    """Pre-flight checks for secrets and unsafe files."""

    def __init__(
        self,
        *,
        ignore_patterns: Sequence[str],
        exclude_files: Sequence[str],
        redact_secrets: bool = True,
        allowlist: Optional[SecretAllowlist] = None,
    ) -> None:
        self.ignore_patterns = list(ignore_patterns)
        self.exclude_files = list(exclude_files)
        self.redact_secrets = redact_secrets
        self.allowlist = allowlist
        self.patterns: Dict[str, re.Pattern[str]] = {
            "aws_access_key": re.compile(r"AKIA[0-9A-Z]{16}"),
            "generic_secret": re.compile(r"(?i)(secret|token|api[_-]?key)[\\s:=\"']+[A-Za-z0-9/_\\-]{16,}"),
            "openai_key": re.compile(r"sk-[A-Za-z0-9]{20,}"),
            "gcp_service_account": re.compile(r"\"type\": \"service_account\""),
        }

    def scan_diff(self, diff_text: str) -> List[SecurityWarning]:
        """Scan unified diff text for secrets; respects allowlist and per-file context."""
        warnings: List[SecurityWarning] = []
        current_file: Optional[str] = None
        for idx, raw_line in enumerate(diff_text.splitlines(), 1):
            # Track current file from diff headers
            if raw_line.startswith("+++ "):
                path = raw_line[4:].strip()
                if path != "/dev/null":
                    current_file = path[2:] if path.startswith("b/") else path
                else:
                    current_file = None
                continue
            if raw_line.startswith("--- "):
                continue
            if raw_line.startswith("@@"):
                continue

            # Strip diff prefix
            content = raw_line
            if raw_line[:1] in {"+", "-", " "} and not raw_line.startswith(("+++", "---")):
                content = raw_line[1:]

            # Allowlist check
            if self.allowlist and self.allowlist.is_allowed(content, file_path=current_file):
                continue

            for kind, pattern in self.patterns.items():
                for match in pattern.finditer(content):
                    context = content[max(0, match.start() - 20) : match.end() + 20]
                    warnings.append(
                        SecurityWarning(
                            kind=kind,
                            match=match.group(0),
                            context=context,
                            file=current_file,
                            line=idx,
                        )
                    )
        return warnings

    def is_safe_file(self, filename: str) -> bool:
        path = Path(filename)
        name = path.name
        lowered = name.lower()
        if any(self._match_pattern(filename, pat) for pat in self.exclude_files):
            return False
        if lowered.endswith((".pem", ".key", ".p12", ".crt", ".der")):
            return False
        if lowered.endswith((".png", ".jpg", ".jpeg", ".gif", ".pdf", ".zip", ".tar", ".gz")):
            return False
        return True

    @staticmethod
    def _match_pattern(path: str, pattern: str) -> bool:
        return Path(path).match(pattern)
