from __future__ import annotations

import json
import logging
from dataclasses import dataclass, field
from typing import Any, Dict, List, Sequence

from tools.lib.local_review_llm import LLMClient, LLMError


@dataclass
class Issue:
    file: str
    line: int
    severity: str
    category: str
    description: str
    suggestion: str = ""


@dataclass
class ReviewResult:
    summary: str
    issues: List[Issue] = field(default_factory=list)
    metrics: Dict[str, Any] = field(default_factory=dict)

    @property
    def counts(self) -> Dict[str, int]:
        counts: Dict[str, int] = {"critical": 0, "warning": 0, "suggestion": 0, "info": 0}
        for issue in self.issues:
            severity = issue.severity.lower()
            if severity in counts:
                counts[severity] += 1
        return counts


class ReviewEngine:
    """Handles prompt construction and response parsing."""

    def __init__(self, llm: LLMClient, *, focus_areas: Sequence[str]) -> None:
        self.llm = llm
        self.focus_areas = focus_areas

    def analyze_diff(self, diff_text: str, context: str = "") -> ReviewResult:
        system_prompt = self._system_prompt()
        user_prompt = self._user_prompt(diff_text, context)
        payload = self.llm.complete(system_prompt, user_prompt)
        return self._parse_response(payload)

    def _system_prompt(self) -> str:
        return (
            "You are an expert senior software engineer performing a code review. "
            "Your goal is to catch bugs, security vulnerabilities, and performance issues. "
            "Be concise and output valid JSON."
        )

    def _user_prompt(self, diff_text: str, context: str) -> str:
        focus = ", ".join(self.focus_areas)
        return (
            f"Review the following git diff.\n"
            f"Context: {context}\n"
            f"Focus Areas: {focus}\n\n"
            f"DIFF:\n{diff_text}"
        )

    def _parse_response(self, payload: Dict[str, Any]) -> ReviewResult:
        if not isinstance(payload, dict):
            raise LLMError("LLM response is not a JSON object")

        summary = payload.get("summary") or "No summary provided"
        raw_issues = payload.get("issues") or []
        issues: List[Issue] = []
        for item in raw_issues:
            if not isinstance(item, dict):
                continue
            issues.append(
                Issue(
                    file=str(item.get("file", "")),
                    line=int(item.get("line") or 0),
                    severity=str(item.get("severity", "info")),
                    category=str(item.get("category", "")),
                    description=str(item.get("description", "")),
                    suggestion=str(item.get("suggestion", "")),
                )
            )
        metrics = payload.get("metrics") or {}
        logging.debug("Parsed %s issues from LLM response", len(issues))
        return ReviewResult(summary=summary, issues=issues, metrics=metrics)


def build_offline_result(summary: str = "Offline mode (no LLM call)") -> ReviewResult:
    return ReviewResult(summary=summary, issues=[], metrics={})
