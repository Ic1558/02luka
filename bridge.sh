#!/usr/bin/env zsh
# Wrapper to run gemini_bridge.py with the correct virtual environment
# Notes:
# - Python 3.14 may break older build deps (e.g., pathtools -> imp). Prefer 3.12/3.11 for venv.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${(%):-%N}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
VENV_DIR="$REPO_ROOT/infra/gemini_env"

cd "$REPO_ROOT"

# Pick a stable python for the venv (prefer 3.12, then 3.11)
# You can override by exporting PY_BIN=python3.12 (or full path).
PY_BIN="${PY_BIN:-}"
if [[ -z "${PY_BIN}" ]]; then
  if command -v python3.12 >/dev/null 2>&1; then
    PY_BIN="python3.12"
  elif command -v python3.11 >/dev/null 2>&1; then
    PY_BIN="python3.11"
  else
    PY_BIN="python3"
  fi
fi

# 1) Create venv if missing (locks python version at creation time)
if [[ ! -d "$VENV_DIR" ]]; then
  echo "🔧 Creating virtual environment with: $PY_BIN"
  "$PY_BIN" -m venv "$VENV_DIR"
fi

# 2) Always ensure dependencies are up to date (idempotent)
echo "📦 Ensuring pip tooling (pip/setuptools/wheel)..."
"$VENV_DIR/bin/python" -m pip install --upgrade pip setuptools wheel >/dev/null

echo "📦 Ensuring runtime deps..."
# Fallback minimal deps (keep tiny; real SOT should be requirements files)
# watchdog>=4 reduces legacy build-dep issues on newer pythons.
"$VENV_DIR/bin/python" -m pip install --upgrade \
  google-cloud-aiplatform "watchdog>=4" google-generativeai

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
    # Process is dead; we can't always rm -rf /tmp/xxx under Seatbelt,
    # but we can try to reuse the directory and overwrite the PID.
    echo $$ > "$LOCKDIR/pid" || { rm -rf "$LOCKDIR" && mkdir "$LOCKDIR" && echo $$ > "$LOCKDIR/pid"; }
  else
    # Dir exists but no PID; try to clean up or reuse
    rm -rf "$LOCKDIR" 2>/dev/null || true
    mkdir -p "$LOCKDIR" && echo $$ > "$LOCKDIR/pid"
  fi
else
  mkdir "$LOCKDIR" && echo $$ > "$LOCKDIR/pid"
fi

trap 'rm -rf "$LOCKDIR"' EXIT INT TERM

# --- venv ---

# 4. Run the bridge (exec replaces shell, making python the PID owner)
if [[ "${BRIDGE_DEBUG:-}" == "1" ]]; then
  echo "BRIDGE_PATH=$0"
  echo "PWD=$(pwd)"
  echo "PID=$$"
  echo "PY_BIN(venv_creator)=$PY_BIN"
fi

echo "🚀 Starting Gemini Bridge (locked)..."
exec "$VENV_DIR/bin/python3" -u "$REPO_ROOT/gemini_bridge.py"
