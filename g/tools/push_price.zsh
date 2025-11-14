#!/usr/bin/env zsh
# push_price.zsh — Push trading price metrics to Prometheus Pushgateway
set -euo pipefail

SYMBOL="${1:?symbol}"
PRICE="${2:?last_price}"   # feed from your source (Paula/Fincept/AlphaVantage script)

cat <<METRICS | curl -s --data-binary @- http://127.0.0.1:9091/metrics/job/trading/instance/local
trading_price_last{symbol="${SYMBOL}"} ${PRICE}
METRICS
