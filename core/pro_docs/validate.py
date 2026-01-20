"""Validation for professional document inputs and specs."""

from __future__ import annotations

from dataclasses import dataclass, field, asdict
from typing import Any, Dict, List

from core.pro_docs.utils import ROUNDING_MODES, round_decimal, to_decimal


@dataclass
class ValidationIssue:
    code: str
    message: str
    field: str
    details: Dict[str, Any] = field(default_factory=dict)


@dataclass
class ValidationReport:
    status: str
    errors: List[ValidationIssue]
    warnings: List[ValidationIssue]

    def to_dict(self) -> Dict[str, Any]:
        return {
            "status": self.status,
            "errors": [asdict(issue) for issue in self.errors],
            "warnings": [asdict(issue) for issue in self.warnings],
        }

class ValidationError(Exception):
    def __init__(self, report: ValidationReport) -> None:
        super().__init__("Validation failed")
        self.report = report


def _add_error(errors: List[ValidationIssue], code: str, message: str, field: str, **details: Any) -> None:
    errors.append(ValidationIssue(code=code, message=message, field=field, details=details))


def _validate_config(config: Dict[str, Any]) -> ValidationReport:
    errors: List[ValidationIssue] = []
    warnings: List[ValidationIssue] = []

    if not config.get("config_version"):
        _add_error(errors, "MISSING_CONFIG", "config_version is required", "config_version")
    if not config.get("currency"):
        _add_error(errors, "MISSING_CONFIG", "currency is required", "currency")
    if not config.get("project_types"):
        _add_error(errors, "MISSING_CONFIG", "project_types is required", "project_types")
    if not config.get("pricing_profiles"):
        _add_error(errors, "MISSING_CONFIG", "pricing_profiles is required", "pricing_profiles")
    if config.get("vat_default_percent") is None:
        _add_error(errors, "MISSING_VAT_PROFILE", "vat_default_percent is required", "vat_default_percent")

    rounding = config.get("rounding")
    if not isinstance(rounding, dict):
        _add_error(errors, "MISSING_ROUNDING_RULE", "rounding config is required", "rounding")
    else:
        required_keys = [
            "mode",
            "unit_price_decimals",
            "line_amount_decimals",
            "subtotal_decimals",
            "vat_decimals",
            "grand_total_decimals",
        ]
        for key in required_keys:
            if key not in rounding:
                _add_error(errors, "MISSING_ROUNDING_RULE", f"rounding.{key} is required", f"rounding.{key}")
        mode = rounding.get("mode")
        if mode and mode not in ROUNDING_MODES:
            _add_error(errors, "INVALID_ROUNDING_MODE", "rounding.mode is invalid", "rounding.mode", value=mode)

    pricing_table = config.get("pricing")
    if not isinstance(pricing_table, dict) or not pricing_table:
        _add_error(errors, "MISSING_CONFIG", "pricing table is required", "pricing")

    status = "error" if errors else "ok"
    return ValidationReport(status=status, errors=errors, warnings=warnings)


