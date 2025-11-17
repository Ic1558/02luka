#!/usr/bin/env zsh
set -euo pipefail

usage() {
  echo "Usage: $0 --path <relative> --patch-type <unified_diff> --patch-file <file> [--allow-create true|false] [--allow-delete true|false]" >&2
  exit 1
}

TARGET_REL=""
PATCH_TYPE=""
PATCH_FILE=""
ALLOW_CREATE="false"
ALLOW_DELETE="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --path) TARGET_REL="$2"; shift 2;;
    --patch-type) PATCH_TYPE="$2"; shift 2;;
    --patch-file) PATCH_FILE="$2"; shift 2;;
    --allow-create) ALLOW_CREATE="$2"; shift 2;;
    --allow-delete) ALLOW_DELETE="$2"; shift 2;;
    *) usage;;
  esac
done

[[ -n "$TARGET_REL" && -n "$PATCH_TYPE" && -n "$PATCH_FILE" ]] || usage
[[ -f "$PATCH_FILE" ]] || { echo "patch file not found: $PATCH_FILE" >&2; exit 2; }
[[ "$PATCH_TYPE" == "unified_diff" ]] || { echo "unsupported patch type: $PATCH_TYPE" >&2; exit 3; }

BASE="${LUKA_SOT:-$HOME/02luka}"
TARGET_ABS="$(realpath -m "$BASE/$TARGET_REL")"

[[ "$TARGET_ABS" == "$BASE"/* ]] || { echo "target escapes repo: $TARGET_REL" >&2; exit 4; }

if [[ "$ALLOW_CREATE" != "true" && ! -f "$TARGET_ABS" ]]; then
  echo "target does not exist and creation not allowed: $TARGET_REL" >&2
  exit 5
fi

PATCH_PLUS="$(grep '^\+\+\+ ' "$PATCH_FILE" | head -1 | awk '{print $2}')"
PATCH_MINUS="$(grep '^--- ' "$PATCH_FILE" | head -1 | awk '{print $2}')"
strip_prefix() { echo "${1##a/}" | sed 's#^b/##'; }
PATCH_PLUS_STRIPPED="$(strip_prefix "${PATCH_PLUS:-}" )"
PATCH_MINUS_STRIPPED="$(strip_prefix "${PATCH_MINUS:-}" )"

if [[ "$PATCH_PLUS_STRIPPED" == "/dev/null" || "$PATCH_MINUS_STRIPPED" == "/dev/null" ]]; then
  [[ "$ALLOW_DELETE" == "true" ]] || { echo "delete patch not allowed for $TARGET_REL" >&2; exit 6; }
else
  if [[ "$PATCH_PLUS_STRIPPED" != "$TARGET_REL" && "$PATCH_MINUS_STRIPPED" != "$TARGET_REL" ]]; then
    echo "patch target mismatch (expected $TARGET_REL, saw $PATCH_PLUS_STRIPPED / $PATCH_MINUS_STRIPPED)" >&2
    exit 7
  fi
fi

mkdir -p "$(dirname "$TARGET_ABS")"

print_json() {
  local status="$1" detail="$2"
  jq -n --arg status "$status" --arg detail "$detail" '{status:$status, detail:$detail}'
}

cd "$BASE"

if patch --dry-run --silent --forward -p0 < "$PATCH_FILE"; then
  patch --forward -p0 < "$PATCH_FILE" >/dev/null
  print_json "applied" "patch applied"
elif patch --dry-run --silent --reverse -p0 < "$PATCH_FILE"; then
  print_json "already_applied" "patch already present"
else
  print_json "failed" "patch dry-run failed" >&2
  exit 8
fi
