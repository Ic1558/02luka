#!/usr/bin/env zsh
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"

APP_NAME="then"
BUNDLE_DIR="$HERE/dist/${APP_NAME}.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

BUILD_CACHE_DIR="$HERE/.build_cache"
SWIFT_MODULE_CACHE="$BUILD_CACHE_DIR/swift_module_cache"
CLANG_MODULE_CACHE="$BUILD_CACHE_DIR/clang_module_cache"
TMP_DIR="$BUILD_CACHE_DIR/tmp"

rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
mkdir -p "$SWIFT_MODULE_CACHE" "$CLANG_MODULE_CACHE" "$TMP_DIR"

export TMPDIR="$TMP_DIR"

SWIFTC="$(xcrun --sdk macosx --find swiftc)"
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
LIPO="$(xcrun --sdk macosx --find lipo 2>/dev/null || true)"

ARM_OUT="$TMP_DIR/${APP_NAME}.arm64"
X64_OUT="$TMP_DIR/${APP_NAME}.x86_64"

common_args=(
  -sdk "$SDK_PATH"
  -emit-executable
  -parse-as-library
  -module-cache-path "$SWIFT_MODULE_CACHE"
  -Xcc "-fmodules-cache-path=$CLANG_MODULE_CACHE"
  -O
  -whole-module-optimization
  -framework Cocoa
  -framework Carbon
  -framework ApplicationServices
  "$HERE/src/RightLang.swift"
)

"$SWIFTC" "${common_args[@]}" -target arm64-apple-macosx12.0 -o "$ARM_OUT"

if [[ -n "$LIPO" ]]; then
  if "$SWIFTC" "${common_args[@]}" -target x86_64-apple-macosx12.0 -o "$X64_OUT" 2>/dev/null; then
    "$LIPO" -create -output "$MACOS_DIR/$APP_NAME" "$ARM_OUT" "$X64_OUT"
  else
    cp "$ARM_OUT" "$MACOS_DIR/$APP_NAME"
  fi
else
  cp "$ARM_OUT" "$MACOS_DIR/$APP_NAME"
fi

cp "$HERE/Info.plist" "$CONTENTS_DIR/Info.plist"

# Icon + basic resources
ICON_SRC="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/Actions.icns"
if [[ -f "$ICON_SRC" ]]; then
  cp "$ICON_SRC" "$RESOURCES_DIR/AppIcon.icns"
fi
if [[ -f "$HERE/resources/Credits.rtf" ]]; then
  cp "$HERE/resources/Credits.rtf" "$RESOURCES_DIR/Credits.rtf"
fi

# Ad-hoc sign for local execution
codesign --force --sign - --timestamp=none "$BUNDLE_DIR" >/dev/null 2>&1 || true

echo "Built: $BUNDLE_DIR"