def validate_project_input(raw_input: Dict[str, Any], config: Dict[str, Any]) -> ValidationReport:
    errors: List[ValidationIssue] = []
    warnings: List[ValidationIssue] = []

    config_report = _validate_config(config)
    errors.extend(config_report.errors)
    warnings.extend(config_report.warnings)
    if config_report.errors:
        return ValidationReport(status="error", errors=errors, warnings=warnings)

    required_fields = [
        "project_id",
        "project_type",
        "scope_items",
        "pricing_profile",
        "currency",
        "date",
    ]
    for field_name in required_fields:
        if field_name not in raw_input or raw_input[field_name] in (None, ""):
            _add_error(errors, "MISSING_FIELD", f"Missing required field: {field_name}", field_name)

    scope_items = raw_input.get("scope_items")
    if scope_items is None:
        return ValidationReport(status="error", errors=errors, warnings=warnings)
    if not isinstance(scope_items, list) or not scope_items:
        _add_error(errors, "INVALID_SCOPE_ITEMS", "Scope items must be a non-empty list", "scope_items")
        return ValidationReport(status="error", errors=errors, warnings=warnings)

    project_type = str(raw_input.get("project_type", "")).strip().lower()
    if project_type and project_type not in config.get("project_types", []):
        _add_error(errors, "INVALID_PROJECT_TYPE", "Unsupported project_type", "project_type", value=project_type)

    pricing_profile = str(raw_input.get("pricing_profile", "")).strip().lower()
    if pricing_profile and pricing_profile not in config.get("pricing_profiles", []):
        _add_error(errors, "INVALID_PRICING_PROFILE", "Unsupported pricing_profile", "pricing_profile", value=pricing_profile)

    currency = str(raw_input.get("currency", "")).strip().upper()
    if currency and currency != str(config.get("currency", "")).upper():
        _add_error(errors, "INVALID_CURRENCY", "Unsupported currency", "currency", value=currency)

    vat_percent = raw_input.get("vat_percent")
    if vat_percent is not None:
        try:
            vat_value = to_decimal(vat_percent)
        except Exception:
            _add_error(errors, "INVALID_NUMBER", "vat_percent must be numeric", "vat_percent")
        else:
            if vat_value < 0 or vat_value > 100:
                _add_error(errors, "INVALID_VAT", "vat_percent must be between 0 and 100", "vat_percent")

    area_sqm = raw_input.get("area_sqm")
    if area_sqm is not None:
        try:
            area_value = to_decimal(area_sqm)
        except Exception:
            _add_error(errors, "INVALID_NUMBER", "area_sqm must be numeric", "area_sqm")
        else:
            if area_value < 0:
                _add_error(errors, "NEGATIVE_VALUE", "area_sqm must be non-negative", "area_sqm")

    allowed_units = set(config.get("unit_rules", {}).get("allowed_units", []))
    pricing_table = config.get("pricing", {})

    for index, item in enumerate(scope_items):
        field_prefix = f"scope_items[{index}]"
        if not isinstance(item, dict):
            _add_error(errors, "INVALID_SCOPE_ITEM", "Scope item must be an object", field_prefix)
            continue

        code = str(item.get("code", "")).strip().lower()
        if not code:
            _add_error(errors, "MISSING_FIELD", "Scope item code is required", f"{field_prefix}.code")
            continue

        pricing_entry = pricing_table.get(code)
        if not pricing_entry:
            _add_error(
                errors,
                "CODE_NOT_FOUND",
                "Scope item code not found in pricing table",
                f"{field_prefix}.code",
                code=code,
            )
            continue
        prices = pricing_entry.get("prices")
        if not isinstance(prices, dict) or pricing_profile not in prices:
            _add_error(
                errors,
                "MISSING_PRICING_BAND",
                "Pricing band missing for scope item",
                f"{field_prefix}.code",
                code=code,
                pricing_profile=pricing_profile,
            )
            continue

        description = str(item.get("description", "")).strip()
        if not description:
            _add_error(errors, "MISSING_FIELD", "Scope item description is required", f"{field_prefix}.description")

        unit = str(item.get("unit", "")).strip().lower()
        if not unit:
            _add_error(errors, "MISSING_FIELD", "Scope item unit is required", f"{field_prefix}.unit")
        elif allowed_units and unit not in allowed_units:
            _add_error(
                errors,
                "UNIT_NOT_ALLOWED",
                "Scope item unit is not in allowed units",
                f"{field_prefix}.unit",
                unit=unit,
            )
        else:
            expected_unit = pricing_entry.get("unit")
            if expected_unit and unit != expected_unit:
                _add_error(
                    errors,
                    "UNIT_MISMATCH",
                    "Scope item unit does not match configured unit",
                    f"{field_prefix}.unit",
                    unit=unit,
                    expected=expected_unit,
                )

        qty = item.get("qty")
        try:
            qty_value = to_decimal(qty)
        except Exception:
            _add_error(errors, "INVALID_NUMBER", "Scope item qty must be numeric", f"{field_prefix}.qty")
        else:
            if qty_value <= 0:
                _add_error(errors, "NON_POSITIVE_QTY", "Scope item qty must be > 0", f"{field_prefix}.qty")

    status = "error" if errors else "ok"
    return ValidationReport(status=status, errors=errors, warnings=warnings)


def _float_equal(left: Any, right: Any, decimals: int, mode: str) -> bool:
    left_value = round_decimal(left, decimals, mode)
    right_value = round_decimal(right, decimals, mode)
    return left_value == right_value


