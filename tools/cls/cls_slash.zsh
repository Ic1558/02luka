#!/usr/bin/env zsh
set -euo pipefail
ROOT="$HOME/02luka"
CMD="${1:-}"; shift || true
BRIEF="${*:-}"

if [[ -z "$CMD" ]]; then
  echo "usage: cls /feature-dev|/code-review|/deploy [brief...]" >&2; exit 1
fi

# Load context map (if exists)
if [[ -f "$ROOT/.claude/context-map.json" ]]; then
  source "$ROOT/tools/cls/ctx_load.zsh" || true
fi

ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
slug() { print -r -- "$*" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-_ ' | tr ' ' '-' }

# Load template by command
case "$CMD" in
  /feature-dev)   TPL="$ROOT/.claude/commands/feature-dev.md" ;;
  /code-review)   TPL="$ROOT/.claude/commands/code-review.md" ;;
  /deploy)        TPL="$ROOT/.claude/commands/deploy.md" ;;
  *) echo "unknown command: $CMD" >&2; exit 1 ;;
esac
[[ -f "$TPL" ]] || { echo "missing template: $TPL" >&2; exit 1; }

# Create prompt packet
NAME="$(slug "${CMD#*/}-${BRIEF:-task}")"
OUT="$ROOT/g/reports/cls_prompt_packets/${NAME}-$(date +%Y%m%d-%H%M%S).md"

# Auto-escalate criteria
CHANGED=$(git -C "$ROOT" diff --name-only 2>/dev/null | wc -l | tr -d ' ' || echo "0")
TOUCHES_CI=$(git -C "$ROOT" diff --name-only 2>/dev/null | grep -E '^\.github/workflows/|hub/|_memory/' -c || echo "0")
NEED_CLC=0
# Convert to integers safely (handle empty strings)
CHANGED_NUM=${CHANGED:-0}
TOUCHES_NUM=${TOUCHES_CI:-0}
# Use arithmetic expansion safely
if [[ -n "$CHANGED_NUM" ]] && [[ -n "$TOUCHES_NUM" ]]; then
  if (( CHANGED_NUM >= 25 )) || (( TOUCHES_NUM >= 1 )); then
    NEED_CLC=1
  fi
fi

{
  echo "# $CMD — Prompt Packet"
  echo "- generated_at: $(ts)"
  echo "- repo: 02luka"
  echo "- brief: ${BRIEF:-(none)}"
  echo "- auto_escalate_to_clc: $NEED_CLC"
  echo "- context:"
  echo "  project_root: ${CTX_PROJECT_ROOT:-$ROOT}"
  echo "  hooks_dir: ${CTX_HOOKS_DIR:-$ROOT/tools/claude_hooks}"
  echo "  reports_dir: ${CTX_REPORTS_DIR:-$ROOT/g/reports}"
  echo
  echo "## Instruction (from template)"
  sed 's/^/> /' "$TPL"
  echo
  echo "## Repo Snapshot"
  git -C "$ROOT" status --porcelain=v1 2>/dev/null || echo "(no changes)"
  echo
  echo "## Recent Commits"
  git -C "$ROOT" --no-pager log -n 5 --pretty=format:'- %h %ad %s' --date=short 2>/dev/null || echo "(no commits)"
  echo
  echo "## If complexity is high"
  echo "- If auto_escalate_to_clc=1 → handoff to CLC with this packet."
} > "$OUT"

# Copy to clipboard (macOS)
command -v pbcopy >/dev/null && cat "$OUT" | pbcopy || true

print -P "%F{green}✓%f prompt packet: $OUT"
if [[ "$NEED_CLC" = "1" ]]; then
  print -P "%F{yellow}!%f flagged for CLC (complexity threshold)"
fi
