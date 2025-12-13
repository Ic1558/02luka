#!/usr/bin/env zsh
# tools/spawn.zsh - LAPP Universal Plugin Spawner v2.1
# Model-agnostic with telemetry, governance injection, and debugging flags
# 
# Usage: 
#   zsh tools/spawn.zsh <plugin_name> "<input_context>" [flags]
#   zsh tools/spawn.zsh --list
#   zsh tools/spawn.zsh --help
#   zsh tools/spawn.zsh the_essentialist "input" --dry-run --verbose

set -u

LUKA_BASE="${LUKA_BASE:-$HOME/02luka}"
LOG_FILE="$LUKA_BASE/g/logs/plugin_invocations.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Flags
DRY_RUN=false
VERBOSE=false

show_help() {
    cat << 'EOF'
🔮 LAPP Plugin Spawner v2.1

USAGE:
    zsh spawn.zsh <plugin_name> "<input>" [flags]
    zsh spawn.zsh --list
    zsh spawn.zsh --help

FLAGS:
    --list, -l      List all available plugins
    --dry-run       Show prompt without executing model
    --verbose, -v   Show debug information
    --help, -h      Show this help message

EXAMPLES:
    # Spawn The Essentialist to critique an idea
    zsh spawn.zsh the_essentialist "I want to rewrite the entire DB layer"

    # Spawn Book Writer with session logs
    zsh spawn.zsh book_writer "$(cat g/logs/session.log)"

    # Dry-run to preview prompt
    zsh spawn.zsh the_essentialist "test" --dry-run

    # Verbose mode for debugging
    zsh spawn.zsh the_essentialist "test" --verbose

PLUGINS:
EOF
    list_plugins
}

list_plugins() {
    ls -1 "$LUKA_BASE/agents/plugins/" 2>/dev/null | while read p; do
        if [[ -f "$LUKA_BASE/agents/plugins/$p/manifest.yaml" ]]; then
            local role=$(grep "role:" "$LUKA_BASE/agents/plugins/$p/manifest.yaml" | cut -d'"' -f2)
            local model=$(grep "base_model:" "$LUKA_BASE/agents/plugins/$p/manifest.yaml" | cut -d'"' -f2)
            echo "    ${CYAN}$p${NC}: $role (${model})"
        fi
    done
}

usage() {
    echo "Usage: $(basename "$0") <plugin_name> \"<input_context>\" [--dry-run] [--verbose]"
    echo "       $(basename "$0") --list | --help"
    echo ""
    echo "Available plugins:"
    list_plugins
}

# Parse flags first
POSITIONAL=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --list|-l)
            echo "📦 Available LAPP Plugins:"
            list_plugins
            exit 0
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done
set -- "${POSITIONAL[@]}"

PLUGIN_NAME="${1:-}"
USER_INPUT="${2:-}"
PLUGIN_DIR="$LUKA_BASE/agents/plugins/$PLUGIN_NAME"

# Validation
if [[ -z "$PLUGIN_NAME" ]] || [[ -z "$USER_INPUT" ]]; then
    echo "${RED}❌ Missing arguments${NC}"
    usage
    exit 1
fi

if [[ ! -d "$PLUGIN_DIR" ]]; then
    echo "${RED}❌ Plugin '$PLUGIN_NAME' not found${NC}"
    usage
    exit 1
fi

if [[ ! -f "$PLUGIN_DIR/manifest.yaml" ]]; then
    echo "${RED}❌ Missing manifest.yaml in $PLUGIN_DIR${NC}"
    exit 1
fi

# Load manifest
MANIFEST="$PLUGIN_DIR/manifest.yaml"
SYSTEM_PROMPT=$(cat "$PLUGIN_DIR/system.md" 2>/dev/null || echo "")

# Parse manifest fields
BASE_MODEL=$(grep "base_model:" "$MANIFEST" | cut -d'"' -f2)
FALLBACK_MODEL=$(grep "fallback_model:" "$MANIFEST" | cut -d'"' -f2)
TIMEOUT=$(grep "timeout_seconds:" "$MANIFEST" | awk '{print $2}')
MAX_TOKENS=$(grep "max_tokens:" "$MANIFEST" | awk '{print $2}')
TELEMETRY=$(grep "telemetry_enabled:" "$MANIFEST" | awk '{print $2}')
ROLE=$(grep "role:" "$MANIFEST" | cut -d'"' -f2)

# Defaults
TIMEOUT="${TIMEOUT:-120}"
MAX_TOKENS="${MAX_TOKENS:-4000}"
TELEMETRY="${TELEMETRY:-true}"

# Telemetry logging
log_invocation() {
    local op_status="$1"
    local model="$2"
    if [[ "$TELEMETRY" == "true" ]]; then
        mkdir -p "$(dirname "$LOG_FILE")"
        echo "$(date -Iseconds) | $PLUGIN_NAME | $model | $op_status | ${USER:-unknown}" >> "$LOG_FILE"
    fi
}

