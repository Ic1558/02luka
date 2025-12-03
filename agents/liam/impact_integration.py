"""
Liam Integration for Impact Assessment V3.5

This module provides automatic impact assessment integration for Liam's feature-dev lane.
"""
from __future__ import annotations
import sys
from pathlib import Path
from typing import Dict, Any, List

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from g.core.impact_assessment_v35 import (
    assess_deploy_impact,
    impact_report_to_apio_payload,
    ChangeSummary,
    ImpactReport
)
from tools.ap_io_v31.writer import write_ledger_entry


def liam_feature_dev_decide_deploy(
    feature_name: str,
    description: str,
    files: List[str],
    components: List[str],
    flags: Dict[str, bool]
) -> ImpactReport:
    """
    Automatically assess deploy impact for a feature.
    
    Called by Liam at the end of feature-dev lane.
    
    Args:
        feature_name: Name of the feature
        description: Brief description
        files: List of files touched
        components: List of components affected
        flags: Dict of impact flags (touches_governance, changes_protocol, etc.)
    
    Returns:
        ImpactReport with deploy_type, risk, and required actions
    """
    # Build ChangeSummary
    summary: ChangeSummary = {
        "feature_name": feature_name,
        "description": description,
        "files_touched": files,
        "components_affected": components,
        **flags  # Unpack flags into summary
    }
    
    # Assess impact
    report = assess_deploy_impact(summary)
    
    # Log to AP/IO (mandatory for all deploys)
    write_ledger_entry(
        agent="Liam",
        event="deploy_impact_assessed",
        data=impact_report_to_apio_payload(summary, report)
    )
    
    # Auto-actions based on report
    if report["update_sot"]:
        _create_sot_update_wo(feature_name, files)
    
    if report["update_ai_context"]:
        _create_ai_context_update_wo(feature_name, components)
    
    if report["notify_workers"]:
        _notify_workers(feature_name, report)
    
    return report


def _create_sot_update_wo(feature_name: str, files: List[str]) -> None:
    """Create Work Order for SOT update (02luka.md)"""
    write_ledger_entry(
        agent="Liam",
        event="sot_update_wo_created",
        data={
            "feature_name": feature_name,
            "files_affected": files,
            "note": "SOT update required due to system-level changes"
        }
    )
    # TODO: Create actual WO file in bridge/inbox/HYBRID/


def _create_ai_context_update_wo(feature_name: str, components: List[str]) -> None:
    """Create Work Order for AI context update"""
    write_ledger_entry(
        agent="Liam",
        event="ai_context_update_wo_created",
        data={
            "feature_name": feature_name,
            "components_affected": components,
            "note": "AI context refresh required due to behavior/subsystem changes"
        }
    )
    # TODO: Create actual WO file in bridge/inbox/HYBRID/


def _notify_workers(feature_name: str, report: ImpactReport) -> None:
    """Notify workers via AP/IO events"""
    write_ledger_entry(
        agent="Liam",
        event="workers_notified",
        data={
            "feature_name": feature_name,
            "deploy_type": report["deploy_type"],
            "risk": report["risk"],
            "components_affected": report["components_affected"],
            "note": "Workers notified of system-level deployment"
        }
    )


# Example usage for testing
if __name__ == "__main__":
    # Test minimal deploy
    report = liam_feature_dev_decide_deploy(
        feature_name="fix_typo",
        description="Fix typo in README",
        files=["README.md"],
        components=["docs"],
        flags={
            "touches_governance": False,
            "changes_protocol": False,
            "changes_executor_or_bridge": False,
            "changes_schema": False,
            "changes_agent_behavior": False,
            "adds_new_subsystem": False,
            "changes_launchagents_or_runtime": False,
            "is_experimental": False,
        }
    )
    
    print(f"Deploy type: {report['deploy_type']}")
    print(f"Risk: {report['risk']}")
    print(f"Requires rollback: {report['requires_rollback']}")
    print(f"Update SOT: {report['update_sot']}")
    print(f"Update AI context: {report['update_ai_context']}")
    print(f"Notify workers: {report['notify_workers']}")
