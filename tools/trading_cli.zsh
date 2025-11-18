#!/usr/bin/env bash
# 02luka Trading CLI — implements unified trading workflows per v2 spec
# Usage: tools/trading_cli.zsh <subcommand> [options]

set -euo pipefail

require_cmd() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "❌ Missing dependency: $name" >&2
    exit 3
  fi
}

require_cmd jq
require_cmd date
require_cmd sed
require_cmd awk
require_cmd cut

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
DATA_ROOT="$REPO_ROOT/g"
CLI_DISPLAY_PATH="tools/trading_cli.zsh"
CLI_VERSION="v2"

TRADING_DIR="$DATA_ROOT/trading"
IMPORT_DIR="$TRADING_DIR/import"
JOURNAL_FILE="$TRADING_DIR/trading_journal.jsonl"
REPORT_DIR="$DATA_ROOT/reports/trading"
KNOWLEDGE_DIR="$DATA_ROOT/knowledge"
MLS_FILE="$KNOWLEDGE_DIR/mls_lessons.jsonl"
SCHEMA_FILE="$DATA_ROOT/schemas/trading_journal.schema.json"
IMPORT_SCRIPT="$SCRIPT_DIR/trading_import.zsh"
SNAPSHOT_SCRIPT="$SCRIPT_DIR/trading_snapshot.zsh"

ensure_dir() {
  local dir="$1"
  mkdir -p "$dir"
}

die() {
  echo "❌ $1" >&2
  exit 2
}

usage() {
  cat <<USAGE
Usage: $CLI_DISPLAY_PATH <subcommand> [options]

Subcommands:
  import          CSV -> normalized JSONL
  snapshot        Generate daily or range PnL summaries
  chatgpt-prompt  Emit ChatGPT-ready reflection prompt
  version         Show CLI + schema info

Run '$CLI_DISPLAY_PATH <subcommand> --help' for details.
USAGE
}

format_ts() {
  local path="$1"
  if [[ -f "$path" ]]; then
    local epoch=$(stat -c %Y "$path" 2>/dev/null || stat -f %m "$path" 2>/dev/null || echo "")
    if [[ -n "$epoch" ]]; then
      date -d "@$epoch" '+%Y-%m-%d %H:%M' 2>/dev/null || date -r "$epoch" '+%Y-%m-%d %H:%M'
      return
    fi
  fi
  echo "never"
}

relpath() {
  local target="$1"
  local stripped="${target#$REPO_ROOT/}"
  if [[ -z "$stripped" || "$stripped" == "$target" ]]; then
    echo "$target"
  else
    echo "$stripped"
  fi
}

build_context() {
  local subcmd="$1"
  shift
  local parts=()
  parts+=("$CLI_DISPLAY_PATH" "$subcmd" "$@")
  local out=""
  local part
  for part in "${parts[@]}"; do
    out+=" $(printf '%q' "$part")"
  done
  echo "${out# }"
}

normalize_jsonl() {
  if [[ -z "${1:-}" ]]; then
    echo ""
    return
  fi
  printf '%s\n' "$1" | jq -S -c '.'
}

write_atomic() {
  local target="$1"
  local content="$2"
  local dir=$(dirname "$target")
  ensure_dir "$dir"
  local tmp="$target.$$.tmp"
  printf '%s\n' "$content" > "$tmp"
  mv "$tmp" "$target"
}

append_atomic_jsonl() {
  local target="$1"
  local payload="$2"
  local append_existing="$3"
  local dir=$(dirname "$target")
  ensure_dir "$dir"
  local tmp="$target.$$.tmp"
  if [[ "$append_existing" == "1" && -f "$target" ]]; then
    cat "$target" > "$tmp"
  else
    : > "$tmp"
  fi
  if [[ -n "$payload" ]]; then
    printf '%s\n' "$payload" >> "$tmp"
  fi
  mv "$tmp" "$target"
}

