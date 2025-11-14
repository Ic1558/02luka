#!/usr/bin/env zsh
# R&D Memory Hook - Record R&D proposal outcomes to shared memory
set -euo pipefail

export LUKA_SOT="${LUKA_SOT:-$HOME/02luka}"
MEM_SYNC="$LUKA_SOT/tools/memory_sync.sh"
MEM_HUB="$LUKA_SOT/agents/memory_hub/memory_hub.py"

# Usage: rnd_memory_hook.zsh <proposal_id> <outcome> <result_json>
proposal_id="${1:-unknown}"
outcome="${2:-processed}"
result_json="${3:-{}}"

# Update R&D status
"$MEM_SYNC" update rnd active >/dev/null 2>&1 || true

# Record outcome via hub (if available)
if [[ -f "$MEM_HUB" ]] && command -v python3 >/dev/null 2>&1; then
    python3 -c "
from agents.memory_hub.memory_hub import UnifiedMemoryHub
import json, sys
hub = UnifiedMemoryHub()
result = json.loads('${result_json}')
hub.update_agent_context('rnd', {
    'last_proposal': '${proposal_id}',
    'outcome': '${outcome}',
    'result': result,
    'timestamp': '$(date -Iseconds)'
})
" 2>/dev/null || true
fi

# Also update via file-based sync
echo "$result_json" | jq . > "$LUKA_SOT/bridge/memory/inbox/rnd_outcome_$(date +%s).json" 2>/dev/null || true
