#!/usr/bin/env zsh
# Setup script for then.app on new device
# Usage: zsh setup_then_app.zsh

set -euo pipefail

APP_PATH="/Applications/then.app"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 then.app Setup Script"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if app exists
if [[ ! -d "$APP_PATH" ]]; then
  echo "❌ then.app not found at $APP_PATH"
  echo ""
  echo "Please install then.app first:"
  echo "  1. Copy then.app-signed.tar.gz to this device"
  echo "  2. Extract: cd /Applications && tar -xzf ~/then.app-signed.tar.gz"
  echo "  3. Run this script again"
  exit 1
fi

# Verify signature
echo "📋 Checking code signature..."
if codesign -dvvv "$APP_PATH" 2>&1 | grep -q "flags=0x10002(adhoc,runtime)"; then
  echo "  ✅ Hardened runtime signature verified"
else
  echo "  ⚠️  Signature may not have hardened runtime"
  echo "  App might not launch without additional setup"
fi
echo ""

# Remove quarantine attributes
echo "🔓 Removing quarantine attributes..."
xattr -cr "$APP_PATH" 2>&1 || echo "  ℹ️  No quarantine attributes found (OK)"
echo ""

# Check Gatekeeper status
echo "🔐 Checking Gatekeeper status..."
if spctl --assess --verbose "$APP_PATH" 2>&1 | grep -q "accepted"; then
  echo "  ✅ Gatekeeper accepts this app"
else
  echo "  ℹ️  Gatekeeper shows 'rejected' but app may still launch"
  echo "     (Hardened runtime apps can run despite this message)"
fi
echo ""

# Test launch
echo "🚀 Testing launch..."
open -a "$APP_PATH" 2>&1 || echo "  ⚠️  Launch command executed (check below for status)"

sleep 2

# Check if running
if ps aux | grep -v grep | grep -q "$APP_PATH/Contents/MacOS/then"; then
  echo "  ✅ then.app is running!"
  echo ""
  echo "Process info:"
  ps aux | grep -v grep | grep "$APP_PATH/Contents/MacOS/then" | head -1
else
  echo "  ⚠️  then.app may not have started"
  echo "     (It's a background service - check Activity Monitor)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Setup complete!"
echo ""
echo "ℹ️  then.app is a background service (LSUIElement=true)"
echo "   It won't appear in the Dock or have a visible window."
echo ""
echo "To verify it's running:"
echo "  ps aux | grep -i then"
echo "  # or check Activity Monitor"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
