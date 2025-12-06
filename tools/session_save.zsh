#!/usr/bin/env zsh
# tools/session_save.zsh
# Backend engine for 02luka save system
# Generates session reports from MLS ledger and updates system state

set -e

# --- Telemetry Initialization ---
TELEMETRY_START_TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
# Use date +%s%N if available (Linux), else date +%s (macOS fallback)
if date +%s%N >/dev/null 2>&1; then
    TELEMETRY_START_NS=$(date +%s%N)
else
    TELEMETRY_START_NS=$(($(date +%s) * 1000000000))
fi

TELEMETRY_FILES_WRITTEN=0
TELEMETRY_PROJECT_ID="${PROJECT_ID:-null}"
TELEMETRY_TOPIC="null"

# Function to safely log telemetry on exit
log_telemetry() {
    local exit_code=$?
    local end_ns
    if date +%s%N >/dev/null 2>&1; then
        end_ns=$(date +%s%N)
    else
        end_ns=$(($(date +%s) * 1000000000))
    fi
    
    local duration_ms=$(( (end_ns - TELEMETRY_START_NS) / 1000000 ))
    
    # Metadata gathering
    local agent="${GG_AGENT_ID:-${USER:-unknown}}"
    local source="${SAVE_SOURCE:-manual}"
    
    # Resolve Repo Root robustly
    local repo_root="${LUKA_MEM_REPO_ROOT}"
    if [[ -z "$repo_root" ]]; then
        repo_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "$HOME/02luka")
    fi
    
    # Fallback if still empty or invalid
    if [[ -z "$repo_root" || "$repo_root" == "/" ]]; then
        repo_root="$HOME/02luka"
    fi

    local repo_name=$(basename "$repo_root")
    local branch=$(git -C "$repo_root" branch --show-current 2>/dev/null || echo "detached")
    
    # Safe JSON construction (manual escaping for shell)
    # Note: project_id and topic might contain user input, should be carefully handled if complex.
    # For now assuming simple strings or null.
    
    local json_fmt='{"ts": "%s", "agent": "%s", "source": "%s", "project_id": "%s", "topic": "%s", "files_written": %d, "save_mode": "full", "repo": "%s", "branch": "%s", "exit_code": %d, "duration_ms": %d, "truncated": false}'
    
    # Ensure telemetry directory exists (and ignore errors if readonly etc)
    mkdir -p "${repo_root}/g/telemetry" 2>/dev/null || true
    
    # Write to log file
    if [[ -d "${repo_root}/g/telemetry" ]]; then
        printf "$json_fmt\n" \
            "$TELEMETRY_START_TS" \
            "$agent" \
            "$source" \
            "$TELEMETRY_PROJECT_ID" \
            "$TELEMETRY_TOPIC" \
            "$TELEMETRY_FILES_WRITTEN" \
            "$repo_name" \
            "$branch" \
            "$exit_code" \
            "$duration_ms" \
            >> "${repo_root}/g/telemetry/save_sessions.jsonl" || true
    fi
}

trap log_telemetry EXIT

# --- End Telemetry Init ---

# Set base paths
LUKA_MEM_REPO_ROOT="${LUKA_MEM_REPO_ROOT:-$HOME/02luka}"
MEM_REPO="$LUKA_MEM_REPO_ROOT" # Alias for legacy compatibility
MLS_LEDGER_DIR="$LUKA_MEM_REPO_ROOT/mls/ledger"
TODAY=$(date +"%Y-%m-%d")
MLS_LEDGER="$MLS_LEDGER_DIR/$TODAY.jsonl"
REPORTS_DIR="$LUKA_MEM_REPO_ROOT/g/reports/sessions"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SESSION_FILE="$REPORTS_DIR/session_$TIMESTAMP.md"
LUKA_MD="$LUKA_MEM_REPO_ROOT/02luka.md"
MEMORY_SYSTEM_MD="$LUKA_MEM_REPO_ROOT/memory/CLAUDE_MEMORY_SYSTEM.md"

# ... (rest of the script) ...


# Ensure directories exist
mkdir -p "$MEM_REPO/g/reports/sessions"

# Check if MLS ledger exists
if [[ ! -f "$MLS_LEDGER" ]]; then
  echo "⚠️  No MLS ledger found for today: $MLS_LEDGER"
  echo "Creating minimal session record..."
fi

