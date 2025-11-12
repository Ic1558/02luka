
# Claude Code metrics
if command -v redis-cli >/dev/null 2>&1; then
  claude_data=$(redis-cli -a changeme-02luka HGETALL memory:agents:claude 2>/dev/null || echo "")
  if [[ -n "$claude_data" ]]; then
    claude_metrics=$(echo "$claude_data" | jq -Rs 'split("\n") | . as $lines | reduce range(0; length/2) as $i ({}; .[$lines[$i*2]] = $lines[$i*2+1])' 2>/dev/null || echo "{}")
    tmp_file=$(mktemp)
    jq --argjson claude "$claude_metrics" '.agents.claude = $claude' "$OUTPUT_JSON" > "$tmp_file" && mv "$tmp_file" "$OUTPUT_JSON" 2>/dev/null || rm -f "$tmp_file"
  fi
fi
