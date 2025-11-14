#!/usr/bin/env zsh
# push_account.zsh — Push trading account metrics to Prometheus Pushgateway
set -euo pipefail

# Args: net_pnl margin_used_pct position symbol(optional)
NET_PNL="${1:?}"
MARGIN_PCT="${2:?}"      # 0..100
POS="${3:?}"             # signed contracts
SYMBOL="${4:-SET50}"

cat <<METRICS | curl -s --data-binary @- http://127.0.0.1:9091/metrics/job/trading_account/instance/local
trading_account_net_pnl ${NET_PNL}
trading_account_margin_used_pct ${MARGIN_PCT}
trading_position_contracts{symbol="${SYMBOL}"} ${POS}
METRICS
