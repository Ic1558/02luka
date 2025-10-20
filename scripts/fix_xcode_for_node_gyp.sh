#!/usr/bin/env bash
# fix_xcode_for_node_gyp.sh
# Fix node-gyp Xcode detection issue on macOS 15 (Sequoia)
#
# Issue: node-gyp cannot detect Xcode Command Line Tools version on macOS 15
# Solution: Temporarily install full Xcode or use workaround

set -euo pipefail

echo "=== Fixing node-gyp Xcode Detection (macOS 15 Issue) ==="
echo ""

# Check macOS version
OS_VERSION=$(sw_vers -productVersion)
echo "macOS Version: $OS_VERSION"
echo ""

# Check if Xcode is installed
if [ -d "/Applications/Xcode.app" ]; then
  echo "✅ Xcode is installed"
  sudo xcode-select --switch /Applications/Xcode.app
  echo "✅ Switched to Xcode developer directory"
  echo ""
  echo "Now try installing better-sqlite3:"
  echo "  cd knowledge && npm install better-sqlite3"
  exit 0
fi

echo "⚠️  Xcode (full version) is not installed"
echo ""
echo "Options to fix:"
echo ""
echo "Option 1: Install Xcode from App Store (RECOMMENDED)"
echo "  1. Open App Store"
echo "  2. Search for 'Xcode'"
echo "  3. Install (requires ~15GB disk space)"
echo "  4. Run: sudo xcode-select --switch /Applications/Xcode.app"
echo "  5. Run: cd knowledge && npm install better-sqlite3"
echo ""
echo "Option 2: Reinstall Command Line Tools"
echo "  1. Remove existing: sudo rm -rf /Library/Developer/CommandLineTools"
echo "  2. Reinstall: xcode-select --install"
echo "  3. Wait for installation to complete"
echo "  4. Try: cd knowledge && npm install better-sqlite3"
echo ""
echo "Option 3: Wait for node-gyp fix"
echo "  The node-gyp team is working on macOS 15 compatibility."
echo "  Track issue: https://github.com/nodejs/node-gyp/issues"
echo ""
echo "For now, this script cannot automatically fix the issue without sudo."
echo "Please choose one of the options above."
