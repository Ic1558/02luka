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

# === SLASH ROUTER (WO) ===
wo_make_yaml() {
  local intent="$1" summary="$2" candidates="$3" strict="$4" artifact_type="$5" artifact_path="$6"
  local id="WO-$(date +%y%m%d-%H%M%S)-auto"
  cat <<YAML
id: ${id}
intent: ${intent}
summary: ${summary}
priority: normal
target_candidates: ${candidates}
strict_target: ${strict}
timeout_sec: 900
cost_cap_usd: 0.50
artifacts:
  - type: ${artifact_type}
    path: ${artifact_path}
route_hints:
  fallback_order: [clc, shell]
notify:
  telegram: true
return_channel: "shell:response:shell"
YAML
}

wo_atomic_drop() {
  local inbox="$1"; shift
  local hist="$HOME/02luka/logs/wo_drop_history"
  mkdir -p "$inbox" "$hist"
  local tmp="$(mktemp -t WO_XXXX).yaml"
  cat > "$tmp"
  local dst="$inbox/$(grep '^id:' "$tmp" | awk '{print $2}').yaml"
  mv "$tmp" "$dst"
  cp "$dst" "$hist/" 2>/dev/null || true
  echo "dropped: $dst"
  ls -lt "$inbox" | head -5
}

# Load template by command
case "$CMD" in
  /do)
    SUM="${BRIEF:-Task from Boss}"
    wo_make_yaml "plan" "$SUM" "[clc, shell]" "false" "plan_md" "g/wo/plan.md" | \
      wo_atomic_drop "$HOME/02luka/bridge/inbox/ENTRY"
    exit 0
    ;;
  /wo)
    SUM="${BRIEF:-Draft WO}"
    OUT="$HOME/02luka/g/wo/${SUM// /_}.yaml"
    mkdir -p "$(dirname "$OUT")"
    wo_make_yaml "plan" "$SUM" "[clc, shell]" "false" "plan_md" "g/wo/plan.md" > "$OUT"
    echo "saved: $OUT"; tail -n +1 "$OUT"
    exit 0
    ;;
  /clc)
    SUM="${BRIEF:-CLC Task}"
    wo_make_yaml "apply_sip_patch" "$SUM" "[clc]" "true" "sip_patch" "g/wo/patch.md" | \
      wo_atomic_drop "$HOME/02luka/bridge/inbox/CLC"
    exit 0
    ;;
  /local)
    SUM="${BRIEF:-Local Shell}"
    wo_make_yaml "run_shell" "$SUM" "[shell]" "true" "shell_script" "g/wo/run.zsh" | \
      wo_atomic_drop "$HOME/02luka/bridge/inbox/shell"
    exit 0
    ;;
  /mary)
    SUM="${BRIEF:-Mary Dispatch}"
    wo_make_yaml "plan" "$SUM" "[clc, shell]" "false" "plan_md" "g/wo/plan.md" | \
      wo_atomic_drop "$HOME/02luka/bridge/inbox/ENTRY"
    exit 0
    ;;
  /note)
    NOW="$(date -u +"%Y-%m-%dT%H:%M:%S%z")"
    D="$(date +%Y-%m-%d)"
    LED="$HOME/02luka/mls/ledger/$D.jsonl"
    mkdir -p "$(dirname "$LED")"
    TITLE="${BRIEF:-Quick note}"; SUMMARY="$TITLE"
    printf '{"type":"note","title":"%s","summary":"%s","tags":[],"created_at":"%s"}\n' \
      "$TITLE" "$SUMMARY" "$NOW" >> "$LED"
    echo "note appended: $LED"
    exit 0
    ;;
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

# Ledger integration: Log CLS command execution
LEDGER_HOOK="$ROOT/tools/cls_ledger_hook.zsh"
TASK_ID="cls-$(date +%y%m%d-%H%M%S)"
if [[ -x "$LEDGER_HOOK" ]]; then
  "$LEDGER_HOOK" "task_start" "$TASK_ID" "CLS: $CMD ${BRIEF:-(none)}" "{\"command\":\"$CMD\",\"brief\":\"${BRIEF:-(none)}\",\"output_file\":\"$OUT\"}" || true
fi

print -P "%F{green}✓%f prompt packet: $OUT"
if [[ "$NEED_CLC" = "1" ]]; then
  print -P "%F{yellow}!%f flagged for CLC (complexity threshold)"
fi

# Ledger integration: Log task result
if [[ -x "$LEDGER_HOOK" ]]; then
  "$LEDGER_HOOK" "task_result" "$TASK_ID" "CLS: $CMD completed" "{\"status\":\"success\",\"output_file\":\"$OUT\",\"escalate_to_clc\":$NEED_CLC}" || true
fi
