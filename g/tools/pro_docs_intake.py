#!/usr/bin/env python3
"""Professional document intake CLI (rules-only)."""

from __future__ import annotations

import argparse
import json
import sys
import tempfile
from pathlib import Path
from typing import Any, Dict

from core.pro_docs.engine import build_doc_spec, load_rules_config
from core.pro_docs.validate import ValidationReport, validate_doc_spec, validate_project_input


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


def _write_temp_outputs(doc_spec: Dict[str, Any], validation: Dict[str, Any]) -> None:
    temp_dir = Path(tempfile.mkdtemp(prefix="pro_docs_"))
    (temp_dir / "doc_spec.json").write_text(json.dumps(doc_spec, indent=2, sort_keys=True), encoding="utf-8")
    (temp_dir / "validation.json").write_text(json.dumps(validation, indent=2, sort_keys=True), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Professional document rules intake")
    input_group = parser.add_mutually_exclusive_group(required=True)
    input_group.add_argument("--input", help="Path to input JSON")
    input_group.add_argument("--stdin", action="store_true", help="Read input JSON from stdin")
    parser.add_argument("--mode", choices=["plan", "dry_run", "apply"], default="plan")
    parser.add_argument(
        "--output",
        choices=["doc_spec", "validation"],
        default="doc_spec",
        help="Select JSON output type",
    )
    args = parser.parse_args()

    raw_input = _load_input(args.input, args.stdin)
    config = load_rules_config()

    input_report = validate_project_input(raw_input, config)
    if input_report.errors:
        print(json.dumps(input_report.to_dict(), indent=2, sort_keys=True))
        return 1

    doc_spec = build_doc_spec(raw_input, config).to_dict()
    output_report = validate_doc_spec(doc_spec, config)
    validation_report = _merge_reports(input_report, output_report)

    if args.mode in {"dry_run", "apply"}:
        _write_temp_outputs(doc_spec, validation_report.to_dict())

    if args.output == "validation":
        print(json.dumps(validation_report.to_dict(), indent=2, sort_keys=True))
    else:
        print(json.dumps(doc_spec, indent=2, sort_keys=True))

    return 0 if validation_report.status == "ok" else 1


if __name__ == "__main__":
    raise SystemExit(main())
