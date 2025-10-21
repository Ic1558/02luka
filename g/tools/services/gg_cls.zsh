#!/usr/bin/env zsh
set -euo pipefail
: ${REDIS_URL:="redis://localhost:6379"}
CHAN="${CLS_CHANNEL:-gg:cls:tasks}"

# usage:
#   gg_cls.zsh run "WO-251021_PHASE7_6_WIRE_UP"
#   gg_cls.zsh verify "freeze-proofing"
#   gg_cls.zsh exec '{"cmd":"node knowledge/sync.cjs --export"}'
#   gg_cls.zsh raw  '{"kind":"verify","topic":"freeze-proofing"}'
cmd="${1:-}"
arg="${2:-}"

case "$cmd" in
  run)
    payload="{\"kind\":\"run\",\"work_order\":\"${arg}\"}"
    ;;
  verify)
    payload="{\"kind\":\"verify\",\"topic\":\"${arg}\"}"
    ;;
  exec)
    # arg is JSON or a shell string; try to wrap
    if [[ "$arg" == \{* ]]; then
      payload="$arg"
    else
      payload="{\"kind\":\"exec\",\"cmd\":\"${arg}\"}"
    fi
    ;;
  raw)
    payload="$arg"
    ;;
  *)
    echo "usage: $0 run|verify|exec|raw <value-or-json>"; exit 2;;
esac

redis-cli -u "$REDIS_URL" PUBLISH "$CHAN" "$payload" >/dev/null
echo "OK -> $CHAN $payload"
