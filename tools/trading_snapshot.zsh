#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

JOURNAL="g/trading/trading_journal.jsonl"
REPORT_DIR="g/reports/trading"

usage() {
  cat <<'USAGE'
Usage: tools/trading_snapshot.zsh [--day <YYYY-MM-DD|today> | --from <YYYY-MM-DD> --to <YYYY-MM-DD>] \
       [--market <name>] [--account <name>] [--symbol <name>] [--json]

Examples:
  tools/trading_snapshot.zsh --day today
  tools/trading_snapshot.zsh --day 2025-11-15 --market TFEX --account BIZ-01
  tools/trading_snapshot.zsh --from 2025-11-10 --to 2025-11-15 --symbol S50Z25

Flags:
  --day       Summarize a single day (mutually exclusive with --from/--to)
  --from      Start date (inclusive) when generating a custom range
  --to        End date (inclusive) when generating a custom range
  --market    Optional market filter
  --account   Optional account filter
  --symbol    Optional symbol filter
  --json      Print JSON summary to stdout and save a .json snapshot alongside the markdown report
USAGE
}

slugify() {
  local value="$1"
  value="${value//[[:space:]]/-}"
  value="${value//[^[:alnum:]_.-]/-}"
  while [[ "$value" == *--* ]]; do
    value="${value//--/-}"
  done
  while [[ "$value" == [-._]* ]]; do
    value="${value#[-._]}"
  done
  while [[ "$value" == *[-._] ]]; do
    value="${value%[-._]}"
  done
  if [[ -z "$value" ]]; then
    value="value"
  fi
  printf '%s' "$value"
}

build_filter_suffix() {
  local suffix=""
  if [[ -n "$MARKET_FILTER" ]]; then
    local slug
    slug="$(slugify "$MARKET_FILTER")"
    suffix+="_market-${slug}"
  fi
  if [[ -n "$ACCOUNT_FILTER" ]]; then
    local slug
    slug="$(slugify "$ACCOUNT_FILTER")"
    suffix+="_account-${slug}"
  fi
  if [[ -n "$SYMBOL_FILTER" ]]; then
    local slug
    slug="$(slugify "$SYMBOL_FILTER")"
    suffix+="_symbol-${slug}"
  fi
  printf '%s' "$suffix"
}

DAY=""
FROM_DATE=""
TO_DATE=""
MARKET_FILTER=""
ACCOUNT_FILTER=""
SYMBOL_FILTER=""
JSON_OUTPUT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --day)
      DAY="${2:-}"
      shift 2
      ;;
    --from)
      FROM_DATE="${2:-}"
      shift 2
      ;;
    --to)
      TO_DATE="${2:-}"
      shift 2
      ;;
    --market)
      MARKET_FILTER="${2:-}"
      shift 2
      ;;
    --account)
      ACCOUNT_FILTER="${2:-}"
      shift 2
      ;;
    --symbol)
      SYMBOL_FILTER="${2:-}"
      shift 2
      ;;
    --json)
      JSON_OUTPUT=true
      shift 1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$DAY" && -z "$FROM_DATE" && -z "$TO_DATE" ]]; then
  echo "Error: specify --day or a --from/--to range" >&2
  usage
  exit 1
fi

if [[ -n "$DAY" && ( -n "$FROM_DATE" || -n "$TO_DATE" ) ]]; then
  echo "Error: --day cannot be combined with --from/--to" >&2
  exit 1
fi

if [[ -n "$DAY" ]]; then
  if [[ "$DAY" == "today" ]]; then
    DAY="$(date +%Y-%m-%d)"
  fi
  FROM_DATE="$DAY"
  TO_DATE="$DAY"
else
  if [[ -z "$FROM_DATE" && -n "$TO_DATE" ]]; then
    FROM_DATE="$TO_DATE"
  fi
  if [[ -z "$TO_DATE" && -n "$FROM_DATE" ]]; then
    TO_DATE="$FROM_DATE"
  fi
fi

