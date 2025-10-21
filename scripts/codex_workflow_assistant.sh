#!/usr/bin/env bash
set -euo pipefail

# CLS Codex Workflow Assistant
# Helps streamline the manual selection/conflict resolution process

# Handle --scan argument
SCAN_MODE=false
if [[ "${1:-}" == "--scan" ]]; then
    SCAN_MODE=true
fi

echo "🧠 CLS Codex Workflow Assistant"
echo "=============================="

# Function to check for conflicts
check_conflicts() {
    echo "1) Checking for file conflicts..."
    
    # Check git status for conflicts
    if git status --porcelain | grep -q "^UU\|^AA\|^DD"; then
        echo "❌ Git conflicts detected:"
        git status --porcelain | grep -E "^UU|^AA|^DD"
        return 1
    else
        echo "✅ No git conflicts detected"
        return 0
    fi
}

# Function to suggest conflict resolution
suggest_resolution() {
    echo ""
    echo "2) Conflict Resolution Suggestions:"
    echo "   For .github/workflows/ci.yml conflicts:"
    echo "   - Keep the Node.js setup steps"
    echo "   - Keep the CI-friendly smoke test"
    echo "   - Merge environment variables"
    echo ""
    echo "   For scripts/smoke.sh conflicts:"
    echo "   - Use the CI-friendly version (targets Worker)"
    echo "   - Keep the health check logic"
    echo "   - Preserve the override handling"
}

# Function to create a clean patch
create_clean_patch() {
    echo ""
    echo "3) Creating clean patch for manual application..."
    
    # Create a patch file with all changes
    git diff --no-index /dev/null scripts/smoke.sh > g/patches/smoke_clean.patch 2>/dev/null || true
    git diff HEAD~1 .github/workflows/ci.yml > g/patches/ci_clean.patch 2>/dev/null || true
    
    echo "✅ Clean patches created in g/patches/"
    echo "   Apply manually: git apply g/patches/smoke_clean.patch"
    echo "   Apply manually: git apply g/patches/ci_clean.patch"
}

# Function to suggest batch operations
suggest_batch() {
    echo ""
    echo "4) Batch Operation Suggestions:"
    echo "   Instead of individual file changes, consider:"
    echo "   - Apply all changes at once"
    echo "   - Use 'Accept All' for non-conflicting changes"
    echo "   - Resolve conflicts in order of dependency"
    echo ""
    echo "   Order:"
    echo "   1. scripts/smoke.sh (no dependencies)"
    echo "   2. .github/workflows/ci.yml (depends on smoke.sh)"
    echo "   3. docs/DEPLOY.md (documentation only)"
}

# Function to create a workflow checklist
create_checklist() {
    echo ""
    echo "5) Manual Workflow Checklist:"
    echo "   □ Review scripts/smoke.sh changes"
    echo "   □ Apply scripts/smoke.sh"
    echo "   □ Review .github/workflows/ci.yml changes"
    echo "   □ Resolve any conflicts in ci.yml"
    echo "   □ Apply .github/workflows/ci.yml"
    echo "   □ Review docs/DEPLOY.md changes"
    echo "   □ Apply docs/DEPLOY.md"
    echo "   □ Test: bash scripts/smoke.sh"
    echo "   □ Test: git push (if applicable)"
}

# Function to generate conflict report
generate_conflict_report() {
    echo ""
    echo "4) Generating conflict report..."
    
    REPORT_FILE="g/reports/workflow_conflicts_$(date +%Y%m%d_%H%M).md"
    mkdir -p "$(dirname "$REPORT_FILE")"
    
    cat > "$REPORT_FILE" << EOF
# CLS Workflow Conflict Report

**Generated:** $(date -Iseconds)  
**Mode:** ${SCAN_MODE:+Scan} ${SCAN_MODE:-Manual}

## Conflict Analysis

$(if check_conflicts; then echo "✅ No conflicts detected"; else echo "❌ Conflicts detected - see details below"; fi)

## Resolution Suggestions

$(suggest_resolution)

## Batch Operation Recommendations

$(suggest_batch)

## Manual Workflow Checklist

$(create_checklist)

## Telemetry

- Conflict rate: $(git status --porcelain | grep -c "^UU\|^AA\|^DD" || echo 0)
- Auto-merge success: TBD
- Manual effort saved: Estimated
- Token savings: TBD

EOF
    
    echo "✅ Conflict report generated: $REPORT_FILE"
}

# Function to log telemetry
log_telemetry() {
    echo ""
    echo "5) Logging telemetry..."
    
    TELEM_FILE="g/telemetry/codex_workflow.log"
    mkdir -p "$(dirname "$TELEM_FILE")"
    
    cat >> "$TELEM_FILE" << EOF
{"timestamp":"$(date -Iseconds)","mode":"${SCAN_MODE:+scan}${SCAN_MODE:-manual}","conflicts":$(git status --porcelain | grep -c "^UU\|^AA\|^DD" || echo 0),"auto_resolved":0,"manual_effort_saved":0,"token_savings":0}
EOF
    
    echo "✅ Telemetry logged to $TELEM_FILE"
}

# Main execution
echo "Starting workflow analysis..."

if check_conflicts; then
    echo "✅ No conflicts - you can apply all changes safely"
    suggest_batch
else
    suggest_resolution
    create_clean_patch
fi

create_checklist
generate_conflict_report
log_telemetry

echo ""
echo "🎯 CLS Workflow Assistant Complete"
echo "   This reduces manual work by providing:"
echo "   - Conflict detection and resolution suggestions"
echo "   - Clean patches for manual application"
echo "   - Batch operation recommendations"
echo "   - Step-by-step workflow checklist"
echo "   - Telemetry logging for performance tracking"
