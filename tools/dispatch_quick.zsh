#!/usr/bin/env zsh
# Quick Dispatch Tool
# Provides shortcuts for common CI and monitoring operations

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
ROOT="${ROOT:-$HOME/02luka}"

usage() {
  cat <<EOF
Usage: dispatch_quick.zsh <command>

Available commands:
  ci:ocr:telemetry    Show OCR SHA256 failure telemetry
  help                Show this help message

EOF
  exit 0
}

case "${1:-help}" in
  ci:ocr:telemetry)
    exec "$SCRIPT_DIR/ocr_telemetry.zsh"
    ;;

  help|--help|-h)
    usage
    ;;

  *)
    echo "❌ Unknown command: $1" >&2
    echo ""
    usage
    ;;
esac
