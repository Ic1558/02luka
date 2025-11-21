#!/bin/bash
# Test Gemini Connector with venv
# Created: 2025-11-21
# Agent: Liam (Antigravity/Google Gemini)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VENV_PATH="$REPO_ROOT/venv"

echo "=== Gemini Connector Test ==="
echo ""

# Check if venv exists
if [ ! -d "$VENV_PATH" ]; then
    echo "❌ Virtual environment not found at: $VENV_PATH"
    echo ""
    echo "Creating venv..."
    cd "$REPO_ROOT"
    python3 -m venv venv
    echo "✅ venv created"
    echo ""
    echo "Installing google-generativeai..."
    source venv/bin/activate
    pip install google-generativeai
    echo "✅ google-generativeai installed"
else
    echo "✅ venv found at: $VENV_PATH"
fi

echo ""
echo "Activating venv..."
source "$VENV_PATH/bin/activate"
echo "✅ venv activated"
echo ""

# Test 1: Import test
echo "Test 1: Import GeminiConnector"
python -c "from g.connectors.gemini_connector import GeminiConnector; print('✅ Import successful')" || {
    echo "❌ Import failed"
    exit 1
}
echo ""

# Test 2: Connector initialization
echo "Test 2: Initialize connector"
python -c "
from g.connectors.gemini_connector import GeminiConnector
gc = GeminiConnector()
print(f'✅ Connector available: {gc.is_available()}')
print(f'   Model: {gc.model_name}')
" || {
    echo "❌ Initialization failed"
    exit 1
}
echo ""

# Test 3: Check quota (if check_quota.py exists)
if [ -f "$REPO_ROOT/g/tools/check_quota.py" ]; then
    echo "Test 3: Check API quota"
    python "$REPO_ROOT/g/tools/check_quota.py" || {
        echo "⚠️  Quota check failed (may be API key issue)"
    }
else
    echo "Test 3: Skipped (check_quota.py not found)"
fi

echo ""
echo "=== All Tests Complete ==="
