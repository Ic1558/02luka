import json
from pathlib import Path

from core.pro_docs.engine import build_doc_spec, load_rules_config
from core.pro_docs.validate import validate_project_input


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
