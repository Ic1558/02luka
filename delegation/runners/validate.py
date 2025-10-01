"""Response validation using JSON Schema."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict, Iterable, Tuple

try:
    import jsonschema
except ModuleNotFoundError:  # pragma: no cover - fallback when dependency missing
    jsonschema = None  # type: ignore[assignment]


class SchemaValidationError(Exception):
    """Raised when a response payload fails schema validation."""

    def __init__(self, errors: Iterable[str]):
        message = "; ".join(errors)
        super().__init__(message)
        self.errors = list(errors)


def load_schema(path: Path) -> Dict[str, Any]:
    """Load the JSON schema from *path*."""

    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def validate_response(payload: Dict[str, Any], schema: Dict[str, Any]) -> None:
    """Validate *payload* against *schema* or raise :class:`SchemaValidationError`."""

    if jsonschema is None:
        missing = tuple(sorted(schema.get("required", [])))
        errors = [key for key in missing if key not in payload]
        if errors:
            raise SchemaValidationError([f"Missing keys: {', '.join(errors)}"])
        return

    validator = jsonschema.Draft202012Validator(schema)
    errors = [error.message for error in validator.iter_errors(payload)]
    if errors:
        raise SchemaValidationError(errors)


def schema_error_summary(errors: Iterable[str]) -> str:
    """Return a newline-delimited summary of schema errors."""

    return "\n".join(errors)


__all__ = [
    "SchemaValidationError",
    "load_schema",
    "schema_error_summary",
    "validate_response",
]
