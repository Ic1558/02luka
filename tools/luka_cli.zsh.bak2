#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname "$0")" && pwd)
BASE="${SCRIPT_DIR%/tools}"

usage() {
  echo "Usage: $0 lpe-apply --file <patch.yaml> | --stdin" >&2
  exit 1
}

[[ $# -gt 0 ]] || usage

case "$1" in
  lpe-apply)
    shift
    "$BASE/tools/lpe_apply_patch.zsh" "$@"
    ;;
  *)
    usage
    ;;
esac
