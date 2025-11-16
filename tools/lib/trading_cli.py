#!/usr/bin/env python3
"""Unified trading CLI backend for journal imports, snapshots, prompts, and MLS hooks."""
from __future__ import annotations

import argparse
import csv
import json
import math
import re
import sys
from collections import defaultdict
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Sequence, Tuple

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_JOURNAL = REPO_ROOT / "g" / "trading" / "journal.jsonl"
DEFAULT_REPORT_DIR = REPO_ROOT / "g" / "reports" / "trading"
DEFAULT_MLS_FILE = REPO_ROOT / "g" / "knowledge" / "mls_lessons.jsonl"


@dataclass
class DateRange:
    start: date
    end: date

    def slug(self) -> str:
        if self.start == self.end:
            return self.start.isoformat()
        return f"{self.start.isoformat()}_{self.end.isoformat()}"


class TradingCLIError(RuntimeError):
    """Domain-specific error for clearer CLI messages."""


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="02luka trading CLI with import, snapshot, chatgpt, and MLS helpers."
    )
    parser.add_argument(
        "--journal",
        default=str(DEFAULT_JOURNAL),
        help="Path to the trading journal JSONL file (default: %(default)s)",
    )

    subparsers = parser.add_subparsers(dest="command", required=True)

    # import subcommand
    import_parser = subparsers.add_parser(
        "import", help="Import a CSV statement into the trading journal"
    )
    import_parser.add_argument(
        "csv",
        help="Path to the CSV statement exported from the broker/platform",
    )
    import_parser.add_argument(
        "--market",
        required=True,
        help="Market identifier to annotate the imported trades (e.g., TFEX)",
    )
    import_parser.add_argument(
        "--account",
        required=True,
        help="Account identifier, e.g., BIZ-01",
    )
    import_parser.add_argument(
        "--scenario",
        help="Optional trading scenario label to tag every imported row",
    )
    import_parser.add_argument(
        "--tag",
        action="append",
        dest="tags",
        default=[],
        help="Additional tag to attach to every imported row (repeatable)",
    )
    import_parser.add_argument(
        "--encoding",
        default="utf-8",
        help="CSV encoding (default: %(default)s)",
    )
    import_parser.add_argument(
        "--delimiter",
        default=",",
        help="CSV delimiter (default: %(default)s)",
    )

    # snapshot + chatgpt share filters/metadata flags
    def add_snapshot_args(p: argparse.ArgumentParser) -> None:
        p.add_argument(
            "--day",
            help="Shortcut for single-day snapshots (today, yesterday, or YYYY-MM-DD)",
        )
        p.add_argument("--from", dest="range_from", help="Start date (YYYY-MM-DD)")
        p.add_argument("--to", dest="range_to", help="End date (YYYY-MM-DD)")
        p.add_argument("--market", help="Filter by market identifier")
        p.add_argument("--account", help="Filter by account identifier")
        p.add_argument(
            "--symbol",
            help="Filter to a specific symbol/ticker (case-insensitive contains)",
        )
        p.add_argument(
            "--scenario",
            help="Scenario label describing this snapshot (stored in metadata)",
        )
        p.add_argument(
            "--tag",
            action="append",
            dest="tags",
            default=[],
            help="Tag to annotate the snapshot metadata (repeatable)",
        )
        p.add_argument(
            "--emit-mls",
            action="store_true",
            help="When set, append a machine lesson to g/knowledge/mls_lessons.jsonl",
        )
        p.add_argument(
            "--mls-file",
            default=str(DEFAULT_MLS_FILE),
            help="Override path for MLS lessons file",
        )
        p.add_argument(
            "--report-dir",
            default=str(DEFAULT_REPORT_DIR),
            help="Directory for Markdown/JSON snapshot outputs",
        )

    snapshot_parser = subparsers.add_parser(
        "snapshot",
        help="Generate Markdown + JSON snapshots for a trading day/range",
    )
    add_snapshot_args(snapshot_parser)

    chatgpt_parser = subparsers.add_parser(
        "chatgpt-prompt",
        help="Emit a ChatGPT-ready prompt summarizing the snapshot",
    )
    add_snapshot_args(chatgpt_parser)

    return parser.parse_args(argv)


def ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def normalize_key(value: str) -> str:
    cleaned = re.sub(r"[^a-zA-Z0-9]+", "_", value.strip().lower())
    return cleaned.strip("_")


def normalize_row(row: Dict[str, Any]) -> Dict[str, Any]:
    normalized: Dict[str, Any] = {}
    for raw_key, raw_value in row.items():
        if raw_key is None:
            continue
        key = normalize_key(raw_key)
        if not key:
            continue
        if isinstance(raw_value, str):
            value = raw_value.strip()
        else:
            value = raw_value
        normalized[key] = value
    return normalized


ISO_PATTERNS = [
    "%Y-%m-%d %H:%M:%S",
    "%Y-%m-%d %H:%M",
    "%Y/%m/%d %H:%M:%S",
    "%Y/%m/%d %H:%M",
    "%d/%m/%Y %H:%M:%S",
    "%d/%m/%Y %H:%M",
    "%Y-%m-%d",
    "%d/%m/%Y",
]


def parse_timestamp_from_row(row: Dict[str, Any]) -> Tuple[Optional[datetime], Optional[str]]:
    candidates = [
        row.get("timestamp"),
        row.get("executed_at"),
        row.get("datetime"),
        row.get("date"),
        row.get("trade_date"),
    ]
    if row.get("date") and row.get("time"):
        candidates.insert(0, f"{row['date']} {row['time']}")
    for candidate in candidates:
        if not candidate:
            continue
        for pattern in ISO_PATTERNS:
            try:
                parsed = datetime.strptime(candidate, pattern)
                return parsed, parsed.date().isoformat()
            except ValueError:
                continue
        try:
            parsed = datetime.fromisoformat(candidate)
            return parsed, parsed.date().isoformat()
        except ValueError:
            continue
    if row.get("date"):
        try:
            parsed_date = datetime.fromisoformat(row["date"])
            return None, parsed_date.date().isoformat()
        except ValueError:
            pass
    return None, None


def to_float(value: Any, default: float = 0.0) -> float:
    if value is None or value == "":
        return default
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        cleaned = value.replace(",", "").replace("THB", "").strip()
        if cleaned in {"", "-", "--"}:
            return default
        try:
            return float(cleaned)
        except ValueError:
            return default
    return default


def safe_win_rate(wins: int, total: int) -> float:
    return wins / total if total else 0.0


def load_journal(path: Path) -> List[Dict[str, Any]]:
    if not path.exists():
        return []
    entries: List[Dict[str, Any]] = []
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            text = line.strip()
            if not text:
                continue
            try:
                entries.append(json.loads(text))
            except json.JSONDecodeError:
                continue
    return entries


def parse_day(value: str, now: datetime) -> date:
    lower = value.strip().lower()
    today = now.date()
    if lower == "today":
        return today
    if lower == "yesterday":
        return today - timedelta(days=1)
    return date.fromisoformat(value)


def resolve_range(args: argparse.Namespace) -> DateRange:
    now = datetime.now().astimezone()
    if args.day:
        day = parse_day(args.day, now)
        return DateRange(day, day)
    if args.range_from or args.range_to:
        if not args.range_from and not args.range_to:
            raise TradingCLIError("Both --from and --to are required when using range filters")
        start = date.fromisoformat(args.range_from or args.range_to)
        end = date.fromisoformat(args.range_to or args.range_from)
        if end < start:
            start, end = end, start
        return DateRange(start, end)
    raise TradingCLIError("Provide --day or --from/--to to define the snapshot range")


def within_range(entry: Dict[str, Any], drange: DateRange) -> bool:
    entry_day = entry.get("day")
    if not entry_day:
        timestamp = entry.get("timestamp")
        if timestamp:
            try:
                entry_day = datetime.fromisoformat(timestamp).date().isoformat()
            except ValueError:
                pass
    if not entry_day:
        return True
    try:
        entry_date = date.fromisoformat(entry_day)
    except ValueError:
        return True
    return drange.start <= entry_date <= drange.end


def extract_symbol(entry: Dict[str, Any]) -> str:
    data = entry.get("data", {})
    for key in ("symbol", "ticker", "instrument", "contract", "product"):
        value = data.get(key)
        if value:
            return str(value)
    return "unspecified"


