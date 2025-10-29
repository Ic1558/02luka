#!/usr/bin/env bash
# Wrap any command: publish start/done events around it.
set -euo pipefail
TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EMIT="${TOOLS_DIR}/emit_task_event.sh"

agent="${AGENT:-cursor}"
action="${1:-task}"
shift || true
ctx="${CONTEXT:-}"
id="WO-$(date +%y%m%d-%H%M%S)-$"

"$EMIT" "$agent" "$action" "started" "$ctx" "$id" >/dev/null || true

set +e
"$@"
rc=$?
set -e

status="done"
[ $rc -ne 0 ] && status="failed"
"$EMIT" "$agent" "$action" "$status" "$ctx" "$id" >/dev/null || true
exit $rc
