#!/usr/bin/env zsh
# tools/run_tool.zsh
# The Single Entry Point for 02luka Operations
# Enforces: Catalog Discovery, Agent Identity, and Safe Execution.

set -e

# 1. Environment Enforcement
export REPO_ROOT="${REPO_ROOT:-$HOME/02luka}"
export AGENT_ID="gmx"  # Enforce consistent identity
export TOOL_RUNNER_VERSION="1.0"
export RUN_TOOL_DISPATCH=1 # Signal that we are running via the canonical dispatcher

# 2. Argument Parsing
if [[ $# -lt 1 ]]; then
    echo "Usage: zsh tools/run_tool.zsh <alias|tool_name> [args...]"
    echo "       zsh tools/run_tool.zsh discover   (Shows Catalog)"
    exit 1
fi

ALIAS="$1"
shift

# 3. Special Command: Discover
if [[ "$ALIAS" == "discover" ]]; then
    echo "🔍 Discovery: Listing Canonical Tools from CATALOG.md..."
    echo ""
    grep "| \*\*" "$REPO_ROOT/tools/CATALOG.md" || echo "Catalog empty/invalid."
    echo ""
    exit 0
fi

# 4. Catalog Lookup
LOOKUP_SCRIPT="$REPO_ROOT/tools/catalog_lookup.zsh"
if [[ ! -x "$LOOKUP_SCRIPT" ]]; then
    # Auto-fix permissions if needed, locally
    chmod +x "$LOOKUP_SCRIPT" 2>/dev/null || true
fi

echo "🔎 Looking up: '$ALIAS'..."
TARGET_SCRIPT=$("$LOOKUP_SCRIPT" "$ALIAS") || {
    echo "❌ Error: Tool '$ALIAS' not found in Catalog."
    echo "   Run 'zsh tools/run_tool.zsh discover' to see available tools."
    exit 1
}

# 5. Execution Guard
TARGET_PATH="$REPO_ROOT/$TARGET_SCRIPT"
if [[ ! -f "$TARGET_PATH" ]]; then
    # Try direct if lookup returned partial
    if [[ -f "$TARGET_SCRIPT" ]]; then 
        TARGET_PATH="$TARGET_SCRIPT"
    else 
        echo "❌ Error: File missing at $TARGET_PATH"
        exit 1
    fi
fi

echo "🚀 Executing: $TARGET_SCRIPT (as $AGENT_ID)"
echo "---------------------------------------------------"
# Handover execution to the target script
# We filter args to ensure "$@" is passed correctly
exec zsh "$TARGET_PATH" "$@"
