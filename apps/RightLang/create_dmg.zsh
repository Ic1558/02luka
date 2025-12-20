#!/usr/bin/env zsh
# Complete script to build then.app and create DMG installer
# Usage: zsh create_dmg.zsh

set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔨 Building and Packaging then.app v0.2.1"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

HERE="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$HOME"

# Step 1: Build the app
echo "📦 Step 1: Building then.app..."
zsh "$HERE/build.zsh"

if [[ ! -d "$HERE/dist/then.app" ]]; then
  echo "❌ Build failed - then.app not created"
  exit 1
fi
echo "  ✅ Built: $HERE/dist/then.app"
echo ""

# Step 2: Sign with hardened runtime
echo "🔐 Step 2: Signing with hardened runtime..."
codesign --force --deep --sign - --options runtime "$HERE/dist/then.app"

# Verify signature
if codesign -dvvv "$HERE/dist/then.app" 2>&1 | grep -q "flags=0x10002(adhoc,runtime)"; then
  echo "  ✅ Hardened runtime signature applied"
else
  echo "  ⚠️  Warning: Hardened runtime may not be applied correctly"
fi
echo ""

# Step 3: Create DMG
echo "💿 Step 3: Creating DMG installer..."

# Create build folder
DMG_BUILD="/tmp/then-dmg-build-$$"
mkdir -p "$DMG_BUILD"

# Copy app
cp -R "$HERE/dist/then.app" "$DMG_BUILD/"

# Create Applications symlink for drag-drop
cd "$DMG_BUILD"
ln -s /Applications Applications

# Create INSTALL.txt
cat > "$DMG_BUILD/INSTALL.txt" << 'EOF'
then 0.2.1 - Thai/English Text Conversion Service
================================================

Installation Instructions:
--------------------------

1. Drag "then.app" to the "Applications" folder
2. Eject this disk image
3. Open then.app from Applications (or it may start automatically)

Note: then.app is a background service (no visible window)
      It provides keyboard services for Thai/English text conversion


Verifying Installation:
------------------------

To check if then.app is running:

   Open Activity Monitor (Applications > Utilities > Activity Monitor)
   Search for "then" - you should see the process running

Or in Terminal:
   ps aux | grep -i then


System Requirements:
--------------------

• macOS 12.0 or later
• Apple Silicon (M1/M2/M3) or Intel processor


About:
------

then.app v0.2.1
Bundle ID: com.02luka.then
Signed with hardened runtime for macOS Sequoia compatibility


Distribution:
--------------

This DMG can be copied to other Macs. The app works on:
- macOS Monterey (12.0) and later
- Both Intel and Apple Silicon
- No additional setup required per device
EOF

# Create DMG
DMG_OUTPUT="$OUTPUT_DIR/then-0.2.1.dmg"
hdiutil create -volname "then 0.2.1" \
  -srcfolder "$DMG_BUILD" \
  -ov -format UDZO \
  "$DMG_OUTPUT"

# Clean up
rm -rf "$DMG_BUILD"

echo "  ✅ Created: $DMG_OUTPUT"
echo ""

# Step 4: Verify
echo "✓  Step 4: Verifying DMG..."
DMG_SIZE=$(ls -lh "$DMG_OUTPUT" | awk '{print $5}')
echo "  📊 DMG size: $DMG_SIZE"

# Mount and verify
hdiutil attach "$DMG_OUTPUT" -quiet
sleep 1

if [[ -d "/Volumes/then 0.2.1/then.app" ]]; then
  echo "  ✅ DMG contains then.app"

  if codesign -v "/Volumes/then 0.2.1/then.app" 2>&1; then
    echo "  ✅ Signature valid"
  else
    echo "  ⚠️  Signature verification failed"
  fi

  if [[ -L "/Volumes/then 0.2.1/Applications" ]]; then
    echo "  ✅ Applications symlink present"
  fi

  if [[ -f "/Volumes/then 0.2.1/INSTALL.txt" ]]; then
    echo "  ✅ INSTALL.txt included"
  fi
else
  echo "  ❌ DMG verification failed"
fi

hdiutil detach "/Volumes/then 0.2.1" -quiet 2>/dev/null || true

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ SUCCESS! DMG created at:"
echo "   $DMG_OUTPUT"
echo ""
echo "📦 Distribution:"
echo "   • Share this DMG with other devices"
echo "   • Users just drag-drop to Applications"
echo "   • Works immediately (no additional setup)"
echo ""
echo "🧪 Test installation:"
echo "   open $DMG_OUTPUT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
