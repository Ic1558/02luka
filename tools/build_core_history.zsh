#!/usr/bin/env zsh
set -euo pipefail

# Thin wrapper: Seatbelt-safe (no here-doc execution).
# All logic lives in tools/build_core_history_engine.py

REPO="${REPO_ROOT:-$HOME/02luka}"
cd "$REPO"

# 1. Deterministic Interpreter Selection
# Priority: .venv > venv > system python3
if [[ -x ".venv/bin/python3" ]]; then
    PYTHON_EXE=".venv/bin/python3"
elif [[ -x "venv/bin/python3" ]]; then
    PYTHON_EXE="venv/bin/python3"
else
    PYTHON_EXE="python3"
fi

# 2. Validation & Logging (Fail-fast if < 3.9)
"$PYTHON_EXE" -c 'import sys; exit(0 if sys.version_info >= (3, 9) else 1)' || { echo "❌ Error: Python 3.9+ required ($PYTHON_EXE)"; exit 1; }

# Parse arguments
EXEC_HOOKS=0
ENGINE_ARGS=()
for arg in "$@"; do
    if [[ "$arg" == "--execute-hooks" ]]; then
        EXEC_HOOKS=1
    else
        ENGINE_ARGS+=("$arg")
    fi
done

# 3. Build Core History
"$PYTHON_EXE" tools/build_core_history_engine.py "${ENGINE_ARGS[@]}"

# 4. Handle Execution Hooks (Phase 14)
if [[ $EXEC_HOOKS -eq 1 ]]; then
    JSON_PATH="g/core_history/latest.json"
    if [[ -f "$JSON_PATH" ]]; then
        # Use Python to parse hooks safely
        HOOKS=$("$PYTHON_EXE" -c 'import json, sys; d=json.load(open("'"$JSON_PATH"'")); print(" ".join(d.get("hooks", {}).get("actionable", [])))')
        
        if [[ -n "$HOOKS" ]]; then
            echo "🏹 Actionable Hooks Found: $HOOKS"
            for hook in ${(z)HOOKS}; do
                case "$hook" in
                    save)
                        echo "🚀 Triggering auto-save..."
                        zsh tools/run_tool.zsh save
                        ;;
                    seal)
                        echo "🔒 Triggering auto-seal..."
                        # Using dispatcher for seal as well
                        zsh tools/run_tool.zsh save --seal
                        ;;
                    *)
                        echo "⚠️ Unknown hook: $hook"
                        ;;
                esac
            done
        fi
    fi
fi
