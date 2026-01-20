"""Audit helpers for applied rules and hashes."""

from __future__ import annotations

from typing import Any, Dict, Iterable, List

from core.pro_docs.schema import AuditEntry, AuditTrail, ProjectInput
from core.pro_docs.utils import ENGINE_VERSION, sha256_digest


def new_audit_entry(rule_id: str, params: Dict[str, Any]) -> AuditEntry:
    return AuditEntry(rule_id=rule_id, params=params)


def build_audit_trail(
    applied_rules: Iterable[AuditEntry],
    project_input: ProjectInput,
    config_hash: str,
    spec_hash: str,
    config_version: str,
) -> AuditTrail:
    rules_list: List[AuditEntry] = list(applied_rules)
    return AuditTrail(
        applied_rules=rules_list,
        input_hash=sha256_digest(project_input.to_dict()),
        config_hash=config_hash,
        spec_hash=spec_hash,
        engine_version=ENGINE_VERSION,
        config_version=config_version,
    )


def audit_to_dict(audit_trail: AuditTrail) -> Dict[str, Any]:
    return {
        "applied_rules": [entry.__dict__ for entry in audit_trail.applied_rules],
        "input_hash": audit_trail.input_hash,
        "config_hash": audit_trail.config_hash,
        "spec_hash": audit_trail.spec_hash,
        "engine_version": audit_trail.engine_version,
        "config_version": audit_trail.config_version,
    }
