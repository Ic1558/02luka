#!/usr/bin/env zsh
set -euo pipefail

REPO="$HOME/02luka"
REDIS_PASS="changeme-02luka"
TODAY=$(date +%Y%m%d)
OUTPUT="$REPO/g/reports/system/memory_digest_${TODAY}.md"

mkdir -p "$(dirname "$OUTPUT")"

# Get timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Get Mary activity
mary_data=$(redis-cli -a "$REDIS_PASS" HGETALL memory:agents:mary 2>/dev/null || echo "")
mary_context=$(jq -r '.agents.mary // {}' "$REPO/shared_memory/context.json" 2>/dev/null || echo "{}")

# Get R&D activity
rnd_data=$(redis-cli -a "$REDIS_PASS" HGETALL memory:agents:rnd 2>/dev/null || echo "")
rnd_context=$(jq -r '.agents.rnd // {}' "$REPO/shared_memory/context.json" 2>/dev/null || echo "{}")

# Count activities from logs (last 24h)
mary_tasks=$(find "$REPO/bridge/memory/inbox" -name "*mary*" -type f 2>/dev/null | wc -l | tr -d ' ' || echo "0")
rnd_proposals=$(find "$REPO/bridge/memory/inbox" -name "*rnd*" -type f 2>/dev/null | wc -l | tr -d ' ' || echo "0")

cat > "$OUTPUT" <<MARKDOWN
# Memory System Daily Digest — $(date +%Y-%m-%d)

**Generated:** $TIMESTAMP  
**System:** Phase 4 (Redis Hub + Mary/R&D Integration)

---

## Summary

- **Mary Tasks:** $mary_tasks completed
- **R&D Proposals:** $rnd_proposals processed
- **Hub Status:** $(launchctl list | grep -q com.02luka.memory.hub && echo "✅ Running" || echo "❌ Not Running")
- **Redis Status:** $(redis-cli -a "$REDIS_PASS" PING >/dev/null 2>&1 && echo "✅ Connected" || echo "❌ Disconnected")

---

## Mary Activity

### Current Status
\`\`\`json
$mary_context
\`\`\`

### Redis Data
\`\`\`
$mary_data
\`\`\`

---

## R&D Activity

### Current Status
\`\`\`json
$rnd_context
\`\`\`

### Redis Data
\`\`\`
$rnd_data
\`\`\`

---

## Hub Logs (Last 10 Lines)

\`\`\`
$(tail -n 10 "$REPO/logs/memory_hub.out.log" 2>/dev/null || echo "No logs available")
\`\`\`

---

## Next Actions

- Review Mary task completions
- Review R&D proposal outcomes
- Check for any errors in hub logs
- Verify Redis pub/sub activity

---

**Report Location:** \`$OUTPUT\`
MARKDOWN

echo "✅ Daily digest generated: $OUTPUT"
