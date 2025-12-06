#!/usr/bin/env zsh
# tools/agent_context.zsh
# Agent context detection and standardization

# Detects the current agent ID based on environment variables or terminal info.
# Returns "unknown" if detection is uncertain, rather than a default.
detect_agent() {
  local agent=""

  # Priority order: explicit AGENT_ID env var > well-known env vars > terminal info
  if [[ -n "${AGENT_ID}" ]]; then
    agent="${AGENT_ID}"
  elif [[ -n "${GG_AGENT_ID}" ]]; then # Specific to Gemini CLI
    agent="gmx"
  elif [[ -n "${GEMINI_CLI}" ]]; then  # Specific to Gemini CLI
    agent="gmx"
  elif [[ "${TERM_PROGRAM}" == "vscode" ]]; then # Cursor.app
    agent="CLS"
  elif [[ -n "${CODEX_SESSION}" ]]; then # Codex CLI
    agent="codex"
  elif [[ -n "${CLC_SESSION}" ]]; then # Claude Code CLI
    agent="CLC"
  # Note: ANTIGRAVITY_SESSION doesn't exist (Liam confirmed)
  # Liam integration must be manual: AGENT_ID=liam save.sh
  else
    agent="unknown" # Don't default to CLC - return "unknown" if uncertain (consensus from multi-agent review)
  fi

  # Validate against known agents as suggested by CLS/Codex
  # Note: terminal/ssh are environments, not agents
  case "$agent" in
    CLS|CLC|codex|gmx|liam) echo "$agent" ;;
    *) echo "unknown" ;; # Return "unknown" for unvalidated agents
  esac
}

# Detects the current execution environment.
detect_environment() {
  if [[ "${TERM_PROGRAM}" == "vscode" ]]; then
    echo "cursor"
  # Note: Antigravity detection removed (Liam confirmed no env vars available)
  elif [[ -n "${SSH_TTY}" ]]; then
    echo "ssh"
  elif [[ -n "${TMUX}" ]]; then
    echo "tmux"
  else
    echo "terminal"
  fi
}

export AGENT_ID=$(detect_agent)
export AGENT_ENV=$(detect_environment)

# Set SAVE_SOURCE. Explicitly provided (e.g., by adapter) takes precedence.
export SAVE_SOURCE="${SAVE_SOURCE:-${AGENT_ENV}}"

# Set SAVE_AGENT. This will be AGENT_ID unless explicitly overridden.
export SAVE_AGENT="${SAVE_AGENT:-${AGENT_ID}}"

# Set SAVE_TIMESTAMP once at source
export SAVE_TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Set Telemetry Schema Version
export SAVE_SCHEMA_VERSION=1

# For debugging purposes:
# echo "DEBUG: AGENT_ID=$AGENT_ID, AGENT_ENV=$AGENT_ENV, SAVE_SOURCE=$SAVE_SOURCE, SAVE_AGENT=$SAVE_AGENT, SAVE_TIMESTAMP=$SAVE_TIMESTAMP, SAVE_SCHEMA_VERSION=$SAVE_SCHEMA_VERSION"
