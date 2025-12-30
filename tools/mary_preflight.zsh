#!/usr/bin/env zsh
# ~/02luka/tools/mary_preflight.zsh
# Report-only preflight using Mary Router (no blocking)

set -uo pipefail
LUKA_ROOT="${LUKA_ROOT:-$HOME/02luka}"

error() {
  echo "Error: $1. Impact: $2. Fix: $3." >&2
}

warn_error() {
  echo "Error: $1. Impact: $2. Fix: $3." >&2
}

if [[ ! -d "$LUKA_ROOT" ]]; then
  error "LUKA_ROOT directory not found at $LUKA_ROOT" \
    "Mary preflight cannot run" \
    "Set LUKA_ROOT or create the repo at $HOME/02luka"
  exit 1
fi

if ! cd "$LUKA_ROOT"; then
  error "Failed to change directory to $LUKA_ROOT" \
    "Git status and routing cannot run" \
    "Check permissions and path"
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  error "git not found in PATH" \
    "Cannot detect changed files for preflight" \
    "Install git and retry"
  exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  error "Not a git repository at $LUKA_ROOT" \
    "Mary preflight cannot determine changed files" \
    "Run inside the repo or set LUKA_ROOT correctly"
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  error "python3 not found in PATH" \
    "Mary router cannot run" \
    "Install Python 3 or update PATH"
  exit 1
fi

MARY_DISPATCH="$LUKA_ROOT/tools/mary_dispatch.py"
if [[ ! -f "$MARY_DISPATCH" ]]; then
  error "Mary router script missing at $MARY_DISPATCH" \
    "Preflight routing cannot run" \
    "Restore the file or sync the repo"
  exit 1
fi

# เอาเฉพาะไฟล์ที่เปลี่ยนจริง (M, A, D)
changed_files=()
git_status_output=$(git status --porcelain=v1 2>/dev/null || true)
if [[ -n "$git_status_output" ]]; then
  while IFS= read -r line; do
    if [[ -n "$line" ]]; then
      file_status=$(echo "$line" | awk '{print $1}')
      file_path=$(echo "$line" | awk '{print $2}')
      if [[ "$file_status" =~ ^[MAD] ]]; then
        changed_files+=("$file_path")
      fi
    fi
  done <<< "$git_status_output"
fi

if (( ${#changed_files[@]} == 0 )); then
  echo "🚦 Mary preflight: ไม่มีไฟล์ที่เปลี่ยน แค่รายงานเฉย ๆ"
  return 0 2>/dev/null || exit 0
fi

echo "🚦 Mary preflight (report-only)"
echo "   Source : interactive"
echo "   Files  : ${#changed_files[@]}"
echo "----------------------------------------"

for rel in "${changed_files[@]}"; do
  # normalize path (Mary จะ handle เอง)
  abs="$LUKA_ROOT/$rel"

  echo ""
  echo "📄 $rel"
  python3 "$MARY_DISPATCH" \
    --source interactive \
    --path "$abs" \
    --op write \
    2>/dev/null || warn_error \
      "Mary router failed for $rel" \
      "Preflight report missing for this file (non-blocking)" \
      "Verify python3 and $MARY_DISPATCH, then rerun"
done

echo ""
echo "✅ Mary preflight เสร็จแล้ว (report-only, ไม่ block save/commit)"
return 0 2>/dev/null || exit 0
