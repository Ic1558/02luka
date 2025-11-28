from __future__ import annotations

from typing import Any, Dict, List


def validate_architect_spec(spec: Dict[str, Any] | None) -> bool:
    if not isinstance(spec, dict):
        return False
    architecture = spec.get("architecture") or {}
    structure = architecture.get("structure") or {}
    modules = structure.get("modules")
    patterns = architecture.get("patterns")
    return bool(isinstance(modules, list) and modules and isinstance(patterns, list) and patterns)


def summarize_architect_spec(spec: Dict[str, Any] | None) -> str:
    if not validate_architect_spec(spec):
        return ""

    architecture = spec.get("architecture") or {}
    structure = architecture.get("structure") or {}
    modules: List[Dict[str, Any]] = structure.get("modules", [])
    patterns: List[Dict[str, Any]] = architecture.get("patterns", [])
    standards = architecture.get("standards") or {}

    module_parts = []
    for module in modules:
        name = module.get("name", "module")
        files = module.get("files", []) or []
        module_parts.append(f"{name}: {', '.join(files[:3])}")

    pattern_parts = [f"{p.get('type', 'pattern')}@{p.get('location', '')}" for p in patterns]

    naming = standards.get("naming", {})
    testing = standards.get("testing", {})
    standards_lines = []
    if naming:
        standards_lines.append(
            f"Naming(classes={naming.get('classes')}, functions={naming.get('functions')}, constants={naming.get('constants')})"
        )
    if testing:
        standards_lines.append(
            f"Testing(framework={testing.get('framework')}, coverage_min={testing.get('coverage_min')})"
        )

    lines = []
    if module_parts:
        lines.append("Modules: " + "; ".join(module_parts))
    if pattern_parts:
        lines.append("Patterns: " + ", ".join(pattern_parts))
    if standards_lines:
        lines.append("Standards: " + "; ".join(standards_lines))

    return "\n".join(lines)


__all__ = ["validate_architect_spec", "summarize_architect_spec"]