append_mls() {
  local json_payload="$1"
  local sorted=$(printf '%s\n' "$json_payload" | jq -S '.')
  local dir=$(dirname "$MLS_FILE")
  ensure_dir "$dir"
  local tmp="$MLS_FILE.$$.tmp"
  if [[ -f "$MLS_FILE" ]]; then
    cat "$MLS_FILE" > "$tmp"
  else
    : > "$tmp"
  fi
  printf '%s\n' "$sorted" >> "$tmp"
  mv "$tmp" "$MLS_FILE"
  echo "📘 MLS entry appended: $(printf '%s\n' "$sorted" | jq -r '.id')"
}

snapshot_range_slug() {
  local from="$1"
  local to="$2"
  if [[ "$from" == "$to" ]]; then
    echo "$from"
  else
    echo "${from}_to_${to}"
  fi
}

sanitize_slug() {
  local input="$1"
  if [[ -z "$input" ]]; then
    echo "GENERAL"
    return
  fi
  echo "$input" | tr '[:lower:]' '[:upper:]' | tr -cs 'A-Z0-9' '-'
}

snapshot_filter_slug() {
  local market="$1"
  local account="$2"
  local symbol="$3"
  local scenario="$4"
  shift 4 || true
  local -a tags=("$@")
  local -a parts=()
  if [[ -n "$market" ]]; then
    parts+=("MKT-$(sanitize_slug "$market")")
  fi
  if [[ -n "$account" ]]; then
    parts+=("ACC-$(sanitize_slug "$account")")
  fi
  if [[ -n "$symbol" ]]; then
    parts+=("SYM-$(sanitize_slug "$symbol")")
  fi
  if [[ -n "$scenario" ]]; then
    parts+=("SCN-$(sanitize_slug "$scenario")")
  fi
  local tag
  for tag in "${tags[@]}"; do
    [[ -n "$tag" ]] || continue
    parts+=("TAG-$(sanitize_slug "$tag")")
  done
  if [[ ${#parts[@]} -eq 0 ]]; then
    echo ""
  else
    local IFS='__'
    echo "${parts[*]}"
  fi
}

format_money() {
  local value="$1"
  if [[ -z "$value" || "$value" == "null" ]]; then
    echo "—"
    return
  fi
  if [[ "$value" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
    LC_ALL=C printf '%.2f' "$value"
  else
    echo "$value"
  fi
}

format_pct() {
  local value="$1"
  if [[ -z "$value" || "$value" == "null" ]]; then
    echo "—"
    return
  fi
  if [[ "$value" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
    local scaled=$(awk -v v="$value" 'BEGIN { printf "%.4f", v * 100 }')
    LC_ALL=C printf '%.1f%%' "$scaled"
  else
    echo "$value"
  fi
}

count_lines() {
  if [[ -z "$1" ]]; then
    echo 0
  else
    printf '%s\n' "$1" | grep -cve '^\s*$'
  fi
}

ensure_backend() {
  local path="$1"
  local name="$2"
  if [[ ! -x "$path" ]]; then
    die "$name backend missing at $path"
  fi
}

cmd_import() {
  if [[ $# -lt 1 ]]; then
    cat <<HELP
Usage: $CLI_DISPLAY_PATH import <csv-file> --market <MARKET> --account <ACCOUNT> [--append] [--emit-mls]
HELP
    exit 1
  fi
  local csv_file="$1"
  shift
  local market=""
  local account=""
  local append_mode=0
  local emit_mls=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --market)
        market="$2"; shift 2 ;;
      --account)
        account="$2"; shift 2 ;;
      --append)
        append_mode=1; shift ;;
      --emit-mls)
        emit_mls=1; shift ;;
      --help)
        cat <<HELP
Usage: $CLI_DISPLAY_PATH import <csv-file> --market <MARKET> --account <ACCOUNT> [--append] [--emit-mls]
HELP
        return 0 ;;
      *)
        die "Unknown option for import: $1" ;;
    esac
  done
  [[ -f "$csv_file" ]] || die "CSV file not found: $csv_file"
  [[ -n "$market" ]] || die "--market is required"
  [[ -n "$account" ]] || die "--account is required"

  ensure_backend "$IMPORT_SCRIPT" "Import"

  ensure_dir "$IMPORT_DIR"
  local context_args=("$csv_file" --market "$market" --account "$account")
  [[ $append_mode -eq 1 ]] && context_args+=(--append)
  [[ $emit_mls -eq 1 ]] && context_args+=(--emit-mls)
  local context=$(build_context "import" "${context_args[@]}")
  local import_output
  if ! import_output=$("$IMPORT_SCRIPT" "$csv_file" --market "$market" --account "$account"); then
    die "Import backend failed"
  fi
  local normalized=$(normalize_jsonl "$import_output")
  local count=$(count_lines "$normalized")
  append_atomic_jsonl "$JOURNAL_FILE" "$normalized" "$append_mode"
  echo "✅ Imported $count records into $(relpath "$JOURNAL_FILE")"

  if [[ "$emit_mls" -eq 1 ]]; then
    local now_ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    local id="MLS-TRADING-IMPORT-$(date -u '+%Y%m%d-%H%M')"
    local desc="Imported ${count} trades from $(basename "$csv_file")"
    local entry=$(jq -n --arg id "$id" --arg desc "$desc" --arg ctx "$context" --arg now "$now_ts" '{id:$id,type:"pattern",title:"Trading journal import",description:$desc,context:$ctx,tags:["trading","import"],timestamp:$now,verified:false}')
    append_mls "$entry"
  fi
}

render_table() {
  local json_lines="$1"
  local title="$2"
  local label_key="$3"
  local output="$title"$'\n\n'
  if [[ -z "$json_lines" ]]; then
    output+="_No data available._"$'\n'
  else
    output+='| Item | Trades | Net PnL | Win rate |'$'\n'
    output+='|---|---|---|---|'$'\n'
    local row
    while IFS= read -r row; do
      local name=$(jq -r --arg key "$label_key" '.[$key] // .symbol // .strategy // .bucket // "—"' <<<"$row")
      local trades=$(jq -r '.trades // "0"' <<<"$row")
      local pnl=$(jq -r '.net_pnl // .pnl // "0"' <<<"$row")
      local win=$(jq -r '.win_rate // .winrate // "null"' <<<"$row")
      output+="| $name | $trades | $(format_money "$pnl") | $(format_pct "$win") |"$'\n'
    done <<<"$json_lines"
  fi
  printf '%s' "$output"
}

generate_snapshot_markdown() {
  local json="$1"
  local generated=$(jq -r '.generated_at // "unknown"' <<<"$json")
  local from=$(jq -r '.range.from // "?"' <<<"$json")
  local to=$(jq -r '.range.to // "?"' <<<"$json")
  local range_display="$from"
  if [[ "$from" != "$to" ]]; then
    range_display="$from → $to"
  fi
  local market=$(jq -r '.filters.market // "all"' <<<"$json")
  local account=$(jq -r '.filters.account // "all"' <<<"$json")
  local symbol=$(jq -r '.filters.symbol // "*"' <<<"$json")
  local scenario=$(jq -r '.filters.scenario // "general"' <<<"$json")
  local tags=$(jq -r '.filters.tags // [] | join(", ")' <<<"$json")
  local summary=$(jq '.summary' <<<"$json")
  local net_pnl=$(jq -r '.net_pnl // "0"' <<<"$summary")
  local trades=$(jq -r '.trades // "0"' <<<"$summary")
  local win_rate=$(jq -r '.win_rate // "null"' <<<"$summary")
  local md=$'# Trading snapshot\n\n'
  md+="- Range: $range_display"$'\n'
  md+="- Generated: $generated"$'\n'
  md+="- Market: $market"$'\n'
  md+="- Account: $account"$'\n'
  md+="- Symbol filter: $symbol"$'\n'
  md+="- Scenario: $scenario"$'\n'
  md+="- Tags: ${tags:-none}"$'\n\n'
  md+=$'## Summary\n\n'
  md+="- Net PnL: $(format_money "$net_pnl")"$'\n'
  md+="- Trades: $trades"$'\n'
  md+="- Win rate: $(format_pct "$win_rate")"$'\n\n'

  local by_symbol_lines by_strategy_lines time_bucket_lines
  by_symbol_lines=$(jq -c '.by_symbol[]?' <<<"$json")
  md+="$(render_table "$by_symbol_lines" "## By symbol" "symbol")"$'\n'
  by_strategy_lines=$(jq -c '.by_strategy[]?' <<<"$json")
  md+="$(render_table "$by_strategy_lines" "## By strategy" "strategy")"$'\n'
  time_bucket_lines=$(jq -c '.time_buckets[]?' <<<"$json")
  md+="$(render_table "$time_bucket_lines" "## Time buckets" "bucket")"$'\n'
  printf '%s' "$md"
}

run_snapshot_backend() {
  local from="$1"
  local to="$2"
  local market="$3"
  local account="$4"
  local symbol="$5"
  local scenario="$6"
  local tags_csv="$7"
  ensure_backend "$SNAPSHOT_SCRIPT" "Snapshot"
  local cmd=("$SNAPSHOT_SCRIPT" --from "$from" --to "$to")
  [[ -n "$market" ]] && cmd+=(--market "$market")
  [[ -n "$account" ]] && cmd+=(--account "$account")
  [[ -n "$symbol" ]] && cmd+=(--symbol "$symbol")
  [[ -n "$scenario" ]] && cmd+=(--scenario "$scenario")
  if [[ -n "$tags_csv" ]]; then
    local IFS=$'\n'
    local tag
    for tag in $tags_csv; do
      [[ -n "$tag" ]] && cmd+=(--tag "$tag")
    done
  fi
  "${cmd[@]}"
}

cmd_snapshot() {
  local day=""
  local range_from=""
  local range_to=""
  local market=""
  local account=""
  local symbol=""
  local scenario=""
  local emit_json=0
  local emit_mls=0
  local -a tags=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --day)
        day="$2"; shift 2 ;;
      --from)
        range_from="$2"; shift 2 ;;
      --to)
        range_to="$2"; shift 2 ;;
      --market)
        market="$2"; shift 2 ;;
      --account)
        account="$2"; shift 2 ;;
      --symbol)
        symbol="$2"; shift 2 ;;
      --scenario)
        scenario="$2"; shift 2 ;;
      --tag)
        tags+=("$2"); shift 2 ;;
      --json)
        emit_json=1; shift ;;
      --emit-mls)
        emit_mls=1; shift ;;
      --help)
        cat <<HELP