if [[ -z "$FROM_DATE" || -z "$TO_DATE" ]]; then
  echo "Error: unable to determine date range" >&2
  exit 1
fi

if [[ ! -f "$JOURNAL" ]]; then
  echo "Error: journal not found at $JOURNAL" >&2
  exit 1
fi

mkdir -p "$REPORT_DIR"

if [[ "$FROM_DATE" == "$TO_DATE" ]]; then
  RANGE_LABEL="$FROM_DATE"
  RANGE_SLUG="$FROM_DATE"
else
  RANGE_LABEL="${FROM_DATE} to ${TO_DATE}"
  RANGE_SLUG="${FROM_DATE}_${TO_DATE}"
fi

FILTER_SUFFIX="$(build_filter_suffix)"
REPORT_NAME="trading_snapshot_${RANGE_SLUG}${FILTER_SUFFIX}"

SUMMARY_JSON_FILE="$(mktemp)"

FROM_DATE_ENV="$FROM_DATE" TO_DATE_ENV="$TO_DATE" \
MARKET_FILTER_ENV="$MARKET_FILTER" ACCOUNT_FILTER_ENV="$ACCOUNT_FILTER" SYMBOL_FILTER_ENV="$SYMBOL_FILTER" \
python3 - "$JOURNAL" "$SUMMARY_JSON_FILE" <<'PY'
import json
import os
import sys
import datetime
from collections import defaultdict

journal_path = sys.argv[1]
out_path = sys.argv[2]
from_date = os.environ.get("FROM_DATE_ENV")
to_date = os.environ.get("TO_DATE_ENV")
market_filter = (os.environ.get("MARKET_FILTER_ENV") or "").strip() or None
account_filter = (os.environ.get("ACCOUNT_FILTER_ENV") or "").strip() or None
symbol_filter = (os.environ.get("SYMBOL_FILTER_ENV") or "").strip() or None

if not from_date or not to_date:
    raise SystemExit("Missing date filters")

def to_float(value):
    if value is None:
        return 0.0
    if isinstance(value, (int, float)):
        return float(value)
    try:
        return float(str(value))
    except (TypeError, ValueError):
        return 0.0

def bucket_hour(ts):
    if not ts:
        return "Unknown"
    normalized = ts.replace("Z", "+00:00")
    try:
        dt = datetime.datetime.fromisoformat(normalized)
        return dt.strftime("%Y-%m-%d %H:00")
    except ValueError:
        if len(ts) >= 13:
            return f"{ts[:13]}:00"
        return ts

trades = []
with open(journal_path, "r", encoding="utf-8") as handle:
    for line in handle:
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        ts = entry.get("timestamp") or entry.get("executed_at") or entry.get("filled_at")
        if not ts or len(ts) < 10:
            continue
        trade_date = ts[:10]
        if trade_date < from_date or trade_date > to_date:
            continue
        if market_filter and str(entry.get("market", "")) != market_filter:
            continue
        if account_filter and str(entry.get("account", "")) != account_filter:
            continue
        if symbol_filter and str(entry.get("symbol", "")) != symbol_filter:
            continue
        trades.append(entry)

count = len(trades)
net_values = []
pos_values = []
neg_values = []
fees_total = 0.0
tax_total = 0.0
wins = 0
symbol_map = defaultdict(lambda: {"symbol": "", "trades": 0, "net_pnl": 0.0, "wins": 0, "volume": 0.0})
strategy_map = defaultdict(lambda: {"strategy": "", "trades": 0, "net_pnl": 0.0, "wins": 0})
time_buckets = defaultdict(lambda: {"label": "", "trades": 0, "net_pnl": 0.0})

