from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Dict, List

from .pattern_library import PatternLibrary
from .standards_enforcer import StandardsEnforcer


class ArchitectAgent:
    """
    Minimal Architect agent that turns requirements into an ArchitectSpec
    aligned with the lac_v4 contract. Generates structure, patterns, standards,
    and a QA checklist that developers and QA can consume.
    """

    def __init__(self, pattern_library: PatternLibrary | None = None, standards_enforcer: StandardsEnforcer | None = None) -> None:
        self.pattern_library = pattern_library or PatternLibrary()
        self.standards_enforcer = standards_enforcer or StandardsEnforcer()

    def design(self, requirement: Dict[str, Any]) -> Dict[str, Any]:
        requirement_id = requirement.get("wo_id") or requirement.get("requirement_id") or "UNKNOWN"
        feature_name = requirement.get("feature_name") or requirement.get("objective") or "feature"
        complexity = (requirement.get("complexity") or "moderate").lower()

        slug = self._slugify(feature_name)
        modules = self._propose_modules(slug)
        patterns = self.pattern_library.select(complexity, modules)
        standards = self.standards_enforcer.build_standards(complexity)
        qa_checklist = self.standards_enforcer.build_qa_checklist(patterns)

        spec = {
            "spec_version": "1.0",
            "requirement_id": requirement_id,
            "created_by": "architect_agent",
            "created_at": datetime.now(timezone.utc).isoformat(),
            "architecture": {
                "structure": {"modules": modules},
                "patterns": patterns,
                "standards": standards,
            },
            "qa_checklist": qa_checklist,
        }

        examples = self._generate_examples(patterns)
        if examples:
            spec["examples"] = {"pattern_examples": examples}
        if requirement.get("notes"):
            spec["notes"] = requirement["notes"]

        return spec

    def _propose_modules(self, slug: str) -> List[Dict[str, Any]]:
        core_module = {
            "name": f"{slug}_core",
            "purpose": "Core business logic",
            "files": [f"{slug}/service.py", f"{slug}/models.py"],
            "interfaces": [f"{slug.title()}Service"],
        }
        api_module = {
            "name": "api",
            "purpose": "API layer and schemas",
            "files": [f"api/{slug}_routes.py", f"api/{slug}_schemas.py"],
            "interfaces": ["HTTP"],
        }
        return [core_module, api_module]

    def _slugify(self, value: str) -> str:
        cleaned = "".join([ch.lower() if ch.isalnum() else "_" for ch in value])
        cleaned = "_".join([piece for piece in cleaned.split("_") if piece])
        return cleaned or "feature"

    def _generate_examples(self, patterns: List[Dict[str, Any]]) -> Dict[str, str]:
        examples: Dict[str, str] = {}
        for pattern in patterns:
            if pattern.get("type") == "service_layer":
                examples["service_layer"] = (
                    "class Service:\n"
                    "    def __init__(self, repository):\n"
                    "        self._repository = repository\n\n"
                    "    def execute(self, payload):\n"
                    "        return self._repository.save(payload)\n"
                )
            if pattern.get("type") == "repository":
                examples["repository"] = (
                    "class Repository:\n"
                    "    def save(self, payload):\n"
                    "        raise NotImplementedError\n"
                )
        return examples


__all__ = ["ArchitectAgent"]
