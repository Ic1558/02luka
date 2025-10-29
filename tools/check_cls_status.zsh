#!/usr/bin/env zsh
# Smoke test for CLS automation assets.
set -euo pipefail

SCRIPT_DIR=${0:A:h}
REPO_ROOT=${SCRIPT_DIR:A:h}
source "${SCRIPT_DIR}/lib/cli_common.zsh"

usage() {
  cat <<'USAGE'
Usage: tools/check_cls_status.zsh [--dry-run]

Validate repository-managed CLS assets and optionally perform a dry-run
bridge invocation.
USAGE
}

DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      die "Unknown option: $1"
      ;;
  esac
  shift
done

echo "$(ts) CLS status check"

TEMPLATE_PATH="$REPO_ROOT/CLS/templates/WO_TEMPLATE.yaml"
[[ -f $TEMPLATE_PATH ]] || die "missing WO template at $TEMPLATE_PATH"

echo "$(ts) Template present: $TEMPLATE_PATH"

BRIDGE_SCRIPT="$REPO_ROOT/tools/bridge_cls_clc.zsh"

if (( DRY_RUN )); then
  echo "$(ts) DRY: would drop WO and verify checksum"
  "$BRIDGE_SCRIPT" --title "CLS CI smoke" --priority P3 --tags "ci,test" --body "$TEMPLATE_PATH" --dry-run
else
  TMP_FILE=$(mktemp /tmp/cls_wo_XXXX.yaml)
  cp "$TEMPLATE_PATH" "$TMP_FILE"
  chmod +x "$BRIDGE_SCRIPT" || true
  "$BRIDGE_SCRIPT" --title "CLS CI smoke" --priority P3 --tags "ci,test" --body "$TMP_FILE"
  rm -f "$TMP_FILE"
fi

echo "$(ts) OK"
