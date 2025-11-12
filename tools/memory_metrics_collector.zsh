#!/usr/bin/env zsh
set -euo pipefail

REPO="$HOME/02luka"
YEARMONTH=$(date +%Y%m)
OUTPUT_JSON="$REPO/g/reports/memory_metrics_${YEARMONTH}.json"
OUTPUT_MD="$REPO/g/reports/memory_metrics_${YEARMONTH}.md"

mkdir -p "$(dirname "$OUTPUT_JSON")"

# Initialize metrics structure if file doesn't exist
if [[ ! -f "$OUTPUT_JSON" ]]; then
  cat > "$OUTPUT_JSON" <<JSON
{
  "month": "${YEARMONTH}",
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "agents": {}
}
JSON
fi

# Collect agent metrics from Redis
REDIS_PASS="${REDIS_PASSWORD:-changeme-02luka}"
[[ -n "${REDIS_ALT_PASSWORD:-}" ]] && REDIS_PASS="$REDIS_ALT_PASSWORD"

if command -v redis-cli >/dev/null 2>&1; then
  for agent in mary rnd claude; do
    agent_data=$(redis-cli -a "$REDIS_PASS" HGETALL memory:agents:${agent} 2>/dev/null || echo "")
    if [[ -n "$agent_data" && "$agent_data" != "NOAUTH"* && "$agent_data" != "AUTH failed"* ]]; then
      # Convert Redis HGETALL output to JSON
      agent_json=$(echo "$agent_data" | awk 'NR%2==1 {key=$0} NR%2==0 {print key":"$0}' | jq -Rs 'split("\n") | map(select(length>0)) | map(split(":")) | reduce .[] as $pair ({}; .[$pair[0]] = ($pair[1:] | join(":")))' 2>/dev/null || echo "{}")
      
      if [[ -n "$agent_json" && "$agent_json" != "{}" ]]; then
        tmp_file=$(mktemp)
        jq --argjson data "$agent_json" ".agents.${agent} = \$data" "$OUTPUT_JSON" > "$tmp_file" && mv "$tmp_file" "$OUTPUT_JSON" 2>/dev/null || rm -f "$tmp_file"
      fi
    fi
  done
fi

# Generate Markdown report
cat > "$OUTPUT_MD" <<MARKDOWN
# Memory Metrics — ${YEARMONTH}

**Generated:** $(date -u +%Y-%m-%dT%H:%M:%SZ)

## Agent Metrics

$(jq -r '.agents | to_entries[] | "### \(.key)\n\n\(.value | to_entries[] | "- \(.key): \(.value)")\n"' "$OUTPUT_JSON" 2>/dev/null || echo "No metrics available")

---

**Data Location:** \`$OUTPUT_JSON\`
MARKDOWN

echo "✅ Metrics collected: $OUTPUT_JSON"
