"""Audit helpers for applied rules."""

from __future__ import annotations

import hashlib
import json
from dataclasses import asdict
from typing import Any, Dict, Iterable, List

from core.pro_docs.schema import AuditEntry, AuditTrail, ProjectInput


def new_audit_entry(rule_id: str, params: Dict[str, Any]) -> AuditEntry:
    return AuditEntry(rule_id=rule_id, params=params)


def inputs_hash(project_input: ProjectInput) -> str:
    payload = json.dumps(project_input.to_dict(), sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def build_audit_trail(
    applied_rules: Iterable[AuditEntry],
    project_input: ProjectInput,
    config_version: str,
) -> AuditTrail:
    rules_list: List[AuditEntry] = list(applied_rules)
    return AuditTrail(
        applied_rules=rules_list,
        inputs_hash=inputs_hash(project_input),
        config_version=config_version,
    )


def audit_to_dict(audit_trail: AuditTrail) -> Dict[str, Any]:
    return {
        "applied_rules": [asdict(entry) for entry in audit_trail.applied_rules],
        "inputs_hash": audit_trail.inputs_hash,
        "config_version": audit_trail.config_version,
    }