Usage: $CLI_DISPLAY_PATH snapshot [--day YYYY-MM-DD|today | --from YYYY-MM-DD --to YYYY-MM-DD] [--market MKT] [--account ACC] [--symbol SYM] [--scenario SCEN] [--tag TAG ...] [--json] [--emit-mls]
HELP
        return 0 ;;
      *)
        die "Unknown option for snapshot: $1" ;;
    esac
  done
  if [[ -n "$day" ]]; then
    if [[ "$day" == "today" ]]; then
      day=$(date '+%Y-%m-%d')
    fi
    range_from="$day"
    range_to="$day"
  fi
  [[ -n "$range_from" ]] || die "--day or --from is required"
  [[ -n "$range_to" ]] || die "--day or --to is required"
  local tags_csv=""
  if [[ ${#tags[@]} -gt 0 ]]; then
    tags_csv=$(printf '%s\n' "${tags[@]}")
  fi
  local snapshot_json
  if ! snapshot_json=$(run_snapshot_backend "$range_from" "$range_to" "$market" "$account" "$symbol" "$scenario" "$tags_csv"); then
    die "Snapshot backend failed"
  fi
  local normalized=$(printf '%s\n' "$snapshot_json" | jq -S '.')
  local slug=$(snapshot_range_slug "$range_from" "$range_to")
  local filter_slug=$(snapshot_filter_slug "$market" "$account" "$symbol" "$scenario" "${tags[@]}")
  local base_name="trading_snapshot_${slug}"
  if [[ -n "$filter_slug" ]]; then
    base_name+="_${filter_slug}"
  fi
  local json_path="$REPORT_DIR/${base_name}.json"
  write_atomic "$json_path" "$normalized"
  local markdown=$(generate_snapshot_markdown "$normalized")
  local md_path="$REPORT_DIR/${base_name}.md"
  write_atomic "$md_path" "$markdown"
  echo "📄 Snapshot saved: $(relpath "$md_path")"
  echo "🗂  JSON saved: $(relpath "$json_path")"
  if [[ "$emit_json" -eq 1 ]]; then
    printf '%s\n' "$normalized"
  fi
  if [[ "$emit_mls" -eq 1 ]]; then
    local id="MLS-TRADING-SNAPSHOT-$(echo "$range_from" | tr -d '-')"
    local scenario_slug=$(sanitize_slug "$scenario")
    id+="-${scenario_slug}"
    local net_pnl=$(jq -r '.summary.net_pnl // "0"' <<<"$normalized")
    local desc="Net PnL ${net_pnl} for range ${range_from}..${range_to}"
    local context_args=(--from "$range_from" --to "$range_to")
    [[ -n "$market" ]] && context_args+=(--market "$market")
    [[ -n "$account" ]] && context_args+=(--account "$account")
    [[ -n "$symbol" ]] && context_args+=(--symbol "$symbol")
    [[ -n "$scenario" ]] && context_args+=(--scenario "$scenario")
    local tag
    for tag in "${tags[@]}"; do
      context_args+=(--tag "$tag")
    done
    context_args+=(--emit-mls)
    local context=$(build_context "snapshot" "${context_args[@]}")
    local -a tag_array=("trading" "snapshot")
    [[ -n "$scenario" ]] && tag_array+=("$scenario")
    local entry=$(jq -n --arg id "$id" --arg desc "$desc" --arg ctx "$context" --arg now "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" --arg title "Trading snapshot — ${scenario:-general}" --argjson tags "$(printf '%s\n' "${tag_array[@]}" | jq -R . | jq -s '.')" '{id:$id,type:"pattern",title:$title,description:$desc,context:$ctx,tags:$tags,timestamp:$now}')
    append_mls "$entry"
  fi
}

generate_prompt_markdown() {
  local json="$1"
  local scenario_override="$2"
  local from=$(jq -r '.range.from // "?"' <<<"$json")
  local to=$(jq -r '.range.to // "?"' <<<"$json")
  local scenario=$(jq -r '.filters.scenario // ""' <<<"$json")
  [[ -n "$scenario_override" ]] && scenario="$scenario_override"
  local market=$(jq -r '.filters.market // "all"' <<<"$json")
  local account=$(jq -r '.filters.account // "all"' <<<"$json")
  local tags=$(jq -r '.filters.tags // [] | join(", ")' <<<"$json")
  local summary=$(jq '.summary' <<<"$json")
  local net_pnl=$(jq -r '.net_pnl // "0"' <<<"$summary")
  local trades=$(jq -r '.trades // "0"' <<<"$summary")
  local win_rate=$(jq -r '.win_rate // "null"' <<<"$summary")
  local symbols=$(jq -c '.by_symbol[]?' <<<"$json")
  local range_display="$from"
  if [[ "$from" != "$to" ]]; then
    range_display="$from → $to"
  fi
  local prompt=$'## Trading reflection prompt\n\n'
  prompt+="- Range: ${range_display}"$'\n'
  prompt+="- Scenario: ${scenario:-general}"$'\n'
  prompt+="- Market: $market"$'\n'
  prompt+="- Account: $account"$'\n'
  prompt+="- Tags: ${tags:-none}"$'\n\n'
  prompt+=$'### Summary\n'
  prompt+="- Net PnL: $(format_money "$net_pnl")"$'\n'
  prompt+="- Trades: $trades"$'\n'
  prompt+="- Win rate: $(format_pct "$win_rate")"$'\n\n'
  prompt+=$'### Symbols\n'
  if [[ -z "$symbols" ]]; then
    prompt+=$'- (no symbol data)\n'
  else
    local row
    while IFS= read -r row; do
      local symbol=$(jq -r '.symbol // "—"' <<<"$row")
      local pnl=$(jq -r '.net_pnl // "0"' <<<"$row")
      local trades_row=$(jq -r '.trades // "0"' <<<"$row")
      local win=$(jq -r '.win_rate // "null"' <<<"$row")
      prompt+="- ${symbol}: PnL $(format_money "$pnl"), trades ${trades_row}, win rate $(format_pct "$win")"$'\n'
    done <<<"$symbols"
  fi
  prompt+=$'\nYou are my trading reflection assistant.\n\nTasks:\n1. Identify 2–3 strengths.\n2. Identify 2–3 risks.\n3. Suggest 3 rules for tomorrow under this scenario.\n4. Give 3 introspective questions for me to answer.\n'
  printf '%s' "$prompt"
}

cmd_chatgpt_prompt() {
  local day="today"
  local scenario=""
  local market=""
  local account=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --day)
        day="$2"; shift 2 ;;
      --scenario)
        scenario="$2"; shift 2 ;;
      --market)
        market="$2"; shift 2 ;;
      --account)
        account="$2"; shift 2 ;;
      --help)
        cat <<HELP
