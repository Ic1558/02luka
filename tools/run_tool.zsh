#!/usr/bin/env zsh
# run_tool.zsh — Single Entry Point for ALL Tools
#
# Purpose: Force all tool calls through catalog (SOT)
# Fallback: Auto-discovery if tool not in catalog (warn but allow)
#
# Usage: zsh tools/run_tool.zsh <tool-id> [args...]
# Example: zsh tools/run_tool.zsh code-review staged --quick

set -euo pipefail

LUKA_BASE="${LUKA_BASE:-$HOME/02luka}"
CATALOG="$LUKA_BASE/tools/catalog.yaml"
CATALOG_LOOKUP="$LUKA_BASE/tools/catalog_lookup.zsh"

tool_id="${1:-}"

if [[ -z "$tool_id" ]]; then
    cat << 'EOF' >&2
Usage: zsh tools/run_tool.zsh <tool-id> [args...]

Examples:
    zsh tools/run_tool.zsh code-review staged
    zsh tools/run_tool.zsh save-now
    zsh tools/run_tool.zsh spawn my-plugin "input"

List available tools:
    zsh tools/catalog_lookup.zsh --list
EOF
    exit 1
fi

shift || true

# Step 1: Try catalog lookup first (preferred path)
if [[ -f "$CATALOG_LOOKUP" ]]; then
    catalog_result=$(zsh "$CATALOG_LOOKUP" "$tool_id" 2>/dev/null || true)
    
    if echo "$catalog_result" | /usr/bin/grep -q "entry:"; then
        # Extract entry path
        entry=$(echo "$catalog_result" | /usr/bin/grep "^entry:" | sed 's/^entry:[[:space:]]*//' | tr -d '"' | head -1)
        
        if [[ -n "$entry" ]]; then
            # Normalize path
            if [[ "$entry" == ./* ]]; then
                cmd="$LUKA_BASE/${entry#./}"
            else
                cmd="$LUKA_BASE/$entry"
            fi
            
            # Check if file exists and is executable
            if [[ -f "$cmd" ]] && [[ -x "$cmd" ]]; then
                # ✅ Catalog path found and valid
                exec "$cmd" "$@"
            elif [[ -f "$cmd" ]]; then
                # File exists but not executable
                chmod +x "$cmd" 2>/dev/null || true
                exec "$cmd" "$@"
            fi
        fi
    fi
fi

# Step 2: Fallback — Auto-discovery (warn but allow)
# This prevents blocking/lag when tool not in catalog or not yet created

# Try common patterns
possible_paths=(
    "$LUKA_BASE/tools/${tool_id}.zsh"
    "$LUKA_BASE/tools/${tool_id}.sh"
    "$LUKA_BASE/tools/${tool_id}"
    "$LUKA_BASE/tools/${tool_id}_gate.zsh"
    "$LUKA_BASE/tools/${tool_id}_gate.sh"
)

for path in "${possible_paths[@]}"; do
    if [[ -f "$path" ]]; then
        if [[ -x "$path" ]] || chmod +x "$path" 2>/dev/null; then
            # ⚠️ Fallback path found (not in catalog)
            echo "⚠️  Tool '$tool_id' not in catalog, using fallback: $path" >&2
            echo "   Suggestion: Add to tools/catalog.yaml" >&2
            exec "$path" "$@"
        fi
    fi
done

# Step 3: Last resort — Check if it's a direct path (for backward compatibility)
if [[ "$tool_id" == *"/"* ]] && [[ -f "$LUKA_BASE/$tool_id" ]]; then
    path="$LUKA_BASE/$tool_id"
    if [[ -x "$path" ]] || chmod +x "$path" 2>/dev/null; then
        echo "⚠️  Direct path detected (not recommended): $path" >&2
        echo "   Suggestion: Use tool-id instead: zsh tools/run_tool.zsh <tool-id>" >&2
        exec "$path" "$@"
    fi
fi

# Step 4: Not found — Show helpful error
/bin/cat << EOF >&2
❌ Tool '$tool_id' not found

Tried:
  1. Catalog lookup: $(zsh "$CATALOG_LOOKUP" "$tool_id" 2>/dev/null | /usr/bin/grep "entry:" || echo "not found")
  2. Auto-discovery: ${possible_paths[*]}
  3. Direct path: $LUKA_BASE/$tool_id

Suggestions:
  • List available tools: zsh tools/catalog_lookup.zsh --list
  • Add to catalog: Edit tools/catalog.yaml
  • Check spelling: Is '$tool_id' the correct tool-id?
EOF

exit 1

