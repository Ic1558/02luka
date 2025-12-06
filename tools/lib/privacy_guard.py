from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Sequence


@dataclass
class SecurityWarning:
    kind: str
    match: str
    context: str


class PrivacyGuard:
    """Pre-flight checks for secrets and unsafe files."""

    def __init__(
        self,
        *,
        ignore_patterns: Sequence[str],
        exclude_files: Sequence[str],
        redact_secrets: bool = True,
    ) -> None:
        self.ignore_patterns = list(ignore_patterns)
        self.exclude_files = list(exclude_files)
        self.redact_secrets = redact_secrets
        self.patterns: Dict[str, re.Pattern[str]] = {
            "aws_access_key": re.compile(r"AKIA[0-9A-Z]{16}"),
            "generic_secret": re.compile(r"(?i)(secret|token|api[_-]?key)[\\s:=\"']+[A-Za-z0-9/_\\-]{16,}"),
            "openai_key": re.compile(r"sk-[A-Za-z0-9]{20,}"),
            "gcp_service_account": re.compile(r"\"type\": \"service_account\""),
        }

    def scan_diff(self, diff_text: str) -> List[SecurityWarning]:
        warnings: List[SecurityWarning] = []
        for kind, pattern in self.patterns.items():
            for match in pattern.finditer(diff_text):
                context = diff_text[max(0, match.start() - 20) : match.end() + 20]
                warnings.append(SecurityWarning(kind=kind, match=match.group(0), context=context))
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