def validate_doc_spec(doc_spec: Dict[str, Any], config: Dict[str, Any]) -> ValidationReport:
    errors: List[ValidationIssue] = []
    warnings: List[ValidationIssue] = []

    if not isinstance(doc_spec, dict):
        _add_error(errors, "INVALID_DOC_SPEC", "Doc spec must be a JSON object", "doc_spec")
        return ValidationReport(status="error", errors=errors, warnings=warnings)

    sections = doc_spec.get("sections")
    if not isinstance(sections, dict):
        _add_error(errors, "MISSING_FIELD", "sections is required", "sections")
        return ValidationReport(status="error", errors=errors, warnings=warnings)

    summary = sections.get("summary")
    line_items = sections.get("line_items")
    totals = sections.get("totals")

    if not isinstance(summary, dict):
        _add_error(errors, "MISSING_FIELD", "summary section is required", "sections.summary")
    if not isinstance(line_items, list):
        _add_error(errors, "MISSING_FIELD", "line_items section is required", "sections.line_items")
    if not isinstance(totals, dict):
        _add_error(errors, "MISSING_FIELD", "totals section is required", "sections.totals")

    if errors:
        return ValidationReport(status="error", errors=errors, warnings=warnings)

    rounding = config["rounding"]
    mode = rounding["mode"]

    amounts = []
    for index, item in enumerate(line_items):
        if not isinstance(item, dict):
            _add_error(errors, "INVALID_LINE_ITEM", "Line item must be an object", f"sections.line_items[{index}]")
            continue
        qty = item.get("qty")
        unit_price = item.get("unit_price")
        amount = item.get("amount")
        if qty is None or unit_price is None or amount is None:
            _add_error(
                errors,
                "MISSING_FIELD",
                "Line item qty, unit_price, and amount are required",
                f"sections.line_items[{index}]",
            )
            continue
        expected_amount = round_decimal(
            to_decimal(qty) * to_decimal(unit_price),
            rounding["line_amount_decimals"],
            mode,
        )
        if not _float_equal(expected_amount, amount, rounding["line_amount_decimals"], mode):
            _add_error(
                errors,
                "ROUNDING_POLICY_VIOLATION",
                "Line item amount does not match rounding policy",
                f"sections.line_items[{index}].amount",
                expected=float(expected_amount),
                actual=amount,
            )
        amounts.append(to_decimal(amount))

    if errors:
        return ValidationReport(status="error", errors=errors, warnings=warnings)

    subtotal = round_decimal(sum(amounts), rounding["subtotal_decimals"], mode)
    vat_percent = summary.get("vat_percent")
    if vat_percent is None:
        _add_error(errors, "MISSING_FIELD", "vat_percent is required for totals validation", "sections.summary.vat_percent")
        return ValidationReport(status="error", errors=errors, warnings=warnings)

    vat = round_decimal(subtotal * to_decimal(vat_percent) / to_decimal(100), rounding["vat_decimals"], mode)
    grand_total = round_decimal(subtotal + vat, rounding["grand_total_decimals"], mode)

    if not _float_equal(subtotal, totals.get("subtotal"), rounding["subtotal_decimals"], mode):
        _add_error(
            errors,
            "TOTAL_MISMATCH",
            "Subtotal does not match line item sum",
            "sections.totals.subtotal",
            expected=float(subtotal),
            actual=totals.get("subtotal"),
        )
    if not _float_equal(vat, totals.get("vat"), rounding["vat_decimals"], mode):
        _add_error(
            errors,
            "TOTAL_MISMATCH",
            "VAT total does not match expected value",
            "sections.totals.vat",
            expected=float(vat),
            actual=totals.get("vat"),
        )
    if not _float_equal(grand_total, totals.get("grand_total"), rounding["grand_total_decimals"], mode):
        _add_error(
            errors,
            "TOTAL_MISMATCH",
            "Grand total does not match expected value",
            "sections.totals.grand_total",
            expected=float(grand_total),
            actual=totals.get("grand_total"),
        )

    status = "error" if errors else "ok"
    return ValidationReport(status=status, errors=errors, warnings=warnings)


def enforce_project_input(raw_input: Dict[str, Any], config: Dict[str, Any]) -> None:
    report = validate_project_input(raw_input, config)
    if report.errors:
        raise ValidationError(report)


def enforce_doc_spec(doc_spec: Dict[str, Any], config: Dict[str, Any]) -> None:
    report = validate_doc_spec(doc_spec, config)
    if report.errors:
        raise ValidationError(report)
