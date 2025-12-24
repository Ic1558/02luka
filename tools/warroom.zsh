#!/usr/bin/env zsh
set -euo pipefail

# tools/warroom.zsh - Consultant Mode Generator
# Purpose: Start the "Think-Before-Act" pipeline by creating a Decision Box draft + Prompt

REPO_ROOT="${REPO_ROOT:-"$HOME/02luka"}"
DECISION_DIR="$REPO_ROOT/g/decision"
DRAFTS_DIR="$DECISION_DIR/drafts"
TEMPLATE="$DECISION_DIR/DECISION_BOX.md"
LAC_MIRROR="$DECISION_DIR/LAC_REASONING_MIRROR.md"

mkdir -p "$DRAFTS_DIR"

# Argument Parsing
provider="gemini" # Default to Gemini (we know it exists)
fill_mode="false"
lac_mode="false"
args=()

while (( $# > 0 )); do
  case "$1" in
    --provider) 
      provider="${2:-gemini}"; shift 2;;
    --fill)
      fill_mode="true"; shift;;
    --lac)
      lac_mode="true"; shift;;
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
set -- "${args[@]:-}"

# Normal mode: Topic Setup
topic="${1:-'Unnamed Strategic Topic'}"
# Sluggify topic: lowercase, replace spaces with hyphens, remove special chars
slug=$(echo "$topic" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/-\+/-/g' | sed 's/^-//;s/-$//')
ts=$(date +"%Y%m%d_%H%M%S")

out_draft="$DRAFTS_DIR/${ts}_${slug}_DECISION_BOX.md"
out_prompt="$DRAFTS_DIR/${ts}_${slug}_PROMPT.md"
out_lac_prompt="$DRAFTS_DIR/${ts}_${slug}_LAC_PROMPT.md"

# Create Base Draft
if [[ -f "$TEMPLATE" ]]; then
    cat > "$out_draft" <<EOF
# Strategic Decision: $topic
**Status:** DRAFT
**Timestamp:** $(date)

---
EOF
else
    # Fallback stub
    cat > "$out_draft" <<EOF
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
  local _prompt_file="$2"

  if [[ "$_provider" == "codex" ]]; then
    command -v codex >/dev/null 2>&1 || return 2
    codex "$(cat "$_prompt_file")"
    return $?
  fi

  if [[ "$_provider" == "gemini" ]]; then
    # Use full path to avoid alias issues if not sourced
    GEMINI_BIN="/opt/homebrew/bin/gemini"
    if [[ ! -x "$GEMINI_BIN" ]]; then
       GEMINI_BIN=$(command -v gemini) || return 2
    fi
    
    # Use -p or direct arg. Unset KEY to force OAuth if needed.
    env -u GEMINI_API_KEY "$GEMINI_BIN" "$(cat "$_prompt_file")"
    return $?
  fi

  return 2
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

_build_lac_prompt() {
  local _topic="$1"
  local _draft_content="$2"

  cat <<EOF
You are the Logical Architecture Council (LAC) Mirror for 02luka.
Your Goal: Apply a "Reviewer Pass" (Option B: Ask + Risk + Evidence) to the draft below.
Do not rewrite the draft. Append your analysis.

TOPIC: $_topic

DRAFT CONTENT TO REVIEW:
$_draft_content

REQUIREMENTS:
1. Ask 3 Hard Questions (Pressure Test) that challenge the assumptions.
2. Identify Top 3 Risks (Pre-mortem) if this decision goes wrong.
3. List 3 Key Evidence items (logs, metrics, tests) required to validate success.
4. Create a Quick Comparison/Risk Table.

OUTPUT FORMAT:
## LAC Mirror Pass
### 1. Pressure Test
...
### 2. Risks (Pre-mortem)
...
### 3. Required Evidence
...
### 4. Quick Table
...
EOF
}

if [[ "$fill_mode" == "true" ]]; then
  echo ""
  echo "🧠 Generating Prompt..."
  _build_fill_prompt "$topic" "$REPO_ROOT" "$TEMPLATE" "$LAC_MIRROR" > "$out_prompt"
  echo "✅ Prompt file created: $out_prompt"

  echo ""
  echo "🧠 Attempting Auto-Fill via provider=$provider ..."
  echo "   (This may take 10-30 seconds)"
  
  if fill_out="$(_run_provider "$provider" "$out_prompt")"; then
      # Success: Append filled content
      cat >> "$out_draft" <<EOF

$fill_out

EOF
      echo "✅ Decision Box created & Auto-Filled."
      
      # -------- LAC Mirror Pass (Auto) --------
      if [[ "$lac_mode" == "true" ]]; then
        echo ""
        echo "🛡️  Generating LAC Mirror Prompt (Option B)..."
        # We use the content we just generated + topic
        _build_lac_prompt "$topic" "$fill_out" > "$out_lac_prompt"
        
        echo "🛡️  Running LAC Mirror Pass via $provider ..."
        if lac_out="$(_run_provider "$provider" "$out_lac_prompt")"; then
           cat >> "$out_draft" <<EOF

---
$lac_out
EOF
           echo "✅ LAC Mirror Pass appended."
        else
           echo "⚠️  LAC Provider failed. Appending manual checklist."
           cat >> "$out_draft" <<EOF

---
## LAC Mirror Pass (Manual Fallback)
- [ ] Pressure Test Q1:
- [ ] Pressure Test Q2:
- [ ] Pressure Test Q3:
- [ ] Risks:
- [ ] Evidence:
EOF
        fi
      fi

      # Finish up file structure
      cat >> "$out_draft" <<EOF

---
## 7. Decision (Human)
- Chosen Option: 
- Reason: 

## 8. Confidence & Next Check
- Confidence: 
- Revisit Trigger: 
EOF

      echo "File: $out_draft"
      echo ""
      echo "Next Steps:"
      echo "  1. Review sections 1-6 (AI generated)"
      if [[ "$lac_mode" == "true" ]]; then
          echo "  2. Review LAC Mirror Pass (Risks & Questions)"
      fi
      echo "  3. Fill sections 7-8 (Your Decision)"

  else
      # Failure (Graceful Fallback)
      echo "⚠️  Provider execution failed or unavailable. Switching to Manual Handoff."
      
      # Append empty template for manual fill
      if [[ -f "$TEMPLATE" ]]; then
          cat "$TEMPLATE" >> "$out_draft"
          echo "" >> "$out_draft"
          echo "---" >> "$out_draft"
          echo "TODO: Run LAC Mirror checks: $LAC_MIRROR" >> "$out_draft"
      fi

      echo ""
      echo "✅ Decision Box Draft created (Empty):"
      echo "$out_draft"
      echo ""
      echo "✅ Prompt created (Ready for Handoff):"
      echo "$out_prompt"
      echo ""
      echo "MANUAL HANDOFF INSTRUCTIONS:"
      echo "  1. Open Prompt: code \"$out_prompt\""
      echo "  2. Copy content -> Paste into your AI (Gemini/Codex/Antigravity)"
      echo "  3. Paste result into: code \"$out_draft\""
  fi

else
  # Manual mode output (No fill requested)
  if [[ -f "$TEMPLATE" ]]; then
      cat "$TEMPLATE" >> "$out_draft"
      echo "" >> "$out_draft"
      echo "---" >> "$out_draft"
      echo "TODO: Run LAC Mirror checks: $LAC_MIRROR" >> "$out_draft"
  fi
  
  echo ""
  echo "✅ Decision Box created (Manual):"
  echo "$out_draft"
  echo ""
  echo "Next Steps:"
  echo "  1. Open the file: code \"$out_draft\""
  echo "  2. Fill sections 1-3 (Objective, Context, Options)"
  echo "  3. Use LAC Mirror: cat $LAC_MIRROR"
fi

echo ""
echo "Skip if: routine ops / typo / tiny bugfix"