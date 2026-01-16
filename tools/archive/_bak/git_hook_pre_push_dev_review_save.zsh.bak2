#!/usr/bin/env zsh
# tools/git_hook_pre_push_dev_review_save.zsh
# Helper script to be called by a git pre-push hook.
# Runs the unified workflow (Review -> Snapshot -> Save).
# Interactive confirmation if workflow fails.

set -u

REPO_ROOT="${LUKA_MEM_REPO_ROOT:-$HOME/02luka}"
WORKFLOW_SCRIPT="$REPO_ROOT/tools/workflow_dev_review_save.zsh"

echo ""
echo "🔄 [Pre-Push] Running dev review chain..."

if [[ ! -f "$WORKFLOW_SCRIPT" ]]; then
    echo "❌ Workflow script not found: $WORKFLOW_SCRIPT"
    # Failsafe: Ask to continue anyway?
    echo "⚠️  Warning: Safety chain missing."
    read -q "response?Continue push anyway? [y/N] "
    echo ""
    if [[ "$response" != "y" ]]; then
        exit 1
    fi
    exit 0
fi

# Run workflow
# Capture output to check status, but also stream to stdout
# Since the workflow handles its own exit codes logic (exit 0 or 1),
# we check the script's final exit code.

"$WORKFLOW_SCRIPT"
WORKFLOW_EXIT=$?

if [[ $WORKFLOW_EXIT -ne 0 ]]; then
    echo ""
    echo "❌ [Pre-Push] Workflow chain reported issues (Exit: $WORKFLOW_EXIT)."
    echo "   Check output above for Review or Save errors."
    echo ""
    read -q "response?⚠️  Continue push despite errors? [y/N] "
    echo ""
    if [[ "$response" != "y" ]]; then
        echo "🚫 Push aborted."
        exit 1
    fi
    echo "⚠️  Proceeding with push (User override)..."
else
    echo "✅ [Pre-Push] Workflow chain clean."
fi

exit 0
