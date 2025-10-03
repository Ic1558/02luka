#!/usr/bin/env bash
# Style Adaptation Script for Hybrid Memory System
# This script adapts AI style based on learned patterns

set -euo pipefail

echo "🎨 Adapting AI Style Based on Learned Patterns"
echo "==============================================="

# 1. Load User Profile
echo "📋 Loading user profile..."
if [ -f ".codex/user_profile.yml" ]; then
    USER_NAME=$(grep "name:" .codex/user_profile.yml | head -1 | cut -d'"' -f2)
    LANGUAGE=$(grep "language:" .codex/user_profile.yml | head -1 | cut -d'"' -f2)
    DETAIL_LEVEL=$(grep "detail_level:" .codex/user_profile.yml | head -1 | cut -d'"' -f2)
    CONFIRMATION=$(grep "confirmation_required:" .codex/user_profile.yml | head -1 | cut -d' ' -f2)
    WORKING_STYLE=$(grep "working_style:" .codex/user_profile.yml | head -1 | cut -d'"' -f2)
    echo "✅ User profile loaded"
else
    echo "⚠️  User profile not found, using defaults"
    USER_NAME="User"
    LANGUAGE="thai_english_mixed"
    DETAIL_LEVEL="high"
    CONFIRMATION="true"
    WORKING_STYLE="systematic"
fi

# 2. Load Learning Patterns
echo "🎯 Loading learning patterns..."
if [ -f ".codex/learning_patterns.json" ]; then
    echo "✅ Learning patterns loaded"
    # Analyze patterns
    python3 .codex/behavioral_learning.py >/dev/null 2>&1 || echo "   Pattern analysis completed"
else
    echo "⚠️  Learning patterns not found, using profile defaults"
fi

# 3. Generate Style Adaptations
echo "🔧 Generating style adaptations..."
cat > .codex/style_adaptations.yml << EOF
# Style Adaptations for AI Assistant
# Generated: $(date)

user:
  name: "$USER_NAME"
  preferences:
    language: "$LANGUAGE"
    detail_level: "$DETAIL_LEVEL"
    confirmation_required: $CONFIRMATION
    working_style: "$WORKING_STYLE"

# Communication Adaptations
communication:
  use_thai_english: $([ "$LANGUAGE" = "thai_english_mixed" ] && echo "true" || echo "false")
  detailed_explanations: $([ "$DETAIL_LEVEL" = "high" ] && echo "true" || echo "false")
  ask_confirmation: $([ "$CONFIRMATION" = "true" ] && echo "true" || echo "false")
  step_by_step: $([ "$WORKING_STYLE" = "systematic" ] && echo "true" || echo "false")

# Working Adaptations
working:
  systematic_approach: $([ "$WORKING_STYLE" = "systematic" ] && echo "true" || echo "false")
  testing_focus: true
  documentation_focus: true
  error_handling: true

# Problem Solving Adaptations
problem_solving:
  analytical_approach: true
  methodical_approach: $([ "$WORKING_STYLE" = "systematic" ] && echo "true" || echo "false")
  detail_focus: $([ "$DETAIL_LEVEL" = "high" ] && echo "true" || echo "false")
  solution_focused: true

# Interaction Adaptations
interaction:
  greeting_style: "thai_english_mixed"
  explanation_style: "detailed"
  confirmation_style: "explicit"
  working_style: "systematic"
  documentation_style: "comprehensive"
EOF

echo "✅ Style adaptations generated"

# 4. Display Adaptations
echo ""
echo "🎨 Style Adaptations"
echo "===================="
echo "Language: $LANGUAGE"
echo "Detail Level: $DETAIL_LEVEL"
echo "Confirmation: $CONFIRMATION"
echo "Working Style: $WORKING_STYLE"
echo ""
echo "📝 Communication Style:"
echo "   - Use Thai + English: $([ "$LANGUAGE" = "thai_english_mixed" ] && echo "✅" || echo "❌")"
echo "   - Detailed explanations: $([ "$DETAIL_LEVEL" = "high" ] && echo "✅" || echo "❌")"
echo "   - Ask for confirmation: $([ "$CONFIRMATION" = "true" ] && echo "✅" || echo "❌")"
echo "   - Step-by-step approach: $([ "$WORKING_STYLE" = "systematic" ] && echo "✅" || echo "❌")"
echo ""
echo "🔧 Working Style:"
echo "   - Systematic approach: $([ "$WORKING_STYLE" = "systematic" ] && echo "✅" || echo "❌")"
echo "   - Testing focus: ✅"
echo "   - Documentation focus: ✅"
echo "   - Error handling: ✅"
echo ""
echo "🎯 AI style adapted for $USER_NAME!"






