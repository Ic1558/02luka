#!/usr/bin/env zsh
# Quick Dispatch Commands for Common Operations
# Usage: ./dispatch_quick.zsh <command>

set -euo pipefail

ROOT="$HOME/02luka"

case "${1:-}" in
  ci:ocr:telemetry)
    exec "$ROOT/tools/ocr_telemetry.zsh"
    ;;

  ci:ocr:consumer)
    exec "$ROOT/f/bridge/processors/ocr_consumer.zsh"
    ;;

  ci:ocr:consumer:simple)
    exec "$ROOT/f/bridge/processors/ocr_consumer_simple.zsh"
    ;;

  ci:test:ocr)
    exec "$ROOT/tests/ocr_consumer_hash_fail.test.sh"
    ;;

  help|--help|-h|"")
    cat <<'EOF'
Available commands:

  ci:ocr:telemetry        - View OCR SHA256 validation telemetry
  ci:ocr:consumer         - Run OCR consumer (full version)
  ci:ocr:consumer:simple  - Run OCR consumer (simplified version)
  ci:test:ocr             - Run OCR integration tests

Examples:
  ./dispatch_quick.zsh ci:ocr:telemetry
  ./dispatch_quick.zsh ci:test:ocr

EOF
    ;;

  *)
    echo "❌ Unknown command: $1"
    echo "Run './dispatch_quick.zsh help' for available commands"
    exit 1
    ;;
esac
