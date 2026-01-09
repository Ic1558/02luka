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

"$PYTHON_EXE" -c 'import sys; print(f"🔧 Core History: Using {sys.version.split()[0]} at {sys.executable}", file=sys.stderr)'

exec "$PYTHON_EXE" tools/build_core_history_engine.py "$@"
