#!/usr/bin/env zsh
# tools/pre_action_gate.zsh
# Pre-Action Gate: Enforce read before work (GG Review v2)
#
# Usage:
#   source tools/pre_action_gate.zsh
#   pre_action_stamp_create   # After reading required files
#   pre_action_stamp_verify   # Before any workflow
#
# Emergency override: SAVE_EMERGENCY=1 (logs to telemetry)
# Interactive override: If AGENT_ID is empty/interactive → warn-only
#
# Integrated into: seal-now, pr-check, save-now

set -u

# === Config ===
REPO_ROOT="${REPO_ROOT:-$HOME/02luka}"
AGENT_ID="${AGENT_ID:-${GG_AGENT_ID:-}}"  # Empty = interactive/Boss
STAMP_DIR="$REPO_ROOT/g/state"
STAMP_FILE="$STAMP_DIR/agent_readstamp_${AGENT_ID:-interactive}.json"
EXPIRY_HOURS="${STAMP_EXPIRY_HOURS:-4}"   # GG: 4 hours default

# Critical files to check (GG: check 3 files, not just LIAM.md)
LIAM_MD="$REPO_ROOT/LIAM.md"
PR_RULES="$REPO_ROOT/g/docs/PR_AUTOPILOT_RULES.md"
WORKFLOW_PROTOCOL="$REPO_ROOT/g/docs/WORKFLOW_PROTOCOL_v1.md"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# === Helper Functions ===

_get_sha256() {
  local file="$1"
  if [[ -f "$file" ]]; then
    shasum -a 256 "$file" 2>/dev/null | cut -d' ' -f1
  else
    echo "missing"
  fi
}

