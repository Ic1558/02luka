
# Claude Code metrics
if command -v redis-cli >/dev/null 2>&1; then
  claude_data=$(redis-cli -a changeme-02luka HGETALL memory:agents:claude 2>/dev/null || echo "")
  if [[ -n "$claude_data" ]]; then
    claude_metrics=$(echo "$claude_data" | jq -Rs 'split("\n") | . as $lines | reduce range(0; length/2) as $i ({}; .[$lines[$i*2]] = $lines[$i*2+1])' 2>/dev/null || echo "{}")
    jq --argjson claude "$claude_metrics" '.agents.claude = $claude' "$OUTPUT_JSON" > "${OUTPUT_JSON}.tmp" && mv "${OUTPUT_JSON}.tmp" "$OUTPUT_JSON" 2>/dev/null || true
  fi
fi
