#!/usr/bin/env zsh
set -euo pipefail

# Persona Loader v5 (defaults to v3)
# Usage: load_persona_v5.zsh <agent> <command>
# Commands: sync, load, verify

ROOT="$HOME/02luka"
PERSONAS_DIR="${ROOT}/personas"
CURSOR_CMD_DIR="${ROOT}/.cursor/commands"

AGENT="${1:-}"
CMD="${2:-}"

if [[ -z "$AGENT" ]]; then
  echo "Usage: $0 <agent> <command>" >&2
  echo "  Agents: cls, gg, gm, liam, mary, clc, gmx, codex, gemini, lac" >&2
  echo "  Commands: sync, load, verify" >&2
  exit 1
fi

# Normalize agent name to uppercase for persona file lookup
AGENT_UPPER="${(U)AGENT}"
PERSONA_FILE="${PERSONAS_DIR}/${AGENT_UPPER}_PERSONA_v3.md"
CURSOR_CMD_FILE="${CURSOR_CMD_DIR}/${AGENT}.md"

# Default command to sync if not specified
if [[ -z "$CMD" ]]; then
  CMD="sync"
fi

# Check if personas directory exists
if [[ ! -d "$PERSONAS_DIR" ]]; then
  echo "Warning: Personas directory not found: $PERSONAS_DIR" >&2
  echo "Creating directory..." >&2
  mkdir -p "$PERSONAS_DIR"
fi

# Load persona function
load_persona() {
  if [[ ! -f "$PERSONA_FILE" ]]; then
    echo "Error: Persona file not found: $PERSONA_FILE" >&2
    echo "Expected location: $PERSONA_FILE" >&2
    return 1
  fi
  
  echo "Loading persona: $PERSONA_FILE"
  cat "$PERSONA_FILE"
}

# Sync persona to Cursor context
sync_to_cursor() {
  if [[ ! -f "$PERSONA_FILE" ]]; then
    echo "Error: Persona file not found: $PERSONA_FILE" >&2
    return 1
  fi
  
  # Ensure cursor commands directory exists
  mkdir -p "$CURSOR_CMD_DIR"
  
  # Create or update cursor command file
  {
    echo "---"
    echo "description: Activate ${AGENT_UPPER} mode (Persona v3)"
    echo "---"
    echo ""
    cat "$PERSONA_FILE"
  } > "$CURSOR_CMD_FILE"
  
  echo "✓ Synced persona to: $CURSOR_CMD_FILE"
  
  # Also update context-map.json if it exists
  CONTEXT_MAP="${ROOT}/.claude/context-map.json"
  if [[ -f "$CONTEXT_MAP" ]] && command -v jq >/dev/null 2>&1; then
    # Update context map with persona path
    jq --arg key "persona:${AGENT}" --arg value "$PERSONA_FILE" \
      '. + {($key): $value}' "$CONTEXT_MAP" > "${CONTEXT_MAP}.tmp" && \
      mv "${CONTEXT_MAP}.tmp" "$CONTEXT_MAP"
    echo "✓ Updated context-map.json"
  fi
}

# Verify persona structure
verify_persona() {
  if [[ ! -f "$PERSONA_FILE" ]]; then
    echo "Error: Persona file not found: $PERSONA_FILE" >&2
    return 1
  fi
  
  echo "Verifying persona structure: $PERSONA_FILE"
  
  local required_sections=(
    "Identity & Mission"
    "Two Worlds Model"
    "Zone Mapping"
    "Identity Matrix"
    "Mary Router Integration"
    "Work Order Decision Rule"
    "Key Principles"
  )
  
  local missing=()
  local content=$(cat "$PERSONA_FILE")
  
  for section in "${required_sections[@]}"; do
    if ! echo "$content" | grep -qi "##.*${section}"; then
      missing+=("$section")
    fi
  done
  
  if [[ ${#missing[@]} -eq 0 ]]; then
    echo "✓ All required sections present"
    return 0
  else
    echo "✗ Missing sections:" >&2
    printf "  - %s\n" "${missing[@]}" >&2
    return 1
  fi
}

# Execute command
case "$CMD" in
  load)
    load_persona
    ;;
  sync)
    sync_to_cursor
    ;;
  verify)
    verify_persona
    ;;
  *)
    echo "Error: Unknown command: $CMD" >&2
    echo "Valid commands: load, sync, verify" >&2
    exit 1
    ;;
esac
