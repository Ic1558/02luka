#!/bin/zsh
# Wrapper to run gemini_bridge.py with the correct virtual environment
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${(%):-%N}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
VENV_DIR="$REPO_ROOT/infra/gemini_env"

cd "$REPO_ROOT"

# 1. Check if venv exists
if [[ ! -d "$VENV_DIR" ]]; then
    echo "🔧 Creating virtual environment..."
    python3 -m venv "$VENV_DIR"
fi

# Always ensure dependencies are up to date (idempotent)
echo "📦 Ensuring pip tooling..."
"$VENV_DIR/bin/python" -m pip install --upgrade pip setuptools wheel

echo "📦 Ensuring runtime deps..."
# Fallback minimal deps (keep tiny; real SOT should be requirements files)
"$VENV_DIR/bin/python" -m pip install --upgrade \
  google-cloud-aiplatform "watchdog>=4.0.0" google-generativeai

# Install from repo requirements (preferred SOT)
if [[ -f "$REPO_ROOT/requirements.txt" ]]; then
  echo "📦 Installing from requirements.txt..."
  "$VENV_DIR/bin/python" -m pip install --upgrade -r "$REPO_ROOT/requirements.txt"
fi

# Optional: agent-specific requirements (if you have it; safe if missing)
if [[ -f "$REPO_ROOT/agents/gmx/requirements.txt" ]]; then
  echo "📦 Installing from agents/gmx/requirements.txt..."
  "$VENV_DIR/bin/python" -m pip install --upgrade -r "$REPO_ROOT/agents/gmx/requirements.txt"
fi

# Sanity check (non-fatal but useful signal)
"$VENV_DIR/bin/python" -m pip check || true

LOCKDIR="/tmp/gemini_bridge.lock"

# --- Atomic lock ---
if [[ -d "$LOCKDIR" ]]; then
    if [[ -f "$LOCKDIR/pid" ]]; then
        pid="$(cat "$LOCKDIR/pid" || true)"
        if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
            echo "⚠️  Bridge already running (PID $pid)."
            exit 0
        fi
    fi
    rm -rf "$LOCKDIR"
fi

if ! mkdir "$LOCKDIR" 2>/dev/null; then
    echo "⚠️  Bridge already running (lock exists)."
    exit 0
fi
echo $$ > "$LOCKDIR/pid"
trap 'rm -rf "$LOCKDIR"' EXIT INT TERM

# --- venv ---

# 4. Run the bridge (exec replaces shell, making python the PID owner)
if [[ "${BRIDGE_DEBUG:-}" == "1" ]]; then
    echo "BRIDGE_PATH=$0"
    echo "PWD=$(pwd)"
    echo "PID=$$"
fi

echo "🚀 Starting Gemini Bridge (locked)..."
exec "$VENV_DIR/bin/python3" -u "$REPO_ROOT/gemini_bridge.py"
