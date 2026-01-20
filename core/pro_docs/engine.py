"""Deterministic rules engine for professional document specs."""

from __future__ import annotations

from pathlib import Path
from typing import Any, Dict, List, Optional

import yaml

from core.pro_docs.audit import build_audit_trail, new_audit_entry, audit_to_dict
from core.pro_docs.schema import DocSpec, LineItem, ProjectInput, ProjectScopeItem, Totals
from core.pro_docs.utils import ENGINE_VERSION, round_decimal, sha256_digest, to_decimal
from core.pro_docs.validate import enforce_doc_spec, enforce_project_input


def load_rules_config(path: Optional[Path] = None) -> Dict[str, Any]:
    config_path = path or Path(__file__).with_name("rules_config.yaml")
    with config_path.open("r", encoding="utf-8") as handle:
        return yaml.safe_load(handle)


def normalize_project_input(raw_input: Dict[str, Any]) -> ProjectInput:
    scope_items: List[ProjectScopeItem] = []
    for item in raw_input["scope_items"]:
        scope_items.append(
            ProjectScopeItem(
                code=str(item["code"]).strip().lower(),
                description=str(item.get("description", "")).strip(),
                qty=to_decimal(item["qty"]),
                unit=str(item["unit"]).strip().lower(),
            )
        )

    client_name = raw_input.get("client_name")
    client_name = str(client_name).strip() if client_name else None

    area_sqm = raw_input.get("area_sqm")
    area_sqm_value = to_decimal(area_sqm) if area_sqm is not None else None

    vat_percent = raw_input.get("vat_percent")
    vat_value = to_decimal(vat_percent) if vat_percent is not None else None

    return ProjectInput(
        project_id=str(raw_input["project_id"]).strip(),
        client_name=client_name,
        project_type=str(raw_input["project_type"]).strip().lower(),
        area_sqm=area_sqm_value,
        scope_items=scope_items,
        pricing_profile=str(raw_input["pricing_profile"]).strip().lower(),
        currency=str(raw_input["currency"]).strip().upper(),
        vat_percent=vat_value,
        date=str(raw_input["date"]).strip(),
    )


def _line_item_description(scope_item: ProjectScopeItem, item_config: Dict[str, Any]) -> str:
    if scope_item.description:
        return scope_item.description
    return str(item_config.get("label_token", scope_item.code))


def build_doc_spec(raw_input: Dict[str, Any], config: Dict[str, Any]) -> DocSpec:
    enforce_project_input(raw_input, config)
    project_input = normalize_project_input(raw_input)
    rounding = config["rounding"]
    mode = rounding["mode"]
    applied_rules = []
    config_hash = sha256_digest(config)

    applied_rules.append(
        new_audit_entry(
            "normalize_input",
            {
                "project_type": project_input.project_type,
                "pricing_profile": project_input.pricing_profile,
                "currency": project_input.currency,
            },
        )
    )

    line_items: List[LineItem] = []
    for scope_item in project_input.scope_items:
        item_config = config["pricing"][scope_item.code]
        unit_price_raw = item_config["prices"][project_input.pricing_profile]
        unit_price = round_decimal(unit_price_raw, rounding["unit_price_decimals"], mode)
        amount = round_decimal(
            scope_item.qty * unit_price,
            rounding["line_amount_decimals"],
            mode,
        )
        description = _line_item_description(scope_item, item_config)
        line_items.append(
            LineItem(
                code=scope_item.code,
                description=description,
                qty=scope_item.qty,
                unit=scope_item.unit,
                unit_price=unit_price,
                amount=amount,
                category=item_config.get("category", "uncategorized"),
            )
        )
        applied_rules.append(
            new_audit_entry(
                "unit_price_lookup",
                {
                    "code": scope_item.code,
                    "pricing_profile": project_input.pricing_profile,
                    "unit_price": unit_price,
                },
            )
        )
        applied_rules.append(
            new_audit_entry(
                "line_amount_calc",
                {
                    "code": scope_item.code,
                    "qty": scope_item.qty,
                    "unit_price": unit_price,
                    "amount": amount,
                },
            )
        )

    subtotal = round_decimal(
        sum(item.amount for item in line_items),
        rounding["subtotal_decimals"],
        mode,
    )

    if project_input.vat_percent is None:
        vat_percent = to_decimal(config["vat_default_percent"])
        vat_source = "default"
    else:
        vat_percent = project_input.vat_percent
        vat_source = "override"

    vat = round_decimal(
        subtotal * vat_percent / to_decimal(100),
        rounding["vat_decimals"],
        mode,
    )
    grand_total = round_decimal(
        subtotal + vat,
        rounding["grand_total_decimals"],
        mode,
    )

    applied_rules.append(
        new_audit_entry(
            "vat_rate",
            {
                "vat_percent": vat_percent,
                "source": vat_source,
            },
        )
    )
    applied_rules.append(
        new_audit_entry(
            "rounding_policy",
            {
                "mode": mode,
                "unit_price_decimals": rounding["unit_price_decimals"],
                "line_amount_decimals": rounding["line_amount_decimals"],
                "subtotal_decimals": rounding["subtotal_decimals"],
                "vat_decimals": rounding["vat_decimals"],
                "grand_total_decimals": rounding["grand_total_decimals"],
            },
        )
    )
    applied_rules.append(
        new_audit_entry(
            "totals_calculated",
            {
                "subtotal": subtotal,
                "vat": vat,
                "grand_total": grand_total,
            },
        )
    )

    summary = {
        "project_type": project_input.project_type,
        "client_name": project_input.client_name,
        "pricing_profile": project_input.pricing_profile,
        "currency": project_input.currency,
        "vat_percent": vat_percent,
        "area_sqm": project_input.area_sqm,
        "date": project_input.date,
    }

    sections = {
        "summary": summary,
        "line_items": [item.__dict__ for item in line_items],
        "totals": Totals(
            subtotal=subtotal,
            vat=vat,
            grand_total=grand_total,
        ).__dict__,
    }

    meta = {
        "project_id": project_input.project_id,
        "generated_at": project_input.date,
        "version": config["config_version"],
    }

    audit_stub = {
        "applied_rules": [entry.__dict__ for entry in applied_rules],
        "input_hash": sha256_digest(project_input.to_dict()),
        "config_hash": config_hash,
        "spec_hash": "",
        "engine_version": ENGINE_VERSION,
        "config_version": config["config_version"],
    }
    doc_spec_stub = DocSpec(
        meta=meta,
        sections=sections,
        audit=audit_stub,
        warnings=[],
    )
    spec_hash = sha256_digest(doc_spec_stub.to_dict())

    audit_trail = build_audit_trail(
        applied_rules=applied_rules,
        project_input=project_input,
        config_hash=config_hash,
        spec_hash=spec_hash,
        config_version=config["config_version"],
    )
    doc_spec = DocSpec(
        meta=meta,
        sections=sections,
        audit=audit_to_dict(audit_trail),
        warnings=[],
    )
    enforce_doc_spec(doc_spec.to_dict(), config)

    return doc_spec
