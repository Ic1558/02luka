# Professional Rules Engine (Phase 2)

This module produces deterministic JSON document specs for professional quotation/invoice workflows. It does **not** render templates and does **not** write to production outputs.

## Location
- Rules engine: `core/pro_docs/`
- CLI: `g/tools/pro_docs_intake.py`
- Config: `core/pro_docs/rules_config.yaml`

## Input Contract (minimum)
ProjectInput (JSON):
- `project_id` (string)
- `client_name` (optional string)
- `project_type` (`interior|renovation|construction|consulting`)
- `area_sqm` (optional number)
- `scope_items[]`: `{code, description, qty, unit}`
- `pricing_profile` (`budget|standard|premium`)
- `currency` (`THB`)
- `vat_percent` (optional number; overrides default if present)
- `date` (ISO string)

## Output Contract
DocSpec:
- `meta`: `{project_id, generated_at, version}`
- `sections.summary`: project metadata + `vat_percent`
- `sections.line_items[]`: `{code, description, qty, unit, unit_price, amount, category}`
- `sections.totals`: `{subtotal, vat, grand_total}`
- `audit`: `{applied_rules[], inputs_hash, config_version}`
- `warnings[]`

Notes:
- `generated_at` uses the input `date` for deterministic output.
- `description` is sourced from input or the configured token if blank.

## Rules (baseline)
- Unit price lookup is strictly `code + pricing_profile` in `rules_config.yaml`.
- Missing codes fail validation (no fallback).
- Rounding policy is configured and applied per-unit, per-line, and totals.
- VAT is configured with optional override only when `vat_percent` is explicitly provided.

## CLI
- Plan (no writes):
  - `python g/tools/pro_docs_intake.py --input examples/sample_project.json --mode plan`
- Dry-run (writes to temp only):
  - `python g/tools/pro_docs_intake.py --input examples/sample_project.json --mode dry_run`
- Apply (writes to temp only for now):
  - `python g/tools/pro_docs_intake.py --input examples/sample_project.json --mode apply`
- Validation output:
  - `python g/tools/pro_docs_intake.py --input examples/sample_project.json --mode plan --output validation`

The CLI prints **JSON only**. On validation errors, it prints the validation report and exits non-zero.

## Tests
- `python -m pytest -q tests/test_pro_docs_engine.py`