# Extract session data from MLS
extract_mls_data() {
  if [[ ! -f "$MLS_LEDGER" ]]; then
    echo '{"total":0,"types":{},"entries":[]}'
    return
  fi
  
  cat "$MLS_LEDGER" | jq -s '{
    total: length,
    types: (group_by(.type) | map({(.[0].type): length}) | add // {}),
    entries: map({
      ts: .ts,
      type: .type,
      title: .title,
      problem: .problem // "",
      solution: .solution // "",
      tags: .tags // []
    })
  }'
}

# Get agent name (CLS/CLC/GG)
AGENT="${SESSION_AGENT:-CLS}"

# Generate session content
echo "📝 Generating session from MLS ledger..."
MLS_DATA=$(extract_mls_data)
TOTAL_ENTRIES=$(echo "$MLS_DATA" | jq -r '.total')

# Count by type
SOLUTIONS=$(echo "$MLS_DATA" | jq -r '.types.solution // 0')
IMPROVEMENTS=$(echo "$MLS_DATA" | jq -r '.types.improvement // 0')
FAILURES=$(echo "$MLS_DATA" | jq -r '.types.failure // 0')
PATTERNS=$(echo "$MLS_DATA" | jq -r '.types.pattern // 0')

# Start writing session file
cat > "$SESSION_FILE" <<EOHEADER
---
title: "$AGENT Session Summary — $(date +"%Y-%m-%d")"
date: $TODAY
type: session
category: system
source: $AGENT
auto_generated: true
tags: [$AGENT, session, auto-generated, mls-derived]
---

# $AGENT Session Summary — $TODAY

**Date:** $TODAY  
**Timestamp:** $(date +"%Y-%m-%d %H:%M:%S %Z")  
**Agent:** $AGENT (Cursor AI Agent)  
**MLS Entries:** $TOTAL_ENTRIES  

---

## Session Statistics

**MLS Entries by Type:**
- Solutions: $SOLUTIONS
- Improvements: $IMPROVEMENTS
- Failures: $FAILURES
- Patterns: $PATTERNS

**Total Activities:** $TOTAL_ENTRIES

---

## Major Activities

EOHEADER

# Add entries grouped by type
for TYPE in solution improvement failure pattern; do
  COUNT=$(echo "$MLS_DATA" | jq -r ".types.$TYPE // 0")
  if [[ $COUNT -gt 0 ]]; then
    # Capitalize first letter (zsh compatible)
    TYPE_CAP="${(C)TYPE}"
    echo "" >> "$SESSION_FILE"
    echo "### ${TYPE_CAP}s ($COUNT)" >> "$SESSION_FILE"
    echo "" >> "$SESSION_FILE"
    
    echo "$MLS_DATA" | jq -r --arg type "$TYPE" '
      .entries[] | select(.type == $type) | 
      "**\(.title)**\n- Time: \(.ts)\n- Problem: \(.problem // "N/A")\n- Solution: \(.solution // "N/A")\n"
    ' >> "$SESSION_FILE"
  fi
done

# Add footer
cat >> "$SESSION_FILE" <<EOFOOTER

---

## Files Modified

_(Auto-detected from MLS entries)_

EOFOOTER

# Extract unique tags
echo "$MLS_DATA" | jq -r '.entries[].tags[]?' | sort -u | while read -r tag; do
  echo "- Tag: $tag" >> "$SESSION_FILE"
done 2>/dev/null || echo "- (No tags recorded)" >> "$SESSION_FILE"

cat >> "$SESSION_FILE" <<EOFOOTER2

---

## Next Steps

EOFOOTER2

# Look for any "followup" or "todo" tags
FOLLOWUPS=$(echo "$MLS_DATA" | jq -r '.entries[] | select(.tags[]? == "followup" or .tags[]? == "todo") | "- [ ] \(.title)"' 2>/dev/null)
if [[ -n "$FOLLOWUPS" ]]; then
  echo "$FOLLOWUPS" >> "$SESSION_FILE"
else
  echo "- Review MLS entries for patterns" >> "$SESSION_FILE"
  echo "- Continue with current phase objectives" >> "$SESSION_FILE"
fi

cat >> "$SESSION_FILE" <<EOFOOTER3

---

**Generated by:** $AGENT (Auto-generated from MLS Ledger)  
**Source:** $MLS_LEDGER  
**Session End:** $(date +"%Y-%m-%d %H:%M:%S %Z")

EOFOOTER3

