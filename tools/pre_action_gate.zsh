#!/usr/bin/env zsh
# tools/pre_action_gate.zsh
# Pre-Action Gate: Enforce read before work
# GG Review requirement: "save without read is forbidden by default workflows"
#
# Usage:
#   source tools/pre_action_gate.zsh
#   pre_action_stamp_create   # After reading LIAM.md, session, telemetry
#   pre_action_stamp_verify   # Before any workflow (returns 0=valid, 1=invalid)
#
# Integrated into: seal-now, pr-check, save-now

set -u

# Config
REPO_ROOT="${REPO_ROOT:-$HOME/02luka}"
AGENT_ID="${AGENT_ID:-${GG_AGENT_ID:-liam}}"
STAMP_DIR="$REPO_ROOT/g/state"
STAMP_FILE="$STAMP_DIR/agent_readstamp_${AGENT_ID}.json"
LIAM_MD="$REPO_ROOT/LIAM.md"
EXPIRY_HOURS="${STAMP_EXPIRY_HOURS:-2}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get SHA256 of a file
_get_sha256() {
  local file="$1"
  if [[ -f "$file" ]]; then
    shasum -a 256 "$file" 2>/dev/null | cut -d' ' -f1
  else
    echo "missing"
  fi
}

# Get latest session file
_get_latest_session() {
  ls -t "$REPO_ROOT"/g/reports/sessions/*.ai.json 2>/dev/null | head -1 || echo ""
}

# Get telemetry tail hash (last 50 lines of all jsonl)
_get_telemetry_hash() {
  local hash=""
  for f in "$REPO_ROOT"/g/telemetry/*.jsonl(N.om[1,3]); do
    [[ -f "$f" ]] && hash+="$(tail -n 10 "$f" 2>/dev/null)"
  done
  echo "$hash" | shasum -a 256 2>/dev/null | cut -d' ' -f1
}

# Check if stamp is expired
_stamp_expired() {
  local stamp_ts="$1"
  local now_ts=$(date -u +%s)
  local stamp_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$stamp_ts" +%s 2>/dev/null || echo 0)
  local expiry_seconds=$((EXPIRY_HOURS * 3600))
  local age=$((now_ts - stamp_epoch))
  
  if (( age > expiry_seconds )); then
    return 0  # expired
  else
    return 1  # still valid
  fi
}

# Display the content being "read"
_display_required_reading() {
  echo ""
  echo "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo "${YELLOW}📖 PRE-ACTION GATE: Required Reading${NC}"
  echo "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  
  # 1. LIAM.md (first 30 lines - contains MANDATORY section)
  echo "${GREEN}[1/3] LIAM.md (Memory/Lessons):${NC}"
  if [[ -f "$LIAM_MD" ]]; then
    head -n 30 "$LIAM_MD" | sed 's/^/  /'
    echo "  ..."
  else
    echo "  ${RED}File not found: $LIAM_MD${NC}"
  fi
  echo ""
  
  # 2. Latest session summary
  echo "${GREEN}[2/3] Latest Session:${NC}"
  local session=$(_get_latest_session)
  if [[ -n "$session" && -f "$session" ]]; then
    echo "  File: $(basename "$session")"
    cat "$session" 2>/dev/null | head -c 500 | sed 's/^/  /'
    echo ""
  else
    echo "  ${RED}No session found${NC}"
  fi
  echo ""
  
  # 3. Telemetry tail
  echo "${GREEN}[3/3] Telemetry (last entries):${NC}"
  for f in "$REPO_ROOT"/g/telemetry/*.jsonl(N.om[1,3]); do
    if [[ -f "$f" ]]; then
      echo "  $(basename "$f"):"
      tail -n 2 "$f" 2>/dev/null | sed 's/^/    /'
    fi
  done
  echo ""
  echo "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Create read stamp (after reading)
pre_action_stamp_create() {
  mkdir -p "$STAMP_DIR"
  
  # Display required reading
  _display_required_reading
  
  # Get hashes
  local liam_sha=$(_get_sha256 "$LIAM_MD")
  local session_path=$(_get_latest_session)
  local telem_hash=$(_get_telemetry_hash)
  local ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  
  # Create stamp JSON
  cat > "$STAMP_FILE" <<EOF
{
  "ts": "$ts",
  "agent": "$AGENT_ID",
  "liam_md_sha256": "$liam_sha",
  "latest_session_path": "$session_path",
  "telemetry_tail_hash": "$telem_hash",
  "expiry_hours": $EXPIRY_HOURS
}
EOF
  
  echo ""
  echo "${GREEN}✅ Read stamp created${NC}"
  echo "   Agent: $AGENT_ID"
  echo "   Expiry: $EXPIRY_HOURS hours"
  echo "   Stamp: $STAMP_FILE"
  echo ""
  echo "You may now run: seal-now, pr-check, save-now"
  return 0
}

# Verify read stamp exists and is valid
pre_action_stamp_verify() {
  # Check stamp exists
  if [[ ! -f "$STAMP_FILE" ]]; then
    echo ""
    echo "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "${RED}❌ BLOCKED: No read stamp found${NC}"
    echo "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "You must read LIAM.md, session, and telemetry first."
    echo ""
    echo "Run: ${GREEN}read-now${NC}"
    echo "     (or: source tools/pre_action_gate.zsh && pre_action_stamp_create)"
    echo ""
    return 1
  fi
  
  # Parse stamp
  local stamp_ts=$(cat "$STAMP_FILE" | grep '"ts"' | cut -d'"' -f4)
  local stamp_sha=$(cat "$STAMP_FILE" | grep '"liam_md_sha256"' | cut -d'"' -f4)
  local current_sha=$(_get_sha256 "$LIAM_MD")
  
  # Check expiry
  if _stamp_expired "$stamp_ts"; then
    echo ""
    echo "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "${RED}❌ BLOCKED: Read stamp expired${NC}"
    echo "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Your read stamp is older than $EXPIRY_HOURS hours."
    echo "Re-read to refresh: ${GREEN}read-now${NC}"
    echo ""
    return 1
  fi
  
  # Check LIAM.md hasn't changed
  if [[ "$stamp_sha" != "$current_sha" ]]; then
    echo ""
    echo "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "${YELLOW}⚠️  WARNING: LIAM.md changed since last read${NC}"
    echo "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "New lessons may have been added. Consider re-reading."
    echo "Continuing anyway (stamp not expired)..."
    echo ""
  fi
  
  echo "${GREEN}✅ Read stamp verified (age: valid, agent: $AGENT_ID)${NC}"
  return 0
}

# Alias for easy use
read_now() {
  pre_action_stamp_create
}

# If sourced with argument "create" or "verify"
case "${1:-}" in
  create) pre_action_stamp_create ;;
  verify) pre_action_stamp_verify ;;
  *) ;; # Just source the functions
esac
