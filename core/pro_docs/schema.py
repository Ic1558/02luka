"""Data contracts for professional document rules engine."""

from __future__ import annotations

from dataclasses import dataclass, field, asdict
from typing import Any, Dict, List, Optional


@dataclass(frozen=True)
class ProjectScopeItem:
    code: str
    description: str
    qty: float
    unit: str


@dataclass(frozen=True)
class ProjectInput:
    project_id: str
    client_name: Optional[str]
    project_type: str
    area_sqm: Optional[float]
    scope_items: List[ProjectScopeItem]
    pricing_profile: str
    currency: str
    vat_percent: Optional[float]
    date: str

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


@dataclass(frozen=True)
class LineItem:
    code: str
    description: str
    qty: float
    unit: str
    unit_price: float
    amount: float
    category: str


@dataclass(frozen=True)
class Totals:
    subtotal: float
    vat: float
    grand_total: float


@dataclass(frozen=True)
class AuditEntry:
    rule_id: str
    params: Dict[str, Any]


@dataclass(frozen=True)
class AuditTrail:
    applied_rules: List[AuditEntry]
    inputs_hash: str
    config_version: str

    def to_dict(self) -> Dict[str, Any]:
        return {
            "applied_rules": [asdict(entry) for entry in self.applied_rules],
            "inputs_hash": self.inputs_hash,
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
