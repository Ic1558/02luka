#!/bin/zsh
# Wrapper to run gemini_bridge.py with the correct virtual environment

# 1. Check if venv exists
if [[ ! -d "infra/gemini_env" ]]; then
    echo "🔧 Creating virtual environment..."
    python3 -m venv infra/gemini_env
    echo "📦 Installing dependencies..."
    infra/gemini_env/bin/pip install google-cloud-aiplatform watchdog
fi

LOCKDIR="/tmp/gemini_bridge.lock"

# --- Atomic lock ---
if ! mkdir "$LOCKDIR" 2>/dev/null; then
    echo "⚠️  Bridge already running (lock exists)."
    exit 0
fi
trap 'rmdir "$LOCKDIR"' EXIT INT TERM

# --- venv ---

# 4. Run the bridge (exec replaces shell, making python the PID owner)
echo "🚀 Starting Gemini Bridge (locked)..."
exec infra/gemini_env/bin/python3 -u gemini_bridge.py
