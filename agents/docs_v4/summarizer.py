from __future__ import annotations

from collections import Counter
from typing import Dict, List


def summarize_events(events: List[Dict]) -> Dict[str, object]:
    counts = Counter([e.get("event_type", "unknown") for e in events])
    lanes = Counter([e.get("lane", "unknown") for e in events])
    statuses = Counter([e.get("status", "unknown") for e in events])

    return {
        "total": len(events),
        "by_event": dict(counts),
        "by_lane": dict(lanes),
        "by_status": dict(statuses),
    }


def summarize_conversations(conversations: List[Dict]) -> Dict[str, object]:
    total = len(conversations)
    participants = Counter()  # type: ignore
    for convo in conversations:
        speaker = convo.get("speaker") or convo.get("agent")
        if speaker:
            participants[speaker] += 1
    return {"total": total, "by_speaker": dict(participants)}


def build_summary(events_summary: Dict[str, object], convo_summary: Dict[str, object]) -> str:
    lines: List[str] = []
    lines.append("# Docs Listener Summary")
    lines.append("")
    lines.append("## Events")
    lines.append(f"- Total: {events_summary.get('total', 0)}")
    if events_summary.get("by_event"):
        lines.append(f"- By Event: {events_summary['by_event']}")
    if events_summary.get("by_lane"):
        lines.append(f"- By Lane: {events_summary['by_lane']}")
    if events_summary.get("by_status"):
        lines.append(f"- By Status: {events_summary['by_status']}")

    lines.append("")
    lines.append("## Conversations")
    lines.append(f"- Total: {convo_summary.get('total', 0)}")
    if convo_summary.get("by_speaker"):
        lines.append(f"- By Speaker: {convo_summary['by_speaker']}")

    return "\n".join(lines)


__all__ = ["summarize_events", "summarize_conversations", "build_summary"]