def extract_strategy(entry: Dict[str, Any]) -> str:
    data = entry.get("data", {})
    for key in ("strategy", "scenario", "system", "playbook"):
        value = data.get(key)
        if value:
            return str(value)
    if entry.get("scenario"):
        return str(entry["scenario"])
    return "unspecified"


def entry_tags(entry: Dict[str, Any]) -> List[str]:
    tags = set()
    data = entry.get("data", {})
    raw = data.get("tags")
    if isinstance(raw, str):
        for segment in re.split(r"[;,]", raw):
            stripped = segment.strip()
            if stripped:
                tags.add(stripped)
    for tag in entry.get("tags", []):
        if tag:
            tags.add(str(tag))
    return sorted(tags)


def extract_numeric(entry: Dict[str, Any], *keys: str, default: float = 0.0) -> float:
    data = entry.get("data", {})
    for key in keys:
        if key in data:
            return to_float(data[key], default=default)
    return default


def filter_entries(
    entries: Iterable[Dict[str, Any]], args: argparse.Namespace, drange: DateRange
) -> List[Dict[str, Any]]:
    selected: List[Dict[str, Any]] = []
    symbol_filter = args.symbol.lower() if args.symbol else None
    for entry in entries:
        if not within_range(entry, drange):
            continue
        if args.market and entry.get("market") and entry["market"] != args.market:
            continue
        if args.account and entry.get("account") and entry["account"] != args.account:
            continue
        if symbol_filter:
            symbol = extract_symbol(entry).lower()
            if symbol_filter not in symbol:
                continue
        selected.append(entry)
    return selected


def compute_snapshot(
    entries: Sequence[Dict[str, Any]],
    drange: DateRange,
    args: argparse.Namespace,
) -> Dict[str, Any]:
    summary = {
        "total_trades": len(entries),
        "gross_pnl": 0.0,
        "fees": 0.0,
        "tax": 0.0,
        "net_pnl": 0.0,
        "win_rate": 0.0,
        "avg_win": 0.0,
        "avg_loss": 0.0,
        "max_gain": 0.0,
        "max_loss": 0.0,
    }
    wins = 0
    losses = 0
    win_total = 0.0
    loss_total = 0.0

    symbol_stats: Dict[str, Dict[str, Any]] = defaultdict(
        lambda: {"net_pnl": 0.0, "gross_pnl": 0.0, "trades": 0, "wins": 0}
    )
    strategy_stats: Dict[str, Dict[str, Any]] = defaultdict(
        lambda: {"net_pnl": 0.0, "gross_pnl": 0.0, "trades": 0, "wins": 0}
    )
    bucket_stats: Dict[str, Dict[str, Any]] = defaultdict(
        lambda: {"net_pnl": 0.0, "gross_pnl": 0.0, "trades": 0}
    )

    for entry in entries:
        gross = extract_numeric(entry, "gross_pnl", "pnl", "profit", default=0.0)
        fees = extract_numeric(entry, "fees", "commission", "commissions", default=0.0)
        tax = extract_numeric(entry, "tax", "vat", default=0.0)
        net = extract_numeric(entry, "net_pnl", "net", "profit_loss", "pl", default=math.nan)
        if math.isnan(net):
            net = gross - fees - tax
        summary["gross_pnl"] += gross
        summary["fees"] += fees
        summary["tax"] += tax
        summary["net_pnl"] += net

        if net > 0:
            wins += 1
            win_total += net
        elif net < 0:
            losses += 1
            loss_total += net
        summary["max_gain"] = max(summary["max_gain"], net)
        summary["max_loss"] = min(summary["max_loss"], net)

        symbol = extract_symbol(entry)
        symbol_stats[symbol]["net_pnl"] += net
        symbol_stats[symbol]["gross_pnl"] += gross
        symbol_stats[symbol]["trades"] += 1
        if net > 0:
            symbol_stats[symbol]["wins"] += 1

        strategy = extract_strategy(entry)
        strategy_stats[strategy]["net_pnl"] += net
        strategy_stats[strategy]["gross_pnl"] += gross
        strategy_stats[strategy]["trades"] += 1
        if net > 0:
            strategy_stats[strategy]["wins"] += 1

        bucket_label = bucket_for_entry(entry)
        bucket_stats[bucket_label]["net_pnl"] += net
        bucket_stats[bucket_label]["gross_pnl"] += gross
        bucket_stats[bucket_label]["trades"] += 1

    summary["win_rate"] = safe_win_rate(wins, summary["total_trades"])
    summary["avg_win"] = win_total / wins if wins else 0.0
    summary["avg_loss"] = loss_total / losses if losses else 0.0

    filters = {
        "market": args.market,
        "account": args.account,
        "symbol": args.symbol,
        "scenario": args.scenario,
        "tags": args.tags or [],
    }

    snapshot = {
        "version": 1,
        "generated_at": datetime.now().astimezone().isoformat(),
        "range": {"from": drange.start.isoformat(), "to": drange.end.isoformat()},
        "filters": filters,
        "summary": summary,
        "by_symbol": format_group_stats(symbol_stats),
        "by_strategy": format_group_stats(strategy_stats),
        "time_buckets": format_bucket_stats(bucket_stats),
        "total_tags": sorted({tag for entry in entries for tag in entry_tags(entry)}),
    }
    return snapshot


