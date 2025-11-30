#!/usr/bin/env python3
"""
CLI for Alter polish/translation (text-only).
"""

from __future__ import annotations

import argparse
import sys

from agents.alter.helpers import get_polish_service


def _format_usage(tracker) -> str:
    counts = {
        "daily": tracker.get_daily_count(),
        "lifetime": tracker.get_lifetime_count(),
    }
    remaining = tracker.get_remaining()
    lines = [
        "Alter Usage",
        f"  Daily:    {counts['daily']}/{tracker.daily_limit} (remaining {remaining['daily']})",
        f"  Lifetime: {counts['lifetime']}/{tracker.lifetime_limit} (remaining {remaining['lifetime']})",
    ]
    alerts = tracker.should_alert()
    if alerts.get("daily"):
        lines.append("⚠️  Daily quota >= alert threshold")
    if alerts.get("lifetime"):
        lines.append("⚠️  Lifetime quota >= alert threshold")
    return "\n".join(lines)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Alter polish/translation tool (text-only).")
    parser.add_argument("--text", help="Text to polish/translate.")
    parser.add_argument("--tone", default="formal", help="Tone for polish (default: formal).")
    parser.add_argument("--translate", dest="translate", help="Target language (e.g., en, th).")
    parser.add_argument("--polish", action="store_true", help="Polish before translation.")
    parser.add_argument("--usage", action="store_true", help="Show usage stats and exit.")
    args = parser.parse_args(argv)

    service = get_polish_service()
    tracker = service.tracker

    if args.usage:
        print(_format_usage(tracker))
        return 0

    if not args.text:
        parser.error("--text is required unless --usage is specified")

    try:
        if args.translate:
            if args.polish:
                result = service.polish_and_translate(args.text, target_lang=args.translate, tone=args.tone)
            else:
                result = service.translate(args.text, target_lang=args.translate)
        else:
            result = service.polish_text(args.text, tone=args.tone)
        print(result)
        return 0
    except Exception as exc:  # pragma: no cover - CLI safety
        print(f"Error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