Usage: $CLI_DISPLAY_PATH chatgpt-prompt --day YYYY-MM-DD|today [--scenario SCEN] [--market MKT] [--account ACC]
HELP
        return 0 ;;
      *)
        die "Unknown option for chatgpt-prompt: $1" ;;
    esac
  done
  if [[ "$day" == "today" ]]; then
    day=$(date '+%Y-%m-%d')
  fi
  local snapshot_json
  if ! snapshot_json=$(run_snapshot_backend "$day" "$day" "$market" "$account" "" "$scenario" ""); then
    die "Snapshot backend failed"
  fi
  local normalized=$(printf '%s\n' "$snapshot_json" | jq -S '.')
  local prompt=$(generate_prompt_markdown "$normalized" "$scenario")
  printf '%s\n' "$prompt"
}

cmd_version() {
  local schema_version="missing"
  if [[ -f "$SCHEMA_FILE" ]]; then
    schema_version=$(jq -r '.version // "unknown"' "$SCHEMA_FILE")
  fi
  local last_import=$(format_ts "$JOURNAL_FILE")
  local last_snapshot="never"
  if ls "$REPORT_DIR"/trading_snapshot_*.json >/dev/null 2>&1; then
    local latest=$(ls -1t "$REPORT_DIR"/trading_snapshot_*.json | head -n1)
    last_snapshot=$(format_ts "$latest")
  fi
  echo "02luka Trading CLI $CLI_VERSION"
  echo "journal schema: $schema_version"
  echo "last import: $last_import"
  echo "last snapshot: $last_snapshot"
}

main() {
  [[ $# -ge 1 ]] || { usage; exit 1; }
  local subcommand="$1"
  shift
  case "$subcommand" in
    import) cmd_import "$@" ;;
    snapshot) cmd_snapshot "$@" ;;
    chatgpt-prompt) cmd_chatgpt_prompt "$@" ;;
    version) cmd_version "$@" ;;
    -h|--help) usage ;;
    *) die "Unknown subcommand: $subcommand" ;;
  esac
}

main "$@"