for entry in trades:
    net = to_float(entry.get("net_pnl"))
    fee = to_float(entry.get("fees"))
    tax = to_float(entry.get("tax"))
    size = to_float(entry.get("size"))
    net_values.append(net)
    fees_total += fee
    tax_total += tax
    if net > 0:
        wins += 1
        pos_values.append(net)
    elif net < 0:
        neg_values.append(net)
    symbol = str(entry.get("symbol") or "(unknown)")
    sym_bucket = symbol_map[symbol]
    sym_bucket["symbol"] = symbol
    sym_bucket["trades"] += 1
    sym_bucket["net_pnl"] += net
    if net > 0:
        sym_bucket["wins"] += 1
    sym_bucket["volume"] += size
    strategy = str(entry.get("strategy_tag") or "unlabeled")
    strat_bucket = strategy_map[strategy]
    strat_bucket["strategy"] = strategy
    strat_bucket["trades"] += 1
    strat_bucket["net_pnl"] += net
    if net > 0:
        strat_bucket["wins"] += 1
    ts = entry.get("timestamp") or entry.get("executed_at") or entry.get("filled_at")
    bucket = bucket_hour(ts)
    bucket_entry = time_buckets[bucket]
    bucket_entry["label"] = bucket
    bucket_entry["trades"] += 1
    bucket_entry["net_pnl"] += net

net_total = sum(net_values) if net_values else 0.0
gross_total = net_total + fees_total + tax_total
max_gain = max(pos_values) if pos_values else (max(net_values) if net_values else 0.0)
max_loss = min(neg_values) if neg_values else (min(net_values) if net_values else 0.0)
avg_win = (sum(pos_values) / len(pos_values)) if pos_values else 0.0
avg_loss = (sum(neg_values) / len(neg_values)) if neg_values else 0.0
win_rate = (wins / count * 100) if count else 0.0

def finalize_bucket(data):
    return {
        "symbol": data.get("symbol"),
        "trades": data.get("trades", 0),
        "net_pnl": data.get("net_pnl", 0.0),
        "win_rate": (data.get("wins", 0) / data.get("trades", 1) * 100) if data.get("trades") else 0.0,
        "volume": data.get("volume", 0.0),
    }

def finalize_strategy(data):
    return {
        "strategy": data.get("strategy"),
        "trades": data.get("trades", 0),
        "net_pnl": data.get("net_pnl", 0.0),
        "win_rate": (data.get("wins", 0) / data.get("trades", 1) * 100) if data.get("trades") else 0.0,
    }

def finalize_timeline(data):
    return {
        "time_bucket": data.get("label"),
        "trades": data.get("trades", 0),
        "net_pnl": data.get("net_pnl", 0.0),
    }

summary = {
    "filters": {
        "from": from_date,
        "to": to_date,
        "range_label": from_date if from_date == to_date else f"{from_date} – {to_date}",
        "market": market_filter,
        "account": account_filter,
        "symbol": symbol_filter,
        "generated_at": datetime.datetime.now().astimezone().isoformat(),
    },
    "stats": {
        "total_trades": count,
        "gross_pnl": gross_total,
        "fees": fees_total,
        "tax": tax_total,
        "net_pnl": net_total,
        "win_rate": win_rate,
        "avg_win": avg_win,
        "avg_loss": avg_loss,
        "max_gain": max_gain,
        "max_loss": max_loss,
        "wins": wins,
    },
    "by_symbol": sorted([finalize_bucket(v) for v in symbol_map.values()], key=lambda x: x["net_pnl"], reverse=True),
    "by_strategy": sorted([finalize_strategy(v) for v in strategy_map.values()], key=lambda x: x["net_pnl"], reverse=True),
    "timeline": sorted([finalize_timeline(v) for v in time_buckets.values()], key=lambda x: x["time_bucket"] or ""),
}

with open(out_path, "w", encoding="utf-8") as handle:
    json.dump(summary, handle, indent=2)
PY

REPORT_MD_PATH="$REPORT_DIR/$REPORT_NAME.md"
python3 - "$SUMMARY_JSON_FILE" <<'PY' > "$REPORT_MD_PATH"
import json
import sys

def fmt_money(value):
    if value > 0:
        return f"+{value:,.2f}"
    if value < 0:
        return f"{value:,.2f}"
    return "0.00"

