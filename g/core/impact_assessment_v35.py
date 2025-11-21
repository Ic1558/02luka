from __future__ import annotations
from typing import TypedDict, List, Literal, Dict, Any


DeployType = Literal["minimal", "full"]
RiskLevel = Literal["low", "medium", "high"]


class ChangeSummary(TypedDict, total=False):
    """
    High-level summary of a feature/change used for impact assessment.

    This is filled by Liam/GMX feature-dev lane before deciding deploy type.
    """
    feature_name: str
    description: str

    # Basic counts
    files_touched: List[str]
    components_affected: List[str]

    # Flags – set by planner or Liam
    touches_governance: bool              # 02luka.md, core/governance/**, etc.
    changes_protocol: bool                # AP/IO, bridge format, SOT-level rules
    changes_executor_or_bridge: bool      # executor.py, bridge bus, WO processors
    changes_schema: bool                  # schemas/*.json
    changes_agent_behavior: bool          # core agent behaviour, routing
    adds_new_subsystem: bool              # new agent/service/pipeline
    changes_launchagents_or_runtime: bool # com.02luka.*, runtime wiring
    is_experimental: bool                 # POC / sandbox / R&D only


class ImpactReport(TypedDict):
    """
    Result of the impact assessment. This is what Liam uses
    to decide deploy lane behaviour.
    """
    deploy_type: DeployType       # "minimal" | "full"
    risk: RiskLevel               # "low" | "medium" | "high"
    reason: str                   # short human-readable reason

    requires_rollback: bool       # full deploy -> usually True
    update_sot: bool              # update 02luka.md / SOT docs?
    update_ai_context: bool       # update ai_context / memory?
    notify_workers: bool          # broadcast to workers / 02luka map?

    files_changed: List[str]
    components_affected: List[str]


def _count_files(summary: ChangeSummary) -> int:
    return len(summary.get("files_touched") or [])


def _has_any(summary: ChangeSummary, keys: List[str]) -> bool:
    return any(bool(summary.get(k)) for k in keys)


def assess_deploy_impact(summary: ChangeSummary) -> ImpactReport:
    """
    Decide whether this change should be treated as a minimal or full deploy.

    Rules (V3.5):

    Minimal deploy when ALL are true:
      - <= 2 files
      - no protocol / schema / executor / bridge / governance / launchagent change
      - no agent behaviour change
      - no new subsystem

    Otherwise → full deploy.

    Risk level is derived from flags:
      - high    → any governance/protocol/executor/bridge/launchagents
      - medium  → agent behaviour, schema, new subsystem
      - low     → misc / docs / small changes
    """
    files_changed = summary.get("files_touched") or []
    components = summary.get("components_affected") or []

    n_files = _count_files(summary)

    # Flags
    touches_governance = bool(summary.get("touches_governance"))
    changes_protocol = bool(summary.get("changes_protocol"))
    changes_executor_or_bridge = bool(summary.get("changes_executor_or_bridge"))
    changes_schema = bool(summary.get("changes_schema"))
    changes_agent_behavior = bool(summary.get("changes_agent_behavior"))
    adds_new_subsystem = bool(summary.get("adds_new_subsystem"))
    changes_launchagents_or_runtime = bool(summary.get("changes_launchagents_or_runtime"))
    is_experimental = bool(summary.get("is_experimental"))

    # --- Decide risk level ---
    if touches_governance or changes_protocol or changes_executor_or_bridge or changes_launchagents_or_runtime:
        risk: RiskLevel = "high"
    elif changes_agent_behavior or changes_schema or adds_new_subsystem:
        risk = "medium"
    else:
        risk = "low"

    # --- Decide deploy_type ---
    # Default assumption: minimal, then escalate
    deploy_type: DeployType = "minimal"

    hard_flags = [
        touches_governance,
        changes_protocol,
        changes_executor_or_bridge,
        changes_schema,
        changes_agent_behavior,
        adds_new_subsystem,
        changes_launchagents_or_runtime,
    ]

    # Full deploy if:
    # - touching any critical flag, OR
    # - more than 2 files
    if any(hard_flags) or n_files > 2:
        deploy_type = "full"

    # Minimal deploy criteria (for clarity):
    minimal_ok = (
        n_files <= 2
        and not _has_any(summary, [
            "touches_governance",
            "changes_protocol",
            "changes_executor_or_bridge",
            "changes_schema",
            "changes_agent_behavior",
            "adds_new_subsystem",
            "changes_launchagents_or_runtime",
        ])
    )
    if minimal_ok:
        deploy_type = "minimal"

    # --- Derived flags ---
    requires_rollback = (deploy_type == "full") or (risk != "low")

    update_sot = (
        deploy_type == "full"
        and (
            changes_protocol
            or changes_executor_or_bridge
            or adds_new_subsystem
            or changes_launchagents_or_runtime
        )
    )

    update_ai_context = (
        deploy_type == "full"
        and (
            changes_agent_behavior
            or adds_new_subsystem
            or changes_protocol
        )
    )

    notify_workers = (
        deploy_type == "full"
        and (
            adds_new_subsystem
            or changes_launchagents_or_runtime
            or changes_protocol
        )
    )

    # --- Build reason string ---
    reasons: List[str] = []
    reasons.append(f"{n_files} file(s) changed")

    if touches_governance:
        reasons.append("touches governance/SOT")
    if changes_protocol:
        reasons.append("changes protocol/AP/IO")
    if changes_executor_or_bridge:
        reasons.append("affects executor/bridge")
    if changes_schema:
        reasons.append("changes schema")
    if changes_agent_behavior:
        reasons.append("changes agent behaviour")
    if adds_new_subsystem:
        reasons.append("adds new subsystem")
    if changes_launchagents_or_runtime:
        reasons.append("changes launchagents/runtime")
    if is_experimental:
        reasons.append("marked as experimental")

    if not reasons:
        reasons.append("no explicit flags; treated as low-impact")

    reason_str = "; ".join(reasons)

    return ImpactReport(
        deploy_type=deploy_type,
        risk=risk,
        reason=reason_str,
        requires_rollback=requires_rollback,
        update_sot=update_sot,
        update_ai_context=update_ai_context,
        notify_workers=notify_workers,
        files_changed=files_changed,
        components_affected=components,
    )


def impact_report_to_apio_payload(
    summary: ChangeSummary,
    report: ImpactReport,
) -> Dict[str, Any]:
    """
    Helper for AP/IO: convert assessment to a ledger data payload.
    """
    return {
        "feature_name": summary.get("feature_name"),
        "description": summary.get("description"),
        "deploy_type": report["deploy_type"],
        "risk": report["risk"],
        "requires_rollback": report["requires_rollback"],
        "update_sot": report["update_sot"],
        "update_ai_context": report["update_ai_context"],
        "notify_workers": report["notify_workers"],
        "files_changed": report["files_changed"],
        "components_affected": report["components_affected"],
    }
