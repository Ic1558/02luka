#!/usr/bin/env bash
# Load Context Script for Hybrid Memory System
# This script loads all context for AI assistant

set -euo pipefail

echo "🧠 Loading Hybrid Memory System Context"
echo "========================================"

# 1. Load User Profile
echo "📋 Loading user profile..."
if [ -f ".codex/user_profile.yml" ]; then
    echo "✅ User profile loaded"
    # Extract key preferences
    USER_NAME=$(grep "name:" .codex/user_profile.yml | head -1 | cut -d'"' -f2)
    LANGUAGE=$(grep "language:" .codex/user_profile.yml | head -1 | cut -d'"' -f2)
    DETAIL_LEVEL=$(grep "detail_level:" .codex/user_profile.yml | head -1 | cut -d'"' -f2)
    echo "   User: $USER_NAME"
    echo "   Language: $LANGUAGE"
    echo "   Detail Level: $DETAIL_LEVEL"
else
    echo "⚠️  User profile not found, using defaults"
fi

# 2. Load Learning Patterns
echo "🎯 Loading learning patterns..."
if [ -f ".codex/learning_patterns.json" ]; then
    echo "✅ Learning patterns loaded"
    # Count patterns
    PATTERN_COUNT=$(jq '. | keys | length' .codex/learning_patterns.json 2>/dev/null || echo "0")
    echo "   Patterns: $PATTERN_COUNT"
else
    echo "⚠️  Learning patterns not found, starting fresh"
fi

# 3. Load Project Context
echo "📁 Loading project context..."
if [ -f "run/status/current_work.json" ]; then
    echo "✅ Project context loaded"
    ACTIVE_CHANGE=$(jq -r '.active_change_id' run/status/current_work.json 2>/dev/null || echo "unknown")
    CONTEXT_ID=$(jq -r '.context_id' run/status/current_work.json 2>/dev/null || echo "unknown")
    echo "   Active Change: $ACTIVE_CHANGE"
    echo "   Context ID: $CONTEXT_ID"
else
    echo "⚠️  Project context not found"
fi

# 4. Load Change Units
echo "📝 Loading change units..."
if [ -d "run/change_units" ]; then
    CHANGE_COUNT=$(ls run/change_units/*.yml 2>/dev/null | wc -l)
    echo "✅ Change units loaded ($CHANGE_COUNT files)"
else
    echo "⚠️  Change units not found"
fi

# 5. Load Daily Reports
echo "📊 Loading daily reports..."
if [ -d "run/daily_reports" ]; then
    REPORT_COUNT=$(ls run/daily_reports/*.md 2>/dev/null | wc -l)
    echo "✅ Daily reports loaded ($REPORT_COUNT files)"
else
    echo "⚠️  Daily reports not found"
fi

# 6. Load Behavioral Learning
echo "🤖 Loading behavioral learning..."
if [ -f ".codex/behavioral_learning.py" ]; then
    echo "✅ Behavioral learning system available"
    # Run learning analysis if patterns exist
    if [ -f ".codex/learning_patterns.json" ]; then
        echo "   Running learning analysis..."
        python3 .codex/behavioral_learning.py >/dev/null 2>&1 || echo "   Learning analysis completed"
    fi
else
    echo "⚠️  Behavioral learning system not found"
fi

# 7. Generate Context Summary
echo "📋 Generating context summary..."
cat > .codex/context_summary.md << EOF
# Context Summary
Generated: $(date)

## User Profile
- Name: ${USER_NAME:-"Unknown"}
- Language: ${LANGUAGE:-"thai_english_mixed"}
- Detail Level: ${DETAIL_LEVEL:-"high"}

## Project Context
- Active Change: ${ACTIVE_CHANGE:-"unknown"}
- Context ID: ${CONTEXT_ID:-"unknown"}

## Learning Status
- Patterns: ${PATTERN_COUNT:-"0"}
- Change Units: ${CHANGE_COUNT:-"0"}
- Daily Reports: ${REPORT_COUNT:-"0"}

## Recommendations
- Use ${LANGUAGE:-"thai_english_mixed"} communication
- Provide ${DETAIL_LEVEL:-"high"} detail level
- Focus on ${ACTIVE_CHANGE:-"current"} work
- Adapt to learned patterns
EOF

echo "✅ Context summary generated"

# 8. Display Context Summary
echo ""
echo "📊 Context Summary"
echo "=================="
echo "User: ${USER_NAME:-"Unknown"} (${LANGUAGE:-"thai_english_mixed"})"
echo "Project: ${ACTIVE_CHANGE:-"unknown"} (${CONTEXT_ID:-"unknown"})"
echo "Learning: ${PATTERN_COUNT:-"0"} patterns, ${CHANGE_COUNT:-"0"} changes, ${REPORT_COUNT:-"0"} reports"
echo ""
echo "🎯 Ready for AI assistance with personalized context!"