def fmt_pct(value):
    return f"{value:.1f}%"

def fmt_volume(value):
    if abs(value - round(value)) < 1e-6:
        return str(int(round(value)))
    return f"{value:.2f}"

data = json.load(open(sys.argv[1], "r", encoding="utf-8"))
filters = data["filters"]
stats = data["stats"]
lines = []
lines.append(f"# Trading Snapshot — {filters['range_label']}")
lines.append("")
lines.append(f"- Range: {filters['range_label']}")
lines.append(f"- Market filter: {filters.get('market') or '(none)'}")
lines.append(f"- Account filter: {filters.get('account') or '(none)'}")
lines.append(f"- Symbol filter: {filters.get('symbol') or '(none)'}")
lines.append(f"- Generated: {filters['generated_at']}")
lines.append("")
lines.append("## 1. Summary")
lines.append("")
lines.append(f"- Total trades: {stats['total_trades']}")
lines.append(f"- Gross PnL: {fmt_money(stats['gross_pnl'])}")
lines.append(f"- Fees: {fmt_money(-abs(stats['fees'])) if stats['fees'] > 0 else fmt_money(stats['fees'])}")
lines.append(f"- Tax: {fmt_money(-abs(stats['tax'])) if stats['tax'] > 0 else fmt_money(stats['tax'])}")
lines.append(f"- **Net PnL: {fmt_money(stats['net_pnl'])}**")
lines.append(f"- Win rate: {fmt_pct(stats['win_rate'])}")
lines.append(f"- Avg win: {fmt_money(stats['avg_win'])}")
lines.append(f"- Avg loss: {fmt_money(stats['avg_loss'])}")
lines.append(f"- Max gain: {fmt_money(stats['max_gain'])}")
lines.append(f"- Max loss: {fmt_money(stats['max_loss'])}")
lines.append("")
lines.append("## 2. By Symbol")
lines.append("")
by_symbol = data.get("by_symbol") or []
if by_symbol:
    lines.append("| Symbol | Trades | Net PnL | Win% | Volume |")
    lines.append("|--------|--------|---------|------|--------|")
    for row in by_symbol:
        lines.append(f"| {row['symbol']} | {row['trades']} | {fmt_money(row['net_pnl'])} | {fmt_pct(row['win_rate'])} | {fmt_volume(row['volume'])} |")
else:
    lines.append("No data.")
lines.append("")
lines.append("## 3. By Strategy")
lines.append("")
by_strategy = data.get("by_strategy") or []
if by_strategy:
    lines.append("| Strategy | Trades | Net PnL | Win% |")
    lines.append("|----------|--------|---------|------|")
    for row in by_strategy:
        lines.append(f"| {row['strategy']} | {row['trades']} | {fmt_money(row['net_pnl'])} | {fmt_pct(row['win_rate'])} |")
else:
    lines.append("No data.")
lines.append("")
lines.append("## 4. Time Buckets")
lines.append("")
timeline = data.get("timeline") or []
if timeline:
    lines.append("| Time Bucket | Trades | Net PnL |")
    lines.append("|-------------|--------|---------|")
    for row in timeline:
        lines.append(f"| {row['time_bucket']} | {row['trades']} | {fmt_money(row['net_pnl'])} |")
else:
    lines.append("No data.")
lines.append("")
print("\n".join(lines))
PY

JSON_REPORT_PATH="$REPORT_DIR/$REPORT_NAME.json"
if $JSON_OUTPUT; then
  cp "$SUMMARY_JSON_FILE" "$JSON_REPORT_PATH"
  rm "$SUMMARY_JSON_FILE"
else
  rm "$SUMMARY_JSON_FILE"
fi

if $JSON_OUTPUT; then
  echo "Markdown snapshot saved to: $REPORT_MD_PATH" >&2
  echo "JSON snapshot saved to: $JSON_REPORT_PATH" >&2
  cat "$JSON_REPORT_PATH"
else
  echo "Report generated: $REPORT_MD_PATH"
fi
