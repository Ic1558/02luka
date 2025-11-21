#!/usr/bin/env python3
"""
V4 Deploy Impact Assessment
"""
import sys
from pathlib import Path

# Add repo root to path
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from g.core.impact_assessment_v35 import assess_deploy_impact, ChangeSummary, impact_report_to_apio_payload
from tools.ap_io_v31.writer import write_ledger_entry
import json

# V4 Change Summary
v4_summary: ChangeSummary = {
    "feature_name": "V4 Stabilization Layer",
    "description": "System-wide enforceable contracts: FDE validator, Memory Hub API, V4 Universal Memory Contract, AP/IO extensions, test suite",
    
    "files_touched": [
        "g/core/fde/fde_validator.py",  # NEW
        "g/core/fde/fde_rules.json",  # NEW
        "agents/memory_hub/memory_hub.py",  # MODIFIED
        "agents/liam/PERSONA_PROMPT.md",  # MODIFIED
        "agents/gmx/PERSONA_PROMPT.md",  # MODIFIED
        "g/tools/ap_io_events.py",  # NEW
        "g/tools/v4_migration_validator.py",  # NEW
        "tests/test_v4_enforcement.py",  # NEW
        "docs/WRITER_POLICY_V4_EXTENSIONS.md",  # NEW
    ],
    
    "components_affected": [
        "FDE (Feature-Dev Enforcement)",
        "Memory Hub",
        "Liam Agent",
        "GMX Agent",
        "AP/IO Events",
        "Writer Policy"
    ],
    
    # Critical flags
    "touches_governance": False,  # No 02luka.md changes
    "changes_protocol": True,  # AP/IO v4 events added
    "changes_executor_or_bridge": False,  # No executor changes
    "changes_schema": False,  # No schema changes
    "changes_agent_behavior": True,  # Mandatory memory contract
    "adds_new_subsystem": True,  # FDE validator is new subsystem
    "changes_launchagents_or_runtime": False,  # No runtime changes
    "is_experimental": False,  # Production-ready
}

# Run assessment
report = assess_deploy_impact(v4_summary)

# Print report
print("=" * 60)
print("V4 DEPLOY IMPACT ASSESSMENT")
print("=" * 60)
print()
print(f"Deploy Type: {report['deploy_type'].upper()}")
print(f"Risk Level: {report['risk'].upper()}")
print(f"Reason: {report['reason']}")
print()
print("Actions Required:")
print(f"  - Requires Rollback Plan: {'YES' if report['requires_rollback'] else 'NO'}")
print(f"  - Update SOT (02luka.md): {'YES' if report['update_sot'] else 'NO'}")
print(f"  - Update AI Context: {'YES' if report['update_ai_context'] else 'NO'}")
print(f"  - Notify Workers: {'YES' if report['notify_workers'] else 'NO'}")
print()
print(f"Files Changed: {len(report['files_changed'])}")
for f in report['files_changed']:
    print(f"  - {f}")
print()
print(f"Components Affected: {len(report['components_affected'])}")
for c in report['components_affected']:
    print(f"  - {c}")
print()
print("=" * 60)

# Log to AP/IO
payload = impact_report_to_apio_payload(v4_summary, report)
ledger_id = write_ledger_entry(
    agent="Liam",
    event="deploy_impact_assessed",
    data=payload
)

print(f"✅ Logged to AP/IO ledger: {ledger_id}")
print("=" * 60)