def bucket_for_entry(entry: Dict[str, Any]) -> str:
    timestamp = entry.get("timestamp")
    if timestamp:
        try:
            parsed = datetime.fromisoformat(timestamp)
            return parsed.strftime("%Y-%m-%d %H:00")
        except ValueError:
            pass
    if entry.get("day"):
        return str(entry["day"])
    return "unspecified"


def format_group_stats(stats: Dict[str, Dict[str, Any]]) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    for key, payload in stats.items():
        trades = payload["trades"]
        wins = payload.get("wins", 0)
        rows.append(
            {
                "name": key,
                "net_pnl": payload["net_pnl"],
                "gross_pnl": payload["gross_pnl"],
                "trades": trades,
                "win_rate": safe_win_rate(wins, trades),
            }
        )
    rows.sort(key=lambda row: row["net_pnl"], reverse=True)
    return rows


def format_bucket_stats(stats: Dict[str, Dict[str, Any]]) -> List[Dict[str, Any]]:
    rows = [
        {"bucket": key, **payload}
        for key, payload in sorted(stats.items(), key=lambda item: item[0])
    ]
    return rows


def write_snapshot_outputs(
    snapshot: Dict[str, Any],
    drange: DateRange,
    args: argparse.Namespace,
) -> Tuple[Path, Path]:
    report_dir = Path(args.report_dir)
    report_dir.mkdir(parents=True, exist_ok=True)
    slug = drange.slug()
    json_path = report_dir / f"trading_snapshot_{slug}.json"
    md_path = report_dir / f"trading_snapshot_{slug}.md"
    with json_path.open("w", encoding="utf-8") as handle:
        json.dump(snapshot, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
    markdown = render_markdown(snapshot)
    with md_path.open("w", encoding="utf-8") as handle:
        handle.write(markdown)
    return json_path, md_path


def render_markdown(snapshot: Dict[str, Any]) -> str:
    summary = snapshot["summary"]
    filters = snapshot["filters"]
    tags = filters.get("tags") or []
    lines = [
        "# Trading Snapshot",
        "",
        f"Generated at: {snapshot['generated_at']}",
        f"Period: {snapshot['range']['from']} → {snapshot['range']['to']}",
    ]
    if filters.get("scenario"):
        lines.append(f"Scenario: {filters['scenario']}")
    if tags:
        lines.append(f"Tags: {', '.join(tags)}")
    lines.append("")
    lines.append("## Summary")
    lines.append("| Metric | Value |")
    lines.append("| --- | --- |")
    for label, key in (
        ("Total trades", "total_trades"),
        ("Gross PnL", "gross_pnl"),
        ("Fees", "fees"),
        ("Tax", "tax"),
        ("Net PnL", "net_pnl"),
        ("Win rate", "win_rate"),
        ("Avg win", "avg_win"),
        ("Avg loss", "avg_loss"),
        ("Max gain", "max_gain"),
        ("Max loss", "max_loss"),
    ):
        value = summary.get(key, 0)
        if "rate" in key:
            rendered = f"{value * 100:.2f}%"
        else:
            rendered = format_currency(value)
        if key == "total_trades":
            rendered = str(value)
        lines.append(f"| {label} | {rendered} |")

    lines.append("")
    lines.append(render_group_section("By Symbol", snapshot.get("by_symbol", [])))
    lines.append("")
    lines.append(render_group_section("By Strategy", snapshot.get("by_strategy", [])))
    lines.append("")
    lines.append("## Time Buckets")
    if not snapshot.get("time_buckets"):
        lines.append("No time bucket data available.")
    else:
        lines.append("| Bucket | Trades | Net PnL | Gross PnL |")
        lines.append("| --- | ---: | ---: | ---: |")
        for bucket in snapshot["time_buckets"]:
            lines.append(
                f"| {bucket['bucket']} | {bucket['trades']} | {format_currency(bucket['net_pnl'])} | {format_currency(bucket['gross_pnl'])} |"
            )
    return "\n".join(lines).strip() + "\n"


def render_group_section(title: str, rows: Sequence[Dict[str, Any]]) -> str:
    if not rows:
        return f"## {title}\nNo data available."
    lines = [f"## {title}", "| Name | Trades | Win % | Net PnL | Gross PnL |", "| --- | ---: | ---: | ---: | ---: |"]
    for row in rows:
        lines.append(
            f"| {row['name']} | {row['trades']} | {row['win_rate'] * 100:.1f}% | {format_currency(row['net_pnl'])} | {format_currency(row['gross_pnl'])} |"
        )
    return "\n".join(lines)


def format_currency(value: float) -> str:
    return f"{value:,.2f}"


def render_chatgpt_prompt(snapshot: Dict[str, Any]) -> str:
    summary = snapshot["summary"]
    filters = snapshot["filters"]
    period = (
        snapshot["range"]["from"]
        if snapshot["range"]["from"] == snapshot["range"]["to"]
        else f"{snapshot['range']['from']} → {snapshot['range']['to']}"
    )
    lines = [
        "# 02luka Trading Snapshot for ChatGPT",
        f"version: {snapshot['version']}",
        f"period: {period}",
        f"scenario: {filters.get('scenario') or 'unspecified'}",
        f"market: {filters.get('market') or 'mixed'}",
        f"account: {filters.get('account') or 'mixed'}",
    ]
    tags = filters.get("tags") or []
    if tags:
        lines.append(f"tags: {', '.join(tags)}")
    lines.append("")
    lines.append("## High-level Summary")
    lines.append(f"- Total trades: {summary['total_trades']}")
    lines.append(f"- Net PnL: {signed_currency(summary['net_pnl'])}")
    lines.append(f"- Win rate: {summary['win_rate'] * 100:.1f}%")
    lines.append(f"- Max gain: {signed_currency(summary['max_gain'])}")
    lines.append(f"- Max loss: {signed_currency(summary['max_loss'])}")

    lines.append("")
    lines.append(render_prompt_section("By Symbol", snapshot.get("by_symbol", [])))
    lines.append("")
    lines.append(render_prompt_section("By Strategy", snapshot.get("by_strategy", [])))
    lines.append("")
    lines.append("---")
    lines.append("")
    lines.append("You are my trading reflection assistant.")
    lines.append("")
    lines.append("Using ONLY the information above (you do NOT see raw trades), please:")
    lines.append("1. Point out the 2–3 biggest strengths of this session.")
    lines.append("2. Point out the 2–3 biggest risks or bad habits.")
    lines.append("3. Suggest 3 practical rules I should adopt for tomorrow in this scenario.")
    lines.append("4. Give me 3 concise questions I should answer in my own words to improve my future decisions.")
    return "\n".join(lines).strip() + "\n"


def render_prompt_section(title: str, rows: Sequence[Dict[str, Any]], limit: int = 5) -> str:
    if not rows:
        return f"## {title}\n(No data)"
    lines = [f"## {title}"]
    for row in rows[:limit]:
        lines.append(
            f"- {row['name']}: {signed_currency(row['net_pnl'])} ({row['trades']} trades, {row['win_rate'] * 100:.1f}% win)"
        )
    return "\n".join(lines)


def signed_currency(value: float) -> str:
    return f"{value:+,.2f}"


def append_mls_entry(
    snapshot: Dict[str, Any], args: argparse.Namespace, drange: DateRange
) -> Path:
    mls_path = Path(args.mls_file)
    ensure_parent(mls_path)
    filters = snapshot["filters"]
    scenario_slug = (filters.get("scenario") or "general").replace(" ", "-").upper()
    lesson_id = f"MLS-TRADING-SNAPSHOT-{drange.slug().replace('_', '-')}-{scenario_slug}"
    summary = snapshot["summary"]
    by_symbol = snapshot.get("by_symbol") or []
    top_symbol_name = by_symbol[0]["name"] if by_symbol else "n/a"
    description = (
        f"Net PnL {signed_currency(summary['net_pnl'])}; {summary['total_trades']} trades; "
        f"{summary['win_rate'] * 100:.1f}% win; top symbol: {top_symbol_name}"
    )
    lesson_tags = ["trading", "journal", "snapshot", filters.get("scenario") or "general"]
    lesson_tags.extend(filters.get("tags") or [])
    entry = {
        "id": lesson_id,
        "type": "pattern",
        "title": f"Trading snapshot {snapshot['range']['from']} ({filters.get('scenario') or 'general'})",
        "description": description,
        "context": "Generated by tools/trading_cli.zsh snapshot",
        "timestamp": snapshot["generated_at"],
        "tags": lesson_tags,
        "verified": False,
        "usefulness_score": 0.0,
    }
    with mls_path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(entry, ensure_ascii=False) + "\n")
    return mls_path


