#!/bin/zsh
# Wrapper to run gemini_bridge.py with the correct virtual environment

# 1. Check if venv exists
if [[ ! -d "infra/gemini_env" ]]; then
    echo "🔧 Creating virtual environment..."
    python3 -m venv infra/gemini_env
    echo "📦 Installing dependencies..."
    infra/gemini_env/bin/pip install google-cloud-aiplatform watchdog
fi

# 2. Run the bridge
echo "🚀 Starting Gemini Bridge..."
infra/gemini_env/bin/python3 gemini_bridge.py
