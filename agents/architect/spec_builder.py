from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Dict, List


@dataclass
class ArchitectSpec:
    requirement_id: str
    structure: Dict[str, Any]
    patterns: List[Dict[str, Any]]
    standards: Dict[str, Any]
    qa_checklist: List[Dict[str, Any]]


class SpecBuilder:
    """
    Build a stable ArchitectSpec object from raw architect analysis.
    Future work: enforce schema and defaults against the shared contract.
    """

    def build_spec(self, analysis: Dict[str, Any]) -> ArchitectSpec:
        requirement_id = analysis.get("requirement_id", "UNKNOWN")
        return ArchitectSpec(
            requirement_id=requirement_id,
            structure=analysis.get("architecture", {}).get("structure", analysis.get("structure", {})),
            patterns=analysis.get("architecture", {}).get("patterns", analysis.get("patterns", [])),
            standards=analysis.get("architecture", {}).get("standards", analysis.get("standards", {})),
            qa_checklist=analysis.get("qa_checklist", []),
        )


__all__ = ["SpecBuilder", "ArchitectSpec"]