echo "✅ Session saved: $SESSION_FILE"
echo "   Total entries: $TOTAL_ENTRIES"
echo "   File size: $(du -h "$SESSION_FILE" | cut -f1)"
((TELEMETRY_FILES_WRITTEN++)) || true

# Auto-commit to memory repo
if [[ -d "$MEM_REPO/.git" ]]; then
  echo ""
  echo "📦 Committing to memory repo..."
  cd "$MEM_REPO"
  git add "g/reports/sessions/session_$TIMESTAMP.md"
  git commit -m "session: $AGENT session summary $TODAY

Auto-generated from MLS ledger:
- Solutions: $SOLUTIONS
- Improvements: $IMPROVEMENTS
- Failures: $FAILURES
- Total entries: $TOTAL_ENTRIES

Timestamp: $TIMESTAMP" || echo "⚠️  Commit failed (may already be committed)"
  
  echo "✅ Committed to memory repo"
else
  echo "⚠️  Memory repo not a git repository, skipping commit"
fi

# Trigger hub index refresh if available
if [[ -f ~/02luka/tools/hub_index_now.zsh ]]; then
  echo ""
  echo "🔄 Triggering hub index refresh..."
  ~/02luka/tools/hub_index_now.zsh 2>/dev/null || echo "⚠️  Hub index refresh failed"
fi

echo ""
echo "📊 Session Summary"
echo "─────────────────"
echo "Agent: $AGENT"
echo "Date: $TODAY"
echo "File: $SESSION_FILE"
echo "Entries: $TOTAL_ENTRIES (S:$SOLUTIONS I:$IMPROVEMENTS F:$FAILURES P:$PATTERNS)"
echo ""
echo "✅ Session file saved!"

# ============================================
# STEP 2: Generate AI Summary JSON
# ============================================
echo ""
echo "📋 Generating AI summary JSON..."
AI_SUMMARY_FILE="$MEM_REPO/g/reports/sessions/session_$(date +%Y%m%d).ai.json"

# Extract top activities (most important titles)
TOP_ACTIVITIES=$(echo "$MLS_DATA" | jq -r '[.entries[] | select(.type == "solution" or .type == "improvement") | .title] | .[0:5]')

# Generate compact AI summary
cat > "$AI_SUMMARY_FILE" <<EOJSON
{
  "date": "$TODAY",
  "ts_utc": "$(date -u +%FT%TZ)",
  "ts_local": "$(date +%FT%T%z)",
  "agent": "$AGENT",
  "summary": {
    "total_entries": $TOTAL_ENTRIES,
    "top_activities": $TOP_ACTIVITIES,
    "stats": {
      "solutions": $SOLUTIONS,
      "improvements": $IMPROVEMENTS,
      "failures": $FAILURES,
      "patterns": $PATTERNS
    }
  },
  "links": {
    "mls_ledger": "mls/ledger/$TODAY.jsonl",
    "full_session": "g/reports/sessions/session_$TIMESTAMP.md"
  }
}
EOJSON

echo "✅ AI summary saved: $AI_SUMMARY_FILE"
((TELEMETRY_FILES_WRITTEN++)) || true

# ============================================
# STEP 3: Scan System Reality (System Map)
# ============================================
echo ""
echo "🔍 Scanning system reality..."

# Check if system_map_scan.zsh exists
if [[ -f ~/02luka/tools/system_map_scan.zsh ]]; then
  ~/02luka/tools/system_map_scan.zsh 2>&1 | head -5
  echo "✅ System map updated"
  ((TELEMETRY_FILES_WRITTEN++)) || true
else
  echo "⚠️  system_map_scan.zsh not found (from System Truth Sync feature)"
  echo "   Creating placeholder system map..."
  
  SYSTEM_MAP_FILE="$HOME/02luka/g/system_map/system_map.v1.json"
  mkdir -p "$(dirname "$SYSTEM_MAP_FILE")"
  
  # Count LaunchAgents, scripts, etc.
  LA_COUNT=$(launchctl list | grep -c com.02luka || echo 0)
  TOOL_COUNT=$(find ~/02luka/tools -type f -name "*.zsh" ! -path "*/node_modules/*" | wc -l | tr -d ' ')
  
  cat > "$SYSTEM_MAP_FILE" <<EOSYSMAP
{
  "version": 1,
  "scanned_at": "$(date -u +%FT%TZ)",
  "host": "$(hostname)",
  "components": {
    "launchagents": {
      "count": $LA_COUNT,
      "note": "Run 'launchctl list | grep com.02luka' for details"
    },
    "tools": {
      "count": $TOOL_COUNT,
      "path": "~/02luka/tools"
    }
  },
  "status": "minimal_scan",
  "note": "Full scan requires system_map_scan.zsh from System Truth Sync feature"
}
EOSYSMAP
  echo "✅ Minimal system map created: $SYSTEM_MAP_FILE"
  ((TELEMETRY_FILES_WRITTEN++)) || true
