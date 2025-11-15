#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: tools/trading_import.zsh <CSV_PATH> [--market MARKET] [--account ACCOUNT] [--append] [--emit-mls]

Arguments:
  CSV_PATH           Path to the exported trading statement CSV.
  --market           Default market label (e.g., TFEX, SET, CME) if CSV lacks one.
  --account          Default account name if CSV lacks one.
  --append           Append entries to the existing JSONL instead of overwriting.
  --emit-mls         Add a lightweight MLS lesson entry summarizing the import.
  -h, --help         Show this message.
USAGE
}

if [[ $# -eq 0 ]]; then
  usage
  exit 1
fi

orig_cmd=$(printf '%q ' "$0" "$@")
orig_cmd=${orig_cmd% }
append_mode=false
emit_mls=false
default_market=""
default_account=""
csv_path=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --market)
      [[ $# -ge 2 ]] || { echo "Missing value for --market" >&2; exit 1; }
      default_market="$2"
      shift 2
      ;;
    --account)
      [[ $# -ge 2 ]] || { echo "Missing value for --account" >&2; exit 1; }
      default_account="$2"
      shift 2
      ;;
    --append)
      append_mode=true
      shift
      ;;
    --emit-mls)
      emit_mls=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
    *)
      if [[ -n "$csv_path" ]]; then
        echo "Multiple CSV paths provided" >&2
        exit 1
      fi
      csv_path="$1"
      shift
      ;;
  esac
done

if [[ -z "$csv_path" ]]; then
  echo "CSV path is required." >&2
  exit 1
fi

if [[ ! -f "$csv_path" ]]; then
  echo "CSV file not found: $csv_path" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to run this importer." >&2
  exit 1
fi

if [[ -n "${BASH_SOURCE:-}" ]]; then
  script_source="${BASH_SOURCE[0]}"
elif [[ -n "${ZSH_VERSION:-}" ]]; then
  script_source="${(%):-%x}"
else
  script_source="$0"
fi

script_dir=$(cd -- "$(dirname -- "$script_source")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)

journal_file="$repo_root/g/trading/trading_journal.jsonl"
mkdir -p "$(dirname "$journal_file")"

knowledge_file="$repo_root/g/knowledge/mls_lessons.jsonl"

json_tmp=$(mktemp)
meta_tmp=$(mktemp)
trap 'rm -f "$json_tmp" "$meta_tmp"' EXIT

CSV_PATH="$csv_path" \
DEFAULT_MARKET="$default_market" \
DEFAULT_ACCOUNT="$default_account" \
JSON_OUTPUT="$json_tmp" \
META_OUTPUT="$meta_tmp" \
python3 <<'PY'
import csv
import datetime as dt
import hashlib
import json
import os
import pathlib
import re

csv_path = os.environ['CSV_PATH']
json_out = os.environ['JSON_OUTPUT']
meta_out = os.environ['META_OUTPUT']
default_market = os.environ.get('DEFAULT_MARKET', '').strip()
default_account = os.environ.get('DEFAULT_ACCOUNT', '').strip()

HEADER_ALIASES = {
    'date': 'date',
    'trade_date': 'date',
    'time': 'time',
    'trade_time': 'time',
    'timestamp': 'timestamp',
    'market': 'market',
    'exchange': 'market',
    'account': 'account',
    'account_id': 'account',
    'symbol': 'symbol',
    'contract': 'symbol',
    'instrument': 'instrument_type',
    'instrument_type': 'instrument_type',
    'side': 'side',
    'buy_sell': 'side',
    'position_effect': 'position_effect',
    'open_close': 'position_effect',
    'volume': 'size',
    'qty': 'size',
    'quantity': 'size',
    'size': 'size',
    'price': 'price',
    'avg_price': 'price',
    'fee': 'fee',
    'commission': 'fee',
    'tax': 'tax',
    'net_p_l': 'net_pnl',
    'net_p/l': 'net_pnl',
    'net_pl': 'net_pnl',
    'pnl': 'net_pnl',
    'net': 'net_pnl',
    'order_id': 'order_id',
    'order': 'order_id',
    'strategy': 'strategy_tag',
    'tag': 'strategy_tag',
    'remark': 'notes',
    'notes': 'notes',
    'comment': 'notes'
}

DATE_FORMATS = ["%Y-%m-%d", "%d/%m/%Y", "%m/%d/%Y", "%Y%m%d"]
TIME_FORMATS = ["%H:%M:%S", "%H:%M", "%H%M%S"]
DATETIME_FORMATS = [
    "%Y-%m-%d %H:%M:%S",
    "%Y-%m-%d %H:%M",
    "%d/%m/%Y %H:%M:%S",
    "%d/%m/%Y %H:%M",
    "%m/%d/%Y %H:%M:%S",
    "%m/%d/%Y %H:%M",
    "%Y%m%d %H%M%S"
]

SIDE_MAP = {
    'b': 'buy',
    'buy': 'buy',
    'long': 'buy',
    's': 'sell',
    'sell': 'sell',
    'short': 'sell'
}

POSITION_MAP = {
    'open': 'open',
    'buy to open': 'open',
    'long': 'open',
    'close': 'close',
    'sell to close': 'close',
    'short': 'close',
    'reduce': 'reduce',
    'reduce only': 'reduce'
}

def normalize_header(name: str) -> str:
    return re.sub(r'[^a-z0-9]+', '_', name.lower()).strip('_')


def parse_number(raw):
    if raw is None:
        return 0.0
    text = raw.strip()
    if not text:
        return 0.0
    text = text.replace(',', '')
    if text.startswith('(') and text.endswith(')'):
        text = '-' + text[1:-1]
    text = text.replace(' ', '')
    try:
        return float(text)
    except ValueError:
        return 0.0


def parse_timestamp(date_str: str, time_str: str, ts_str: str):
    def try_parse_datetime(value: str):
        if not value:
            return None
        value = value.strip()
        if not value:
            return None
        try:
            return dt.datetime.fromisoformat(value)
        except ValueError:
            pass
        for fmt in DATETIME_FORMATS:
            try:
                return dt.datetime.strptime(value, fmt)
            except ValueError:
                continue
        return None

    def try_parse_date(value: str):
        if not value:
            return None
        value = value.strip()
        if not value:
            return None
        for fmt in DATE_FORMATS:
            try:
                return dt.datetime.strptime(value, fmt).date()
            except ValueError:
                continue
        return None

    def try_parse_time(value: str):
        if not value:
            return None
        value = value.strip()
        if not value:
            return None
        for fmt in TIME_FORMATS:
            try:
                return dt.datetime.strptime(value, fmt).time()
            except ValueError:
                continue
        return None

    ts_obj = try_parse_datetime(ts_str)
    if ts_obj:
        return ts_obj.isoformat()

    date_obj = try_parse_date(date_str)
    time_obj = try_parse_time(time_str)

    if date_obj and time_obj:
        return dt.datetime.combine(date_obj, time_obj).isoformat()
    if date_obj and not time_obj:
        return dt.datetime.combine(date_obj, dt.time()).isoformat()

    if date_str or time_str:
        combined = ' '.join(part for part in [date_str, time_str] if part)
        ts_obj = try_parse_datetime(combined)
        if ts_obj:
            return ts_obj.isoformat()
        return combined.strip()

    return ts_str.strip()


entries = []
first_ts = ''
last_ts = ''

with open(csv_path, 'r', encoding='utf-8-sig', newline='') as csv_file:
    reader = csv.DictReader(csv_file)
    for row in reader:
        if not any(row.values()):
            continue
        normalized = {}
        for header, value in row.items():
            if header is None:
                continue
            canonical = HEADER_ALIASES.get(normalize_header(header))
            if canonical:
                normalized[canonical] = (value or '').strip()

        symbol = normalized.get('symbol')
        if not symbol:
            continue

        side_value = normalized.get('side', '').lower()
        side = SIDE_MAP.get(side_value)
        if not side:
            continue

        timestamp = parse_timestamp(
            normalized.get('date', ''),
            normalized.get('time', ''),
            normalized.get('timestamp', '')
        )
        if not timestamp:
            continue

        market = normalized.get('market') or default_market or 'UNKNOWN'
        account = normalized.get('account') or default_account
        instrument = normalized.get('instrument_type', '').lower() or None
        position_effect = POSITION_MAP.get(normalized.get('position_effect', '').lower(), 'unknown')
        size = parse_number(normalized.get('size'))
        price = parse_number(normalized.get('price'))
        fee = parse_number(normalized.get('fee'))
        tax = parse_number(normalized.get('tax'))
        net_pnl = parse_number(normalized.get('net_pnl'))
        order_id = normalized.get('order_id') or ''
        strategy_tag = normalized.get('strategy_tag') or ''
        notes = normalized.get('notes') or ''

        hash_source = f"{timestamp}|{symbol}|{side}|{order_id}|{size}|{price}"
        entry_id = 'journal-' + hashlib.sha1(hash_source.encode('utf-8')).hexdigest()[:16]

        entry = {
            'id': entry_id,
            'timestamp': timestamp,
            'market': market,
            'symbol': symbol,
            'side': side,
            'size': size,
            'price': price
        }

        if account:
            entry['account'] = account
        if instrument:
            entry['instrument_type'] = instrument
        entry['position_effect'] = position_effect
        entry['fee'] = fee
        entry['tax'] = tax
        entry['net_pnl'] = net_pnl
        if order_id:
            entry['order_id'] = order_id
        if strategy_tag:
            entry['strategy_tag'] = strategy_tag
        if notes:
            entry['notes'] = notes

        entries.append(entry)
        first_ts = first_ts or timestamp
        last_ts = timestamp

with open(json_out, 'w', encoding='utf-8') as output:
    for entry in entries:
        json.dump(entry, output, ensure_ascii=False)
        output.write('\n')

with open(meta_out, 'w', encoding='utf-8') as meta_file:
    json.dump({
        'count': len(entries),
        'first_timestamp': first_ts,
        'last_timestamp': last_ts,
        'source_name': pathlib.Path(csv_path).name
    }, meta_file)
PY

meta_values=$(META_PATH="$meta_tmp" python3 - <<'PY'
import json
import os
with open(os.environ['META_PATH'], 'r', encoding='utf-8') as meta_file:
    data = json.load(meta_file)
print(
    f"{data.get('count', 0)}|"
    f"{data.get('source_name', '')}|"
    f"{data.get('first_timestamp', '')}|"
    f"{data.get('last_timestamp', '')}"
)
PY
)

IFS='|' read -r count source_name first_ts last_ts <<<"$meta_values"

if [[ "$count" -eq 0 ]]; then
  echo "No entries were imported from $csv_path" >&2
  exit 1
fi

if [[ "$append_mode" == true && -f "$journal_file" ]]; then
  cat "$json_tmp" >> "$journal_file"
  mode_label="append"
else
  mv "$json_tmp" "$journal_file"
  mode_label="overwrite"
fi

printf 'Imported %s entries from %s -> %s (%s).\n' "$count" "$source_name" "$journal_file" "$mode_label"

if [[ "$emit_mls" == true ]]; then
  mkdir -p "$(dirname "$knowledge_file")"
  import_stamp=$(date -Iseconds)
  summary_ts="$last_ts"
  if [[ -z "$summary_ts" ]]; then
    summary_ts="$import_stamp"
  fi
  cmd_context="CLI: $orig_cmd"
  lesson_id="MLS-TRADING-IMPORT-$(date '+%Y%m%d-%H%M%S')"
  description="Imported ${count} trades from ${source_name} into normalized trading_journal.jsonl."
  LESSON_FILE="$knowledge_file" \
  LESSON_ID="$lesson_id" \
  LESSON_TS="$summary_ts" \
  LESSON_TITLE="Trading journal import ${source_name}" \
  LESSON_DESC="$description" \
  LESSON_CTX="$cmd_context" \
  python3 <<'PY'
import json
import os
entry = {
    'id': os.environ['LESSON_ID'],
    'type': 'pattern',
    'title': os.environ['LESSON_TITLE'],
    'description': os.environ['LESSON_DESC'],
    'context': os.environ['LESSON_CTX'],
    'timestamp': os.environ['LESSON_TS'],
    'tags': ['trading', 'journal', 'import'],
    'verified': False,
    'usefulness_score': 0.0
}
with open(os.environ['LESSON_FILE'], 'a', encoding='utf-8') as handle:
    json.dump(entry, handle, ensure_ascii=False)
    handle.write('\n')
PY
  echo "MLS entry appended to $knowledge_file"
fi

trap - EXIT
rm -f "$meta_tmp" "$json_tmp"
