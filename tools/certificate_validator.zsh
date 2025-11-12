
# Claude Code component validation
echo "Validating Claude Code components..."

claude_ok=0
claude_total=0

# Check .claude/settings.json
claude_total=$((claude_total+1))
if [[ -f "$REPO/.claude/settings.json" ]]; then
  echo "  ✅ .claude/settings.json exists"
  claude_ok=$((claude_ok+1))
else
  echo "  ❌ .claude/settings.json missing"
fi

# Check hooks
for hook in pre_commit.zsh quality_gate.zsh verify_deployment.zsh; do
  claude_total=$((claude_total+1))
  if [[ -f "$REPO/tools/claude_hooks/$hook" && -x "$REPO/tools/claude_hooks/$hook" ]]; then
    echo "  ✅ $hook exists and executable"
    claude_ok=$((claude_ok+1))
  else
    echo "  ❌ $hook missing or not executable"
  fi
done

# Check metrics collector
claude_total=$((claude_total+1))
if [[ -f "$REPO/tools/claude_tools/metrics_collector.zsh" && -x "$REPO/tools/claude_tools/metrics_collector.zsh" ]]; then
  echo "  ✅ metrics_collector.zsh exists and executable"
  claude_ok=$((claude_ok+1))
else
  echo "  ❌ metrics_collector.zsh missing or not executable"
fi

# Check dependencies
for dep in shellcheck pylint jq gh git; do
  claude_total=$((claude_total+1))
  if command -v "$dep" >/dev/null 2>&1; then
    echo "  ✅ $dep available"
    claude_ok=$((claude_ok+1))
  else
    echo "  ❌ $dep missing"
  fi
done

claude_score=$((claude_ok * 100 / claude_total))
echo "Claude Code Validation Score: ${claude_score}% (${claude_ok}/${claude_total})"