# Assemble context with governance
GOVERNANCE_CONTEXT="
---
## GOVERNANCE CONTEXT (You are in CLI World / FAST Lane)
- World: CLI (Human-triggered)
- Lane: FAST (Low friction)
- You may NOT write files unless allowed_write_paths permits
- Follow GOVERNANCE_UNIFIED_v5 semantics
---
"

FULL_PROMPT="
$SYSTEM_PROMPT

$GOVERNANCE_CONTEXT

## USER INPUT
$USER_INPUT
"

# Verbose debug info
if [[ "$VERBOSE" == "true" ]]; then
    echo "${CYAN}🔍 DEBUG INFO${NC}"
    echo "   Plugin: $PLUGIN_NAME"
    echo "   Dir: $PLUGIN_DIR"
    echo "   Model: $BASE_MODEL (fallback: $FALLBACK_MODEL)"
    echo "   Timeout: ${TIMEOUT}s"
    echo "   Max Tokens: $MAX_TOKENS"
    echo "   Telemetry: $TELEMETRY"
    echo "   Prompt length: ${#FULL_PROMPT} chars"
    echo "─────────────────────────────────────────────────────"
fi

# Dry-run mode
if [[ "$DRY_RUN" == "true" ]]; then
    echo "${YELLOW}📋 DRY-RUN MODE — No model execution${NC}"
    echo "─────────────────────────────────────────────────────"
    echo "$FULL_PROMPT"
    echo "─────────────────────────────────────────────────────"
    echo "${GREEN}✅ Dry-run complete. Would execute: $BASE_MODEL${NC}"
    exit 0
fi

echo "${CYAN}🔮 Spawning '$PLUGIN_NAME' ($ROLE)${NC}"
echo "${YELLOW}   Model: $BASE_MODEL | Timeout: ${TIMEOUT}s | Max Tokens: $MAX_TOKENS${NC}"
echo "─────────────────────────────────────────────────────"

# Model routing
run_model() {
    local model="$1"
    
    case "$model" in
        claude*)
            # Anthropic Claude via claude CLI (Anthropic official)
            if command -v claude &>/dev/null; then
                echo "$FULL_PROMPT" | claude -p
                return $?
            else
                echo "${YELLOW}⚠️ Claude CLI not found${NC}"
                echo "$FULL_PROMPT"
                echo ""
                echo "${YELLOW}📋 Copy the above prompt to Cursor/Claude${NC}"
                return 0
            fi
            ;;
        gemini*)
            # Google Gemini via GMX or gemini CLI
            if command -v gemini &>/dev/null; then
                gemini --model "$model" <<< "$FULL_PROMPT"
                return $?
            elif [[ -f "$LUKA_BASE/tools/gmx_cli.py" ]]; then
                python3 "$LUKA_BASE/tools/gmx_cli.py" --prompt "$FULL_PROMPT"
                return $?
            else
                echo "${YELLOW}⚠️ Gemini CLI not found${NC}"
                echo "$FULL_PROMPT"
                echo ""
                echo "${YELLOW}📋 Copy the above prompt to Gemini/GMX${NC}"
                return 0
            fi
            ;;
        gpt*)
            # OpenAI GPT via Codex or openai CLI
            if command -v codex &>/dev/null; then
                codex run --input "$FULL_PROMPT"
                return $?
            elif command -v openai &>/dev/null; then
                openai api chat.completions.create -m "$model" -g user "$FULL_PROMPT"
                return $?
            else
                echo "${YELLOW}⚠️ OpenAI CLI not found${NC}"
                echo "$FULL_PROMPT"
                echo ""
                echo "${YELLOW}📋 Copy the above prompt to ChatGPT/Codex${NC}"
                return 0
            fi
            ;;
        *)
            echo "${RED}❌ Unknown model: $model${NC}"
            return 1
            ;;
    esac
}

# Execute with fallback
if run_model "$BASE_MODEL"; then
    log_invocation "SUCCESS" "$BASE_MODEL"
    echo ""
    echo "${GREEN}✅ Spawn complete${NC}"
else
    echo "${YELLOW}⚠️ Primary model failed, trying fallback: $FALLBACK_MODEL${NC}"
    if [[ -n "$FALLBACK_MODEL" ]] && run_model "$FALLBACK_MODEL"; then
        log_invocation "FALLBACK_SUCCESS" "$FALLBACK_MODEL"
        echo ""
        echo "${GREEN}✅ Spawn complete (fallback)${NC}"
    else
        log_invocation "FAILED" "$BASE_MODEL"
        echo "${RED}❌ Spawn failed${NC}"
        exit 1
    fi
fi
