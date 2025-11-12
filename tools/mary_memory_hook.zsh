#!/usr/bin/env zsh
# Mary Memory Hook - Record Mary dispatcher results to shared memory
set -euo pipefail

export LUKA_SOT="${LUKA_SOT:-$HOME/02luka}"
MEM_SYNC="$LUKA_SOT/tools/memory_sync.sh"
MEM_HUB="$LUKA_SOT/agents/memory_hub/memory_hub.py"

# Usage: mary_memory_hook.zsh <task_id> <task_status> <result_json>
task_id="${1:-unknown}"
task_status="${2:-completed}"
result_json="${3:-{}}"

# Update Mary status
"$MEM_SYNC" update mary active >/dev/null 2>&1 || true

# Record result via hub (if available)
if [[ -f "$MEM_HUB" ]] && command -v python3 >/dev/null 2>&1; then
    python3 -c "
from agents.memory_hub.memory_hub import UnifiedMemoryHub
import json, sys
hub = UnifiedMemoryHub()
result = json.loads('${result_json}')
hub.update_agent_context('mary', {
    'last_task': '${task_id}',
    'task_status': '${task_status}',
    'result': result,
    'timestamp': '$(date -Iseconds)'
})
" 2>/dev/null || true
fi

# Also update via file-based sync
echo "$result_json" | jq . > "$LUKA_SOT/bridge/memory/inbox/mary_result_$(date +%s).json" 2>/dev/null || true
