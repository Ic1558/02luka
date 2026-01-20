import copy
import json
import subprocess
import sys
import tempfile
from pathlib import Path

from core.pro_docs.engine import build_doc_spec, load_rules_config
from core.pro_docs.utils import canonical_json_dumps
from core.pro_docs.validate import ValidationError, enforce_project_input, validate_project_input


def _load_sample() -> dict:
    sample_path = Path(__file__).resolve().parents[1] / "examples" / "sample_project.json"
    return json.loads(sample_path.read_text(encoding="utf-8"))


def test_golden_totals_and_ordering():
    config = load_rules_config()
    raw_input = _load_sample()
    report = validate_project_input(raw_input, config)
    assert report.status == "ok"

    doc_spec = build_doc_spec(raw_input, config).to_dict()
    line_items = doc_spec["sections"]["line_items"]

    assert [item["code"] for item in line_items] == [
        "design_fee",
        "site_visit",
        "3d_perspective",
        "material_sample",
    ]

    totals = doc_spec["sections"]["totals"]
    assert totals["subtotal"] == 50300.0
    assert totals["vat"] == 3521.0
    assert totals["grand_total"] == 53821.0


def test_plan_output_deterministic():
    config = load_rules_config()
    raw_input = _load_sample()

    first = canonical_json_dumps(build_doc_spec(raw_input, config).to_dict())
    second = canonical_json_dumps(build_doc_spec(raw_input, config).to_dict())

    assert first == second


def test_validate_missing_required_fields():
    config = load_rules_config()
    raw_input = {
        "project_type": "interior",
        "scope_items": [],
        "pricing_profile": "standard",
        "currency": "THB",
        "date": "2026-01-15",
    }
    report = validate_project_input(raw_input, config)
    codes = {issue.code for issue in report.errors}
    assert report.status == "error"
    assert "MISSING_FIELD" in codes
    assert "INVALID_SCOPE_ITEMS" in codes


def test_fail_closed_unknown_unit_and_negative_qty():
    config = load_rules_config()
    raw_input = {
        "project_id": "PRJ-BAD-001",
        "client_name": "Test Client",
        "project_type": "interior",
        "scope_items": [
            {
                "code": "design_fee",
                "description": "Design fee",
                "qty": -1,
                "unit": "unknown_unit",
            }
        ],
        "pricing_profile": "standard",
        "currency": "THB",
        "date": "2026-01-20",
    }

    report = validate_project_input(raw_input, config)
    codes = {issue.code for issue in report.errors}
    assert "UNIT_NOT_ALLOWED" in codes or "UNIT_MISMATCH" in codes
    assert "NON_POSITIVE_QTY" in codes

    try:
        enforce_project_input(raw_input, config)
    except ValidationError as exc:
        error_codes = {issue.code for issue in exc.report.errors}
        assert "NON_POSITIVE_QTY" in error_codes
    else:
        assert False, "ValidationError was not raised"


def test_fail_closed_missing_pricing_band():
    config = copy.deepcopy(load_rules_config())
    config["pricing"]["design_fee"]["prices"].pop("standard")
    raw_input = {
        "project_id": "PRJ-BAD-002",
        "client_name": "Test Client",
        "project_type": "interior",
        "scope_items": [
            {
                "code": "design_fee",
                "description": "Design fee",
                "qty": 1,
                "unit": "lot",
            }
        ],
        "pricing_profile": "standard",
        "currency": "THB",
        "date": "2026-01-21",
    }

    try:
        enforce_project_input(raw_input, config)
    except ValidationError as exc:
        error_codes = {issue.code for issue in exc.report.errors}
        assert "MISSING_PRICING_BAND" in error_codes
    else:
        assert False, "ValidationError was not raised"


def test_rounding_and_vat_override():
    config = load_rules_config()
    raw_input = {
        "project_id": "PRJ-ROUND-001",
        "client_name": "Test Client",
        "project_type": "interior",
        "area_sqm": 50,
        "scope_items": [
            {
                "code": "site_visit",
                "description": "Site visit",
                "qty": 1,
                "unit": "visit",
            }
        ],
        "pricing_profile": "standard",
        "currency": "THB",
        "vat_percent": 7.5,
        "date": "2026-01-16",
    }

    report = validate_project_input(raw_input, config)
    assert report.status == "ok"

    doc_spec = build_doc_spec(raw_input, config).to_dict()
    totals = doc_spec["sections"]["totals"]

    assert totals["subtotal"] == 2500.0
    assert totals["vat"] == 187.5
    assert totals["grand_total"] == 2688.0


def test_rounding_boundaries_half_up():
    config = copy.deepcopy(load_rules_config())
    config["pricing"]["rounding_probe"] = {
        "category": "service",
        "label_token": "ROUNDING_PROBE",
        "unit": "lot",
        "prices": {"budget": 1, "standard": 1, "premium": 1},
    }
    raw_input = {
        "project_id": "PRJ-ROUND-BOUNDARY",
        "client_name": "Test Client",
        "project_type": "interior",
        "scope_items": [
            {
                "code": "rounding_probe",
                "description": "Rounding 0.005",
                "qty": 0.005,
                "unit": "lot",
            },
            {
                "code": "rounding_probe",
                "description": "Rounding 0.015",
                "qty": 0.015,
                "unit": "lot",
            },
        ],
        "pricing_profile": "standard",
        "currency": "THB",
        "date": "2026-01-22",
    }

    doc_spec = build_doc_spec(raw_input, config).to_dict()
    line_items = doc_spec["sections"]["line_items"]
    assert line_items[0]["amount"] == 0.01
    assert line_items[1]["amount"] == 0.02


def test_cli_output_dir_guardrails():
    cli_path = Path(__file__).resolve().parents[1] / "g" / "tools" / "pro_docs_intake.py"
    sample_path = Path(__file__).resolve().parents[1] / "examples" / "sample_project.json"

    result = subprocess.run(
        [sys.executable, str(cli_path), "--input", str(sample_path), "--mode", "dry_run"],
        capture_output=True,
        text=True,
    )
    assert result.returncode != 0
    error_payload = json.loads(result.stdout or "{}")
    assert error_payload.get("status") == "error"

    with tempfile.TemporaryDirectory() as tmpdir:
        result = subprocess.run(
            [
                sys.executable,
                str(cli_path),
                "--input",
                str(sample_path),
                "--mode",
                "dry_run",
                "--output-dir",
                tmpdir,
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        outputs = {path.name for path in Path(tmpdir).iterdir()}
        assert "doc_spec.json" in outputs
        assert "validation.json" in outputs
        assert "audit.json" not in outputs

    with tempfile.NamedTemporaryFile() as tmpfile:
        result = subprocess.run(
            [
                sys.executable,
                str(cli_path),
                "--input",
                str(sample_path),
                "--mode",
                "apply",
                "--output-dir",
                tmpfile.name,
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode != 0
