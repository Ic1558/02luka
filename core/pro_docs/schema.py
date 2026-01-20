"""Data contracts for professional document rules engine."""

from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal
from typing import Any, Dict, List, Optional

from core.pro_docs.utils import canonical_json_dumps


@dataclass(frozen=True)
class ProjectScopeItem:
    code: str
    description: str
    qty: Decimal
    unit: str


@dataclass(frozen=True)
class ProjectInput:
    project_id: str
    client_name: Optional[str]
    project_type: str
    area_sqm: Optional[Decimal]
    scope_items: List[ProjectScopeItem]
    pricing_profile: str
    currency: str
    vat_percent: Optional[Decimal]
    date: str

    def to_dict(self) -> Dict[str, Any]:
        return {
            "project_id": self.project_id,
            "client_name": self.client_name,
            "project_type": self.project_type,
            "area_sqm": self.area_sqm,
            "scope_items": [
                {
                    "code": item.code,
                    "description": item.description,
                    "qty": item.qty,
                    "unit": item.unit,
                }
                for item in self.scope_items
            ],
            "pricing_profile": self.pricing_profile,
            "currency": self.currency,
            "vat_percent": self.vat_percent,
            "date": self.date,
        }


@dataclass(frozen=True)
class LineItem:
    code: str
    description: str
    qty: Decimal
    unit: str
    unit_price: Decimal
    amount: Decimal
    category: str


@dataclass(frozen=True)
class Totals:
    subtotal: Decimal
    vat: Decimal
    grand_total: Decimal


@dataclass(frozen=True)
class AuditEntry:
    rule_id: str
    params: Dict[str, Any]


@dataclass(frozen=True)
class AuditTrail:
    applied_rules: List[AuditEntry]
    input_hash: str
    config_hash: str
    spec_hash: str
    engine_version: str
    config_version: str

    def to_dict(self) -> Dict[str, Any]:
        return {
            "applied_rules": [entry.__dict__ for entry in self.applied_rules],
            "input_hash": self.input_hash,
            "config_hash": self.config_hash,
            "spec_hash": self.spec_hash,
            "engine_version": self.engine_version,
            "config_version": self.config_version,
        }


@dataclass(frozen=True)
class DocSpec:
    meta: Dict[str, Any]
    sections: Dict[str, Any]
    audit: Dict[str, Any]
    warnings: List[str] = field(default_factory=list)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "meta": self.meta,
            "sections": self.sections,
            "audit": self.audit,
            "warnings": self.warnings,
        }

    def canonical_json(self) -> str:
        return canonical_json_dumps(self.to_dict())
