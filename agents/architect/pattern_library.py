from __future__ import annotations

from copy import deepcopy
from typing import Any, Dict, List, Optional

DEFAULT_PATTERNS: Dict[str, List[Dict[str, Any]]] = {
    "simple": [
        {
            "type": "service_layer",
            "usage": "Encapsulate business logic behind a thin interface.",
            "location": "{module}/service.py",
        }
    ],
    "moderate": [
        {
            "type": "service_layer",
            "usage": "Encapsulate business logic behind a thin interface.",
            "location": "{module}/service.py",
        },
        {
            "type": "repository",
            "usage": "Isolate data access from business logic.",
            "location": "{module}/repository.py",
        },
    ],
    "complex": [
        {
            "type": "service_layer",
            "usage": "Encapsulate business logic behind a thin interface.",
            "location": "{module}/service.py",
        },
        {
            "type": "repository",
            "usage": "Isolate data access from business logic.",
            "location": "{module}/repository.py",
        },
        {
            "type": "factory",
            "usage": "Construct service instances with dependencies.",
            "location": "{module}/factory.py",
        },
    ],
}


class PatternLibrary:
    """Small pattern catalog for Architect outputs."""

    def __init__(self, defaults: Optional[Dict[str, List[Dict[str, Any]]]] = None) -> None:
        self.defaults = defaults or DEFAULT_PATTERNS

    def select(self, complexity: str, modules: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Return patterns appropriate for the requested complexity level.
        The primary module name is used to render pattern locations.
        """
        key = (complexity or "moderate").lower()
        pattern_defs = self.defaults.get(key, self.defaults["moderate"])
        module_prefix = modules[0].get("name", "core") if modules else "core"

        selected: List[Dict[str, Any]] = []
        for entry in pattern_defs:
            rendered = deepcopy(entry)
            rendered["location"] = entry.get("location", "{module}/module.py").format(module=module_prefix)
            selected.append(rendered)
        return selected


__all__ = ["PatternLibrary", "DEFAULT_PATTERNS"]
