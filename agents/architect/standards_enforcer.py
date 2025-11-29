from __future__ import annotations

from copy import deepcopy
from typing import Any, Dict, List

DEFAULT_STANDARDS: Dict[str, Any] = {
    "naming": {
        "classes": "PascalCase",
        "functions": "snake_case",
        "constants": "UPPER_SNAKE_CASE",
        "files": "snake_case",
    },
    "error_handling": {
        "strategy": "raise_custom_exceptions",
        "base_exception": "AppException",
    },
    "testing": {
        "framework": "pytest",
        "coverage_min": 80,
        "test_location": "tests/",
    },
    "documentation": {"docstring_style": "google", "required_for": ["classes", "public_functions"]},
}


class StandardsEnforcer:
    """Builds standards and QA checklist entries to accompany Architect specs."""

    def __init__(self, standards: Dict[str, Any] | None = None) -> None:
        self.standards = standards or DEFAULT_STANDARDS

    def build_standards(self, complexity: str) -> Dict[str, Any]:
        payload = deepcopy(self.standards)
        if complexity.lower() == "complex":
            payload["testing"]["coverage_min"] = 85
        return payload

    def build_qa_checklist(self, patterns: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        pattern_types = [p.get("type", "pattern") for p in patterns] or ["pattern"]
        pattern_desc = ", ".join(sorted(set(pattern_types)))
        return [
            {
                "id": "struct_001",
                "description": "Modules and files follow architected structure",
                "type": "structure_check",
                "required": True,
            },
            {
                "id": "pattern_001",
                "description": f"Patterns applied: {pattern_desc}",
                "type": "pattern_check",
                "required": True,
            },
            {
                "id": "std_001",
                "description": "Naming and error-handling standards applied",
                "type": "standards_check",
                "required": True,
            },
            {
                "id": "test_001",
                "description": "Tests exist and pass",
                "type": "automated_test",
                "command": "pytest",
                "required": True,
            },
        ]


__all__ = ["StandardsEnforcer", "DEFAULT_STANDARDS"]
