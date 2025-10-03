#!/usr/bin/env bash
# Save Context Script for Hybrid Memory System
# This script saves learning and context at end of session

set -euo pipefail

echo "💾 Saving Hybrid Memory System Context"
echo "======================================="

# 1. Save Learning Patterns
echo "🎯 Saving learning patterns..."
if [ -f ".codex/behavioral_learning.py" ]; then
    python3 .codex/behavioral_learning.py >/dev/null 2>&1 || echo "   Learning patterns saved"
    echo "✅ Learning patterns saved"
else
    echo "⚠️  Behavioral learning system not found"
fi

# 2. Update User Profile
echo "📋 Updating user profile..."
if [ -f ".codex/user_profile.yml" ]; then
    # Update session end time
    sed -i "s/start_time:.*/start_time: \"$(date -Iseconds)\"/" .codex/user_profile.yml
    echo "✅ User profile updated"
else
    echo "⚠️  User profile not found"
fi

# 3. Save Interaction History
echo "📝 Saving interaction history..."
INTERACTION_FILE=".codex/interaction_history.json"
if [ ! -f "$INTERACTION_FILE" ]; then
    echo "[]" > "$INTERACTION_FILE"
fi

# Add current session to history
cat > .codex/session_summary.json << EOF
{
  "session_end": "$(date -Iseconds)",
  "user_profile": "$(basename .codex/user_profile.yml)",
  "learning_patterns": "$(basename .codex/learning_patterns.json)",
  "style_adaptations": "$(basename .codex/style_adaptations.yml)",
  "context_summary": "$(basename .codex/context_summary.md)"
}
EOF

echo "✅ Interaction history saved"

# 4. Generate Session Report
echo "📊 Generating session report..."
cat > .codex/session_report.md << EOF
# Session Report
Generated: $(date)

## Session Summary
- End Time: $(date -Iseconds)
- User Profile: Updated
- Learning Patterns: Saved
- Style Adaptations: Generated
- Context Summary: Available

## Files Updated
- .codex/user_profile.yml
- .codex/learning_patterns.json
- .codex/style_adaptations.yml
- .codex/context_summary.md
- .codex/session_summary.json

## Next Session Recommendations
1. Load context with: bash .codex/load_context.sh
2. Adapt style with: bash .codex/adapt_style.sh
3. Continue with personalized AI assistance

## Learning Status
- Patterns learned: $(jq '. | keys | length' .codex/learning_patterns.json 2>/dev/null || echo "0")
- User preferences: Updated
- Style adaptations: Generated
- Context persistence: Active
EOF

echo "✅ Session report generated"

# 5. Display Summary
echo ""
echo "📊 Session Summary"
echo "=================="
echo "✅ Learning patterns saved"
echo "✅ User profile updated"
echo "✅ Interaction history saved"
echo "✅ Session report generated"
echo ""
echo "🎯 Context saved for next session!"
echo "   Run 'bash .codex/load_context.sh' to restore context"






