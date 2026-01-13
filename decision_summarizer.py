# decision_summarizer.py
# 02LUKA Decision Summarizer — lightweight, deterministic, testable
# - No external deps
# - Marker-friendly integration into bridges
from __future__ import annotations

from dataclasses import dataclass, asdict
from typing import Any, Dict, List, Optional, Tuple
import json
import re
import time


# ----------------------------
# Rule table (source of truth)
# ----------------------------
RULE_TABLE: List[Dict[str, Any]] = [
    {
        "rule_id": "R1_EXEC_OR_FS_MUTATION",
        "if_any": [
            r"\b(rm\s+-rf|sudo|chmod\s+\+x|chown|launchctl|systemctl|brew\s+install|pip\s+install)\b",
            r"\b(write|overwrite|delete|remove|patch|modify|edit)\b.*\b(file|repo|config|plist|launchagent)\b",
        ],
        "risk": "high",
        "requires": ["SIP", "verify"],
        "route_hint": "CLC_or_CLS_executor",
        "note": "Any exec / file mutation requires Safe Idempotent Patch + verification.",
    },
    {
        "rule_id": "R2_SECRETS_OR_CREDENTIALS",
        "if_any": [
            r"\b(api[_-]?key|token|secret|password|private key|ssh key)\b",
            r"\b(\.env|vault|gitleaks|acl)\b",
        ],
        "risk": "critical",
        "requires": ["redact", "no-echo", "verify"],
        "route_hint": "secure_lane",
        "note": "Never print secrets; prefer env/vault paths; enforce redaction.",
    },
    {
        "rule_id": "R3_MULTI_LAYER_DECISION",
        "if_any": [
            r"\b(strategy|architecture|governance|roadmap|trade[- ]?off|design)\b",
            r"\b(multi[- ]?step|depends on|evaluate options|choose)\b",
        ],
        "risk": "medium",
        "requires": ["clarify_if_ambiguous"],
        "route_hint": "GG_or_GC_planning",
        "note": "Planning ok; if ambiguous, ask or snapshot before action.",
    },
    {
        "rule_id": "R4_DATA_TRANSFORM_ONLY",
        "if_any": [
            r"\b(summarize|rewrite|translate|format|table|extract)\b",
        ],
        "risk": "low",
        "requires": [],
        "route_hint": "bridge_ok",
        "note": "Pure text/data transformation; safe to execute inline.",
    },
    {
        "rule_id": "R5_DEFAULT",
        "if_any": [r".*"],
        "risk": "low",
        "requires": [],
        "route_hint": "bridge_ok",
        "note": "Fallback: treat as low-risk unless other rules trigger.",
    },
]

# Markdown table (for logs / human review)
RULE_TABLE_MD = """\
| Rule ID | Trigger (keywords/regex) | Risk | Requires | Route Hint | Note |
|---|---|---:|---|---|---|
| R1_EXEC_OR_FS_MUTATION | rm -rf / sudo / chmod / launchctl / install / write+file | high | SIP, verify | CLC_or_CLS_executor | File/exec mutations must be SIP + verified |
| R2_SECRETS_OR_CREDENTIALS | api_key/token/secret/.env/vault/gitleaks/acl | critical | redact, no-echo, verify | secure_lane | Never print secrets; redact always |
| R3_MULTI_LAYER_DECISION | strategy/architecture/governance/trade-off | medium | clarify_if_ambiguous | GG_or_GC_planning | Snapshot before action if ambiguous |
| R4_DATA_TRANSFORM_ONLY | summarize/rewrite/translate/format | low | - | bridge_ok | Safe, non-mutating |
| R5_DEFAULT | any | low | - | bridge_ok | Default fallback |
"""


@dataclass
class DecisionSummary:
    ts: int
    text_preview: str
    matched_rules: List[str]
    risk: str
    requires: List[str]
    route_hint: str
    rationale: List[str]

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)

    def to_json(self) -> str:
        return json.dumps(self.to_dict(), ensure_ascii=False)


def _norm_text(text: str, max_len: int = 240) -> str:
    t = (text or "").strip()
    t = re.sub(r"\s+", " ", t)
    return (t[:max_len] + "…") if len(t) > max_len else t


def _match_rules(text: str) -> List[Tuple[str, Dict[str, Any], List[str]]]:
    hits: List[Tuple[str, Dict[str, Any], List[str]]] = []
    for rule in RULE_TABLE:
        patterns = rule.get("if_any", [])
        matched: List[str] = []
        for pat in patterns:
            if re.search(pat, text, flags=re.IGNORECASE):
                matched.append(pat)
        if matched:
            hits.append((rule["rule_id"], rule, matched))
    return hits


_RISK_ORDER = {"low": 0, "medium": 1, "high": 2, "critical": 3}


def summarize_decision(
    user_text: str,
    *,
    metadata: Optional[Dict[str, Any]] = None,
) -> DecisionSummary:
    """
    Deterministic decision summary:
    - Evaluate RULE_TABLE
    - Pick highest-risk rule as primary
    - Aggregate requires
    """
    metadata = metadata or {}
    text = user_text or ""
    hits = _match_rules(text)

    # Choose primary by highest risk, stable tie-breaker by order in RULE_TABLE
    primary_rule = None
    primary_risk = "low"
    primary_route = "bridge_ok"

    matched_rules: List[str] = []
    rationale: List[str] = []
    requires_set = set()

    for rule_id, rule, matched in hits:
        matched_rules.append(rule_id)
        for req in rule.get("requires", []):
            requires_set.add(req)
        rationale.append(f"{rule_id}: matched {len(matched)} pattern(s)")

        r = rule.get("risk", "low")
        if _RISK_ORDER.get(r, 0) > _RISK_ORDER.get(primary_risk, 0):
            primary_risk = r
            primary_rule = rule
            primary_route = rule.get("route_hint", primary_route)

    if primary_rule is None:
        # should not happen because R5_DEFAULT matches .*
        primary_rule = {"route_hint": "bridge_ok"}

    return DecisionSummary(
        ts=int(time.time()),
        text_preview=_norm_text(text),
        matched_rules=matched_rules,
        risk=primary_risk,
        requires=sorted(list(requires_set)),
        route_hint=primary_route,
        rationale=rationale,
    )


def build_decision_block_for_logs(user_text: str) -> str:
    """
    Human-friendly log block: compact and copy-pasteable.
    """
    s = summarize_decision(user_text)
    lines = [
        "decision_summary:",
        f"  ts: {s.ts}",
        f"  risk: {s.risk}",
        f"  route_hint: {s.route_hint}",
        f"  requires: {s.requires}",
        f"  matched_rules: {s.matched_rules}",
        f"  text_preview: {json.dumps(s.text_preview, ensure_ascii=False)}",
    ]
    return "\n".join(lines)
