#!/usr/bin/env python3
"""Professional document intake CLI (rules-only)."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Dict

from core.pro_docs.engine import build_doc_spec, load_rules_config
from core.pro_docs.utils import canonical_json_dumps
from core.pro_docs.validate import (
    ValidationError,
    ValidationIssue,
    ValidationReport,
    validate_doc_spec,
    validate_project_input,
)


def _load_input(path: str | None, use_stdin: bool) -> Dict[str, Any]:
    if use_stdin:
        return json.load(sys.stdin)
    if not path:
        raise ValueError("--input is required when not using --stdin")
    input_path = Path(path)
    with input_path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def _merge_reports(primary: ValidationReport, secondary: ValidationReport) -> ValidationReport:
    errors = list(primary.errors) + list(secondary.errors)
    warnings = list(primary.warnings) + list(secondary.warnings)
    status = "error" if errors else "ok"
    return ValidationReport(status=status, errors=errors, warnings=warnings)


def _error_report(code: str, message: str, field: str) -> ValidationReport:
    issue = ValidationIssue(code=code, message=message, field=field, details={})
    return ValidationReport(status="error", errors=[issue], warnings=[])


def _resolve_output_dir(path: str | None) -> Path:
    if not path:
        raise ValueError("output_dir is required for dry_run/apply")
    output_dir = Path(path).expanduser().resolve()
    if output_dir.exists() and not output_dir.is_dir():
        raise ValueError("output_dir must be a directory")
    output_dir.mkdir(parents=True, exist_ok=True)
    return output_dir


def _safe_output_path(output_dir: Path, filename: str) -> Path:
    target = (output_dir / filename).resolve()
    try:
        target.relative_to(output_dir)
    except ValueError as exc:
        raise ValueError("output path escapes output_dir") from exc
    return target


def _write_outputs(doc_spec: Dict[str, Any], validation: Dict[str, Any], output_dir: Path, include_audit: bool) -> None:
    doc_path = _safe_output_path(output_dir, "doc_spec.json")
    validation_path = _safe_output_path(output_dir, "validation.json")
    doc_path.write_text(canonical_json_dumps(doc_spec), encoding="utf-8")
    validation_path.write_text(canonical_json_dumps(validation), encoding="utf-8")
    if include_audit:
        audit_path = _safe_output_path(output_dir, "audit.json")
        audit_path.write_text(canonical_json_dumps(doc_spec.get("audit", {})), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Professional document rules intake")
    input_group = parser.add_mutually_exclusive_group(required=True)
    input_group.add_argument("--input", help="Path to input JSON")
    input_group.add_argument("--stdin", action="store_true", help="Read input JSON from stdin")
    parser.add_argument("--mode", choices=["plan", "dry_run", "apply"], default="plan")
    parser.add_argument("--output-dir", help="Output directory for dry_run/apply JSON artifacts")
    parser.add_argument(
        "--output",
        choices=["doc_spec", "validation"],
        default="doc_spec",
        help="Select JSON output type",
    )
    args = parser.parse_args()

    if args.mode in {"dry_run", "apply"} and not args.output_dir:
        report = _error_report("MISSING_OUTPUT_DIR", "output_dir is required for dry_run/apply", "output_dir")
        print(canonical_json_dumps(report.to_dict()))
        return 1

    output_dir = None
    if args.mode in {"dry_run", "apply"}:
        try:
            output_dir = _resolve_output_dir(args.output_dir)
        except ValueError as exc:
            report = _error_report("INVALID_OUTPUT_DIR", str(exc), "output_dir")
            print(canonical_json_dumps(report.to_dict()))
            return 1

    raw_input = _load_input(args.input, args.stdin)
    config = load_rules_config()

    input_report = validate_project_input(raw_input, config)
    if input_report.errors:
        print(canonical_json_dumps(input_report.to_dict()))
        return 1

    try:
        doc_spec = build_doc_spec(raw_input, config).to_dict()
    except ValidationError as exc:
        print(canonical_json_dumps(exc.report.to_dict()))
        return 1

    output_report = validate_doc_spec(doc_spec, config)
    validation_report = _merge_reports(input_report, output_report)

    if args.mode in {"dry_run", "apply"}:
        _write_outputs(
            doc_spec,
            validation_report.to_dict(),
            output_dir=output_dir,
            include_audit=args.mode == "apply",
        )

    if args.output == "validation":
        print(canonical_json_dumps(validation_report.to_dict()))
    else:
        print(canonical_json_dumps(doc_spec))

    return 0 if validation_report.status == "ok" else 1


if __name__ == "__main__":
    raise SystemExit(main())
