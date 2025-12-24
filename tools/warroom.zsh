#!/usr/bin/env zsh
set -euo pipefail

# tools/warroom.zsh - Consultant Mode Generator
# Purpose: Start the "Think-Before-Act" pipeline by creating a Decision Box draft

REPO_ROOT="${REPO_ROOT:-"$HOME/02luka"}"
DECISION_DIR="$REPO_ROOT/g/decision"
DRAFTS_DIR="$DECISION_DIR/drafts"
TEMPLATE="$DECISION_DIR/DECISION_BOX.md"
LAC_MIRROR="$DECISION_DIR/LAC_REASONING_MIRROR.md"

mkdir -p "$DRAFTS_DIR"

# --check mode: Verify core files exist
if [[ "${1:-}" == "--check" ]]; then
    ok=true
    for f in "$TEMPLATE" "$LAC_MIRROR"; do
        if [[ -f "$f" ]]; then
            echo "OK: $f"
        else
            echo "MISSING: $f"
            ok=false
        fi
    done
    
    if $ok; then exit 0; else exit 1; fi
fi

# Normal mode: Create draft
topic="${1:-'Unnamed Strategic Topic'}"
# Sluggify topic: lowercase, replace spaces with hyphens, remove special chars
slug=$(echo "$topic" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/-\+/-/g' | sed 's/^-//;s/-$//')
ts=$(date +"%Y%m%d_%H%M%S")

out="$DRAFTS_DIR/${ts}_${slug}_DECISION_BOX.md"

if [[ -f "$TEMPLATE" ]]; then
    # Create from template with header injection
    cat > "$out" <<EOF
# Strategic Decision: $topic
**Status:** DRAFT
**Timestamp:** $(date)

---
EOF
    cat "$TEMPLATE" >> "$out"
    echo "" >> "$out"
    echo "---" >> "$out"
    echo "TODO: Run LAC Mirror checks: $LAC_MIRROR" >> "$out"
else
    # Fallback stub if template missing
    cat > "$out" <<EOF
# Warroom Draft (Stub)
**Topic:** $topic
**Timestamp:** $ts
**Warning:** Template not found at $TEMPLATE

Status: NOT IMPLEMENTED
EOF
fi

# Clear, actionable output
echo ""
echo "✅ Decision Box created:"
echo "$out"
echo ""
echo "Next Steps:"
echo "  1. Open the file: code \"$out\""
echo "  2. Fill sections 1-3 (Objective, Context, Options)"
echo "  3. Use LAC Mirror: cat $LAC_MIRROR"
echo ""
echo "Skip if: routine ops / typo / tiny bugfix"