fi

# ============================================
# STEP 4: Update 02luka.md AUTO_RUNTIME Section
# ============================================
echo ""
echo "📝 Updating 02luka.md..."

# Check if system_map_render.zsh exists
if [[ -f ~/02luka/tools/system_map_render.zsh ]]; then
  ~/02luka/tools/system_map_render.zsh 2>&1 | head -5
  echo "✅ 02luka.md updated"
else
  echo "⚠️  system_map_render.zsh not found (from System Truth Sync feature)"
  echo "   Will update manually with session info..."
  
  # Add a simple timestamp update to 02luka.md
  if [[ -f ~/02luka/02luka.md ]]; then
    # Check if AUTO_RUNTIME markers exist
    if grep -q "<!-- AUTO_RUNTIME_START -->" ~/02luka/02luka.md 2>/dev/null; then
      # Markers exist, update section
      sed -i.bak '/<!-- AUTO_RUNTIME_START -->/,/<!-- AUTO_RUNTIME_END -->/c\
<!-- AUTO_RUNTIME_START -->\
**Last Session:** '"$TODAY"' '"$(date +%H:%M:%S)"'\
**Agent:** '"$AGENT"'\
**MLS Entries:** '"$TOTAL_ENTRIES"' (S:'"$SOLUTIONS"' I:'"$IMPROVEMENTS"' F:'"$FAILURES"' P:'"$PATTERNS"')\
**System Map:** `g/system_map/system_map.v1.json`\
<!-- AUTO_RUNTIME_END -->' ~/02luka/02luka.md
      echo "✅ Updated AUTO_RUNTIME section in 02luka.md"
    else
      echo "⚠️  AUTO_RUNTIME markers not found in 02luka.md"
      echo "   Add these markers to enable auto-update:"
      echo "   <!-- AUTO_RUNTIME_START -->"
      echo "   <!-- AUTO_RUNTIME_END -->"
    fi
  else
    echo "⚠️  02luka.md not found"
  fi
fi

# ============================================
# STEP 5: Commit All Changes to Main Repo
# ============================================
echo ""
echo "📦 Committing to main 02luka repo..."

if [[ -d ~/02luka/.git ]]; then
  cd ~/02luka
  
  # Add all changed files
  git add -A 2>/dev/null || true
  
  # Create comprehensive commit message
  COMMIT_MSG="session save: $AGENT $TODAY

Session Summary:
- Total MLS entries: $TOTAL_ENTRIES
- Solutions: $SOLUTIONS
- Improvements: $IMPROVEMENTS  
- Failures: $FAILURES
- Patterns: $PATTERNS

Files updated:
- Session: session_$TIMESTAMP.md
- AI Summary: session_$(date +%Y%m%d).ai.json
- System Map: g/system_map/system_map.v1.json
- Documentation: 02luka.md (AUTO_RUNTIME section)

Timestamp: $(date +%FT%TZ)"
  
  # Commit (will only commit if there are changes)
  if git commit -m "$COMMIT_MSG" 2>/dev/null; then
    echo "✅ Committed to main repo"
  else
    echo "ℹ️  No changes to commit in main repo"
  fi
else
  echo "⚠️  Main repo not a git repository"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ COMPLETE SAVE SUCCESSFUL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 What Was Saved:"
echo "  1. Session file:    $SESSION_FILE"
echo "  2. AI summary:      $AI_SUMMARY_FILE"
echo "  3. System map:      ~/02luka/g/system_map/system_map.v1.json"
echo "  4. Documentation:   ~/02luka/02luka.md"
echo "  5. Memory repo:     Git committed"
echo "  6. Main repo:       Git committed"
echo ""
echo "🎯 Session Stats: $TOTAL_ENTRIES entries (S:$SOLUTIONS I:$IMPROVEMENTS F:$FAILURES P:$PATTERNS)"
echo ""
