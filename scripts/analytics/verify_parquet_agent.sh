#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPORT_DIR="$REPO_ROOT/g/reports/parquet"
LOG_DIR="$REPO_ROOT/logs/wo_drop_history"
INBOX_DIR="$REPO_ROOT/bridge/inbox/CLC"
WO_FILE="$INBOX_DIR/WO-251029-PARQUET-EXPORTER.md"
REPORT_TS="$(date -u +"%Y%m%dT%H%M%SZ")"
REPORT_PATH="$REPORT_DIR/verify_${REPORT_TS}.md"

TRIGGER_MODE="manual"
if [[ "${1-}" == "--trigger" ]]; then
  TRIGGER_MODE="trigger"
  shift || true
fi

mkdir -p "$REPORT_DIR"

wo_status="❌ Missing"
if [[ -f "$WO_FILE" ]]; then
  wo_status="✅ Present"
fi

history_log="$LOG_DIR/WO_HISTORY.log"
audit_status="⚠️ Pending"
if [[ -f "$history_log" ]]; then
  if grep -q "WO-251029-PARQUET-EXPORTER" "$history_log"; then
    audit_status="✅ Logged"
  else
    audit_status="⚠️ Drop Logged?"
  fi
else
  audit_status="⚠️ Log Missing"
fi

mapfile -t daily_csv < <(find "$REPO_ROOT/g/reports" -maxdepth 1 -type f -name 'query_perf_daily_*.csv' 2>/dev/null | sort)
mapfile -t weekly_csv < <(find "$REPO_ROOT/g/reports" -maxdepth 1 -type f -name 'query_perf_weekly_*.csv' 2>/dev/null | sort)
mapfile -t daily_parquet < <(find "$REPO_ROOT/g/reports" -maxdepth 1 -type f -name 'query_perf_daily_*.parquet' 2>/dev/null | sort)
mapfile -t weekly_parquet < <(find "$REPO_ROOT/g/reports" -maxdepth 1 -type f -name 'query_perf_weekly_*.parquet' 2>/dev/null | sort)

csv_daily_count=${#daily_csv[@]}
csv_weekly_count=${#weekly_csv[@]}
parquet_daily_count=${#daily_parquet[@]}
parquet_weekly_count=${#weekly_parquet[@]}

exporter_status="⚠️ Awaiting first parquet export"
if (( parquet_daily_count > 0 || parquet_weekly_count > 0 )); then
  exporter_status="✅ Parquet artifacts detected"
fi

node_status="⚠️ Node not available"
if command -v node >/dev/null 2>&1; then
  node_status="✅ Node $(node --version)"
fi

python_status="⚠️ Python not available"
if command -v python >/dev/null 2>&1; then
  python_status="✅ Python $(python --version | cut -d' ' -f2)"
fi

cat <<REPORT > "$REPORT_PATH"
# Parquet Exporter Verification — ${REPORT_TS}

- **Invocation:** ${TRIGGER_MODE}
- **Work Order:** ${wo_status}
- **Audit Trail:** ${audit_status}
- **Node Runtime:** ${node_status}
- **Python Runtime:** ${python_status}

## Dataset Scan

| Dataset | CSV Files | Parquet Files |
|---------|-----------|----------------|
| Daily   | ${csv_daily_count} | ${parquet_daily_count} |
| Weekly  | ${csv_weekly_count} | ${parquet_weekly_count} |

## Findings

- ${exporter_status}
- Daily source CSVs inspected: ${csv_daily_count}
- Weekly source CSVs inspected: ${csv_weekly_count}
- Generated report: $(basename "$REPORT_PATH")

## Next Steps

1. If Parquet counts remain at 0, schedule exporter job or run conversion utility.
2. Confirm audit trail entries in \`logs/wo_drop_history/WO_HISTORY.log\` continue to append.
3. Re-run \`scripts/analytics/verify_parquet_agent.sh --trigger\` after exporter activation.
REPORT

chmod 644 "$REPORT_PATH"

echo "Parquet verification report created at $REPORT_PATH"
if [[ "$exporter_status" == "✅ Parquet artifacts detected" ]]; then
  echo "Exporter: healthy"
else
  echo "Exporter: awaiting artifacts"
fi

exit 0