_get_latest_session() {
  ls -t "$REPO_ROOT"/g/reports/sessions/*.ai.json 2>/dev/null | head -1 || echo ""
}

_get_telemetry_hash() {
  local hash=""
  for f in "$REPO_ROOT"/g/telemetry/*.jsonl(N.om[1,3]); do
    [[ -f "$f" ]] && hash+="$(tail -n 10 "$f" 2>/dev/null)"
  done
  echo "$hash" | shasum -a 256 2>/dev/null | cut -d' ' -f1
}

_stamp_expired() {
  local stamp_epoch="$1"
  local now_epoch=$(date +%s)
  local expiry_seconds=$((EXPIRY_HOURS * 3600))
  local age=$((now_epoch - stamp_epoch))
  
  if (( age > expiry_seconds )) || (( age < 0 )); then
    return 0  # expired
  else
    return 1  # valid
  fi
}

_is_interactive() {
  # GG: If AGENT_ID is empty or "unknown" → interactive/Boss
  [[ -z "$AGENT_ID" || "$AGENT_ID" == "unknown" || "$AGENT_ID" == "$USER" ]]
}

_log_emergency() {
  local reason="$1"
  local ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local log_file="$REPO_ROOT/g/telemetry/gate_emergency.jsonl"
  mkdir -p "$(dirname "$log_file")"
  echo "{\"ts\":\"$ts\",\"agent\":\"${AGENT_ID:-interactive}\",\"action\":\"emergency_bypass\",\"reason\":\"$reason\"}" >> "$log_file"
  echo "${YELLOW}⚠️  Emergency bypass logged to telemetry${NC}"
}

# === Display Required Reading ===

_display_required_reading() {
  echo ""
  echo "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo "${YELLOW}📖 PRE-ACTION GATE: Required Reading${NC}"
  echo "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  
  # 1. LIAM.md (first 30 lines)
  echo "${GREEN}[1/5] LIAM.md (Memory/Lessons):${NC}"
  if [[ -f "$LIAM_MD" ]]; then
    head -n 30 "$LIAM_MD" | sed 's/^/  /'
    echo "  ..."
  else
    echo "  ${RED}Not found${NC}"
  fi
  echo ""
  
  # 2. PR_AUTOPILOT_RULES.md (first 20 lines)
  echo "${GREEN}[2/5] PR_AUTOPILOT_RULES.md (key rules):${NC}"
  if [[ -f "$PR_RULES" ]]; then
    head -n 20 "$PR_RULES" | sed 's/^/  /'
    echo "  ..."
  else
    echo "  ${RED}Not found${NC}"
  fi
  echo ""
  
  # 3. WORKFLOW_PROTOCOL_v1.md (first 15 lines)
  echo "${GREEN}[3/5] WORKFLOW_PROTOCOL_v1.md (workflow):${NC}"
  if [[ -f "$WORKFLOW_PROTOCOL" ]]; then
    head -n 15 "$WORKFLOW_PROTOCOL" | sed 's/^/  /'
    echo "  ..."
  else
    echo "  ${RED}Not found${NC}"
  fi
  echo ""
  
  # 4. Latest session
  echo "${GREEN}[4/5] Latest Session:${NC}"
  local session=$(_get_latest_session)
  if [[ -n "$session" && -f "$session" ]]; then
    echo "  File: $(basename "$session")"
    head -c 300 "$session" 2>/dev/null | sed 's/^/  /'
    echo ""
  else
    echo "  ${RED}No session found${NC}"
  fi
  echo ""
  
  # 5. Telemetry tail
  echo "${GREEN}[5/5] Telemetry (last entries):${NC}"
  for f in "$REPO_ROOT"/g/telemetry/*.jsonl(N.om[1,3]); do
    if [[ -f "$f" ]]; then
      echo "  $(basename "$f"):"
      tail -n 1 "$f" 2>/dev/null | sed 's/^/    /'
    fi
  done
  echo ""
  echo "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# === Create Stamp ===

pre_action_stamp_create() {
  mkdir -p "$STAMP_DIR"
  
  # Display required reading
  _display_required_reading
  
  # Get hashes for all 3 critical files (GG: check 3 files)
  local liam_sha=$(_get_sha256 "$LIAM_MD")
  local pr_rules_sha=$(_get_sha256 "$PR_RULES")
  local workflow_sha=$(_get_sha256 "$WORKFLOW_PROTOCOL")
  local session_path=$(_get_latest_session)
  local telem_hash=$(_get_telemetry_hash)
  local ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local ts_local=$(date +"%Y-%m-%dT%H:%M:%S%z")
  local epoch=$(date +%s)
  
  # Create stamp JSON with all 3 file SHAs
  cat > "$STAMP_FILE" <<EOF
{
  "ts_utc": "$ts",
  "ts_local": "$ts_local",
  "epoch": $epoch,
  "agent": "${AGENT_ID:-interactive}",
  "files_read": {
    "liam_md_sha256": "$liam_sha",
    "pr_autopilot_sha256": "$pr_rules_sha",
    "workflow_protocol_sha256": "$workflow_sha"
  },
  "latest_session_path": "$session_path",
  "telemetry_tail_hash": "$telem_hash",
  "expiry_hours": $EXPIRY_HOURS
}
EOF
  
  echo ""
  echo "${GREEN}✅ Read stamp created${NC}"
  echo "   Agent: ${AGENT_ID:-interactive}"
  echo "   Expiry: $EXPIRY_HOURS hours"
  echo "   Files: LIAM.md, PR_AUTOPILOT_RULES.md, WORKFLOW_PROTOCOL_v1.md"
  echo "   Stamp: $STAMP_FILE"
  echo ""
  echo "You may now run: seal-now, pr-check, save-now"
  return 0
}

# === Verify Stamp ===

pre_action_stamp_verify() {
  # GG: Emergency override (must log)
  if [[ "${SAVE_EMERGENCY:-}" == "1" ]]; then
    _log_emergency "SAVE_EMERGENCY=1 override used"
    echo "${YELLOW}⚠️  Emergency override active - proceeding without read stamp${NC}"
    return 0
  fi
  
  # GG: Actor-aware gating (interactive = warn-only)
  local is_interactive=false
  if _is_interactive; then
    is_interactive=true
  fi
  
  # Check stamp exists
  if [[ ! -f "$STAMP_FILE" ]]; then
    echo ""
    echo "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if $is_interactive; then
      echo "${YELLOW}⚠️  WARNING: No read stamp found (interactive mode)${NC}"
    else
      echo "${RED}❌ BLOCKED: No read stamp found${NC}"
    fi
    echo "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Run: ${GREEN}read-now${NC} (or: zsh tools/pre_action_gate.zsh create)"
    echo ""
    
    if $is_interactive; then
      echo "${CYAN}Continuing anyway (interactive/Boss mode)...${NC}"
      return 0
    fi
    return 1
  fi
  
  # Parse stamp
  local stamp_epoch=$(grep '"epoch"' "$STAMP_FILE" | grep -oE '[0-9]+' | head -1)
  local stamp_liam_sha=$(grep '"liam_md_sha256"' "$STAMP_FILE" | cut -d'"' -f4)
  local stamp_pr_sha=$(grep '"pr_autopilot_sha256"' "$STAMP_FILE" | cut -d'"' -f4 2>/dev/null || echo "")
  local stamp_wf_sha=$(grep '"workflow_protocol_sha256"' "$STAMP_FILE" | cut -d'"' -f4 2>/dev/null || echo "")
  
  # Default epoch to 0 if missing
  [[ -z "$stamp_epoch" ]] && stamp_epoch=0
  
  # Get current SHAs
  local current_liam_sha=$(_get_sha256 "$LIAM_MD")
  local current_pr_sha=$(_get_sha256 "$PR_RULES")
  local current_wf_sha=$(_get_sha256 "$WORKFLOW_PROTOCOL")
  
  # GG: Invalidate immediately if critical files changed
  local files_changed=false
  local changed_files=""
  
  if [[ -n "$stamp_liam_sha" && "$stamp_liam_sha" != "$current_liam_sha" ]]; then
    files_changed=true
    changed_files+="LIAM.md "
  fi
  if [[ -n "$stamp_pr_sha" && "$stamp_pr_sha" != "$current_pr_sha" ]]; then
    files_changed=true
    changed_files+="PR_AUTOPILOT_RULES.md "
  fi
  if [[ -n "$stamp_wf_sha" && "$stamp_wf_sha" != "$current_wf_sha" ]]; then
    files_changed=true
    changed_files+="WORKFLOW_PROTOCOL.md "
  fi
  
  if $files_changed; then
    echo ""
    echo "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if $is_interactive; then
      echo "${YELLOW}⚠️  WARNING: Critical files changed: $changed_files${NC}"
    else
      echo "${RED}❌ BLOCKED: Critical files changed: $changed_files${NC}"
    fi
    echo "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "You must re-read to get latest rules."
    echo "Run: ${GREEN}read-now${NC}"
    echo ""
    
    if $is_interactive; then
      echo "${CYAN}Continuing anyway (interactive/Boss mode)...${NC}"
      return 0
    fi
    return 1
  fi
  
  # Check expiry
  if _stamp_expired "$stamp_epoch"; then
    echo ""
    echo "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if $is_interactive; then
      echo "${YELLOW}⚠️  WARNING: Read stamp expired (>$EXPIRY_HOURS hours)${NC}"
    else
      echo "${RED}❌ BLOCKED: Read stamp expired (>$EXPIRY_HOURS hours)${NC}"
    fi
    echo "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Re-read to refresh: ${GREEN}read-now${NC}"
    echo ""
    
    if $is_interactive; then
      echo "${CYAN}Continuing anyway (interactive/Boss mode)...${NC}"
      return 0
    fi
    return 1
  fi
  
  echo "${GREEN}✅ Read stamp verified (agent: ${AGENT_ID:-interactive}, age: valid)${NC}"
  return 0
}

# === Aliases ===

read_now() {
  pre_action_stamp_create
}

# === CLI ===

case "${1:-}" in
  create) pre_action_stamp_create ;;
  verify) pre_action_stamp_verify ;;
  *) ;; # Just source
esac
