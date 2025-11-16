#!/usr/bin/env zsh
# paula_signal.zsh — Send Paula trading signal to Pushgateway
# Usage: paula_signal.zsh <buy|sell|flat> <price> <confidence 0..1> "<reason>" [timeframe]
# Example: paula_signal.zsh buy 855 0.78 "Breakout > 850" M15
set -euo pipefail

PG_URL="${PG_URL:-http://127.0.0.1:9091}"
SYM="${SYM:-SET50}"
STRAT="${STRAT:-paula_v1}"
ACT="${1:?buy|sell|flat}"
PRICE="${2:?price}"
CONF="${3:?confidence}"
REASON_RAW="${4:?reason text}"
TF="${5:-M15}"

# Sanitize reason for Prometheus label (replace spaces with underscores, remove special chars)
REASON=$(echo "$REASON_RAW" | sed 's/ /_/g' | sed 's/[<>]//g')

case "$ACT" in
  buy)  SIG=1 ;;
  sell) SIG=-1 ;;
  flat) SIG=0 ;;
  *) echo "❌ Unknown action: $ACT"; exit 2 ;;
esac

# Push to Pushgateway (job=trading_signals, instance=paula)
cat <<METRICS | curl -fsS -X PUT --data-binary @- "$PG_URL/metrics/job/trading_signals/instance/paula"
trading_price_last{symbol="$SYM"} $PRICE
trading_signal{symbol="$SYM",strategy="$STRAT",reason="$REASON",timeframe="$TF"} $SIG
trading_signal_confidence{symbol="$SYM",strategy="$STRAT",reason="$REASON",timeframe="$TF"} $CONF
METRICS

echo "✅ Pushed: action=$ACT price=$PRICE conf=$CONF reason=\"$REASON\" tf=$TF"