def handle_import(args: argparse.Namespace) -> None:
    csv_path = Path(args.csv).expanduser()
    if not csv_path.exists():
        raise TradingCLIError(f"CSV file not found: {csv_path}")
    journal_path = Path(args.journal)
    ensure_parent(journal_path)
    imported = []
    now = datetime.now().astimezone().isoformat()
    with csv_path.open("r", encoding=args.encoding, newline="") as handle:
        reader = csv.DictReader(handle, delimiter=args.delimiter)
        if not reader.fieldnames:
            raise TradingCLIError("CSV appears to be empty or missing headers")
        for idx, row in enumerate(reader, start=1):
            normalized = normalize_row(row)
            timestamp, day = parse_timestamp_from_row(normalized)
            entry = {
                "id": f"IMPORT-{int(datetime.now().timestamp())}-{idx}",
                "imported_at": now,
                "source_file": str(csv_path),
                "row_number": idx,
                "market": args.market,
                "account": args.account,
                "scenario": args.scenario or normalized.get("scenario"),
                "tags": list(sorted(set(args.tags))),
                "timestamp": timestamp.isoformat() if timestamp else None,
                "day": day,
                "data": normalized,
            }
            imported.append(entry)
    with journal_path.open("a", encoding="utf-8") as handle:
        for entry in imported:
            handle.write(json.dumps(entry, ensure_ascii=False) + "\n")
    print(
        f"Imported {len(imported)} rows into {journal_path}. Last row timestamp: "
        f"{imported[-1]['timestamp'] if imported else 'n/a'}"
    )


