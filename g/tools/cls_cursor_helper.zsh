#!/usr/bin/env zsh
# === CLS Helper for Cursor IDE ===
# Provides commands for manual learning and pattern detection

case "${1:-help}" in
  learn-last)
    # Learn the last command from history
    local last_cmd=$(fc -ln -1 | sed 's/^[[:space:]]*//')
    echo "Learning command: $last_cmd"
    ~/02luka/tools/cls_learn.zsh command "$last_cmd" "manual capture" 0 "$PWD"
    echo "✅ Command logged to CLS"
    ;;
    
  learn-clip)
    # Learn from clipboard (for pasted commands)
    if command -v pbpaste >/dev/null 2>&1; then
      local clip=$(pbpaste)
      echo "Learning from clipboard: $clip"
      ~/02luka/tools/cls_learn.zsh command "$clip" "from clipboard" 0 "$PWD"
      echo "✅ Command logged to CLS"
    else
      echo "❌ pbpaste not available (macOS only)"
      exit 1
    fi
    ;;
    
  analyze)
    # Run pattern detection and show results
    echo "🔍 Analyzing command patterns..."
    ~/02luka/tools/cls_detect_patterns.zsh all
    echo ""
    echo "📊 Latest patterns:"
    tail -3 ~/02luka/memory/cls/patterns.jsonl | jq -r '. | "  • \(.pattern_type): \(.total_commands) cmds, \(.error_rate)% errors"'
    ;;
    
  stats)
    # Show CLS statistics
    echo "📈 CLS Database Statistics:"
    echo "  Learning DB: $(wc -l < ~/02luka/memory/cls/learning_db.jsonl) entries"
    echo "  Session Context: $(wc -l < ~/02luka/memory/cls/session_context.json) sessions"
    echo "  Patterns: $(wc -l < ~/02luka/memory/cls/patterns.jsonl) patterns"
    echo ""
    echo "📝 Recent commands:"
    tail -5 ~/02luka/memory/cls/learning_db.jsonl | jq -r 'select(.interaction_type=="command") | "  \(.timestamp): \(.context) (exit:\(.metadata.exit_code))"' 2>/dev/null || echo "  (no commands yet)"
    ;;
    
  session-save)
    # Save current session context
    local ctx_type="${2:-manual}"
    local ctx_data="${3:-{}}"
    ~/02luka/tools/cls_save_context.zsh session "$(date +%s)" "$ctx_type" "$ctx_data"
    echo "✅ Session context saved"
    ;;
    
  *)
    cat <<'USAGE'
CLS Cursor Helper - Command Learning System

Usage: cls_cursor_helper.zsh <command>

Commands:
  learn-last     Learn the last command from shell history
  learn-clip     Learn command from clipboard (macOS)
  analyze        Run pattern detection and show results
  stats          Show CLS database statistics
  session-save   Save current session context
  
Environment (in Cursor terminal):
  cls-on         Enable automatic command learning
  cls-off        Disable automatic command learning
  cls-status     Show current CLS status
  
Examples:
  # Enable auto-learning
  cls-on
  
  # Run some commands (they'll be logged automatically)
  git status
  npm test
  
  # Analyze patterns
  cls_cursor_helper.zsh analyze
  
  # View stats
  cls_cursor_helper.zsh stats
  
  # Disable when done
  cls-off

Files:
  Learning DB:     ~/02luka/memory/cls/learning_db.jsonl
  Session Context: ~/02luka/memory/cls/session_context.json
  Patterns:        ~/02luka/memory/cls/patterns.jsonl
  Logs:            ~/02luka/g/logs/cls_phase3.log
USAGE
    ;;
esac
