#!/usr/bin/env zsh
set -euo pipefail

# tools/warroom.zsh - Consultant Mode Generator
# Purpose: Start the "Think-Before-Act" pipeline by creating a Decision Box draft

REPO_ROOT="${REPO_ROOT:-"$HOME/02luka"}"
DECISION_DIR="$REPO_ROOT/g/decision"
DRAFTS_DIR="$DECISION_DIR/drafts"
TEMPLATE="$DECISION_DIR/DECISION_BOX.md"
LAC_MIRROR="$DECISION_DIR/LAC_REASONING_MIRROR.md"

mkdir -p "$DRAFTS_DIR"

# Argument Parsing
provider="auto"
fill_mode="false"
args=()

while (( $# > 0 )); do
  case "$1" in
    --provider) 
      provider="${2:-auto}"; shift 2;;
    --fill)
      fill_mode="true"; shift;;
    --check)
      # Check Mode
      ok=true
      for f in "$TEMPLATE" "$LAC_MIRROR"; do
          if [[ -f "$f" ]]; then echo "OK: $f"; else echo "MISSING: $f"; ok=false; fi
      done
      if $ok; then exit 0; else exit 1; fi
      ;;
    *)
      args+=("$1"); shift;;
  esac
done
set -- "${args[@]:-""}"

# Normal mode: Topic Setup
topic="${1:-'Unnamed Strategic Topic'}"
# Sluggify topic: lowercase, replace spaces with hyphens, remove special chars
slug=$(echo "$topic" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/-\+/-/g' | sed 's/^-//;s/-$//')
ts=$(date +"%Y%m%d_%H%M%S")

out="$DRAFTS_DIR/${ts}_${slug}_DECISION_BOX.md"

# Create Base File
if [[ -f "$TEMPLATE" ]]; then
    # Create from template with header injection
    cat > "$out" <<EOF
# Strategic Decision: $topic
**Status:** DRAFT
**Timestamp:** $(date)

---
EOF
    # If not filling, just copy template. If filling, we will append later.
    if [[ "$fill_mode" == "false" ]]; then
        cat "$TEMPLATE" >> "$out"
        echo "" >> "$out"
        echo "---" >> "$out"
        echo "TODO: Run LAC Mirror checks: $LAC_MIRROR" >> "$out"
    fi
else
    # Fallback stub
    cat > "$out" <<EOF
# Warroom Draft (Stub)
**Topic:** $topic
**Timestamp:** $ts
**Warning:** Template not found at $TEMPLATE

Status: NOT IMPLEMENTED
EOF
fi

# -------- Warroom Fill Mode (Codex/Gemini) --------

_run_provider() {
  local _provider="$1"
  local _prompt="$2"

  if [[ "$_provider" == "codex" ]]; then
    command -v codex >/dev/null 2>&1 || return 2
    # Codex CLI usually accepts prompt as arg
    codex "$_prompt"
    return $?
  fi

  if [[ "$_provider" == "gemini" ]]; then
    # Use full path to avoid alias issues if not sourced
    GEMINI_BIN="/opt/homebrew/bin/gemini"
    if [[ ! -x "$GEMINI_BIN" ]]; then
       GEMINI_BIN=$(command -v gemini) || return 2
    fi
    
    # Use -p or direct arg. Unset KEY to force OAuth if needed, or rely on env.
    # Assuming gemini_full_feature environment is active or usable.
    env -u GEMINI_API_KEY "$GEMINI_BIN" "$_prompt"
    return $?
  fi

  return 2
}

_pick_provider_and_run() {
  local _provider="$1"
  local _prompt="$2"

  if [[ "$_provider" == "auto" ]]; then
    # Try Codex first, then Gemini
    _run_provider "codex" "$_prompt" && return 0
    _run_provider "gemini" "$_prompt" && return 0
    return 2
  fi

  _run_provider "$_provider" "$_prompt"
}

_build_fill_prompt() {
  local _topic="$1"
  local _repo="$2"
  local _template_path="$3"
  local _lac_path="$4"

  # Lightweight context (read-only)
  local _protocol="$(sed -n '1,120p' "$_repo/g/docs/WORKFLOW_PROTOCOL_v1.md" 2>/dev/null || true)"
  local _rules="$(sed -n '1,160p' "$_repo/g/docs/PR_AUTOPILOT_RULES.md" 2>/dev/null || true)"
  local _patterns="$(sed -n '1,120p' "$_repo/g/rules/runtime_patterns.yaml" 2>/dev/null || true)"

  cat <<EOF
You are a consultant-mode planner for the 02luka system.
Goal: Fill DECISION_BOX sections 1–6 ONLY. Do NOT fill sections 7–8.
Be concise. Use bullets. Include a trade-off table.

TOPIC:
$_topic

CONSTRAINTS:
- Do NOT execute anything. Planning only.
- Output MUST be Markdown with EXACT headings:
  ## 1. Objective
  ## 2. Context
  ## 3. Options
  ## 4. Trade-offs
  ## 5. Assumptions
  ## 6. Recommendation (Non-binding)

Useful policy excerpts:
WORKFLOW_PROTOCOL excerpt:
$_protocol

PR_AUTOPILOT_RULES excerpt:
$_rules

runtime_patterns excerpt (guards):
$_patterns

Now produce the filled sections 1–6.
EOF
}

if [[ "$fill_mode" == "true" ]]; then
  echo ""
  echo "🧠 Filling Decision Box (1–6) via provider=$provider ..."
  echo "   (This may take 10-30 seconds)"
  
  prompt="$(_build_fill_prompt "$topic" "$REPO_ROOT" "$TEMPLATE" "$LAC_MIRROR")"
  
  fill_out="$(_pick_provider_and_run "$provider" "$prompt")" || {
    echo "⚠️ Provider unavailable or failed. Draft created but not filled."
    cat "$TEMPLATE" >> "$out" # Fallback to empty template
    echo ""
    echo "✅ Decision Box created (Manual mode):"
    echo "$out"
    exit 0
  }

  # Append filled content
  cat >> "$out" <<EOF

$fill_out

---
## 7. Decision (Human)
- Chosen Option: 
- Reason: 

## 8. Confidence & Next Check
- Confidence: 
- Revisit Trigger: 

---
TODO: Run LAC Mirror checks: $LAC_MIRROR
EOF

  echo "✅ Decision Box created & Auto-Filled:"
  echo "$out"
  echo ""
  echo "Next Steps:"
  echo "  1. Review sections 1-6 (AI generated)"
  echo "  2. Fill sections 7-8 (Your Decision)"
  echo "  3. Use LAC Mirror for pressure test"
else
  # Manual mode output
  echo ""
  echo "✅ Decision Box created:"
  echo "$out"
  echo ""
  echo "Next Steps:"
  echo "  1. Open the file: code \"$out\""
  echo "  2. Fill sections 1-3 (Objective, Context, Options)"
  echo "  3. Use LAC Mirror: cat $LAC_MIRROR"
fi

echo ""
echo "Skip if: routine ops / typo / tiny bugfix"