def handle_snapshot(args: argparse.Namespace, emit_outputs: bool) -> Optional[Dict[str, Any]]:
    journal_path = Path(args.journal)
    entries = load_journal(journal_path)
    if not entries:
        raise TradingCLIError(
            f"No journal data found at {journal_path}. Import trades before running snapshots."
        )
    drange = resolve_range(args)
    selected = filter_entries(entries, args, drange)
    snapshot = compute_snapshot(selected, drange, args)
    if emit_outputs:
        json_path, md_path = write_snapshot_outputs(snapshot, drange, args)
        print(f"Snapshot JSON: {json_path}")
        print(f"Snapshot Markdown: {md_path}")
        if args.emit_mls:
            mls_path = append_mls_entry(snapshot, args, drange)
            print(f"MLS entry appended to {mls_path}")
    return snapshot


def main(argv: Sequence[str]) -> int:
    try:
        args = parse_args(argv)
        if args.command == "import":
            handle_import(args)
            return 0
        if args.command == "snapshot":
            handle_snapshot(args, emit_outputs=True)
            return 0
        if args.command == "chatgpt-prompt":
            snapshot = handle_snapshot(args, emit_outputs=False)
            if not snapshot:
                print("No data available for the requested range.")
                return 0
            print(render_chatgpt_prompt(snapshot))
            return 0
        raise TradingCLIError(f"Unknown command: {args.command}")
    except TradingCLIError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1
    except Exception as exc:  # pragma: no cover - surface unexpected tracebacks
        print(f"Unexpected error: {exc}", file=sys.stderr)
        raise


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main(sys.argv[1:]))
