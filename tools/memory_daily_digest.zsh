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

## Adaptive Insights

$(INSIGHTS_FILE="$REPO/mls/adaptive/insights_${TODAY}.json"
if [[ -f "$INSIGHTS_FILE" ]] && command -v jq >/dev/null 2>&1; then
  # Read insights
  trends=$(jq -r '.trends // {}' "$INSIGHTS_FILE" 2>/dev/null || echo "{}")
  anomalies=$(jq -r '.anomalies // []' "$INSIGHTS_FILE" 2>/dev/null || echo "[]")
  recommendations=$(jq -r '.recommendations // []' "$INSIGHTS_FILE" 2>/dev/null || echo "[]")
  summary=$(jq -r '.recommendation_summary // "No insights available"' "$INSIGHTS_FILE" 2>/dev/null || echo "No insights available")
  
  # Display trends
  echo "### Trends (Last 7 Days)"
  echo ""
  if [[ "$trends" != "{}" && "$trends" != "null" ]]; then
    echo "$trends" | jq -r 'to_entries[] | "- **\(.key):** \(.value.direction // "stable") (\(.value.change // "0%"))"' 2>/dev/null || echo "No trends available"
  else
    echo "No trends detected."
  fi
  echo ""
  
  # Display anomalies
  if [[ "$anomalies" != "[]" && "$anomalies" != "null" ]]; then
    echo "### Anomalies"
    echo ""
    echo "$anomalies" | jq -r '.[] | "- **\(.metric):** \(.value) (expected: \(.expected)) - \(.severity)"' 2>/dev/null || echo "No anomalies data"
    echo ""
  fi
  
  # Display recommendations
  if [[ "$summary" != "No insights available" && "$summary" != "null" ]]; then
    echo "### Recommendations"
    echo ""
    echo "$summary"
    echo ""
  fi
else
  echo "*Adaptive insights not available for today.*"
  echo ""
fi)

---

## Next Actions

- Review Mary task completions
- Review R&D proposal outcomes
- Check for any errors in hub logs
- Verify Redis pub/sub activity
- Review adaptive insights and recommendations

---

**Report Location:** \`$OUTPUT\`
MARKDOWN

echo "✅ Daily digest generated: $OUTPUT"
